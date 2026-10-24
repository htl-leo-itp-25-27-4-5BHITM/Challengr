//
//  BattleLoseView.swift
//  Challengr
//
//  Created by Sebastian Lehner  on 21.01.26.
//
import SwiftUI

struct BattleLoseView: View {
    // MARK: - Input (Eingaben)
    let data: BattleResultData
    let ownPlayerName: String
    let onClose: () -> Void

    // MARK: - Animation States
    @State private var appearScale: CGFloat = 1.3
    @State private var appearOpacity: Double = 0.0
    @State private var shakeOffset: CGFloat = 0.0

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
                colors: [Color.challengrRed.opacity(0.3), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .opacity(appearOpacity)
            .ignoresSafeArea()

            VStack {
                Spacer()

                // Zentrale Lose-Card
                VStack(spacing: 24) {

                    Text("BATTLE ERGEBNIS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.challengrRed.opacity(0.9))

                    Text(data.isDraw ? "UNENTSCHIEDEN" : isConflict ? "KONFLIKT" : "NIEDERLAGE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .tracking(data.isDraw ? 1 : 3)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundColor(data.isDraw ? .challengrYellow : .challengrRed)
                        .shadow(color: (data.isDraw ? Color.challengrYellow : .challengrRed).opacity(0.6), radius: 14, x: 0, y: 0)

                    Text(data.isDraw
                         ? (data.mode.isRanked ? "Keiner hat gewonnen – keine Trophäen." : "Keiner hat gewonnen – war ja nur ein Friendly.")
                         : isConflict
                         ? "Ihr habt unterschiedlich abgestimmt – keine Einigung."
                         : "KOPF HOCH, \(data.loserName.uppercased())!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))

                    // Konflikt: beide Spieler mit echtem Namen (das Backend schickt sonst "Niemand")
                    if isConflict, let names = data.playerNames(ownPlayerName: ownPlayerName) {
                    HStack(spacing: 20) {
                        resultPlayerCard(
                            name: names.own,
                            character: character(for: names.own),
                            pointsDelta: data.loserPointsDelta,
                            isLoser: true
                        )
                        resultPlayerCard(
                            name: names.opponent,
                            character: character(for: names.opponent),
                            pointsDelta: data.winnerPointsDelta,
                            isLoser: true
                        )
                    }
                    }

                    // Spieler nebeneinander (bei Unentschieden/Konflikt gibt es keinen Gewinner/Verlierer)
                    if !data.isDraw && !isConflict {
                    HStack(spacing: 20) {
                        resultPlayerCard(
                            name: data.loserName,
                            character: character(for: data.loserName),
                            pointsDelta: data.loserPointsDelta,
                            isLoser: true
                        )

                        resultPlayerCard(
                            name: data.winnerName,
                            character: character(for: data.winnerName),
                            pointsDelta: data.winnerPointsDelta,
                            isLoser: false
                        )
                    }
                    }

                    if let quiz = data.quizScoreLine {
                        Label(quiz, systemImage: "brain.head.profile")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Trophäen-Verlust (Liga) bzw. Friendly-Hinweis
                    Text(
                        !data.mode.isRanked || data.loserPointsDelta == 0
                        ? data.mode.isRanked ? "KEINE TROPHÄEN VERÄNDERT" : data.mode.trophyText(delta: 0).uppercased()
                        : data.mode.trophyText(delta: data.loserPointsDelta).uppercased()
                    )
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(
                        !data.mode.isRanked ? Color.white.opacity(0.8)
                        : data.loserPointsDelta <= 0 ? Color.challengrRed
                        : Color.challengrGreen
                    )

                    if let metrics = data.metrics {
                        let rows = metricRows(from: metrics)
                        if !rows.isEmpty {
                            metricsSection(rows: rows)
                        }
                    }

                    // Trash-Talk Panel
                    VStack(spacing: 8) {
                        Text("TRASH TALK")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.5))

                        Text(data.trashTalk)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.challengrRed.opacity(0.6), lineWidth: 2)
                    )
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
                                        Color.challengrYellow.opacity(0.35),
                                        Color.challengrRed.opacity(0.6)
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
                .shadow(color: .challengrRed.opacity(0.15), radius: 30, x: 0, y: 0)
                .scaleEffect(appearScale)
                .opacity(appearOpacity)
                .offset(x: shakeOffset)

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
                                .fill(Color.white.opacity(0.95))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .padding(.top, 18)
                .opacity(appearOpacity)

                Spacer()
            }
            .padding(.horizontal, 24)
            .onAppear {
                SoundManager.shared.play(.lose)
                // Hefty drop-in slam animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    appearScale = 1.0
                    appearOpacity = 1.0
                }
                // Shake effect milliseconds after slamming down
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(Animation.default.speed(2).repeatCount(4, autoreverses: true)) {
                        shakeOffset = -8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation { shakeOffset = 0 }
                    }
                }
            }
        }
    }

    // MARK: - Helpers (Hilfsfunktionen)

    private var isConflict: Bool { data.outcome == "CONFLICT" }

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
        isLoser: Bool
    ) -> some View {
        let color: Color = isLoser ? .challengrRed : .challengrGreen

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

                if isLoser {
                    // kleines X-Badge
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.challengrRed)
                        )
                        .offset(x: -40, y: -70)
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
