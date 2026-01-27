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
            // Heller Hintergrund
            Color.challengrWhite
                .ignoresSafeArea()

            VStack(spacing: 32) {

                // TITLE
                Text("WER HAT GEWONNEN?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.challengrBlack)

                // VOTING BUTTONS
                VStack(spacing: 20) {
                    voteButton(
                        for: playerA,
                        color: .challengrYellow
                    )

                    voteButton(
                        for: playerB,
                        color: .chalengrRed
                    )
                }

                // FEEDBACK
                if let selected {
                    Text("DU HAST FÜR \(selected.uppercased()) GESTIMMT")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.challengrBlack)
                } else {
                    Text("TIPPE AUF EINEN SPIELER")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.challengrBlack.opacity(0.6))
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Vote Button
    private func voteButton(
        for name: String,
        color: Color
    ) -> some View {
        Button {
            selected = name
            onVote(name)
        } label: {
            Text(name.uppercased())
                .font(.system(size: 18, weight: .black))
                .tracking(1)
                .foregroundStyle(.challengrBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(color)
                )
        }
        .disabled(selected != nil)
        .opacity(selected == nil || selected == name ? 1 : 0.5)
    }
}
