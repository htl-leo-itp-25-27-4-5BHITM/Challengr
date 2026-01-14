import Foundation
import Combine

final class GameSocketService: ObservableObject {

    private let playerId: Int64
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)

    // Wird aufgerufen, wenn eine Battle-Anfrage reinkommt
    // battleId, fromId, toId, challengeId
    var onChallengeReceived: ((Int64, Int64, Int64, Int64) -> Void)?

    init(playerId: Int64) {
        self.playerId = playerId
    }

    // MARK: - Connect / Disconnect

    func connect() {
        guard webSocketTask == nil else { return }

        guard let url = URL(string: "ws://localhost:8080/ws/game?playerId=\(playerId)") else {
            print("❌ Ungültige WebSocket-URL")
            return
        }

        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        print("🔌 WS connect für Player \(playerId)")
        receive()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Senden

    func sendCreateBattle(fromId: Int64, toId: Int64, challengeId: Int64) {
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
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let text = String(data: data, encoding: .utf8) ?? ""
            task.send(.string(text)) { error in
                if let error = error {
                    print("❌ WS send error:", error)
                }
            }
        } catch {
            print("❌ JSON serialisation error:", error)
        }
    }

    // MARK: - Empfangen

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("WS receive error:", error)
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

            // JSON vom Server:
            // {
            //   "type": "battle-requested",
            //   "battleId": 10,
            //   "fromPlayerId": 3,
            //   "toPlayerId": 1,
            //   "challengeId": 7,
            //   "status": "REQUESTED"
            // }
            if type == "battle-requested" {
                let battleId = (json["battleId"] as? NSNumber)?.int64Value ?? 0
                let fromId = (json["fromPlayerId"] as? NSNumber)?.int64Value ?? 0
                let toId = (json["toPlayerId"] as? NSNumber)?.int64Value ?? 0
                let challengeId = (json["challengeId"] as? NSNumber)?.int64Value ?? 0
                onChallengeReceived?(battleId, fromId, toId, challengeId)
            }

            // Optional: weitere Typen wie "battle-updated" usw. hier auswerten

        } catch {
            print("Error parsing WS JSON:", error)
        }
    }

    deinit {
        disconnect()
    }
}
