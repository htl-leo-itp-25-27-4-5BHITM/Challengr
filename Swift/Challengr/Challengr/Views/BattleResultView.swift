import SwiftUI

/// Ergebnis nach einem Battle: 3D-Siegerehrung (`ResultStageView`), Titel, der ins Bild knallt,
/// Trophäen-Zähler, Challenge-Werte und – nach einer Niederlage – Trash Talk.
struct BattleResultView: View {
    // MARK: - Input (Eingaben)
    let data: BattleResultData
    let ownPlayerName: String
    /// Kommt aus `didWin` (MapView): true = Sieg-Sicht, sonst Niederlage/Unentschieden/Konflikt.
    let ownWins: Bool
    let onClose: () -> Void

    // MARK: - Animation States
    @State private var titleShown = false
    @State private var detailsShown = false
    @State private var shownDelta = 0
    @State private var flash = 0.0

    private enum Kind { case win, lose, draw, conflict }

    private var kind: Kind {
        if ownWins { return .win }
        if data.isDraw { return .draw }
        if data.outcome == "CONFLICT" { return .conflict }
        return .lose
    }

    private var accent: Color {
        switch kind {
        case .win: return .challengrYellow
        case .lose, .conflict: return .challengrRed
        case .draw: return .challengrYellow
        }
    }

    /// Eigener und gegnerischer Name (bei Unentschieden schickt das Backend "Niemand").
    private var names: (own: String, opponent: String) {
        switch kind {
        case .win: return (data.winnerName, data.loserName)
        case .lose: return (data.loserName, data.winnerName)
        case .draw, .conflict: return data.playerNames(ownPlayerName: ownPlayerName) ?? (ownPlayerName, "Gegner")
        }
    }

    /// Wer links (Podest 1) und rechts steht – bei Gleichstand links man selbst.
    private var stageNames: (left: String, right: String) {
        switch kind {
        case .win, .lose: return (data.winnerName, data.loserName)
        case .draw, .conflict: return (names.own, names.opponent)
        }
    }

