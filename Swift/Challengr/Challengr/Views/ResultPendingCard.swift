import SwiftUI
import Combine

/// Shown briefly while the backend/voting decides a battle's outcome.
/// Replaces a static spinner with a bit of "juice" so the wait feels
/// like part of the game rather than a stalled loading screen.
struct ResultPendingCard: View {
    @State private var trophyScale: CGFloat = 0.9
    @State private var trophyRotation: Angle = .degrees(-8)
    @State private var dotCount: Int = 0

    private let dotTimer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    private var dots: String {
        String(repeating: ".", count: dotCount)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.challengrYellow.opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 6)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.challengrYellow)
                    .scaleEffect(trophyScale)
                    .rotationEffect(trophyRotation)
            }

            Text("ERGEBNIS WIRD BERECHNET\(dots)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(.white)
                .frame(minWidth: 220)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                trophyScale = 1.12
                trophyRotation = .degrees(8)
            }
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ResultPendingCard()
    }
}
