//
//  ChallengeRealtimeService.swift
//  Challengr
//
//  Created by Dominik Binder on 17.12.25.
//

import Foundation

final class ChallengeRealtimeService {

    func sendChallenge(
        fromPlayerId: Int64,
        toPlayerId: Int64,
        fromPlayerName: String,
        category: String,
        challenge: String
    ) async {

        let msg = OutgoingMessage.challengeAssigned(
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
            fromPlayerName: fromPlayerName,
            category: category,
            challenge: challenge
        )

        await WebSocketService.shared.send(msg)
    }
}
