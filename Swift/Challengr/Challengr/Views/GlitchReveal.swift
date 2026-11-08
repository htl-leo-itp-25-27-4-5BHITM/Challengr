import SwiftUI

/// Das Geheimnis ist gelüftet: der Bildschirm flackert, Glitch bricht aus dem Trainings-Dummy aus.
struct GlitchReveal: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var broken = false

    private let cyan = Color(red: 0.18, green: 0.95, blue: 1.0)
    private let magenta = Color(red: 1.0, green: 0.18, blue: 0.6)

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let jitter = reduceMotion ? 0 : CGFloat(sin(t * 37) * 6)
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                // Störstreifen
                if !reduceMotion {
                    ForEach(0..<6, id: \.self) { i in
                        Rectangle()
                            .fill(i % 2 == 0 ? cyan.opacity(0.25) : magenta.opacity(0.25))
                            .frame(height: CGFloat(4 + (i * 7) % 18))
                            .offset(y: CGFloat(sin(t * Double(3 + i) + Double(i)) * 320))
                    }
                }

                VStack(spacing: 16) {
                    Text(broken ? "GLITCH IST AUSGEBROCHEN" : "F E H L E R   I M   D U M M Y")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: cyan, radius: 0, x: -2 + jitter * 0.3, y: 0)
                        .shadow(color: magenta, radius: 0, x: 2 - jitter * 0.3, y: 0)

                    ZStack {
                        Image(GameCharacter.crashDummy.imageName)
                            .resizable().scaledToFit()
                            .opacity(broken ? 0 : 1)
                            .offset(x: jitter)
                        Image(GameCharacter.glitch.imageName)
                            .resizable().scaledToFit()
                            .colorMultiply(cyan).opacity(broken ? 0.6 : 0)
                            .offset(x: -6 - jitter)
                        Image(GameCharacter.glitch.imageName)
                            .resizable().scaledToFit()
                            .colorMultiply(magenta).opacity(broken ? 0.6 : 0)
                            .offset(x: 6 + jitter)
                        Image(GameCharacter.glitch.imageName)
                            .resizable().scaledToFit()
                            .opacity(broken ? 1 : 0)
                            .scaleEffect(broken ? 1 : 0.6)
                    }
                    .frame(height: 280)

                    Text(broken ? "Eine geheime Figur ist frei. Du findest sie im Figuren-Editor." : "…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 30)

                    if broken {
                        GamePrimaryButton(title: "Weiter", color: magenta, action: onClose)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
        .transition(.opacity)
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { broken = true }
        }
        .accessibilityElement(children: .contain)
    }
}
