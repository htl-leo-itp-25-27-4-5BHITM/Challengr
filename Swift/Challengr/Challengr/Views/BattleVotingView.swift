//
//  BattleVotingView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 27.01.26.
//


import SwiftUI

struct BattleVotingView: View {
    let playerA: String
    let playerB: String
    let onVote: (String) -> Void

    @State private var selected: String? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Wer hat gewonnen?")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    voteButton(for: playerA)
                    voteButton(for: playerB)
                }

                if let selected {
                    Text("Du hast für \(selected) gestimmt.")
                        .foregroundColor(.gray)
                        .font(.footnote)
                } else {
                    Text("Tippe auf einen Spieler, um abzustimmen.")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            }
            .padding()
        }
    }

    private func voteButton(for name: String) -> some View {
        Button {
            selected = name
            onVote(name)
        } label: {
            Text(name)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(selected == name ? Color.green : Color.red)
                .cornerRadius(12)
        }
    }
}
