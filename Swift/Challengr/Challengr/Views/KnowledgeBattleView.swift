import SwiftUI

struct KnowledgeBattleView: View {
    let battleId: Int64
    let socket: GameSocketService

    @State private var question: ChallengeDTO?
    @State private var selectedIndex: Int? = nil
    @State private var isSubmitting = false

    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let q = question,
               let choices = q.choices,
               choices.count == 4 {

                Text(q.text)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()

                ForEach(choices.indices, id: \.self) { index in
                    Button {
                        selectedIndex = index
                    } label: {
                        HStack {
                            Text(choices[index])
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.challengrYellow)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIndex == index ? Color.challengrYellow.opacity(0.2)
                                                             : Color(.systemBackground))
                        )
                    }
                    .disabled(isSubmitting)
                }

                Button("Antwort senden") {
                    guard let index = selectedIndex else { return }
                    isSubmitting = true
                    socket.sendKnowledgeAnswer(battleId: battleId, answerIndex: index)
                }
                .buttonStyle(.borderedProminent)
                .tint(.challengrYellow)
                .disabled(selectedIndex == nil || isSubmitting)

            } else {
                ProgressView("Frage wird geladen …")
            }
        }
        .padding()
        .onAppear {
            socket.onKnowledgeQuestion = { incomingBattleId, dto in
                guard incomingBattleId == battleId else { return }
                question = dto
                selectedIndex = nil
                isSubmitting = false
            }
        }
    }
}
