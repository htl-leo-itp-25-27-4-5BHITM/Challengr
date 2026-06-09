//
//  ShopView.swift
//  Challengr
//
//  Created by Julian Richter on 07.06.26.
//

import SwiftUI

struct ShopItem {
    let name: String
    let imageName: String
    let price: Int
    let rarity: ItemRarity
}

enum ItemRarity {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    
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
    
    private let shopItems = [
        // Legendary
        ShopItem(name: "Full Stealth Potion", imageName: "Unsichtbar 1", price: 800, rarity: .legendary),
        
        // Epic
        ShopItem(name: "Point Shield", imageName: "PunkteSchild 1", price: 600, rarity: .epic),
        ShopItem(name: "Streak Saver", imageName: "StreakSaver 1", price: 400, rarity: .epic),
        
        // Rare
        ShopItem(name: "Stealth Cloak", imageName: "StealthCloak 1", price: 300, rarity: .rare),
        ShopItem(name: "Rematch Ticket", imageName: "RematchTicket 1", price: 250, rarity: .rare),
        
        // Uncommon
        ShopItem(name: "Trophy Boost", imageName: "Energieflasche 1", price: 200, rarity: .uncommon),
        ShopItem(name: "Combo Booster", imageName: "ComboBooster 1", price: 150, rarity: .uncommon),
        
        // Common
        ShopItem(name: "Coin", imageName: "Coin 1", price: 50, rarity: .common),
        ShopItem(name: "Trophy", imageName: "Trophy 1", price: 100, rarity: .common)
    ]
    
    var body: some View {
        ZStack {
            Color.challengrDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Shop")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.challengrYellow)
                    }
                }
                .padding(20)
                .background(Color.challengrDark.opacity(0.8))
                
                // Grid of items
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 20) {
                        ForEach(shopItems, id: \.name) { item in
                            ShopItemView(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct ShopItemView: View {
    let item: ShopItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Rarity Badge - centered
            Text(rarityLabel(item.rarity))
                .font(.system(size: 7, weight: .bold))
                .tracking(-0.3)
                .foregroundColor(.challengrDark)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.rarity.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Item Image
            ZStack {
                Color.white.opacity(0.1)
                
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Item Name
            Text(item.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Price with Rarity Color
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(item.rarity.color)
                
                Text("\(item.price)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(item.rarity.color)
            }
            
            // Buy Button
            Button(action: {}) {
                Text("Kaufen")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.challengrDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.challengrYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func rarityLabel(_ rarity: ItemRarity) -> String {
        switch rarity {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}

#Preview {
    ShopView()
}
