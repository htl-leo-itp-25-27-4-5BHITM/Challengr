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
            text: "Auf der Karte siehst du Spieler in deiner Umgebung. Tippe auf einen Spieler, um ihm ein Emote zu schicken oder ihn herauszufordern."
        ),
        OnboardingStep(
            icon: "bolt.fill",
            title: "Liga oder Friendly",
            text: "In der Liga spielst du um Trophäen – als Quiz-Show oder als Real-Life-Challenge, die dein iPhone misst. Im Friendly wählst du die Challenge selbst, und es geht um nichts."
        ),
        OnboardingStep(
            icon: "trophy.fill",
            title: "Trophäen & Punkte",
            text: "Siege in der Liga bringen Trophäen und lassen dich aufsteigen. Punkte sammelst du nebenbei – im Shop tauschst du sie gegen Items."
        )
    ]

    /// Letzte Seite: Datenschutz + Alter (kann nicht übersprungen werden)
    private var privacyIndex: Int { steps.count }
    @State private var ageConfirmed = false

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
                    // Überspringen führt zum Datenschutz-Schritt – der muss bestätigt werden
                    Button { withAnimation { pageIndex = privacyIndex } } label: {
                        Text("ÜBERSPRINGEN")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .opacity(pageIndex == privacyIndex ? 0 : 1)
                    .disabled(pageIndex == privacyIndex)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $pageIndex) {
                    ForEach(steps.indices, id: \.self) { idx in
                        stepView(steps[idx]).tag(idx)
                    }
                    privacyView.tag(privacyIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                GamePrimaryButton(
                    title: pageIndex == privacyIndex ? "Los geht's" : "Weiter",
                    color: .challengrYellow
                ) {
                    if pageIndex == privacyIndex {
                        guard ageConfirmed else { return }
                        finish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pageIndex += 1
                        }
                    }
                }
                .opacity(pageIndex == privacyIndex && !ageConfirmed ? 0.45 : 1)
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

    /// B3: wer den Standort sieht, Link zur Datenschutzerklärung, Mindestalter 14
    private var privacyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.challengrYellow)
                    Spacer()
                }
                .padding(.top, 24)

                Text("Dein Standort & deine Daten")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                privacyPoint("location.circle.fill", "Andere sehen dich nur, wenn sie höchstens 300 m entfernt sind – und nur ungefähr (ca. 50 m), nie metergenau.")
                privacyPoint("eye.slash.fill", "In den Einstellungen kannst du dich unsichtbar machen und Spieler blockieren oder melden.")
                privacyPoint("camera.fill", "Kamera und Mikrofon werten nur auf deinem iPhone aus – nichts wird aufgenommen oder hochgeladen.")
                privacyPoint("trash.fill", "Du kannst dein Konto jederzeit in den Einstellungen löschen.")

                Link(destination: BackendConfig.privacyPolicyURL) {
                    Label("Datenschutzerklärung lesen", systemImage: "doc.text.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.challengrYellow)
                }
                .padding(.top, 4)

                Toggle(isOn: $ageConfirmed) {
                    Text("Ich bin mindestens 14 Jahre alt (oder meine Eltern sind einverstanden).")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .tint(.challengrGreen)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func privacyPoint(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.challengrYellow)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
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
