import XCTest
import SceneKit
import UIKit
@testable import Challengr

/// Tests für die 3D-Spielfiguren.
final class GameCharacterTests: XCTestCase {

    func testOpponentIsTheOtherCharacter() {
        XCTAssertNotEqual(GameCharacter.own, GameCharacter.opponent)
    }

    func testResultScreensPickCharacterByPlayerName() {
        XCTAssertEqual(GameCharacter.forPlayer("Ich", ownPlayerName: "Ich"), GameCharacter.own)
        XCTAssertEqual(GameCharacter.forPlayer("Gegner", ownPlayerName: "Ich"), GameCharacter.opponent)
    }

    func testEveryCharacterHasModelAndImages() {
        for character in GameCharacter.allCases {
            let model = CharacterScene.prototype(for: character)
            XCTAssertNotNil(model, "Modell fehlt: \(character.sceneName).scn")
            var triangles = 0
            model?.enumerateHierarchy { node, _ in node.geometry?.elements.forEach { triangles += $0.primitiveCount } }
            XCTAssertGreaterThan(triangles, 1000, character.sceneName)
            XCTAssertNotNil(UIImage(named: character.imageName), character.imageName)
            XCTAssertNotNil(UIImage(named: character.avatarImageName), character.avatarImageName)
        }
    }

    func testModelsUseNoCustomShaders() {
        // Eigene Shader kompilierten auf echten iPhones nicht → Magenta-Fläche im Battle
        for character in GameCharacter.allCases {
            CharacterScene.prototype(for: character)?.enumerateHierarchy { node, _ in
                for material in node.geometry?.materials ?? [] {
                    XCTAssertNil(material.shaderModifiers, "\(character.sceneName): Material mit eigenem Shader")
                    XCTAssertNotEqual(material.lightingModel, .physicallyBased)
                }
            }
        }
    }

    func testSceneHasCameraAndLights() {
        let built = CharacterScene.make(.own, yaw: 0, autoRotate: false)
        XCTAssertNotNil(built?.camera.camera)
        var lights = 0
        built?.scene.rootNode.enumerateHierarchy { node, _ in if node.light != nil { lights += 1 } }
        XCTAssertEqual(lights, 2)
    }

    func testOutfitPresetIsOwnCharacter() {
        XCTAssertEqual(AvatarPresets.presets(for: .outfits).map(\.character), [GameCharacter.own])
    }

    func testOldTwoDPresetFallsBackToOwnCharacter() {
        let key = AvatarCustomizationStore.presetKey
        let previous = UserDefaults.standard.string(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }

        UserDefaults.standard.set("boy", forKey: key)
        XCTAssertEqual(AvatarPresets.persistedPreset().character, GameCharacter.own)
        XCTAssertEqual(AvatarPresets.persistedAvatarImageName(), GameCharacter.own.avatarImageName)
    }
}

/// Sicherheitsnetz gegen SceneKits Magenta-Fehlerfläche.
final class MagentaCheckTests: XCTestCase {
    private func image(_ color: UIColor, size: CGSize = CGSize(width: 40, height: 40), fill: CGFloat = 1) -> CGImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width * fill, height: size.height))
        }.cgImage!
    }

    func testDetectsSceneKitMagenta() {
        XCTAssertTrue(MagentaCheck.isMostlyMagenta(image(UIColor(red: 1, green: 0.25, blue: 1, alpha: 1))))
    }

    func testIgnoresCharacterColorsAndTransparency() {
        XCTAssertFalse(MagentaCheck.isMostlyMagenta(image(.clear)))
        XCTAssertFalse(MagentaCheck.isMostlyMagenta(image(UIColor(red: 0.73, green: 0.12, blue: 0.2, alpha: 1)))) // Rot (Schild, Federbusch)
        XCTAssertFalse(MagentaCheck.isMostlyMagenta(image(UIColor(red: 0.88, green: 0.42, blue: 0.1, alpha: 1)))) // Orange (Bart)
        // Ein kleiner magentafarbener Fleck ist noch keine Fehlerfläche
        XCTAssertFalse(MagentaCheck.isMostlyMagenta(image(UIColor(red: 1, green: 0.25, blue: 1, alpha: 1), fill: 0.1)))
    }

    func testRenderGateRunsOneAfterAnother() {
        var log: [String] = []
        let done = expectation(description: "beide fertig")
        var releaseFirst: (() -> Void)?
        CharacterRenderGate.enqueue { release in log.append("A start"); releaseFirst = release }
        CharacterRenderGate.enqueue { release in log.append("B start"); release(); done.fulfill() }
        XCTAssertEqual(log, ["A start"], "B darf erst nach A starten")
        log.append("A fertig")
        releaseFirst?()
        wait(for: [done], timeout: 2)
        XCTAssertEqual(log, ["A start", "A fertig", "B start"])
    }
}
