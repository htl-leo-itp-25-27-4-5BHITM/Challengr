import SwiftUI
import Combine

struct KnowledgeBattleView: View {
    // MARK: - Input (Eingaben)
    let battleId: Int64
    let socket: GameSocketService
    let initialQuestion: (battleId: Int64, text: String, choices: [String], timeLimit: Int?)?
    let onClose: () -> Void

    // MARK: - State (State)
    @State private var questionText: String = "Frage wird geladen …"
    @State private var choices: [String] = []
    @State private var selectedIndex: Int? = nil
    @State private var isSending = false
    /// Backend hat die eigene Antwort als falsch gemeldet.
    @State private var answerWasWrong = false
    /// Zeitpunkt, an dem das Zeitlimit abläuft (nil = altes Backend ohne Zeitlimit).
    @State private var deadline: Date? = nil
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var secondsLeft: Int? {
        guard let deadline else { return nil }
        return KnowledgeTimer.secondsLeft(until: deadline, now: now)
    }

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .challengrDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                // Header
                VStack(spacing: 8) {
                    Text("WISSENS-BATTLE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                        .tracking(2)

                    Text("Wer kennt sich besser aus?")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    if let secondsLeft {
                        Text(secondsLeft > 0 ? "Noch \(secondsLeft) s" : "Zeit abgelaufen")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(secondsLeft <= 5 ? .challengrRed : .challengrYellow)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .accessibilityLabel(secondsLeft > 0 ? "Noch \(secondsLeft) Sekunden" : "Zeit abgelaufen")
                    }
                }
                .padding(.top, 32)

                // Frage
                Text(questionText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                    )

                // Antworten
                VStack(spacing: 12) {
                    ForEach(choices.indices, id: \.self) { idx in
                        Button {
                            selectedIndex = idx
                        } label: {
                            HStack {
                                Text(choices[idx])
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedIndex == idx
                                          ? (answerWasWrong ? Color.challengrRed : Color.challengrYellow)
                                          : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedIndex == idx
                                        ? Color.white
                                        : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .foregroundColor(selectedIndex == idx ? (answerWasWrong ? .white : .black) : .white)
                        }
                        .buttonStyle(.plain)
                        // Nur eine Antwort pro Spieler – danach ist die Auswahl gesperrt.
                        .disabled(isSending || timeIsUp)
                    }
                }
                .padding(.horizontal, 20)

                // Bestätigen-Button
                Button {
                    guard let idx = selectedIndex else { return }
                    isSending = true
                    socket.sendKnowledgeAnswer(battleId: battleId, answerIndex: idx)
                } label: {
                    Text(selectedIndex == nil ? "Antwort wählen" : "Antwort bestätigen")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(selectedIndex == nil || isSending || timeIsUp ? Color.gray : Color.challengrGreen)
                        )
                        .foregroundColor(.white)
                }
                .disabled(selectedIndex == nil || isSending || timeIsUp)
                .padding(.horizontal, 32)
                .padding(.top, 8)

                if answerWasWrong {
                    VStack(spacing: 4) {
                        Text("FALSCH!")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.challengrRed)
                        Text("Jetzt kann nur noch dein Gegner gewinnen – antwortet er auch falsch, ist es unentschieden.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                } else if isSending {
                    Text("Antwort gesendet – warte auf Ergebnis …")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                } else if timeIsUp {
                    Text("Zeit abgelaufen – warte auf Ergebnis …")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                }

                Spacer()

                // Close
                Button {
                    onClose()
                } label: {
                    Text("Schließen")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // Frage, die schon vor dem Öffnen des Screens ankam
            if let q = initialQuestion, q.battleId == battleId {
                show(text: q.text, choices: q.choices, timeLimit: q.timeLimit)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .knowledgeQuestionReceived)) { notif in
            guard let userInfo = notif.userInfo,
                  let bId = userInfo["battleId"] as? Int64, bId == battleId else { return }
            show(text: userInfo["text"] as? String ?? "Frage",
                 choices: userInfo["choices"] as? [String] ?? [],
                 timeLimit: userInfo["timeLimit"] as? Int)
        }
        .onReceive(NotificationCenter.default.publisher(for: .knowledgeAnswerFeedback)) { notif in
            guard let userInfo = notif.userInfo,
                  let bId = userInfo["battleId"] as? Int64, bId == battleId,
                  let correct = userInfo["correct"] as? Bool, !correct else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { answerWasWrong = true }
            SoundManager.shared.play(.challengeClosed)
        }
        .onReceive(tick) { now = $0 }
    }

    private var timeIsUp: Bool { (secondsLeft ?? 1) <= 0 }

    private func show(text: String, choices: [String], timeLimit: Int?) {
        questionText = text
        self.choices = choices
        selectedIndex = nil
        isSending = false
        answerWasWrong = false
        let start = Date()
        now = start
        deadline = timeLimit.map { start.addingTimeInterval(TimeInterval($0)) }
    }
}

/// Countdown-Rechnung für das Wissens-Battle (testbar ohne UI).
enum KnowledgeTimer {
    static func secondsLeft(until deadline: Date, now: Date) -> Int {
        max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
    }
}
