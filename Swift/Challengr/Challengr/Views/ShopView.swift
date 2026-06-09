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
    let price: Int = 100
}

struct ShopView: View {
    @Environment(\.dismiss) var dismiss
    
    private let shopItems = [
        ShopItem(name: "Coin", imageName: "Coin"),
        ShopItem(name: "Combo Booster", imageName: "ComboBooster"),
        ShopItem(name: "Energieflasche", imageName: "Energieflasche"),
        ShopItem(name: "Punkte Schild", imageName: "PunkteSchild"),
        ShopItem(name: "Rematch Ticket", imageName: "RematchTicket"),
        ShopItem(name: "Stealth Cloak", imageName: "StealthCloak"),
        ShopItem(name: "Streak Saver", imageName: "StreakSaver"),
        ShopItem(name: "Trophy", imageName: "Trophy"),
        ShopItem(name: "Unsichtbar", imageName: "Unsichtbar")
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
            // Item Image
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Item Name
            Text(item.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Price
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.challengrYellow)
                
                Text("\(item.price)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.challengrYellow)
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
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ShopView()
}
