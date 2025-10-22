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

struct CategoryChallenge: Codable {
    let description: String
    let tasks: [String]
}

func loadCategoryChallenges(category: String) async throws -> CategoryChallenge {
    let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
    let url = URL(string: "http://localhost:8080/challenge/\(encodedCategory)")!

    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    return try decoder.decode(CategoryChallenge.self, from: data)
}
