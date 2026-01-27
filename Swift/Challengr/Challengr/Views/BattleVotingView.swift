import SwiftUI

struct BattleVotingView: View {
    let playerA: String
    let playerB: String
    let onVote: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Wer hat gewonnen?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Button(playerA) {
                    onVote(playerA)
                }
                .buttonStyle(.borderedProminent)

                Button(playerB) {
                    onVote(playerB)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("Warte auf Abstimmung des Gegners…")
                    .foregroundColor(.gray)
                    .padding(.top, 16)
            }
            .padding()
        }
    }
}
