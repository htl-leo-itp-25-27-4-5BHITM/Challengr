import Foundation

// MARK: - DTOs (matches boundary/ShopResources.java on the backend)

struct ShopItemDTO: Codable, Identifiable {
    let id: Int64
    let code: String
    let name: String
    let imageName: String
    let price: Int
    let rarity: String
}

struct PlayerItemDTO: Codable {
    let itemCode: String
    let quantity: Int
}

struct PurchaseResultDTO: Codable {
    let success: Bool
    let message: String
    let remainingPoints: Int
    let itemCode: String?
    let newQuantity: Int
}

private struct PurchaseRequestDTO: Codable {
    let itemCode: String
}

// MARK: - Service (Service)

final class ShopService {
    private let baseURL = BackendConfig.apiURL("api/shop")

    func loadItems() async throws -> [ShopItemDTO] {
        let url = baseURL.appendingPathComponent("items")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([ShopItemDTO].self, from: data)
    }

    func loadOwnedItems(playerId: String) async throws -> [PlayerItemDTO] {
        let url = baseURL
            .appendingPathComponent("players")
            .appendingPathComponent(playerId)
            .appendingPathComponent("items")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PlayerItemDTO].self, from: data)
    }

    func purchase(playerId: String, itemCode: String) async throws -> PurchaseResultDTO {
        let url = baseURL
            .appendingPathComponent("players")
            .appendingPathComponent(playerId)
            .appendingPathComponent("purchase")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PurchaseRequestDTO(itemCode: itemCode))

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(PurchaseResultDTO.self, from: data)
    }
}
