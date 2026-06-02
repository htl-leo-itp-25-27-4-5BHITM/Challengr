import Foundation
import Combine

final class GameSocketService: ObservableObject {

    private static let ownershipQueue = DispatchQueue(label: "gamesocket.ownership.queue")
    private static var activeOwnerByPlayerId: [String: UUID] = [:]

    // MARK: - Configuration (Konfiguration)

    private let playerId: String
    private let instanceId = UUID()
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    private var reconnectWorkItem: DispatchWorkItem?
    private var isManualDisconnect = false
    private var reconnectAttempt: Int = 0
    private var pendingMessages: [String] = []
    private let maxPendingMessages = 30
    private var pingTimer: DispatchSourceTimer?

    // MARK: - Event callbacks (Event-Callbacks)

    /// Called when a battle request arrives (Aufgerufen bei Battle-Anfrage)
    /// Parameters: battleId, fromId, toId, challengeId, targetLat, targetLon
    var onChallengeReceived: ((Int64, String, String, Int64, Double?, Double?) -> Void)?
    /// Called when a battle reaches ACCEPTED (Aufgerufen bei Status ACCEPTED)
    var onBattleAccepted: ((Int64) -> Void)?
    /// Called when the battle is ready for voting (Bereit fürs Voting)
    var onReadyForVoting: ((Int64) -> Void)?
    /// Called on generic status updates (Generische Status-Updates)
    var onBattleUpdatedStatus: ((Int64, String) -> Void)?
    /// Called when battle is pending (Battle pending)
    var onBattlePending: ((Int64) -> Void)?
    /// Called when a knowledge question arrives (Wissensfrage empfangen)
    var onKnowledgeQuestion: ((Int64, ChallengeDTO) -> Void)?



    
    init(playerId: String) {
        self.playerId = playerId
    }
    
    var onBattleResult: ((BattleResultData) -> Void)?

    // MARK: - Connect / Disconnect (Verbinden / Trennen)

    private func claimSocketOwnership() {
        Self.ownershipQueue.sync {
            Self.activeOwnerByPlayerId[playerId] = instanceId
        }
    }

    private func releaseSocketOwnershipIfNeeded() {
        Self.ownershipQueue.sync {
            if Self.activeOwnerByPlayerId[playerId] == instanceId {
                Self.activeOwnerByPlayerId[playerId] = nil
            }
        }
    }

    private func isCurrentOwner() -> Bool {
        Self.ownershipQueue.sync {
            Self.activeOwnerByPlayerId[playerId] == instanceId
        }
    }

