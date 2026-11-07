import Foundation

/// Übungsgegner am Server (`control.PracticeBot`): nimmt jede Herausforderung an und spielt mit.
/// Übungs-Battles bringen keine Trophäen, Sticker oder Aufgaben-Fortschritt.
enum PracticeBot {
    static let id = "practice-bot"
    static let name = "Trainings-Dummy"
    static let character: GameCharacter = .crashDummy

    static func isBot(_ playerId: String?) -> Bool { playerId == id }
}

extension BattleParticipants {
    var isPractice: Bool { PracticeBot.isBot(fromId) || PracticeBot.isBot(toId) }
}
