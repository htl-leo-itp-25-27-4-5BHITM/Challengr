//
//  OutgoingMessage.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

import Foundation

enum OutgoingMessage: Encodable, Sendable {
    case challengeAssigned(
        fromPlayerId: Int64,
        toPlayerId: Int64,
        fromPlayerName: String,
        category: String,
        challenge: String
    )

    enum CodingKeys: String, CodingKey { case type, payload }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .challengeAssigned(fromId, toId, name, category, challenge):
            try container.encode("challengeAssigned", forKey: .type)
            try container.encode(
                ChallengePayload(
                    fromPlayerId: fromId,
                    toPlayerId: toId,
                    fromPlayerName: name,
                    category: category,
                    challenge: challenge
                ),
                forKey: .payload
            )
        }
    }
}

