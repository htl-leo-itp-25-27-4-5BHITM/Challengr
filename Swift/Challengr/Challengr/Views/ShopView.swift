//
//  ShopView.swift
//  Challengr
//
//  Created by Julian Richter on 07.06.26.
//

import SwiftUI

enum ItemRarity: String {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    init(backendValue: String) {
        self = ItemRarity(rawValue: backendValue.lowercased()) ?? .common
    }

    var label: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var color: Color {
        switch self {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.yellow
        }
    }
}

struct ShopView: View {
    @Environment(\.dismiss) var dismiss

    let ownPlayerId: String
    let initialPoints: Int
    /// Called whenever the player's points change (after a purchase), so the
    /// presenting screen (map HUD) can refresh its own balance.
    var onPointsChanged: (Int) -> Void = { _ in }

    @State private var items: [ShopItemDTO] = []
    @State private var ownedQuantities: [String: Int] = [:]
    @State private var currentPoints: Int
    @State private var isLoading = true
    @State private var purchasingCode: String? = nil
    @State private var toastMessage: String? = nil
    @State private var toastIsError = false

    init(ownPlayerId: String, initialPoints: Int, onPointsChanged: @escaping (Int) -> Void = { _ in }) {
        self.ownPlayerId = ownPlayerId
        self.initialPoints = initialPoints
        self.onPointsChanged = onPointsChanged
        _currentPoints = State(initialValue: initialPoints)
    }

    private let shopService = ShopService()

    var body: some View {
        ZStack {
            Color.challengrDark.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.challengrYellow)
                    Spacer()
                } else if items.isEmpty {
                    Spacer()
                    Text("Shop ist gerade nicht erreichbar.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(items) { item in
                                ShopItemView(
                                    item: item,
                                    ownedQuantity: ownedQuantities[item.code] ?? 0,
                                    canAfford: currentPoints >= item.price,
                                    isPurchasing: purchasingCode == item.code
                                ) {
                                    Task { await purchase(item) }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }

            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(.challengrDark)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(toastIsError ? Color.challengrRed : Color.challengrGreen)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await loadShop() }
    }

    // MARK: - Header (Kopfbereich)

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SHOP")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.challengrYellow)
                    Text("\(currentPoints) PUNKTE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.challengrYellow)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.challengrYellow)
            }
        }
        .padding(20)
        .background(Color.challengrDark.opacity(0.8))
    }

    // MARK: - Data loading (Daten laden)

    private func loadShop() async {
        isLoading = true
        async let itemsAsync = shopService.loadItems()
        async let ownedAsync = shopService.loadOwnedItems(playerId: ownPlayerId)

        let loadedItems = (try? await itemsAsync) ?? []
        let owned = (try? await ownedAsync) ?? []

        await MainActor.run {
            items = loadedItems
            ownedQuantities = Dictionary(uniqueKeysWithValues: owned.map { ($0.itemCode, $0.quantity) })
            isLoading = false
        }
    }

    private func purchase(_ item: ShopItemDTO) async {
        guard purchasingCode == nil else { return }
        guard currentPoints >= item.price else {
            showToast("Nicht genug Punkte", isError: true)
            return
        }

        await MainActor.run { purchasingCode = item.code }

        do {
            let result = try await shopService.purchase(playerId: ownPlayerId, itemCode: item.code)
            await MainActor.run {
                purchasingCode = nil
                if result.success {
                    currentPoints = result.remainingPoints
                    ownedQuantities[item.code] = result.newQuantity
                    onPointsChanged(result.remainingPoints)
                    SoundManager.shared.playSound("COIN_02")
                    showToast("\(item.name) gekauft!", isError: false)
                } else {
                    currentPoints = result.remainingPoints
                    showToast(result.message, isError: true)
                }
            }
        } catch {
            await MainActor.run {
                purchasingCode = nil
                showToast("Kauf fehlgeschlagen", isError: true)
            }
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toastMessage = message
            toastIsError = isError
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }
}

struct ShopItemView: View {
    let item: ShopItemDTO
    let ownedQuantity: Int
    let canAfford: Bool
    let isPurchasing: Bool
    let onBuy: () -> Void

    private var rarity: ItemRarity { ItemRarity(backendValue: item.rarity) }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(rarity.label.uppercased())
                    .font(.system(size: 7, weight: .black))
                    .tracking(0.4)
                    .foregroundColor(.challengrDark)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rarity.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                if ownedQuantity > 0 {
                    Text("x\(ownedQuantity)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.challengrGreen)
                }
            }

            ZStack {
                Color.white.opacity(0.08)

                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(rarity.color.opacity(0.5), lineWidth: 1.5)
            )

            Text(item.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)

            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(rarity.color)

                Text("\(item.price)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(rarity.color)
            }

            Button(action: onBuy) {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.challengrDark)
                    } else {
                        Text("KAUFEN")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(0.5)
                    }
                }
                .foregroundColor(.challengrDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(canAfford ? Color.challengrYellow : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!canAfford || isPurchasing)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(canAfford ? 1.0 : 0.75)
    }
}

#Preview {
    ShopView(ownPlayerId: "demo-1", initialPoints: 500)
}
