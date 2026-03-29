//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//
import Foundation
final class ChallengesService {

    private let baseURL = BackendConfig.apiURL("api/challenges")

    // Optional: Falls du wirklich noch alle Challenges brauchst
    func loadChallenges() async throws -> [ChallengeDTO] {
        let (data, response) = try await URLSession.shared.data(from: baseURL)

        if let http = response as? HTTPURLResponse {
            print("HTTP Status:", http.statusCode)
        }
        if let s = String(data: data, encoding: .utf8) {
            print("Raw response:", s)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([ChallengeDTO].self, from: data)
    }

    // Neue Hauptfunktion: Challenges für eine Kategorie laden
    func loadCategoryChallenges(category: String) async throws -> [ChallengeDTO] {
        let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category
        let url = baseURL.appendingPathComponent(encodedCategory)

        print("Lade Kategorie '\(category)' von:", url.absoluteString)

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse {
            print("HTTP Status:", http.statusCode)
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("Raw response for category:", raw)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([ChallengeDTO].self, from: data)
    }
}
