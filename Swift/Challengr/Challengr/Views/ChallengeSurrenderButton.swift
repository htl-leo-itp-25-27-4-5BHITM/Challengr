import SwiftUI

/// "Aufgeben" für Challenge-Screens: wer eine laufende Challenge verlässt, gibt auf.
/// So kann man nicht mehr aus einer iPhone-Challenge raus, ohne dass das Battle endet.
struct ChallengeSurrenderButton: View {
    let battleId: Int64
    let socket: GameSocketService
    /// Nach dem Aufgeben (Screen schließen – das Ergebnis kommt vom Server).
    let onSurrendered: () -> Void

    @State private var confirm = false

    var body: some View {
        Button {
            confirm = true
        } label: {
            Text("AUFGEBEN")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(.white.opacity(0.85))
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.challengrRed.opacity(0.8), lineWidth: 2)
                )
        }
        .confirmationDialog("Wirklich aufgeben?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Aufgeben", role: .destructive) {
                socket.sendUpdateBattleStatus(battleId: battleId, status: "DONE_SURRENDER")
                onSurrendered()
            }
            Button("Weiterspielen", role: .cancel) {}
        } message: {
            Text("Dein Gegner gewinnt dann das Battle.")
        }
    }
}
