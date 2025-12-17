//
//  IncomingMessage.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

import Foundation

enum IncomingMessage: Decodable, Sendable {
    case challengeAssigned(ChallengePayload)

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "challengeAssigned":
            let payload = try container.decode(ChallengePayload.self, forKey: .payload)
            self = .challengeAssigned(payload)
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unknown type \(type)")
            )
        }
    }
}



