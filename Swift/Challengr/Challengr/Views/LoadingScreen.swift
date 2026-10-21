import SwiftUI

/// Lade-Screen im Challengr-Look (beim Start mit gespeichertem Login und beim Laden des Profils).
struct LoadingScreen: View {
    var error: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = 0.0
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.00, blue: 0.04),
                                    Color(red: 0.18, green: 0.02, blue: 0.08),
                                    Color(red: 0.73, green: 0.12, blue: 0.20).opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.challengrYellow.opacity(0.18))
                        .frame(width: pulse ? 150 : 128, height: pulse ? 150 : 128)
                        .blur(radius: 14)
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.challengrYellow.opacity(0.5), radius: 20)
                }

                Text("CHALLENGR")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundColor(.white)

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    // drehende Münze statt grauem Spinner
                    Image("MenuCoin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                        .padding(.top, 8)
                        .accessibilityLabel("Lädt")
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { spin = 360 }
        }
    }
}
