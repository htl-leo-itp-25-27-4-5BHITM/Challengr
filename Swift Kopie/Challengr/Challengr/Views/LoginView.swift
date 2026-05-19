import SwiftUI

struct LoginView: View {

    @ObservedObject var auth: KeycloakAuthService

    @State private var pulsing = false

    var body: some View {
        ZStack {
            // MARK: Hintergrund
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

            // Dekorative Kreise im Hintergrund
            Circle()
                .fill(Color.challengrYellow.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: 120, y: -200)

            Circle()
                .fill(Color.challengrRed.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: -100, y: 250)

            // MARK: Inhalt
            VStack(spacing: 0) {
                Spacer()

                // Logo / Icon
                ZStack {
                    Circle()
                        .fill(Color.challengrYellow.opacity(0.15))
                        .frame(width: pulsing ? 130 : 120, height: pulsing ? 130 : 120)
                        .blur(radius: 12)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulsing)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.challengrYellow, Color.challengrYellow.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.challengrYellow.opacity(0.5), radius: 20)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(.challengrDark)
                }
                .padding(.bottom, 28)
                .onAppear { pulsing = true }

                // App-Name
                Text("CHALLENGR")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundColor(.white)

                Text("Real-Life Battles. Überall.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 6)

                Spacer()

                // MARK: Card
                VStack(spacing: 20) {

                    // Features
                    VStack(spacing: 12) {
                        featureRow(icon: "mappin.and.ellipse", text: "Finde Spieler in deiner Nähe")
                        featureRow(icon: "trophy.fill",        text: "Sammle Punkte & steig auf")
                        featureRow(icon: "bolt.shield.fill",   text: "Kompetitiv & fair")
                    }
                    .padding(.bottom, 8)

                    // Login-Button
                    Button {
                        auth.login()
                    } label: {
                        HStack(spacing: 12) {
                            if auth.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.challengrDark)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            Text(auth.isLoading ? "Wird angemeldet…" : "MIT KEYCLOAK ANMELDEN")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .tracking(1)
                        }
                        .foregroundColor(.challengrDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.challengrYellow)
                                .shadow(color: Color.challengrYellow.opacity(0.45), radius: 14, x: 0, y: 6)
                        )
                    }
                    .disabled(auth.isLoading)

                    // Fehler-Anzeige
                    if let err = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(err)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: auth.isLoading)
    }

    // MARK: - Feature Row
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.challengrYellow)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Spacer()
        }
    }
}
