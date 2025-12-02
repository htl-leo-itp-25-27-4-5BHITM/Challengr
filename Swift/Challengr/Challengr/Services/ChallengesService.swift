//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation

typealias ChallengeData = [String: [String]]

let baseURLString = "http://localhost:8080/api/challenges"

func loadChallenges() async throws -> ChallengeData {
    guard let url = URL(string: baseURLString) else {
        throw URLError(.badURL)
    }
    print("Lade alle Challenges von:", url.absoluteString)
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse {
        print("HTTP Status:", http.statusCode)
    }
    // Debug: roher JSON-String
    if let s = String(data: data, encoding: .utf8) {
        print("Raw response:", s)
    }
    let decoder = JSONDecoder()
    let challenges = try decoder.decode(ChallengeData.self, from: data)
    print("challenges loaded:", challenges)
    return challenges
}

struct Challenge: Codable {
    let id: Int
    let text: String
    let challengeCategory: Category
}

struct Category: Codable {
    let id: Int
    let name: String
    let description: String
}
struct CategoryChallenge: Codable {
    let description: String
    let tasks: [String]
}

func loadCategoryChallenges(category: String) async throws -> CategoryChallenge {
    let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category
    let url = URL(string: "http://localhost:8080/api/challenges/\(encodedCategory)")!

    print("Lade Kategorie '\(category)' von:", url.absoluteString)

    let (data, response) = try await URLSession.shared.data(from: url)

    if let http = response as? HTTPURLResponse {
        print("HTTP Status:", http.statusCode)
    }

    // Debug-Ausgabe
    if let raw = String(data: data, encoding: .utf8) {
        print("Raw response for category:", raw)
    }

    let decoder = JSONDecoder()

    // 1️⃣ Backend liefert ein ARRAY → wir decodieren ein Array
    let arr = try decoder.decode([Challenge].self, from: data)

    // 2️⃣ Beschreibung aus der ersten Challenge holen
    let description = arr.first?.challengeCategory.description ?? ""

    // 3️⃣ Alle Texte zusammenstellen
    let tasks = arr.map { $0.text }

    // 4️⃣ Ergebnis im Format von ChallengeDetailView
    return CategoryChallenge(description: description, tasks: tasks)
}
