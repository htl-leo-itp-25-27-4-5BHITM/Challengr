import Foundation
import Combine

/// Eine Frage der Quiz-Show (Liga Wissen) vom Server.
struct QuizQuestion: Equatable {
    let battleId: Int64
    let round: Int
    let rounds: Int
    let timeLimitSeconds: Int
    /// Restzeit beim Empfang (nach einem Neustart weniger als das Limit)
    let remainingMs: Int
    let questionId: Int64
    let text: String
    let choices: [String]
    let scores: [String: Int]

    static func parse(_ json: [String: Any]) -> QuizQuestion? {
        guard let battleId = (json["battleId"] as? NSNumber)?.int64Value,
              let q = json["question"] as? [String: Any],
              let text = q["text"] as? String,
              let choices = q["choices"] as? [String] else { return nil }
        let limit = json["timeLimitSeconds"] as? Int ?? 15
        return QuizQuestion(
            battleId: battleId,
            round: json["round"] as? Int ?? 1,
            rounds: json["rounds"] as? Int ?? 4,
            timeLimitSeconds: limit,
            remainingMs: json["remainingMs"] as? Int ?? limit * 1000,
            questionId: (q["id"] as? NSNumber)?.int64Value ?? 0,
            text: text,
            choices: choices,
            scores: json["scores"] as? [String: Int] ?? [:]
        )
    }
}

/// Auflösung einer Runde: richtige Antwort, was jeder gewählt hat, Punkte.
struct QuizRoundResult: Equatable {
    struct Answer: Equatable {
        let answerIndex: Int
        let points: Int
    }

    let battleId: Int64
    let round: Int
    let rounds: Int
    let correctIndex: Int
    let last: Bool
    let answers: [String: Answer]
    let scores: [String: Int]

    static func parse(_ json: [String: Any]) -> QuizRoundResult? {
        guard let battleId = (json["battleId"] as? NSNumber)?.int64Value else { return nil }
        var answers: [String: Answer] = [:]
        for (player, value) in json["answers"] as? [String: [String: Any]] ?? [:] {
            answers[player] = Answer(answerIndex: value["answerIndex"] as? Int ?? -1, points: value["points"] as? Int ?? 0)
        }
        return QuizRoundResult(
            battleId: battleId,
            round: json["round"] as? Int ?? 1,
            rounds: json["rounds"] as? Int ?? 4,
            correctIndex: json["correctIndex"] as? Int ?? -1,
            last: json["last"] as? Bool ?? false,
            answers: answers,
            scores: json["scores"] as? [String: Int] ?? [:]
        )
    }
}

/// Zustand der Quiz-Show für die eigene Sicht. Lebt in der MapView, damit keine Nachricht
/// verloren geht, auch wenn sie ankommt, bevor der Quiz-Screen offen ist.
/// `nonisolated` wie `AvatarCustomizationStore`: sonst stürzt das Freigeben im Back-Deploy-Shim ab.
nonisolated final class QuizShowModel: ObservableObject {
    enum Phase: Equatable {
        /// "QUIZ-SHOW" – vor der ersten Frage
        case intro
        /// Frage läuft, Antwort noch offen oder schon abgegeben
        case question
        /// Auflösung der Runde
        case reveal
    }

    let ownPlayerId: String

    @Published private(set) var battleId: Int64? = nil
    @Published private(set) var phase: Phase = .intro
    @Published private(set) var question: QuizQuestion? = nil
    @Published private(set) var myAnswer: Int? = nil
    @Published private(set) var opponentAnswered = false
    @Published private(set) var lastResult: QuizRoundResult? = nil
    @Published private(set) var ownScore = 0
    @Published private(set) var opponentScore = 0
    /// Wann die aktuelle Frage endet (für den Countdown)
    @Published private(set) var deadline: Date? = nil

    init(ownPlayerId: String) {
        self.ownPlayerId = ownPlayerId
    }

    /// Neues Quiz-Battle: alles zurücksetzen.
    func start(battleId: Int64) {
        guard self.battleId != battleId else { return }
        self.battleId = battleId
        phase = .intro
        question = nil
        myAnswer = nil
        opponentAnswered = false
        lastResult = nil
        ownScore = 0
        opponentScore = 0
        deadline = nil
    }

    func receive(_ q: QuizQuestion, now: Date = Date()) {
        if battleId != q.battleId { start(battleId: q.battleId) }
        let isNewRound = question?.round != q.round
        question = q
        if isNewRound {
            myAnswer = nil
            opponentAnswered = false
        }
        phase = .question
        deadline = now.addingTimeInterval(Double(q.remainingMs) / 1000)
        applyScores(q.scores)
    }

    func receive(_ r: QuizRoundResult) {
        guard r.battleId == battleId else { return }
        lastResult = r
        phase = .reveal
        deadline = nil
        applyScores(r.scores)
    }

    func opponentDidAnswer(battleId: Int64, round: Int) {
        guard battleId == self.battleId, round == question?.round else { return }
        opponentAnswered = true
    }

    /// Eigene Antwort merken; nil, wenn schon geantwortet oder Zeit um.
    func answer(_ index: Int, now: Date = Date()) -> (battleId: Int64, round: Int, index: Int)? {
        guard phase == .question, myAnswer == nil, let q = question, let battleId,
              !isTimeUp(now: now) else { return nil }
        myAnswer = index
        return (battleId, q.round, index)
    }

    func secondsLeft(now: Date = Date()) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }

    /// 1…0 für den Zeitbalken
    func timeFraction(now: Date = Date()) -> Double {
        guard let deadline, let q = question, q.timeLimitSeconds > 0 else { return 0 }
        return max(0, min(1, deadline.timeIntervalSince(now) / Double(q.timeLimitSeconds)))
    }

    func isTimeUp(now: Date = Date()) -> Bool {
        guard let deadline else { return phase != .question }
        return now >= deadline
    }

    /// Punkte der letzten Runde für mich bzw. den Gegner
    var myRoundPoints: Int { lastResult?.answers[ownPlayerId]?.points ?? 0 }
    var opponentRoundAnswer: Int? {
        lastResult?.answers.first(where: { $0.key != ownPlayerId })?.value.answerIndex
    }
    var opponentRoundPoints: Int {
        lastResult?.answers.first(where: { $0.key != ownPlayerId })?.value.points ?? 0
    }

    private func applyScores(_ scores: [String: Int]) {
        ownScore = scores[ownPlayerId] ?? ownScore
        if let other = scores.first(where: { $0.key != ownPlayerId }) {
            opponentScore = other.value
        }
    }
}
