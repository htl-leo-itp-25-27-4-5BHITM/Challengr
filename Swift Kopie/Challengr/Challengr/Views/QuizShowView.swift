import SwiftUI
import UIKit

/// Liga Wissen: animierte Quiz-Show mit 4 Fragen. Richtig gibt Punkte, schneller gibt Bonus.
struct QuizShowView: View {
    @ObservedObject var model: QuizShowModel
    let battleId: Int64
    let ownName: String
    let opponentName: String
    let ownCharacter: GameCharacter
    let opponentCharacter: GameCharacter
    let socket: GameSocketService
    /// Nach dem Aufgeben (Ergebnis kommt vom Server)
    let onSurrendered: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introAppeared = false
    @State private var pointsPop = false
    /// Was das 3D-Studio gerade spielt
    @State private var stageEvent = QuizStageEvent(kind: .intro, id: 0)

    private static let answerColors: [Color] = [.challengrRed, .blue, .challengrYellow, .challengrGreen]
    private static let letters = ["A", "B", "C", "D"]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 12) {
                studio
                    .frame(height: model.phase == .intro ? 380 : 210)
                    .padding(.top, 4)

                switch model.phase {
                case .intro:
                    intro
                    Spacer()
                case .question, .reveal:
                    if let q = model.question {
                        roundHeader(q)
                        questionCard(q)
                            .id(q.round)
                            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                                                    removal: .opacity))
                        answers(q)
                        statusLine
                        Spacer(minLength: 0)
                    }
                }

                ChallengeSurrenderButton(battleId: battleId, socket: socket, onSurrendered: onSurrendered)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 18)
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: model.question?.round)
            .animation(.easeInOut(duration: 0.25), value: model.phase)
        }
        .onAppear {
            model.start(battleId: battleId)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { introAppeared = true }
        }
        .onChange(of: model.lastResult) { _, result in
            guard let result else { return }
            feedbackForReveal()
            stage(.reveal(ownCorrect: model.myRoundPoints > 0, opponentCorrect: model.opponentRoundPoints > 0))
            if result.last {
                let ownWins: Bool? = model.ownScore == model.opponentScore ? nil : model.ownScore > model.opponentScore
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { stage(.finished(ownWins: ownWins)) }
            }
        }
        .onChange(of: model.question?.round) { _, round in
            if let round { stage(.question(round: round)) }
        }
        .onChange(of: model.myAnswer) { _, answer in
            if answer != nil { stage(.answered(own: true)) }
        }
        .onChange(of: model.opponentAnswered) { _, answered in
            if answered { stage(.answered(own: false)) }
        }
    }

    private func stage(_ kind: QuizStageEvent.Kind) {
        stageEvent = QuizStageEvent(kind: kind, id: stageEvent.id + 1)
    }

    // MARK: - 3D-Studio mit Punktestand über den Pulten

    private var studio: some View {
        QuizStageView(ownCharacter: ownCharacter, opponentCharacter: opponentCharacter, event: stageEvent)
            .overlay(alignment: .top) {
                HStack(alignment: .top) {
                    scoreSign(name: ownName, score: model.ownScore,
                              roundPoints: model.phase == .reveal ? model.myRoundPoints : nil,
                              color: .challengrYellow, answered: model.myAnswer != nil && model.phase == .question)
                    Spacer()
                    scoreSign(name: opponentName, score: model.opponentScore,
                              roundPoints: model.phase == .reveal ? model.opponentRoundPoints : nil,
                              color: .challengrRed, answered: model.opponentAnswered && model.phase == .question)
                }
                .padding(.horizontal, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.purple.opacity(0.6), lineWidth: 2))
    }

    /// Namensschild mit Punktestand (wie die Anzeige an einem TV-Pult)
    private func scoreSign(name: String, score: Int, roundPoints: Int?, color: Color, answered: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if answered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white, Color.challengrGreen)
                        .transition(.scale)
                }
            }
            .foregroundColor(.white.opacity(0.85))
            Text("\(score)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6), value: score)
            if let roundPoints {
                Text("+\(roundPoints)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(roundPoints > 0 ? .challengrGreen : .white.opacity(0.5))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 104)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.8), lineWidth: 1.5))
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Hintergrund mit drehenden Scheinwerfern

    private var background: some View {
        ZStack {
            GameStyle.background
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 12
                AngularGradient(colors: [.purple.opacity(0.35), .clear, .challengrYellow.opacity(0.18), .clear,
                                         .purple.opacity(0.35), .clear, .challengrYellow.opacity(0.18), .clear],
                                center: .top)
                    .rotationEffect(.degrees(angle))
                    .scaleEffect(2.2)
                    .blur(radius: 30)
            }
            RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 120, endRadius: 520)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(spacing: 12) {
            Text("QUIZ-SHOW")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundColor(.challengrYellow)
                .shadow(color: .challengrYellow.opacity(0.6), radius: 16)
                .scaleEffect(introAppeared ? 1 : 1.8)
                .opacity(introAppeared ? 1 : 0)
            Text("4 Fragen · 15 Sekunden · Tempo zählt")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            ProgressView().tint(.white)
            Text("Gleich geht's los …")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Frage

    private func roundHeader(_ q: QuizQuestion) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...max(q.rounds, 1), id: \.self) { r in
                    Capsule()
                        .fill(r < q.round ? Color.challengrYellow : r == q.round ? Color.white : Color.white.opacity(0.2))
                        .frame(width: r == q.round ? 26 : 14, height: 6)
                }
            }
            Text("FRAGE \(q.round) VON \(q.rounds)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.75))

            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let fraction = model.phase == .question ? model.timeFraction(now: context.date) : 0
                let seconds = model.phase == .question ? model.secondsLeft(now: context.date) : 0
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(fraction > 0.33 ? Color.challengrYellow : Color.challengrRed)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 10)
                    Text(model.phase == .question ? "\(seconds)" : "")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(seconds <= 5 ? .challengrRed : .white)
                        .frame(width: 28)
                }
                .accessibilityElement()
                .accessibilityLabel("Noch \(seconds) Sekunden")
            }
            .frame(height: 20)
        }
    }

    private func questionCard(_ q: QuizQuestion) -> some View {
        Text(q.text)
            .font(.system(size: 21, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundColor(.challengrDark)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 84)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.purple, lineWidth: 3))
            .shadow(color: .purple.opacity(0.5), radius: 14)
    }

    private func answers(_ q: QuizQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(q.choices.enumerated()), id: \.offset) { index, choice in
                answerButton(index: index, text: choice)
            }
        }
    }

    private func answerButton(index: Int, text: String) -> some View {
        let reveal = model.phase == .reveal ? model.lastResult : nil
        let isCorrect = reveal?.correctIndex == index
        let isMine = model.myAnswer == index
        let isOpponents = reveal != nil && model.opponentRoundAnswer == index
        let dimmed = (model.myAnswer != nil && !isMine && reveal == nil) || (reveal != nil && !isCorrect && !isMine)
        let base = Self.answerColors[index % 4]
        let fill: Color = reveal == nil ? base : isCorrect ? .challengrGreen : isMine ? .challengrRed : base

        return Button {
            guard let answer = model.answer(index) else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            SoundManager.shared.play(.tap)
            socket.sendQuizAnswer(battleId: answer.battleId, round: answer.round, answerIndex: answer.index)
        } label: {
            HStack(spacing: 8) {
                Text(Self.letters[index % 4])
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(base)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white))
                Text(text)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .lineLimit(3)
                Spacer(minLength: 0)
                if reveal != nil && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                } else if reveal != nil && isMine {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white, lineWidth: isMine ? 3 : 0))
            .overlay(alignment: .topTrailing) {
                // Wahl des Gegners erst bei der Auflösung zeigen
                if isOpponents {
                    CharacterBadge(character: opponentCharacter, ringColor: .challengrRed, size: 26)
                        .offset(x: 6, y: -8)
                        .transition(.scale)
                }
            }
            .scaleEffect(reveal != nil && isCorrect && !reduceMotion ? 1.05 : 1)
            .opacity(dimmed ? 0.45 : 1)
            .shadow(color: reveal != nil && isCorrect ? Color.challengrGreen.opacity(0.8) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(model.phase != .question || model.myAnswer != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.phase)
        .accessibilityLabel("Antwort \(Self.letters[index % 4]): \(text)\(reveal != nil && isCorrect ? ", richtig" : "")")
    }

    private var statusLine: some View {
        Group {
            if model.phase == .reveal {
                let pts = model.myRoundPoints
                Text(pts > 0 ? "RICHTIG! +\(pts)" : (model.myAnswer == nil ? "ZU LANGSAM" : "FALSCH"))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(pts > 0 ? .challengrGreen : .challengrRed)
                    .scaleEffect(pointsPop ? 1.15 : 0.8)
                    .onAppear {
                        pointsPop = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { pointsPop = true }
                    }
                    .id(model.lastResult?.round)
            } else if model.myAnswer != nil {
                Label(model.opponentAnswered ? "Beide haben geantwortet" : "Warte auf \(opponentName) …",
                      systemImage: "hourglass")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Schnell sein bringt Bonus!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(height: 30)
    }

    private func feedbackForReveal() {
        let correct = model.myRoundPoints > 0
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        SoundManager.shared.play(correct ? .purchase : .challengeClosed)
    }
}

#Preview {
    let model = QuizShowModel(ownPlayerId: "me")
    return QuizShowView(model: model, battleId: 1, ownName: "Basti", opponentName: "Mia",
                        ownCharacter: .junge, opponentCharacter: .maedchen,
                        socket: GameSocketService(playerId: "me"), onSurrendered: {})
}
