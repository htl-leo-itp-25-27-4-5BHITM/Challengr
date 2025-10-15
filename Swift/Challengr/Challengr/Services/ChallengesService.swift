//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation

typealias ChallengeData = [String: [String]]

let url = URL(string: "http://localhost:8080/challenge")!

func loadChallenges() async throws -> ChallengeData {
    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    let challenges = try decoder.decode(ChallengeData.self, from: data)
    print("challenges loaded:", challenges)
    return challenges
}
