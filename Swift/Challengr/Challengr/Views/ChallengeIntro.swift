import SwiftUI

/// Was vor einer gemessenen Challenge erklärt wird – damit jeder weiß, was zu tun ist.
struct ChallengeIntro: Equatable {
    let title: String
    let icon: String
    let steps: [String]
    /// Wer gewinnt
    let goal: String
    /// Nach „Los“ noch so viele Sekunden zum In-Position-Gehen
    var getReadySeconds: Int = 3

    /// Erklärung zur Challenge-Art; nil = keine (Wissen, Friendly ohne Messung)
    static func `for`(_ screen: BattleScreen) -> ChallengeIntro? {
        switch screen {
        case .sprint:
            return ChallengeIntro(title: "Sprint", icon: "figure.run", steps: [
                "Halte dein Handy in der Hand und such dir freie Bahn.",
                "Nach einem kurzen Countdown hast du 15 Sekunden.",
                "Lauf so weit du kannst – das GPS misst deine Meter.",
            ], goal: "Wer weiter läuft, gewinnt.")
        case .loudness:
            return ChallengeIntro(title: "Schrei-Challenge", icon: "speaker.wave.3.fill", steps: [
                "Halte das Handy vor dich – das Mikrofon misst.",
                "Nach dem Countdown hast du 10 Sekunden.",
                "Sei so laut wie möglich: schreien, klatschen, jubeln. Pass auf deine Ohren auf!",
            ], goal: "Wer lauter ist, gewinnt.")
        case .compass:
            return ChallengeIntro(title: "Kompass", icon: "safari.fill", steps: [
                "Halte dein Handy flach vor dir, Display nach oben.",
                "Zuerst siehst du, wohin du schaust: 0° = Norden, 90° = Osten, 180° = Süden, 270° = Westen.",
                "Dann kommt ein Zielwinkel und die Anzeige verschwindet – dreh dich aus dem Gefühl dorthin.",
                "Nach 10 Sekunden wird gemessen, wohin du zeigst.",
            ], goal: "Wer weniger Grad danebenliegt, gewinnt.")
        case .shake:
            return ChallengeIntro(title: "Schütteln", icon: "iphone.radiowaves.left.and.right", steps: [
                "Halte dein Handy gut fest – nicht loslassen!",
                "Nach 3 Sekunden geht's los: 10 Sekunden so stark schütteln wie du kannst.",
            ], goal: "Wer mehr Schüttel-Punkte hat, gewinnt.")
        case .pushup:
            return ChallengeIntro(title: "Liegestütze", icon: "figure.strengthtraining.traditional", steps: [
                "Leg dein Handy flach auf den Boden, Display nach oben, genau unter dein Gesicht.",
                "Geh in Liegestütz-Position über dem Handy.",
                "Runter bis unter 25 cm über dem Handy, dann wieder ganz hoch – so zählt eine.",
                "Nach „Los“ hast du 5 Sekunden, um in Position zu gehen.",
            ], goal: "Wer mehr Liegestütze schafft, gewinnt.", getReadySeconds: 5)
        case .checkInSpot:
            return ChallengeIntro(title: "Check-in-Spot", icon: "mappin.and.ellipse", steps: [
                "Auf der Karte erscheint ein Zielpunkt in der Nähe.",
                "Lauf so schnell du kannst hin – sobald du im Kreis bist, zählt es.",
            ], goal: "Wer zuerst ankommt, gewinnt.")
        case .country:
            return ChallengeIntro(title: "Länder-Kompass", icon: "globe.europe.africa.fill", steps: [
                "Du siehst ein Land, z. B. Italien.",
                "Halte dein Handy flach vor dir und dreh dich, bis es genau in Richtung des Landes zeigt.",
                "Tippe auf „Hier!“ – oder nach 15 Sekunden wird automatisch gemessen.",
            ], goal: "Wer genauer zeigt, gewinnt.")
        case .reaction:
            return ChallengeIntro(title: "Reaktions-Test", icon: "bolt.fill", steps: [
                "Der Bildschirm ist rot – warte.",
                "Sobald er grün wird: so schnell wie möglich irgendwo tippen.",
                "Zu früh getippt gibt eine Sekunde Strafe. Es gibt 3 Runden.",
            ], goal: "Wer im Schnitt schneller reagiert, gewinnt.")
        case .timing:
            return ChallengeIntro(title: "Zeitgefühl", icon: "stopwatch.fill", steps: [
                "Du bekommst eine Zielzeit, z. B. 7 Sekunden.",
                "Tippe auf Start – die Uhr läuft, aber du siehst sie nicht.",
                "Zähl im Kopf mit und tippe Stopp, wenn du glaubst, die Zeit ist um.",
            ], goal: "Wer näher an der Zielzeit stoppt, gewinnt.")
        case .knowledge, .camera, .generic:
            return nil
        }
    }
}

