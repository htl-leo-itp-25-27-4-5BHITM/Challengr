import SwiftUI

struct KnowledgeBattleView: View {
    let battleId: Int64
    let socket: GameSocketService
    let initialQuestion: (battleId: Int64, text: String, choices: [String])?
    let onClose: () -> Void

    @State private var questionText: String = "Frage wird geladen …"
    @State private var choices: [String] = []
    @State private var selectedIndex: Int? = nil
    @State private var isSending = false

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
                                          ? Color.challengrYellow
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
                            .foregroundColor(selectedIndex == idx ? .black : .white)
                        }
                        .buttonStyle(.plain)
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
                                .fill(selectedIndex == nil ? Color.gray : Color.challengrGreen)
                        )
                        .foregroundColor(.white)
                }
                .disabled(selectedIndex == nil || isSending)
                .padding(.horizontal, 32)
                .padding(.top, 8)

                if isSending {
                    Text("Antwort gesendet – warte auf Ergebnis …")
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
            // 1) sofort vorhandene Frage setzen (falls schon da)
            if let q = initialQuestion, q.battleId == battleId {
                questionText = q.text
                choices = q.choices
            }

            // 2) für weitere Fragen lauschen
            NotificationCenter.default.addObserver(
                forName: .knowledgeQuestionReceived,
                object: nil,
                queue: .main
            ) { notif in
                guard
                    let userInfo = notif.userInfo,
                    let bId = userInfo["battleId"] as? Int64,
                    bId == battleId
                else { return }

                self.questionText = userInfo["text"] as? String ?? "Frage"
                self.choices = userInfo["choices"] as? [String] ?? []
                self.selectedIndex = nil
                self.isSending = false
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(
                self,
                name: .knowledgeQuestionReceived,
                object: nil
            )
        }
    }
}
