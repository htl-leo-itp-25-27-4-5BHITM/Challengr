import XCTest
@testable import Challengr

/// Welche Battle-Ansicht öffnet sich für welche Challenge?
final class BattleScreenTests: XCTestCase {

    func testKnowledgeCategoryAlwaysOpensKnowledgeView() {
        XCTAssertEqual(BattleScreen.forChallenge(category: "Wissen", name: "Was ist die Hauptstadt von Österreich?"), .knowledge)
        XCTAssertEqual(BattleScreen.forChallenge(category: "Wissen", name: "Sprint-Challenge"), .knowledge,
                       "Kategorie gewinnt vor dem Namen")
    }

    func testIPhoneChallengesByName() {
        let cases: [(String, BattleScreen)] = [
            ("Check-In-Spot: Wer ist zuerst da?", .checkInSpot),
            ("Sprint-Challenge: 15 Sekunden", .sprint),
            ("Schrei-Challenge: Wer ist lauter?", .loudness),
            ("Kamera-Farbe finden", .camera),
            ("Camera Hunt", .camera),
            ("Foto von etwas Rotem", .camera),
            ("Kompass: Finde Norden", .compass),
            ("Compass Duel", .compass),
            ("Shake it!", .shake),
            ("Schüttel-Challenge", .shake),
            ("Liegestütze in 30 Sekunden", .pushup),
            ("Pushup Battle", .pushup),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: name), expected, name)
        }
    }

    func testNameMatchingIsCaseInsensitiveWhereItWasBefore() {
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "KAMERA"), .camera)
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "SCHÜTTELN"), .shake)
    }

    func testUnknownIPhoneChallengeIsGeneric() {
        XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: "Irgendwas Neues"), .generic)
    }

    func testOtherCategoriesAreGenericEvenWithSpecialWords() {
        for category in ["Fitness", "Mutprobe", "Customer", "Unbekannt"] {
            XCTAssertEqual(BattleScreen.forChallenge(category: category, name: "Liegestütze mit Kamera"), .generic, category)
        }
    }

    func testUnresolvedChallengeFallsBackToGeneric() {
        // So sieht eine Challenge aus, die nicht aufgelöst werden konnte
        XCTAssertEqual(BattleScreen.forChallenge(category: "Unbekannt", name: "Challenge 42"), .generic)
    }

    /// Genau die Texte aus import.sql – jede iPhone-Challenge braucht ihre Spezial-Ansicht.
    func testAllIPhoneChallengesFromImportSqlHaveTheirOwnView() {
        let fromImportSql: [(String, BattleScreen)] = [
            ("Sprint-Challenge: Laufe in 15 Sekunden so weit wie möglich.", .sprint),
            ("Check-In-Spot: Erreiche den Zielpunkt auf der Karte.", .checkInSpot),
            ("Kompass-Präzision: Richte dich auf einen zufälligen Zielwinkel aus.", .compass),
            ("Shake-Challenge: Schüttle das iPhone 5 Sekunden lang maximal.", .shake),
            ("Schrei-Challenge: Sei in 10 Sekunden so laut wie möglich.", .loudness),
            ("Foto-Beweis: Finde ein rotes Auto und fotografiere es.", .camera),
            ("Liegestütz-Zähler: Zähle deine Push-Ups mit der Nase auf dem Screen.", .pushup),
        ]
        for (text, expected) in fromImportSql {
            XCTAssertEqual(BattleScreen.forChallenge(category: "iPhone", name: text), expected, text)
        }
    }
}
