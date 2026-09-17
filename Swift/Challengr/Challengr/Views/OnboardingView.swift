import SwiftUI

struct OnboardingStep {
    let icon: String
    let title: String
    let text: String
}

/// Shown once after the very first login so new players understand the core
/// loop (find someone nearby -> send a challenge -> earn points -> spend them
/// in the shop) before they're dropped onto an empty-looking map.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "mappin.and.ellipse",
            title: "Finde Spieler in deiner Nähe",
            text: "Auf der Karte siehst du alle Spieler in einem Radius von 200 Metern um dich. Tippe auf einen Spieler, um ihn herauszufordern."
        ),
        OnboardingStep(
            icon: "bolt.fill",
            title: "Challenge senden & annehmen",
            text: "Wähle eine Kategorie – Fitness, Mutprobe, Wissen, iPhone oder Customer – und schick eine zufällige Challenge an deinen Gegner. Nimmt er an, geht's direkt los."
        ),
        OnboardingStep(
            icon: "trophy.fill",
            title: "Punkte sammeln & aufsteigen",
            text: "Jeder Sieg bringt dir Punkte und lässt dich in der Trophy Road aufsteigen. Im Shop kannst du deine Punkte gegen Items eintauschen."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.00, blue: 0.04),
                    Color(red: 0.18, green: 0.02, blue: 0.08),
                    Color(red: 0.73, green: 0.12, blue: 0.20).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: finish) {
                        Text("ÜBERSPRINGEN")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $pageIndex) {
                    ForEach(steps.indices, id: \.self) { idx in
                        stepView(steps[idx]).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                GamePrimaryButton(
                    title: pageIndex == steps.count - 1 ? "Los geht's" : "Weiter",
                    color: .challengrYellow
                ) {
                    if pageIndex == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pageIndex += 1
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.challengrYellow.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 10)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.challengrYellow, Color.challengrYellow.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.challengrYellow.opacity(0.4), radius: 16)

                Image(systemName: step.icon)
                    .font(.system(size: 38, weight: .black))
                    .foregroundColor(.challengrDark)
            }

            Text(step.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            Text(step.text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: OnboardingView.hasSeenOnboardingKey)
        onFinish()
    }

    static let hasSeenOnboardingKey = "hasSeenOnboarding"

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