    private var ownDelta: Int {
        switch kind {
        case .win: return data.winnerPointsDelta
        case .lose: return data.loserPointsDelta
        case .draw, .conflict: return 0
        }
    }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(kind == .win ? 0.35 : 0.22), .clear],
                           center: UnitPoint(x: 0.5, y: 0.35), startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
            // kurzer heller Blitz bei der Landung
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    modeChip
                        .padding(.top, 12)

                    title

                    ZStack(alignment: .bottom) {
                        ResultStageView(winner: character(for: stageNames.left),
                                        loser: character(for: stageNames.right),
                                        focus: stageFocus)
                        nameRow
                    }
                    .frame(height: 360)
                    .padding(.horizontal, -24)   // Bühne bis an den Rand

                    trophyCounter
                        .opacity(detailsShown ? 1 : 0)

                    Group {
                        if let quiz = data.quizScoreLine {
                            Label(quiz, systemImage: "brain.head.profile")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        if let metrics = data.metrics, !metrics.rows.isEmpty {
                            metricsSection(rows: metrics.rows)
                        }
                        if kind == .lose && !data.trashTalk.isEmpty {
                            trashTalk
                        }
                        GamePrimaryButton(title: "Weiter", color: kind == .win ? .challengrYellow : .white, action: onClose)
                            .padding(.top, 4)
                    }
                    .opacity(detailsShown ? 1 : 0)
                    .offset(y: detailsShown ? 0 : 30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear(perform: runSequence)
    }

    // MARK: - Ablauf

    private var stageFocus: ResultStageView.Focus {
        switch kind {
        case .win: return .win
        case .lose: return .lose
        case .draw: return .even(happy: true)
        case .conflict: return .even(happy: false)
        }
    }

    private func runSequence() {
        SoundManager.shared.play(kind == .win ? .win : .lose)
        let landing = ResultStageView.landingTime
        DispatchQueue.main.asyncAfter(deadline: .now() + landing) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { titleShown = true }
            if kind == .win {
                flash = 0.35
                withAnimation(.easeOut(duration: 0.4)) { flash = 0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + landing + 0.5) {
            withAnimation(.easeOut(duration: 0.45)) { detailsShown = true }
            countTrophies()
        }
    }

    /// Zähler läuft von 0 bis zum Trophäen-Gewinn bzw. -Verlust
    private func countTrophies() {
        let target = ownDelta
        guard data.mode.isRanked, target != 0 else { return }
        let steps = min(abs(target), 30)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 * Double(i) / Double(steps)) {
                shownDelta = target * i / steps
                if i == steps { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
        }
    }

    // MARK: - Subviews (Unteransichten)

    private var modeChip: some View {
        Text(data.mode.title.uppercased())
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.6)
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private var title: some View {
        VStack(spacing: 6) {
            Text(titleText)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(kind == .win ? .challengrYellow : kind == .draw ? .white : .challengrRed)
                .shadow(color: accent.opacity(0.8), radius: 18)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 3)
            Text(subtitleText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.85))
        }
        .scaleEffect(titleShown ? 1 : 2.4)
        .rotationEffect(.degrees(titleShown ? -3 : -12))
        .opacity(titleShown ? 1 : 0)
        .frame(minHeight: 84)
    }

    private var titleText: String {
        switch kind {
        case .win: return "SIEG!"
        case .lose: return "NIEDERLAGE"
        case .draw: return "UNENTSCHIEDEN"
        case .conflict: return "KONFLIKT"
        }
    }

    private var subtitleText: String {
        switch kind {
        case .win: return "\(names.opponent) ist geschlagen!"
        case .lose: return "\(names.opponent) war diesmal stärker. Kopf hoch!"
        case .draw: return data.mode.isRanked ? "Keiner hat gewonnen – keine Trophäen." : "Keiner hat gewonnen – war ja nur ein Friendly."
        case .conflict: return "Ihr habt unterschiedlich abgestimmt – keine Einigung."
        }
    }

    /// Namen unter den Podesten (Sieger links, Verlierer rechts)
    private var nameRow: some View {
        HStack(alignment: .bottom) {
            nameTag(stageNames.left, crown: kind == .win || kind == .lose,
                    color: kind == .lose || kind == .win ? .challengrYellow : .white)
            Spacer()
            nameTag(stageNames.right, crown: false, color: .white.opacity(0.8))
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 4)
        .opacity(titleShown ? 1 : 0)
    }

    private func nameTag(_ name: String, crown: Bool, color: Color) -> some View {
        HStack(spacing: 5) {
            if crown {
                Image(systemName: "crown.fill").font(.system(size: 11, weight: .black)).foregroundColor(.challengrYellow)
            }
            Text(name == ownPlayerName ? "\(name) (du)" : name)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .lineLimit(1)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .frame(maxWidth: 160)
    }

    @ViewBuilder
    private var trophyCounter: some View {
        if data.mode.isRanked && ownDelta != 0 {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.challengrYellow)
                Text("\(shownDelta > 0 ? "+" : "")\(shownDelta)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownDelta)))
                    .foregroundColor(ownDelta > 0 ? .challengrGreen : .challengrRed)
                Text("TROPHÄEN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().stroke((ownDelta > 0 ? Color.challengrGreen : .challengrRed).opacity(0.5), lineWidth: 2))
        } else {
            Text(data.mode.isRanked ? "KEINE TROPHÄEN VERÄNDERT" : data.mode.trophyText(delta: 0).uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private func metricsSection(rows: [(title: String, winner: String, loser: String)]) -> some View {
        VStack(spacing: 8) {
            GameSectionHeader(title: "Challenge-Werte")
            ForEach(rows, id: \.title) { row in
                VStack(spacing: 6) {
                    Text(row.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.6))
                    HStack {
                        metricValue(name: data.winnerName, value: row.winner, color: .challengrGreen, alignment: .leading)
                        Spacer()
                        Text("VS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        metricValue(name: data.loserName, value: row.loser, color: .challengrRed, alignment: .trailing)
                    }
                }
                .gamePanel(padding: 12, cornerRadius: 16)
            }
        }
    }

    private func metricValue(name: String, value: String, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(name.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
        }
        .foregroundColor(color)
    }

    private var trashTalk: some View {
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
        .frame(maxWidth: .infinity)
        .gamePanel(padding: 16, cornerRadius: 20, highlight: .challengrRed)
    }

    // MARK: - Helpers (Hilfsfunktionen)

    /// Echte Figur des Spielers (vom Server); ohne Angabe eigene bzw. Ersatz-Figur.
    private func character(for playerName: String) -> GameCharacter {
        data.character(forPlayerName: playerName, ownPlayerName: ownPlayerName)
    }
}
