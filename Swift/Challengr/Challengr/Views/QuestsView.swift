import SwiftUI

/// Aufgaben: täglich neue Aufgaben (bringen Challengr Coins) und Events mit eigenen Challenges (z. B. Beta-Event → Figur).
struct QuestsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case daily = "Täglich"
        case events = "Events"
        var id: String { rawValue }
    }

    /// Nach dem Abholen einer Event-Figur direkt in die Figurenwahl
    var onOpenCharacter: (GameCharacter) -> Void = { _ in }
    /// Neuer Stand für die Zahl am Menü-Knopf
    var onBoardChanged: (QuestBoard) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State var tab: Tab = .daily
    /// Vorbelegt nur für Vorschau/Tests – sonst lädt die Ansicht selbst
    @State var board: QuestBoard?
    var scrolls = true
    @State private var failed = false
    @State private var claiming: String?
    @State private var celebrate = false
    @State private var errorText: String?

    private let service = QuestService()

    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabPicker

                if let board {
                    if scrolls {
                        ScrollView { content(board) }
                            .refreshable { await load() }
                    } else {
                        content(board)  // Testbilder: ImageRenderer zeichnet keine ScrollView
                        Spacer(minLength: 0)
                    }
                } else if failed {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("Aufgaben konnten nicht geladen werden.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        GamePillButton(icon: "arrow.clockwise", title: "Nochmal") { Task { await load() } }
                    }
                    Spacer()
                } else {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }
            .padding(.top, 18)

            if celebrate {
                ConfettiView().allowsHitTesting(false).ignoresSafeArea()
            }
        }
        .task { if board == nil { await load() } }
    }

    private func content(_ board: QuestBoard) -> some View {
        VStack(spacing: 12) {
            if let errorText {
                Text(errorText).font(.footnote).foregroundColor(.challengrRed)
            }
            switch tab {
            case .daily: dailyList(board)
            case .events: eventList(board)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Kopf

    private var header: some View {
        HStack {
            coinChip
            Spacer()
            Text("AUFGABEN")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundColor(.challengrYellow)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(GameStyle.panelFill))
                    .overlay(Circle().stroke(GameStyle.panelStroke, lineWidth: 1))
            }
            .accessibilityLabel("Schließen")
        }
        .padding(.horizontal, 16)
    }

    /// Challengr Coins (Währung für den Shop, der bald öffnet)
    private var coinChip: some View {
        HStack(spacing: 5) {
            Image("MenuCoin").resizable().scaledToFit().frame(width: 22, height: 22)
            Text((board?.coins ?? 0).formatted())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(board?.coins ?? 0)))
        }
        .padding(.leading, 6).padding(.trailing, 10).padding(.vertical, 5)
        .background(Capsule().fill(GameStyle.panelFill))
        .overlay(Capsule().stroke(Color.challengrYellow.opacity(0.4), lineWidth: 1))
        .frame(width: 96, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(board?.coins ?? 0) Challengr Coins")
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Button {
                    SoundManager.shared.play(.tap)
                    withAnimation(.easeOut(duration: 0.2)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Text(t.rawValue.uppercased())
                        if badge(for: t) > 0 {
                            Circle().fill(Color.challengrRed).frame(width: 8, height: 8)
                        }
                    }
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(tab == t ? .challengrDark : .white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(tab == t ? Color.challengrYellow : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == t ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(GameStyle.panelFill))
        .overlay(Capsule().stroke(GameStyle.panelStroke, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func badge(for tab: Tab) -> Int {
        guard let board else { return 0 }
        switch tab {
        case .daily: return board.daily.filter { $0.done && !$0.claimed }.count
        case .events: return board.events.filter { $0.completed && !$0.claimed }.count
        }
    }

    // MARK: - Täglich

    @ViewBuilder
    private func dailyList(_ board: QuestBoard) -> some View {
        if let reset = board.resetDate {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Label("Neue Aufgaben in \(Self.duration(until: reset, now: ctx.date))", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(GameStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        ForEach(board.daily) { task in
            HStack(spacing: 12) {
                taskIcon(task)
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    progressBar(task)
                }
                Spacer(minLength: 4)
                dailyAction(task)
            }
            .gamePanel(padding: 12, cornerRadius: 18, highlight: task.done && !task.claimed ? .challengrYellow : nil)
            .opacity(task.claimed ? 0.6 : 1)
        }
        Text("Coins sammelst du für den Shop – der öffnet bald.")
            .font(.footnote)
            .foregroundColor(GameStyle.secondaryText)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func dailyAction(_ task: QuestTask) -> some View {
        if task.claimed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white, Color.challengrGreen)
                .accessibilityLabel("Abgeholt")
        } else if task.done {
            Button { claimDaily(task) } label: {
                HStack(spacing: 4) {
                    Image("MenuCoin").resizable().scaledToFit().frame(width: 16, height: 16)
                    Text("+\(task.coins)")
                }
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.challengrDark)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Capsule().fill(Color.challengrYellow))
            }
            .buttonStyle(.plain)
            .disabled(claiming != nil)
            .accessibilityLabel("\(task.coins) Coins abholen")
        } else {
            HStack(spacing: 3) {
                Image("MenuCoin").resizable().scaledToFit().frame(width: 14, height: 14).saturation(0.3)
                Text("\(task.coins)")
            }
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(GameStyle.secondaryText)
        }
    }

    // MARK: - Events

    @ViewBuilder
    private func eventList(_ board: QuestBoard) -> some View {
        if board.events.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.challengrYellow)
                Text("Gerade läuft kein Event")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Schau bald wieder vorbei – das nächste kommt bestimmt.")
                    .font(.footnote)
                    .foregroundColor(GameStyle.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .gamePanel(padding: 18)
        }
        ForEach(board.events) { event in
            eventCard(event)
        }
    }

    private func eventCard(_ event: QuestEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kopf: Belohnung + Titel
            HStack(spacing: 14) {
                if let character = event.character {
                    Image(character.imageName)
                        .resizable().scaledToFit()
                        .frame(width: 92, height: 92)
                        .background(CharacterBackdrop(character: character).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .saturation(event.claimed ? 1 : 0.85)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("EVENT")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.challengrDark)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.challengrYellow))
                    Text(event.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(GameStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let end = event.endDate {
                        TimelineView(.periodic(from: .now, by: 60)) { ctx in
                            Label(event.active ? "Endet in \(Self.duration(until: end, now: ctx.date))" : "Event beendet",
                                  systemImage: "hourglass")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(event.active ? .challengrYellow : GameStyle.secondaryText)
                        }
                    }
                }
            }

            if let character = event.character {
                Text("Belohnung: \(character.displayName)\(event.rewardCoins > 0 ? " + \(event.rewardCoins) Coins" : "")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }

            Text("\(event.doneCount)/\(event.tasks.count) CHALLENGES")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(GameStyle.secondaryText)

            ForEach(event.tasks) { task in
                HStack(spacing: 10) {
                    taskIcon(task, size: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        progressBar(task)
                    }
                }
            }

            eventAction(event)
        }
        .gamePanel(padding: 14, cornerRadius: 22, highlight: event.completed && !event.claimed ? .challengrYellow : nil)
    }

    @ViewBuilder
    private func eventAction(_ event: QuestEvent) -> some View {
        if event.claimed {
            if let character = event.character {
                GamePrimaryButton(title: "\(character.displayName) auswählen", color: .challengrGreen) {
                    dismiss()
                    onOpenCharacter(character)
                }
            }
        } else if event.completed {
            GamePrimaryButton(title: claiming == event.id ? "…" : "Belohnung abholen", color: .challengrYellow) {
                claimEvent(event)
            }
            .disabled(claiming != nil)
        } else if !event.active {
            Text("Leider nicht ganz geschafft – beim nächsten Event!")
                .font(.footnote)
                .foregroundColor(GameStyle.secondaryText)
        }
    }

    // MARK: - Bausteine

    private func taskIcon(_ task: QuestTask, size: CGFloat = 42) -> some View {
        Image(systemName: task.done ? "checkmark" : task.icon)
            .font(.system(size: size * 0.4, weight: .black))
            .foregroundColor(task.done ? .white : .challengrYellow)
            .frame(width: size, height: size)
            .background(Circle().fill(task.done ? Color.challengrGreen : Color.white.opacity(0.08)))
            .accessibilityHidden(true)
    }

    private func progressBar(_ task: QuestTask) -> some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(task.done ? Color.challengrGreen : Color.challengrYellow)
                        .frame(width: max(6, geo.size.width * task.fraction))
                }
            }
            .frame(height: 7)
            Text("\(task.progress)/\(task.target)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(GameStyle.secondaryText)
                .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel("\(task.progress) von \(task.target)")
    }

    /// "5 Std. 12 Min.", "3 Tage"
    static func duration(until end: Date, now: Date) -> String {
        let s = max(0, Int(end.timeIntervalSince(now)))
        let days = s / 86_400, hours = (s % 86_400) / 3600, minutes = (s % 3600) / 60
        if days >= 2 { return "\(days) Tagen" }
        if days == 1 { return "1 Tag \(hours) Std." }
        if hours > 0 { return "\(hours) Std. \(minutes) Min." }
        return "\(max(1, minutes)) Min."
    }

    // MARK: - Laden und Abholen

    private func load() async {
        do {
            let loaded = try await service.load()
            board = loaded
            failed = false
            onBoardChanged(loaded)
        } catch {
            if board == nil { failed = true }
        }
    }

    private func claimDaily(_ task: QuestTask) {
        claiming = task.id
        Task {
            defer { claiming = nil }
            do {
                let updated = try await service.claimDaily(task.id)
                SoundManager.shared.play(.win)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { board = updated }
                errorText = nil
                onBoardChanged(updated)
            } catch {
                errorText = "Abholen ging gerade nicht – zieh zum Neuladen nach unten."
            }
        }
    }

    private func claimEvent(_ event: QuestEvent) {
        claiming = event.id
        Task {
            defer { claiming = nil }
            do {
                let updated = try await service.claimEvent(event.id)
                SoundManager.shared.play(.win)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { board = updated }
                errorText = nil
                onBoardChanged(updated)
                celebrate = true
                try? await Task.sleep(for: .seconds(3))
                celebrate = false
            } catch {
                errorText = "Abholen ging gerade nicht – zieh zum Neuladen nach unten."
            }
        }
    }
}