/// Zeigt zuerst die Erklärung, dann (nach „Los“ oder automatisch) einen kurzen Countdown und erst dann die Challenge.
struct ChallengeIntroGate<Content: View>: View {
    let intro: ChallengeIntro?
    @ViewBuilder let content: () -> Content

    /// Spätestens dann geht es von selbst los (der Gegner wartet sonst)
    static var autoStartSeconds: Int { 20 }

    enum Stage { case intro, getReady(Int), running }
    @State private var stage: Stage = .intro
    @State private var autoLeft = 20
    /// Zwei getrennte Timer: die Erklär-Karte stoppt beim Verschwinden nur ihren eigenen
    /// (vorher teilten sie sich einen – dann blieb „Bereit machen“ hängen)
    @State private var autoTimer: Timer?
    @State private var readyTimer: Timer?

    var body: some View {
        if let intro {
            switch stage {
            case .running:
                content()
            case .getReady(let n):
                ZStack {
                    GameStyle.background.ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("BEREIT MACHEN").font(.system(size: 16, weight: .black, design: .rounded)).tracking(2)
                            .foregroundColor(.challengrYellow)
                        Text("\(n)").font(.system(size: 110, weight: .black, design: .rounded)).foregroundColor(.white)
                            .contentTransition(.numericText(value: Double(n)))
                    }
                }
            case .intro:
                introCard(intro)
                    .onAppear { startAutoTimer(intro) }
                    .onDisappear { autoTimer?.invalidate() }
            }
        } else {
            content()
        }
    }

    private func introCard(_ intro: ChallengeIntro) -> some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: intro.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.challengrDark)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.challengrYellow))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SO GEHT'S").font(.system(size: 12, weight: .black, design: .rounded)).tracking(1.5)
                            .foregroundColor(GameStyle.secondaryText)
                        Text(intro.title).font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(intro.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.challengrDark)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                            Text(step)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .gamePanel(padding: 16)
                Label(intro.goal, systemImage: "trophy.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.challengrYellow)
                Spacer()
                GamePrimaryButton(title: "Los geht's", color: .challengrGreen) { go(intro) }
                Text("Startet automatisch in \(autoLeft) s")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(GameStyle.secondaryText)
                    .frame(maxWidth: .infinity)
                    .monospacedDigit()
            }
            .padding(24)
        }
    }

    private func startAutoTimer(_ intro: ChallengeIntro) {
        autoTimer?.invalidate()
        autoLeft = Self.autoStartSeconds
        autoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                autoLeft -= 1
                if autoLeft <= 0 { go(intro) }
            }
        }
    }

    private func go(_ intro: ChallengeIntro) {
        guard case .intro = stage else { return }
        autoTimer?.invalidate()
        SoundManager.shared.play(.click)
        var left = intro.getReadySeconds
        guard left > 0 else {
            stage = .running
            return
        }
        stage = .getReady(left)
        readyTimer?.invalidate()
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                left -= 1
                if left > 0 {
                    SoundManager.shared.play(.countdownTick)
                    withAnimation { stage = .getReady(left) }
                } else {
                    t.invalidate()
                    SoundManager.shared.play(.countdownGo)
                    stage = .running
                }
            }
        }
    }
}