    private func openConnectionIfNeeded() {
        guard webSocketTask == nil else { return }

        let url = BackendConfig.gameWebSocketURL(playerId: playerId)
        print("🔎 WS URL for \(playerId): \(url.absoluteString)")

        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        print("🔌 WS connect für Player \(playerId)")

        startPing()
        receive()

        // If we already queued messages before connect(), try flushing shortly after.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.flushPendingMessages()
        }
    }

    func connect() {
        isManualDisconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        claimSocketOwnership()
        openConnectionIfNeeded()
    }

    private func flushPendingMessages() {
        guard let task = webSocketTask else { return }
        guard !pendingMessages.isEmpty else { return }

        let toSend = pendingMessages
        pendingMessages.removeAll()
        print("📦 WS flush queued messages: \(toSend.count)")

        for text in toSend {
            task.send(.string(text)) { error in
                if let error = error {
                    print("❌ WS flush send error:", error)
                    self.webSocketTask = nil
                    self.scheduleReconnect()
                }
            }
        }
    }

    func disconnect() {
        isManualDisconnect = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectAttempt = 0
        stopPing()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        releaseSocketOwnershipIfNeeded()
    }

    private func scheduleReconnect() {
        guard !isManualDisconnect else { return }
        guard isCurrentOwner() else { return }
        guard reconnectWorkItem == nil else { return }

        stopPing()

        // Cancel any existing task so we always reconnect from a clean state.
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        reconnectAttempt = min(reconnectAttempt + 1, 6)
        // 1s, 2s, 4s, 8s, 16s, 30s...
        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 30.0)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            guard self.isCurrentOwner(), !self.isManualDisconnect else { return }
            self.openConnectionIfNeeded()
        }

        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        print("🔁 WS reconnect scheduled for player \(playerId) in \(delay)s (attempt \(reconnectAttempt))")
    }

    // MARK: - Keepalive ping

    private func startPing() {
        stopPing()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.sendPing()
        }
        pingTimer = timer
        timer.resume()
    }

    private func stopPing() {
        pingTimer?.setEventHandler {}
        pingTimer?.cancel()
        pingTimer = nil
    }

    private func sendPing() {
        guard let task = webSocketTask else { return }
        task.sendPing { [weak self] error in
            guard let self else { return }
            if let error {
                print("🏓 WS ping failed:", error)
                self.webSocketTask = nil
                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Send messages (Senden)

    func sendCreateBattle(fromId: String, toId: String, challengeId: Int64) {
        let payload: [String: Any] = [
            "type": "create-battle",
            "fromId": fromId,
            "toId": toId,
            "challengeId": challengeId
        ]
        send(json: payload)
    }

    func sendUpdateBattleStatus(battleId: Int64, status: String) {
        let payload: [String: Any] = [
            "type": "update-battle-status",
            "battleId": battleId,
            "status": status
        ]
        send(json: payload)
    }

    private func send(json: [String: Any]) {
        guard let task = webSocketTask else {
            // Queue and auto-connect (prevents lost messages when connection isn't up yet)
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                let text = String(data: data, encoding: .utf8) ?? ""

                if pendingMessages.count >= maxPendingMessages {
                    pendingMessages.removeFirst()
                }
                pendingMessages.append(text)

                if let type = json["type"] as? String {
                    print("⚠️ WS not connected yet, queued (\(type))")
                } else {
                    print("⚠️ WS not connected yet, queued message")
                }

                // Try to connect if not connected
                connect()
            } catch {
                print("❌ JSON serialisation error:", error)
            }
            return
        }
        // Ensure the underlying task is running (at least resumed)
        // URLSessionWebSocketTask doesn't expose a public readyState, but we can
        // still try-catch send errors and log the task description for debugging.
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let text = String(data: data, encoding: .utf8) ?? ""

            // Debug: log outgoing messages (helps verify button actions are really sending)
            if let type = json["type"] as? String {
                print("📤 WS send (\(type)): \(text)")
            } else {
                print("📤 WS send: \(text)")
            }

            task.send(.string(text)) { error in
                if let error = error {
                    print("❌ WS send error:", error)
                    // If send failed due to disconnected socket, nil out and schedule reconnect
                    self.webSocketTask = nil
                    self.scheduleReconnect()

                    // Queue the message so it can be sent after reconnect
                    if self.pendingMessages.count >= self.maxPendingMessages {
                        self.pendingMessages.removeFirst()
                    }
                    self.pendingMessages.append(text)
                } else {
                    print("✅ WS send ok")
                }
            }
        } catch {
            print("❌ JSON serialisation error:", error)
        }
    }
    
    func sendVote(battleId: Int64, winnerName: String) {
        let payload: [String: Any] = [
            "type": "battle-vote",
            "battleId": battleId,
            "winnerName": winnerName
        ]
        send(json: payload)
    }
    
    func sendKnowledgeAnswer(battleId: Int64, answerIndex: Int) {
        let payload: [String: Any] = [
            "type": "battle-answer",
            "battleId": battleId,
            "answerIndex": answerIndex
        ]
        send(json: payload)
    }
    
    func sendSprintResult(battleId: Int64, distance: Double) {
        let payload: [String: Any] = [
            "type": "sprint-result",
            "battleId": battleId,
            "distance": distance
        ]
        print("📤 sendSprintResult:", payload)    // Debug
        send(json: payload)
    }
    
    func sendLoudnessResult(battleId: Int64, loudness: Double) {
        let payload: [String: Any] = [
            "type": "loudness-result",
            "battleId": battleId,
            "loudness": loudness
        ]
        print("📤 sendLoudnessResult:", payload)    // Debug
        send(json: payload)
    }

    func sendShakeResult(battleId: Int64, shakes: Int) {
        let payload: [String: Any] = [
            "type": "shake-result",
            "battleId": battleId,
            "shakes": shakes
        ]
        print("📤 sendShakeResult:", payload)
        send(json: payload)
    }

    func sendPushupResult(battleId: Int64, reps: Int) {
        let payload: [String: Any] = [
            "type": "pushup-result",
            "battleId": battleId,
            "reps": reps
        ]
        print("📤 sendPushupResult:", payload)
        send(json: payload)
    }

    func sendCompassResult(battleId: Int64, distance: Double) {
        let payload: [String: Any] = [
            "type": "compass-result",
            "battleId": battleId,
            "distance": distance
        ]
        print("📤 sendCompassResult:", payload)
        send(json: payload)
    }

    func sendCameraResult(battleId: Int64, score: Double) {
        let payload: [String: Any] = [
            "type": "camera-result",
            "battleId": battleId,
            "score": score
        ]
        print("📤 sendCameraResult:", payload)
        send(json: payload)
    }

    // MARK: - Receive messages (Empfangen)

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("WS receive error:", error)
                self.scheduleReconnect()
                // IMPORTANT: don't call receive() again on failure.
                // scheduleReconnect() will create a new task and restart receive().
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    print("WS message:", text)
                    self.handleIncoming(text: text)
                case .data(let data):
                    print("WS binary, bytes:", data.count)
                @unknown default:
                    break
                }
            }
            // weiter zuhören
            self.receive()
        }
    }

    // Whenever we get any message, we know the socket is alive; flush any queued sends.
    private func handleIncoming(text: String) {
        reconnectAttempt = 0
        flushPendingMessages()

        guard let data = text.data(using: .utf8) else { return }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }

            if type == "battle-requested" {
                let battleId    = (json["battleId"] as? NSNumber)?.int64Value ?? 0
                let fromId      = parsePlayerId(json["fromPlayerId"])
                let toId        = parsePlayerId(json["toPlayerId"])
                let challengeId = (json["challengeId"] as? NSNumber)?.int64Value ?? 0

                let targetLat   = json["targetLatitude"] as? Double
                let targetLon   = json["targetLongitude"] as? Double

                print("🔹 battle-requested targetLat=\(targetLat as Any), targetLon=\(targetLon as Any)")

                onChallengeReceived?(battleId, fromId, toId, challengeId, targetLat, targetLon)
            }

            if type == "battle-updated" {
                let battleId = (json["battleId"] as? NSNumber)?.int64Value ?? 0
                let status   = json["status"] as? String ?? ""

                print("🔁 battle-updated empfangen:", battleId, status)

                if status == "ACCEPTED" {
                    DispatchQueue.main.async { self.onBattleAccepted?(battleId) }
                } else if status == "READY_FOR_VOTING" {
                    DispatchQueue.main.async { self.onReadyForVoting?(battleId) }
                } else {
                    DispatchQueue.main.async {
                        self.onBattleUpdatedStatus?(battleId, status)
                    }
                }
            }

            if type == "battle-pending" {
                let battleId = (json["battleId"] as? NSNumber)?.int64Value ?? 0
                print("🔄 battle-pending empfangen:", battleId)   // <--
                DispatchQueue.main.async {
                    self.onBattlePending?(battleId)
                }
            }

            // Result after voting (Ergebnis nach Voting)
            if type == "battle-result" {
                let winnerName = json["winnerName"] as? String ?? ""
                let loserName  = json["loserName"]  as? String ?? ""
                let winnerDelta = json["winnerPointsDelta"] as? Int ?? 0
                let loserDelta  = json["loserPointsDelta"]  as? Int ?? 0
                let trashTalk   = json["trashTalk"] as? String ?? "Good game!"
                let metrics = parseBattleMetrics(from: json)

                let result = BattleResultData(
                    winnerName: winnerName,
                    winnerAvatar: "opponentAvatar",
                    winnerPointsDelta: winnerDelta,
                    loserName: loserName,
                    loserAvatar: "ownAvatar",
                    loserPointsDelta: loserDelta,
                    trashTalk: trashTalk,
                    metrics: metrics
                )

                DispatchQueue.main.async {
                    self.onBattleResult?(result)
                }
            }

            if type == "battle-question" {
                let battleId = (json["battleId"] as? NSNumber)?.int64Value ?? 0

                guard let challengeJson = json["challenge"] as? [String: Any] else { return }

                let id       = (challengeJson["id"] as? NSNumber)?.int64Value ?? 0
                let text     = challengeJson["text"] as? String ?? ""
                let category = challengeJson["category"] as? String ?? ""
                let choices  = challengeJson["choices"] as? [String]
                let correct  = challengeJson["correctIndex"] as? Int

                let dto = ChallengeDTO(
                    id: id,
                    text: text,
                    category: category,
                    choices: choices,
                    correctIndex: correct
                )

                DispatchQueue.main.async {
                    self.onKnowledgeQuestion?(battleId, dto)
                }
            }

        } catch {
            print("Error parsing WS JSON:", error)
        }
    }

    deinit {
        stopPing()
        disconnect()
    }

    private func parsePlayerId(_ value: Any?) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        return ""
    }

    private func parseBattleMetrics(from json: [String: Any]) -> BattleMetrics? {
        guard let metricsJson = json["metrics"] as? [String: Any] else { return nil }

        let sprint = parseDoubleMetric(metricsJson["sprint"])
        let loudness = parseDoubleMetric(metricsJson["loudness"])
        let compass = parseDoubleMetric(metricsJson["compass"])
        let shake = parseIntMetric(metricsJson["shake"])
        let pushup = parseIntMetric(metricsJson["pushup"])

        if sprint == nil, loudness == nil, compass == nil, shake == nil, pushup == nil {
            return nil
        }

        return BattleMetrics(
            sprint: sprint,
            loudness: loudness,
            compass: compass,
            shake: shake,
            pushup: pushup
        )
    }

    private func parseDoubleMetric(_ value: Any?) -> BattleMetricPair<Double>? {
        guard let dict = value as? [String: Any],
              let winner = (dict["winner"] as? NSNumber)?.doubleValue,
              let loser = (dict["loser"] as? NSNumber)?.doubleValue else { return nil }
        return BattleMetricPair(winner: winner, loser: loser)
    }

    private func parseIntMetric(_ value: Any?) -> BattleMetricPair<Int>? {
        guard let dict = value as? [String: Any],
              let winner = (dict["winner"] as? NSNumber)?.intValue,
              let loser = (dict["loser"] as? NSNumber)?.intValue else { return nil }
        return BattleMetricPair(winner: winner, loser: loser)
    }
}
