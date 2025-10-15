//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation
let url = URL(string: "http://localhost:8080/challenge")!

func loadChallenges() async throws -> [Challenge] {
    var challenges: [Challenge] = []

    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    /*let optional = try? decoder.decode([Achievement].self, from: data)
    if optional != nil {
        achievements = optional!
    }*/
    if let tomatos = try? decoder.decode([Challenge].self, from: data) {
        challenges = tomatos
    }
    print("challenges loaded", data)
    return challenges;
}
