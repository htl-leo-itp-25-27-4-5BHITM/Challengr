import XCTest
@testable import Challengr

/// Figurenwahl, Freischalten, echte Gegner-Figuren, Neustart in iPhone-Challenges.
@MainActor
final class CharacterUnlockTests: XCTestCase {

    private func unlock(_ id: String, _ unlocked: Bool, progress: Int = 0, required: Int = 0, type: String = "WINS") -> CharacterUnlockDTO {
        CharacterUnlockDTO(id: id, name: id, requirement: type, required: required, progress: progress, unlocked: unlocked, selected: false)
    }

    func testIdsMatchTheBackend() {
        XCTAssertEqual(GameCharacter.allCases.map(\.rawValue),
                       ["junge", "maedchen", "sir-brecht", "ragnar", "hayato", "kage", "kai", "merlo", "lyra", "kaeptn-rex", "crash-dummy"])
        XCTAssertEqual(GameCharacter.crashDummy.requirement, .event("Beta-Event"))
        XCTAssertEqual(GameCharacter.hayato.requirement, .rank("Tryhard", trophies: 600))
        XCTAssertEqual(GameCharacter.lyra.requirement, .checkins(5))
        XCTAssertEqual(GameCharacter.allCases.filter { $0.requirement == .none }, [.junge, .maedchen], "nur Junge und Mädchen frei")
        XCTAssertNil(GameCharacter.from(serverId: "godzilla"))
        XCTAssertNil(GameCharacter.from(serverId: nil))
    }

    func testStoreUsesServerUnlocksAndStartersAreFreeOffline() {
        let store = AvatarCustomizationStore()
        XCTAssertTrue(store.isUnlocked(.maedchen), "Start-Figur ohne Serverdaten frei")
        XCTAssertFalse(store.isUnlocked(.sirBrecht), "Roster-Figur ohne Serverdaten gesperrt")

        store.unlocks = ["ragnar": unlock("ragnar", false, progress: 1, required: 3)]
        XCTAssertEqual(store.progressText(.ragnar), "1/3 Siege")
        store.unlocks = ["lyra": unlock("lyra", false, progress: 2, required: 5, type: "CHECKINS")]
        XCTAssertEqual(store.progressText(.lyra), "2/5 Check-ins")
        store.unlocks = ["ragnar": unlock("ragnar", true, progress: 9, required: 3)]
        XCTAssertTrue(store.isUnlocked(.ragnar))
        XCTAssertEqual(store.progressText(.ragnar), "3/3 Siege")
        store.unlocks = ["hayato": unlock("hayato", false, progress: 420, required: 600, type: "TROPHIES")]
        XCTAssertEqual(store.progressText(.hayato), "Rang Tryhard · 420/600")
    }

    func testUnlockBannerOnlyForNewUnlocks() {
        let defaults = UserDefaults(suiteName: "unlock-test-\(UUID())")!
        // Erster Abgleich: nichts ankündigen
        XCTAssertEqual(CharacterUnlockTracker.newlyUnlocked([unlock("junge", true), unlock("hayato", false)], defaults: defaults), [])
        // Keine Änderung
        XCTAssertEqual(CharacterUnlockTracker.newlyUnlocked([unlock("junge", true), unlock("hayato", false)], defaults: defaults), [])
        // Hayato neu frei
        XCTAssertEqual(CharacterUnlockTracker.newlyUnlocked([unlock("junge", true), unlock("hayato", true)], defaults: defaults), [.hayato])
        // Nur einmal
        XCTAssertEqual(CharacterUnlockTracker.newlyUnlocked([unlock("junge", true), unlock("hayato", true)], defaults: defaults), [])
    }

    func testParticipantsFromBackendMessage() {
        let json: [String: Any] = ["fromPlayerId": "a", "toPlayerId": "me", "fromName": "test",
                                   "toName": "cookieclicker", "fromCharacter": "hayato", "toCharacter": NSNull()]
        let p = BattleParticipants.parse(json)
        XCTAssertEqual(p?.opponentName(ownId: "me"), "test")
        XCTAssertEqual(p?.opponentCharacter(ownId: "me"), .hayato)
        XCTAssertNil(p?.opponentCharacter(ownId: "a"), "unbekannte Figur → Ersatz-Figur in der App")
        XCTAssertNil(BattleParticipants.parse(["fromName": "x"]), "ohne Ids nichts")
    }

    func testConflictShowsRealNames() {
        var data = BattleResultData(winnerName: "Niemand", winnerAvatar: "", winnerPointsDelta: -10,
                                    loserName: "Niemand", loserAvatar: "", loserPointsDelta: -10,
                                    trashTalk: "Keine Einigung", metrics: nil)
        XCTAssertNil(data.playerNames(ownPlayerName: "Ich"))
        data.participants = BattleParticipants(fromId: "a", toId: "b", fromName: "Gegner", toName: "Ich")
        XCTAssertEqual(data.playerNames(ownPlayerName: "Ich")?.own, "Ich")
        XCTAssertEqual(data.playerNames(ownPlayerName: "Ich")?.opponent, "Gegner")
    }

    func testRestoreAfterRestart() {
        XCTAssertEqual(BattleRestore.screen(status: "ACCEPTED", submitted: false), .battle)
        XCTAssertEqual(BattleRestore.screen(status: "READY_FOR_VOTING", submitted: false), .voting)
        XCTAssertEqual(BattleRestore.screen(status: "ACCEPTED", submitted: true), .waitForResult,
                       "Ergebnis schon geschickt → nicht nochmal spielen")
        XCTAssertEqual(BattleRestore.screen(status: "READY_FOR_VOTING", submitted: true), .waitForResult)
    }

    func testRunningMessageKeepsTargetAndSubmitted() async {
        let socket = GameSocketService(playerId: "me")
        let exp = expectation(description: "running")
        socket.onBattleRunning = { _, _, _, _, _, _, _ in exp.fulfill() }
        socket.handleIncoming(text: #"{"type":"battle-running","battleId":21,"fromPlayerId":"a","toPlayerId":"me","challengeId":5,"challengeText":"Check-In-Spot","challengeCategory":"iPhone","status":"ACCEPTED","targetLatitude":48.1,"targetLongitude":14.2,"fromName":"test","toName":"me","fromCharacter":"ragnar","toCharacter":null,"submitted":true}"#)
        await fulfillment(of: [exp], timeout: 2)
        XCTAssertEqual(socket.runningExtras[21], RunningBattleExtras(targetLatitude: 48.1, targetLongitude: 14.2, submitted: true))
        XCTAssertEqual(socket.participantsByBattle[21]?.opponentName(ownId: "me"), "test")
        XCTAssertEqual(socket.participantsByBattle[21]?.opponentCharacter(ownId: "me"), .ragnar)
    }
}

final class CharacterServiceErrorTests: XCTestCase {
    func testOnlyLockedResetsTheChoice() {
        XCTAssertTrue(CharacterServiceError.rejected("gesperrt", statusCode: 403).isLocked)
        XCTAssertFalse(CharacterServiceError.rejected("alter Server", statusCode: 404).isLocked,
                       "Alter Server ohne Figuren-API darf die Wahl nicht zurücksetzen")
    }
}
