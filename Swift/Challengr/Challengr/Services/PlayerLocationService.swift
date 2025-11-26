//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 26.11.25.
//

import Foundation

typealias PlayerData = [String: [String]]

let urlPlayers = URL(string: "http://localhost:8080/players")!

func loadPlayers() async throws -> PlayerData {
    let (data, _) = try await URLSession.shared.data(from: urlPlayers)
    let decoder = JSONDecoder()
    let challenges = try decoder.decode(ChallengeData.self, from: data)
    print("challenges loaded:", challenges)
    return challenges
}

