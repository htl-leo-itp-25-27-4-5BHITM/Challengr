//
//  WebSocketConnection.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

import Foundation

public enum WebSocketConnectionError: Error {
    case connectionError
    case transportError
    case encodingError
    case decodingError
    case disconnected
    case closed
}

public final class WebSocketConnection<
    Incoming: Decodable & Sendable,
    Outgoing: Encodable & Sendable
>: NSObject, Sendable {

    private let task: URLSessionWebSocketTask
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(task: URLSessionWebSocketTask) {
        self.task = task
        super.init()
        task.resume()
    }

    deinit {
        task.cancel(with: .goingAway, reason: nil)
    }

    func send(_ message: Outgoing) async throws {
        let data = try encoder.encode(message)
        try await task.send(.data(data))
    }

    func receiveOnce() async throws -> Incoming {
        let message = try await task.receive()
        switch message {
        case .data(let data):
            return try decoder.decode(Incoming.self, from: data)
        case .string(let text):
            guard let data = text.data(using: .utf8) else {
                throw WebSocketConnectionError.decodingError
            }
            return try decoder.decode(Incoming.self, from: data)
        @unknown default:
            throw WebSocketConnectionError.transportError
        }
    }

    func receive() -> AsyncThrowingStream<Incoming, Error> {
        AsyncThrowingStream {
            try await self.receiveOnce()
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

