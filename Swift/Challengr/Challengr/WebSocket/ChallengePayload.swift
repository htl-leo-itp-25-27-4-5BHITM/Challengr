//
//  ChallengePayload.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

import Foundation

struct ChallengePayload: Codable, Sendable {
    let fromPlayerId: Int64
    let toPlayerId: Int64
    let fromPlayerName: String
    let category: String
    let challenge: String
}


