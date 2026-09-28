//
//  ChallengesService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//
import Foundation

final class ChallengesService {

    // MARK: - Configuration (Konfiguration)

    private let baseURL = BackendConfig.apiURL("api/challenges")

    // MARK: - Fetching (Laden)

    /// Loads challenges for a single category (Challenges pro Kategorie laden)
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

    /// Loads a single challenge by id (Einzelne Challenge per ID laden)
    func loadChallenge(id: Int64) async throws -> ChallengeDTO {
        let url = baseURL.appendingPathComponent("id").appendingPathComponent(String(id))
        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ChallengeDTO.self, from: data)
    }
}
