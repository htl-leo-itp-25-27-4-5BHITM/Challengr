//
//  WebSocketService.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

//
//  WebSocketService.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//
/*
 import Foundation
 
 final class WebSocketService: ObservableObject {
 
 static let shared = WebSocketService()
 private var connection: WebSocketConnection<IncomingMessage, OutgoingMessage>?
 
 private init() {}
 
 // MARK: - Connect to WebSocket
 func connect(playerId: Int64) {
 guard connection == nil else { return }
 
 let url = URL(string: "ws://localhost:8080/channel?playerId=\(playerId)")!
 let task = URLSession.shared.webSocketTask(with: url)
 
 // WebSocketConnection initialisieren
 connection = WebSocketConnection<IncomingMessage, OutgoingMessage>(task: task)
 task.resume()
 
 // Hintergrund Task für Empfang starten
 Task {
 await listen()
 }
 }
 
 // MARK: - Send Message
 func send(_ message: OutgoingMessage) async {
 do {
 try await connection?.send(message)
 } catch {
 print("❌ WebSocket send error:", error)
 }
 }
 
 // MARK: - Listen for Incoming Messages
 private func listen() async {
 guard let connection else { return }
 
 do {
 for try await message in connection.receive() {
 await handle(message)
 }
 } catch {
 print("❌ WebSocket receive error:", error)
 }
 }
 
 // MARK: - Handle Incoming Message on MainActor
 @MainActor
 private func handle(_ message: IncomingMessage) {
 switch message {
 case .challengeAssigned(let payload):
 print("🔥 Challenge erhalten von \(payload.fromPlayerName)")
 NotificationCenter.default.post(
 name: .challengeReceived,
 object: payload
 )
 }
 }
 }
 
 // MARK: - Notification Extension
 extension Notification.Name {
 static let challengeReceived = Notification.Name("challengeReceived")
 }
 */
