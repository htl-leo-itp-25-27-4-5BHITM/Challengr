import SwiftUI

struct BattleWinView: View {
    // MARK: - Input (Eingaben)
    let data: BattleResultData
    let ownPlayerName: String
    let onClose: () -> Void

    // MARK: - Animation States
    @State private var appearScale: CGFloat = 0.6
    @State private var appearOpacity: Double = 0.0
    @State private var titleScale: CGFloat = 1.0

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            // Dark, cinematic background — continues the mood from the battle
            // screen instead of cutting to a plain light card.
            LinearGradient(
                colors: [Color.challengrDark, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.challengrYellow.opacity(0.4), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .opacity(appearOpacity)
            .ignoresSafeArea()

            ConfettiView()

            VStack {
                Spacer()

                // Zentrale Win-Card
                VStack(spacing: 24) {

                    // kleines Label
                    Text("BATTLE ERGEBNIS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrYellow.opacity(0.9))

                    // großer WIN-Titel
                    Text("GEWONNEN!")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white)
                        .shadow(color: .challengrYellow.opacity(0.7), radius: 16, x: 0, y: 0)
                        .scaleEffect(titleScale)

                    // Glückwunsch-Zeile
                    Text("GLÜCKWUNSCH, \(data.winnerName.uppercased())!")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))

                    // Winner / Loser Cards nebeneinander
                    HStack(spacing: 20) {
                        resultPlayerCard(
                            name: data.winnerName,
                            character: character(for: data.winnerName),
                            pointsDelta: data.winnerPointsDelta,
                            isWinner: true
                        )

                        resultPlayerCard(
                            name: data.loserName,
                            character: character(for: data.loserName),
                            pointsDelta: data.loserPointsDelta,
                            isWinner: false
                        )
                    }

                    if let quiz = data.quizScoreLine {
                        Label(quiz, systemImage: "brain.head.profile")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Trophäen-Gewinn hervorgehoben (Liga) bzw. Friendly-Hinweis
                    Text(data.mode.trophyText(delta: data.winnerPointsDelta).uppercased())
                        .font(.system(size: data.mode.isRanked ? 22 : 16, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(data.mode.isRanked ? .challengrGreen : .white.opacity(0.8))
                        .padding(.top, 4)

                    if let metrics = data.metrics {
                        let rows = metricRows(from: metrics)
                        if !rows.isEmpty {
                            metricsSection(rows: rows)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.white.opacity(0.07))

                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.challengrYellow.opacity(0.7),
                                        Color.challengrGreen.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 18)
                .shadow(color: .challengrYellow.opacity(0.15), radius: 30, x: 0, y: 0)
                .scaleEffect(appearScale)
                .opacity(appearOpacity)

                // Button zurück zur Karte
                Button(action: onClose) {
                    Text("ZURÜCK ZUR KARTE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.challengrDark)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.challengrYellow)
                        )
                        .shadow(color: .challengrYellow.opacity(0.4), radius: 14, x: 0, y: 6)
                }
                .padding(.top, 18)
                .opacity(appearOpacity)

                Spacer()
            }
            .padding(.horizontal, 24)
            .onAppear {
                SoundManager.shared.play(.win)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    appearScale = 1.0
                    appearOpacity = 1.0
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    titleScale = 1.1
                }
            }
        }
    }

    // MARK: - Helpers (Hilfsfunktionen)

    /// Echte Figur des Spielers (vom Server); ohne Angabe eigene bzw. Ersatz-Figur.
    private func character(for playerName: String) -> GameCharacter {
        data.character(forPlayerName: playerName, ownPlayerName: ownPlayerName)
    }

    // MARK: - Subviews (Unteransichten)
    // MARK: - Result Player Card (Ergebnis-Karte)
    private func resultPlayerCard(
        name: String,
        character: GameCharacter,
        pointsDelta: Int,
        isWinner: Bool
    ) -> some View {
        let color: Color = isWinner ? .challengrGreen : .challengrRed

        return VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 130, height: 190)
                    .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 8)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 118, height: 178)

                Character3DView(character: character)
                    .frame(width: 118, height: 178)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )

                if isWinner {
                    // kleines Trophy-Badge oben links
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.75))
                            )
                            .offset(x: -40, y: -70)

                        Spacer()
                    }
                }
            }

            Text(name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)

            Text(data.deltaLabel(pointsDelta))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color.opacity(0.9))
        }
    }

    private struct MetricRow {
        let title: String
        let winnerValue: String
        let loserValue: String
    }

    private func metricRows(from metrics: BattleMetrics) -> [MetricRow] {
        metrics.rows.map { MetricRow(title: $0.title, winnerValue: $0.winner, loserValue: $0.loser) }
    }

    private func metricsSection(rows: [MetricRow]) -> some View {
        VStack(spacing: 10) {
            Text("CHALLENGE WERTE")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.6)
                .foregroundColor(.white.opacity(0.6))

            ForEach(rows, id: \.title) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.winnerName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1)
                            Text(row.winnerValue)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.challengrGreen)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(data.loserName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1)
                            Text(row.loserValue)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.challengrRed)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .padding(.top, 6)
    }
}
