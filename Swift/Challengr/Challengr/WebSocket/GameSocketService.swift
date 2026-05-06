import Foundation
import Combine

final class GameSocketService: ObservableObject {

    // MARK: - Configuration (Konfiguration)

    private let playerId: String
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)
    private var reconnectWorkItem: DispatchWorkItem?
    private var isManualDisconnect = false

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

    func connect() {
        isManualDisconnect = false
        reconnectWorkItem?.cancel()
        guard webSocketTask == nil else { return }

        let url = BackendConfig.gameWebSocketURL(playerId: playerId)

        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        print("🔌 WS connect für Player \(playerId)")
        receive()
    }

    func disconnect() {
        isManualDisconnect = true
        reconnectWorkItem?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func scheduleReconnect() {
        guard !isManualDisconnect else { return }
        guard reconnectWorkItem == nil else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            self.webSocketTask = nil
            self.connect()
        }

        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        print("🔁 WS reconnect scheduled for player \(playerId)")
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
            print("❌ send() ohne aktive WebSocket-Verbindung")
            return
        }
        // Ensure the underlying task is running (at least resumed)
        // URLSessionWebSocketTask doesn't expose a public readyState, but we can
        // still try-catch send errors and log the task description for debugging.
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let text = String(data: data, encoding: .utf8) ?? ""
            task.send(.string(text)) { error in
                if let error = error {
                    print("❌ WS send error:", error)
                    // If send failed due to disconnected socket, nil out and schedule reconnect
                    self.webSocketTask = nil
                    self.scheduleReconnect()
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

    // MARK: - Receive messages (Empfangen)

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("WS receive error:", error)
                self.webSocketTask = nil
                self.scheduleReconnect()
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

    private func handleIncoming(text: String) {
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

                let result = BattleResultData(
                    winnerName: winnerName,
                    winnerAvatar: "opponentAvatar",
                    winnerPointsDelta: winnerDelta,
                    loserName: loserName,
                    loserAvatar: "ownAvatar",
                    loserPointsDelta: loserDelta,
                    trashTalk: trashTalk
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
        disconnect()
    }

    private func parsePlayerId(_ value: Any?) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        return ""
    }
}
