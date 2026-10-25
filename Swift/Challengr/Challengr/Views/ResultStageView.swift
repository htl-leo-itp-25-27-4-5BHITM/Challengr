import SwiftUI
import SceneKit

/// 3D-Siegerehrung nach einem Battle: Sieger landet auf dem Podest, Pokal steigt auf, Konfetti;
/// der Verlierer geht K.O. (Sicht des Siegers) oder steht im Regen (eigene Niederlage).
/// Wie das Quiz-Studio EIN SceneKit-Fenster für beide Figuren, keine eigenen Shader,
/// 2D-Ersatz, falls SceneKit nicht zeichnet.
struct ResultStageView: View {
    nonisolated enum Focus: Equatable {
        /// Eigener Sieg: Kamera auf den Sieger, Gegner geht K.O.
        case win
        /// Eigene Niederlage: Kamera auf den Verlierer im Regen, Sieger jubelt dahinter
        case lose
        /// Unentschieden/Konflikt: beide gleich hoch (`happy` = Unentschieden, sonst Konflikt)
        case even(happy: Bool)
    }

    /// Bei `.even` links der eigene Spieler, rechts der Gegner.
    let winner: GameCharacter
    let loser: GameCharacter
    let focus: Focus

    @State private var showsModel = false

    /// Sekunden bis zur Landung des Siegers – danach knallt der Titel ins Bild.
    static let landingTime: TimeInterval = 0.95

    var body: some View {
        ZStack {
            if !showsModel { fallback }
            ResultStageSceneView(winner: winner, loser: loser, focus: focus) { ok in
                showsModel = ok
            }
            .opacity(showsModel ? 1 : 0.011)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch focus {
        case .win: return "Siegerehrung: deine Figur steht auf dem Podest"
        case .lose: return "Siegerehrung: der Gegner steht auf dem Podest"
        case .even: return "Beide Figuren stehen gleich hoch"
        }
    }

    /// 2D-Ersatz: Figuren als Bilder auf Podesten.
    private var fallback: some View {
        let even: Bool = { if case .even = focus { return true } else { return false } }()
        return HStack(alignment: .bottom, spacing: 18) {
            podium2D(winner, height: even ? 50 : 80, label: even ? nil : "1", mirrored: true)
            podium2D(loser, height: even ? 50 : 26, label: even ? nil : "2", mirrored: false)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
    }

    private func podium2D(_ character: GameCharacter, height: CGFloat, label: String?, mirrored: Bool) -> some View {
        VStack(spacing: -6) {
            Image(character.imageName)
                .resizable().scaledToFit()
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                .frame(maxHeight: 170)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                if let label {
                    Text(label)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.challengrYellow)
                }
            }
            .frame(width: 120, height: height)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SceneKit

private struct ResultStageSceneView: UIViewRepresentable {
    let winner: GameCharacter
    let loser: GameCharacter
    let focus: ResultStageView.Focus
    let onResult: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isPlaying = true
        view.isUserInteractionEnabled = false
        view.delegate = context.coordinator
        context.coordinator.view = view

        guard let stage = ResultStage.build(winner: winner, loser: loser, focus: focus) else {
            print("❌ Ergebnis-Bühne konnte nicht gebaut werden")
            DispatchQueue.main.async { onResult(false) }
            return view
        }
        context.coordinator.stage = stage
        let coordinator = context.coordinator
        CharacterRenderGate.enqueue { release in
            coordinator.release = release
            view.prepare([stage.scene]) { _ in
                DispatchQueue.main.async {
                    coordinator.awaitingFirstFrame = true
                    view.scene = stage.scene
                    view.pointOfView = stage.camera
                    stage.playIntro()
                }
            }
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onResult = onResult
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.releaseGate()
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view: SCNView?
        var stage: ResultStage?
        var onResult: (Bool) -> Void
        var release: (() -> Void)?
        var awaitingFirstFrame = false

        init(onResult: @escaping (Bool) -> Void) { self.onResult = onResult }

        func releaseGate() {
            release?()
            release = nil
        }

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard awaitingFirstFrame else { return }
            awaitingFirstFrame = false
            DispatchQueue.main.async { self.checkFirstFrame() }
        }

        private func checkFirstFrame() {
            defer { releaseGate() }
            guard let view else { return }
            if let image = view.snapshot().cgImage, MagentaCheck.isMostlyMagenta(image) {
                print("⚠️ Ergebnis-Bühne zeichnet Magenta – 2D-Ersatz bleibt")
                view.scene = nil
                onResult(false)
            } else {
                onResult(true)
            }
        }
    }
}

// MARK: - Bühnen-Aufbau und Animationen

/// Boden, Podeste, Pokal, Scheinwerfer, Kamera und beide Figuren.
/// Nur Standard-Materialien und -Lichter (keine eigenen Shader).
/// `nonisolated` wie `QuizStudio`: sonst stürzt das Freigeben im Back-Deploy-Shim ab.
nonisolated final class ResultStage {
    let scene: SCNScene
    let camera: SCNNode
    private let focus: ResultStageView.Focus
    private let winnerActor: SCNNode
    private let loserActor: SCNNode
    private let winnerSpot: SCNNode
    private let loserSpot: SCNNode
    private let trophy: SCNNode
    private let root: SCNNode

    static let gold = UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)        // challengrYellow
    static let red = UIColor(red: 0.73, green: 0.12, blue: 0.20, alpha: 1)       // challengrRed
    static let rainBlue = UIColor(red: 0.55, green: 0.70, blue: 1.0, alpha: 1)

    /// Podest-Höhen: Sieger, Verlierer, beide bei Gleichstand
    static let winnerHeight: CGFloat = 0.42
    static let loserHeight: CGFloat = 0.10
    static let evenHeight: CGFloat = 0.26

    private var isEven: Bool { if case .even = focus { return true } else { return false } }

    private init(scene: SCNScene, camera: SCNNode, focus: ResultStageView.Focus, winner: SCNNode, loser: SCNNode,
                 winnerSpot: SCNNode, loserSpot: SCNNode, trophy: SCNNode) {
        self.scene = scene
        self.camera = camera
        self.focus = focus
        self.winnerActor = winner
        self.loserActor = loser
        self.winnerSpot = winnerSpot
        self.loserSpot = loserSpot
        self.trophy = trophy
        self.root = scene.rootNode
    }

    static func build(winner: GameCharacter, loser: GameCharacter, focus: ResultStageView.Focus) -> ResultStage? {
        guard let winnerModel = CharacterScene.prototype(for: winner)?.clone(),
              let loserModel = CharacterScene.prototype(for: loser)?.clone() else { return nil }
        let even: Bool = { if case .even = focus { return true } else { return false } }()

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let root = scene.rootNode

        // Boden: runde Arena mit Lauflichtern am Rand
        let floor = SCNNode(geometry: SCNCylinder(radius: 2.4, height: 0.06))
        floor.geometry?.firstMaterial = material(UIColor(red: 0.20, green: 0.04, blue: 0.10, alpha: 1))
        floor.position = SCNVector3(0, -0.03, -0.3)
        root.addChildNode(floor)
        for i in 0..<28 {
            let a = Float(i) / 28 * .pi * 2
            let bulb = SCNNode(geometry: SCNSphere(radius: 0.03))
            bulb.geometry?.firstMaterial = glow(i % 2 == 0 ? .white : gold)
            bulb.position = SCNVector3(2.4 * cos(a), 0.02, -0.3 + 2.4 * sin(a))
            bulb.runAction(.repeatForever(.sequence([.wait(duration: Double(i % 4) * 0.12),
                                                      .fadeOpacity(to: 0.2, duration: 0.25),
                                                      .fadeOpacity(to: 1, duration: 0.25)])))
            root.addChildNode(bulb)
        }

        // Podeste: Sieger links hoch ("1"), Verlierer rechts niedrig ("2")
        let winnerX: Float = even ? -0.6 : -0.5
        let loserX: Float = even ? 0.6 : 0.62
        let winnerTop = even ? evenHeight : winnerHeight
        let loserTop = even ? evenHeight : loserHeight
        root.addChildNode(podium(x: winnerX, height: winnerTop, width: 0.8, label: even ? nil : "1",
                                 color: even ? gold : gold))
        root.addChildNode(podium(x: loserX, height: loserTop, width: 0.72, label: even ? nil : "2",
                                 color: even ? gold : UIColor(white: 0.5, alpha: 1)))

        // Figuren (ca. 1 m hoch, Füße auf y = 0, Blick nach +z), leicht zueinander gedreht
        let winnerActor = actor(winnerModel, position: SCNVector3(winnerX, Float(winnerTop), 0), yaw: 0.3)
        let loserActor = actor(loserModel, position: SCNVector3(loserX, Float(loserTop), 0), yaw: -0.3)
        [winnerActor, loserActor].forEach(root.addChildNode)
        idle(winnerActor); idle(loserActor)

        // Pokal: steckt erst im Podest bzw. unsichtbar in der Mitte
        let trophy = makeTrophy()
        trophy.position = even ? SCNVector3(0, 0.9, 0.1) : SCNVector3(winnerX, Float(winnerTop) - 0.3, 0)
        trophy.opacity = 0
        root.addChildNode(trophy)

        // Licht
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = focus == .lose ? 300 : 380
        ambient.light?.color = UIColor(red: 0.80, green: 0.72, blue: 0.90, alpha: 1)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 520
        key.eulerAngles = SCNVector3(-0.7, -0.3, 0)
        root.addChildNode(key)

        let winnerSpot = spot(color: gold, at: SCNVector3(winnerX, 3.6, 1.6), target: winnerActor)
        let loserSpot = spot(color: even ? gold : UIColor(white: 0.8, alpha: 1), at: SCNVector3(loserX, 3.6, 1.6), target: loserActor)
        [winnerSpot, loserSpot].forEach(root.addChildNode)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 34
        camera.position = SCNVector3(0, 3.0, 8.5)
        camera.look(at: SCNVector3(0, 0.7, 0))
        root.addChildNode(camera)

        return ResultStage(scene: scene, camera: camera, focus: focus, winner: winnerActor, loser: loserActor,
                           winnerSpot: winnerSpot, loserSpot: loserSpot, trophy: trophy)
    }

    // MARK: Ablauf

    /// Kamera-Endpunkt und Blickziel je nach Sicht
    private var cameraShot: (position: SCNVector3, lookAt: SCNVector3) {
        switch focus {
        case .win:  return (SCNVector3(-0.15, 1.35, 3.6), SCNVector3(-0.05, 0.9, 0))
        case .lose: return (SCNVector3(0.3, 1.2, 3.3), SCNVector3(0.2, 0.78, 0))
        case .even: return (SCNVector3(0, 1.15, 3.5), SCNVector3(0, 0.72, 0))
        }
    }

    func playIntro() {
        let shot = cameraShot
        let fly = SCNAction.move(to: shot.position, duration: 1.3)
        fly.timingMode = .easeInEaseOut
        let look = SCNAction.customAction(duration: 1.3) { node, _ in node.look(at: shot.lookAt) }
        // danach langsames Hin- und Herschwenken, damit die Bühne lebt
        let drift = SCNAction.repeatForever(.sequence([
            .moveBy(x: 0.25, y: 0, z: 0, duration: 3.5), .moveBy(x: -0.25, y: 0, z: 0, duration: 3.5)
        ]))
        drift.timingMode = .easeInEaseOut
        camera.runAction(.sequence([.group([fly, look]),
                                    .group([drift, .repeatForever(.customAction(duration: 1) { node, _ in node.look(at: shot.lookAt) })])]))

        winnerSpot.light?.intensity = 0
        loserSpot.light?.intensity = 0

        switch focus {
        case .win:
            dropIn(winnerActor, delay: 0.5)
            dropIn(loserActor, delay: 0.25, height: 2.2)
            lightUp(winnerSpot, delay: ResultStageView.landingTime, intensity: 1200)
            lightUp(loserSpot, delay: 0.6, intensity: 450)
            celebrate(winnerActor, delay: 1.35)
            raiseTrophy(delay: 1.5)
            knockOut(loserActor, delay: 1.7)
            confetti(xRange: -1.6...1.6, delay: 1.2)

        case .lose:
            dropIn(winnerActor, delay: 0.5)
            dropIn(loserActor, delay: 0.25, height: 2.2)
            lightUp(winnerSpot, delay: ResultStageView.landingTime, intensity: 1100)
            lightUp(loserSpot, delay: 0.6, intensity: 380)
            loserSpot.light?.color = ResultStage.rainBlue
            celebrate(winnerActor, delay: 1.35)
            raiseTrophy(delay: 1.5)
            confetti(xRange: -1.2...(-0.1), delay: 1.2)
            rainCloud(over: loserActor, delay: 1.4)
            slump(loserActor, delay: 1.9)

        case .even(let happy):
            dropIn(winnerActor, delay: 0.5)
            dropIn(loserActor, delay: 0.5)
            lightUp(winnerSpot, delay: ResultStageView.landingTime, intensity: 900)
            lightUp(loserSpot, delay: ResultStageView.landingTime, intensity: 900)
            if happy {
                hop(winnerActor, delay: 1.3); hop(loserActor, delay: 1.5)
                hop(winnerActor, delay: 1.9); hop(loserActor, delay: 2.1)
                showMiddleTrophy(delay: 1.4)
            } else {
                slump(winnerActor, delay: 1.4)
                slump(loserActor, delay: 1.4)
            }
        }
    }

    // MARK: Bausteine

    /// Figur fällt von oben auf ihr Podest: Stauchen beim Aufprall + Druckwelle
    private func dropIn(_ actor: SCNNode, delay: TimeInterval, height: CGFloat = 3.0) {
        guard let body = actor.childNodes.first else { return }
        body.position.y = Float(height)
        body.opacity = 0
        let fall = SCNAction.moveBy(x: 0, y: -height, z: 0, duration: 0.45)
        fall.timingMode = .easeIn
        let squash = SCNAction.customAction(duration: 0.32) { node, t in
            // schnell flach, dann federnd zurück
            let p = Float(t / 0.32)
            let s = 1 - 0.22 * sin(p * .pi) * (1 - p * 0.5)
            node.scale = SCNVector3(2 - s, s, 2 - s)
        }
        body.runAction(.sequence([
            .wait(duration: delay), .fadeIn(duration: 0.05), fall, squash,
            .run { node in node.scale = SCNVector3(1, 1, 1) }
        ]))
        shockwave(at: actor.position, delay: delay + 0.5)
    }

    /// Leuchtender Ring, der sich beim Aufprall ausbreitet
    private func shockwave(at position: SCNVector3, delay: TimeInterval) {
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.3, pipeRadius: 0.015))
        ring.geometry?.firstMaterial = ResultStage.glow(.white)
        ring.position = SCNVector3(position.x, position.y + 0.02, position.z)
        ring.opacity = 0
        root.addChildNode(ring)
        ring.runAction(.sequence([.wait(duration: delay), .fadeIn(duration: 0),
                                  .group([.scale(to: 3.2, duration: 0.5), .fadeOut(duration: 0.5)]),
                                  .removeFromParentNode()]))
    }

    private func lightUp(_ spot: SCNNode, delay: TimeInterval, intensity: CGFloat) {
        spot.runAction(.sequence([.wait(duration: delay), .customAction(duration: 0.25) { node, t in
            node.light?.intensity = intensity * t / 0.25
        }]))
    }

    /// Jubel: hochspringen mit voller Drehung, dann immer wieder kleine Freudensprünge
    private func celebrate(_ actor: SCNNode, delay: TimeInterval) {
        guard let body = actor.childNodes.first else { return }
        let up = SCNAction.moveBy(x: 0, y: 0.4, z: 0, duration: 0.25); up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -0.4, z: 0, duration: 0.25); down.timingMode = .easeIn
        let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 0.5)
        let smallUp = SCNAction.moveBy(x: 0, y: 0.14, z: 0, duration: 0.14); smallUp.timingMode = .easeOut
        let smallDown = SCNAction.moveBy(x: 0, y: -0.14, z: 0, duration: 0.14); smallDown.timingMode = .easeIn
        let cheer = SCNAction.sequence([smallUp, smallDown, smallUp, smallDown, .wait(duration: 1.6)])
        body.runAction(.sequence([.wait(duration: delay), .group([.sequence([up, down]), spin]),
                                  .wait(duration: 0.8), .repeatForever(cheer)]))
    }

    private func hop(_ actor: SCNNode, delay: TimeInterval) {
        guard let body = actor.childNodes.first else { return }
        let up = SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.15); up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.15); down.timingMode = .easeIn
        body.runAction(.sequence([.wait(duration: delay), up, down]))
    }

    /// Pokal fährt aus dem Podest über den Kopf des Siegers und dreht sich
    private func raiseTrophy(delay: TimeInterval) {
        let target = SCNVector3(trophy.position.x, Float(ResultStage.winnerHeight) + 1.08, 0.05)
        let rise = SCNAction.move(to: target, duration: 0.7)
        rise.timingMode = .easeOut
        trophy.runAction(.sequence([.wait(duration: delay), .group([.fadeIn(duration: 0.2), rise]),
                                    .run { node in ResultStage.floatAndSpin(node) }]))
    }

    private func showMiddleTrophy(delay: TimeInterval) {
        trophy.scale = SCNVector3(0.01, 0.01, 0.01)
        let pop = SCNAction.scale(to: 1, duration: 0.35)
        pop.timingMode = .easeOut
        trophy.runAction(.sequence([.wait(duration: delay), .group([.fadeIn(duration: 0.15), pop]),
                                    .run { node in ResultStage.floatAndSpin(node) }]))
    }

    private static func floatAndSpin(_ node: SCNNode) {
        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3)))
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.05, z: 0, duration: 0.9), .moveBy(x: 0, y: -0.05, z: 0, duration: 0.9)])
        bob.timingMode = .easeInEaseOut
        node.runAction(.repeatForever(bob))
    }

    /// K.O.: wackeln, nach hinten umkippen, nachfedern; Sterne kreisen über dem Kopf
    private func knockOut(_ actor: SCNNode, delay: TimeInterval) {
        guard let body = actor.childNodes.first else { return }
        let wobble = SCNAction.sequence((0..<2).flatMap { _ in
            [SCNAction.rotateBy(x: 0, y: 0, z: 0.18, duration: 0.09), .rotateBy(x: 0, y: 0, z: -0.18, duration: 0.09)]
        })
        // Füße liegen auf y = 0 → Drehung um x kippt die Figur um die Füße nach hinten
        let fall = SCNAction.rotateBy(x: -.pi / 2, y: 0, z: 0, duration: 0.42)
        fall.timingMode = .easeIn
        let bounce = SCNAction.sequence([.rotateBy(x: 0.18, y: 0, z: 0, duration: 0.1),
                                         .rotateBy(x: -0.18, y: 0, z: 0, duration: 0.12)])
        body.runAction(.sequence([.wait(duration: delay), wobble, fall, bounce]))
        dizzyStars(on: actor, delay: delay + 0.36 + 0.42 + 0.22)
    }

    private func dizzyStars(on actor: SCNNode, delay: TimeInterval) {
        let ring = SCNNode()
        // Kopf liegt nach dem Umfallen ca. 0,9 m hinter den Füßen
        ring.position = SCNVector3(0, 0.32, -0.85)
        for i in 0..<3 {
            let star = SCNNode(geometry: ResultStage.starShape(radius: 0.07, depth: 0.025))
            star.geometry?.firstMaterial = ResultStage.glow(ResultStage.gold)
            let a = Float(i) / 3 * .pi * 2
            star.position = SCNVector3(0.2 * cos(a), 0, 0.2 * sin(a))
            // immer zur Kamera gedreht, sonst sieht man die flachen Sterne von der Kante
            star.constraints = [SCNBillboardConstraint()]
            ring.addChildNode(star)
        }
        ring.opacity = 0
        actor.addChildNode(ring)
        ring.runAction(.sequence([.wait(duration: delay), .fadeIn(duration: 0.2)]))
        ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.6)))
    }

    /// Enttäuschung: Kopf hängen lassen und kleiner werden
    private func slump(_ actor: SCNNode, delay: TimeInterval) {
        guard let body = actor.childNodes.first else { return }
        let shake = SCNAction.sequence((0..<3).flatMap { _ in
            [SCNAction.rotateBy(x: 0, y: 0.15, z: 0, duration: 0.1), .rotateBy(x: 0, y: -0.15, z: 0, duration: 0.1)]
        })
        let sag = SCNAction.group([.rotateBy(x: 0.22, y: 0, z: 0, duration: 0.5), .scale(to: 0.9, duration: 0.5)])
        sag.timingMode = .easeOut
        body.runAction(.sequence([.wait(duration: delay), shake, sag]))
    }

    /// Graue Wolke über der Figur, aus der es regnet
    private func rainCloud(over actor: SCNNode, delay: TimeInterval) {
        let cloud = SCNNode()
        cloud.position = SCNVector3(0, 1.45, 0)
        let grey = ResultStage.material(UIColor(white: 0.45, alpha: 1))
        for (x, y, r) in [(-0.16, 0.0, 0.12), (0.0, 0.05, 0.16), (0.17, 0.0, 0.12), (0.08, -0.04, 0.11), (-0.07, -0.04, 0.11)] {
            let puff = SCNNode(geometry: SCNSphere(radius: r))
            puff.geometry?.firstMaterial = grey
            puff.position = SCNVector3(Float(x), Float(y), 0)
            cloud.addChildNode(puff)
        }
        let dropMaterial = ResultStage.glow(ResultStage.rainBlue)
        for i in 0..<16 {
            let drop = SCNNode(geometry: SCNCylinder(radius: 0.006, height: 0.07))
            drop.geometry?.firstMaterial = dropMaterial
            let start = SCNVector3(Float.random(in: -0.24...0.24), -0.1, Float.random(in: -0.12...0.12))
            drop.position = start
            drop.opacity = 0
            let fall = SCNAction.sequence([.move(to: start, duration: 0), .fadeIn(duration: 0.05),
                                           .moveBy(x: 0, y: -1.25, z: 0, duration: 0.55), .fadeOut(duration: 0.05)])
            drop.runAction(.sequence([.wait(duration: Double(i) * 0.06), .repeatForever(fall)]))
            cloud.addChildNode(drop)
        }
        cloud.opacity = 0
        cloud.scale = SCNVector3(0.3, 0.3, 0.3)
        actor.addChildNode(cloud)
        let pop = SCNAction.group([.fadeIn(duration: 0.3), .scale(to: 1, duration: 0.35)])
        pop.timingMode = .easeOut
        let drift = SCNAction.repeatForever(.sequence([.moveBy(x: 0.04, y: 0, z: 0, duration: 1.2),
                                                       .moveBy(x: -0.04, y: 0, z: 0, duration: 1.2)]))
        cloud.runAction(.sequence([.wait(duration: delay), pop, drift]))
    }

    /// 3D-Konfetti, das in Schleife von oben über die Bühne regnet
    private func confetti(xRange: ClosedRange<Float>, delay: TimeInterval) {
        let colors: [UIColor] = [ResultStage.gold, ResultStage.red, .white,
                                 UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1),
                                 UIColor(red: 0.3, green: 0.55, blue: 1, alpha: 1)]
        let materials = colors.map { color -> SCNMaterial in
            let m = ResultStage.glow(color)
            m.isDoubleSided = true
            return m
        }
        for i in 0..<60 {
            let piece = SCNNode(geometry: SCNPlane(width: 0.05, height: 0.03))
            piece.geometry?.firstMaterial = materials[i % materials.count]
            let start = SCNVector3(Float.random(in: xRange), 2.5, Float.random(in: -0.8...0.9))
            piece.position = start
            piece.opacity = 0
            let duration = Double.random(in: 2.2...3.6)
            let fall = SCNAction.sequence([
                .move(to: start, duration: 0),
                .group([.moveBy(x: CGFloat.random(in: -0.3...0.3), y: -2.7, z: 0, duration: duration),
                        .rotateBy(x: .pi * CGFloat.random(in: 2...6), y: .pi * CGFloat.random(in: 1...3), z: 0, duration: duration)])
            ])
            piece.runAction(.sequence([.wait(duration: delay + Double.random(in: 0...1.8)), .fadeIn(duration: 0),
                                       .repeatForever(fall)]))
            root.addChildNode(piece)
        }
    }

    // MARK: Geometrie

    private static func actor(_ model: SCNNode, position: SCNVector3, yaw: Float) -> SCNNode {
        // Außen: Platz + Blickrichtung; innen (body): Reaktionen
        let actor = SCNNode()
        actor.position = position
        actor.eulerAngles.y = yaw
        let body = SCNNode()
        body.addChildNode(model)
        actor.addChildNode(body)
        return actor
    }

    private static func idle(_ actor: SCNNode) {
        guard let model = actor.childNodes.first?.childNodes.first else { return }
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.015, z: 0, duration: 0.6), .moveBy(x: 0, y: -0.015, z: 0, duration: 0.6)])
        bob.timingMode = .easeInEaseOut
        model.runAction(.repeatForever(bob))
    }

    private static func podium(x: Float, height: CGFloat, width: CGFloat, label: String?, color: UIColor) -> SCNNode {
        let node = SCNNode()
        node.position = SCNVector3(x, 0, 0)
        let block = SCNNode(geometry: SCNBox(width: width, height: height, length: 0.62, chamferRadius: 0.04))
        block.geometry?.firstMaterial = material(UIColor(red: 0.28, green: 0.10, blue: 0.18, alpha: 1))
        block.position = SCNVector3(0, Float(height / 2), 0)
        node.addChildNode(block)
        // leuchtende Kante oben
        let edge = SCNNode(geometry: SCNBox(width: width + 0.04, height: 0.03, length: 0.66, chamferRadius: 0.012))
        edge.geometry?.firstMaterial = glow(color)
        edge.position = SCNVector3(0, Float(height), 0)
        node.addChildNode(edge)
        if let label, height > 0.2 {
            let text = SCNText(string: label, extrusionDepth: 2)
            text.font = UIFont.systemFont(ofSize: 20, weight: .black)
            text.flatness = 0.2
            text.firstMaterial = glow(color)
            let textNode = SCNNode(geometry: text)
            let (minB, maxB) = textNode.boundingBox
            let scale: Float = Float(height) * 0.6 / max(maxB.y - minB.y, 1)
            textNode.scale = SCNVector3(scale, scale, scale)
            textNode.position = SCNVector3(-(minB.x + maxB.x) / 2 * scale, Float(height) * 0.2 - minB.y * scale, 0.31)
            node.addChildNode(textNode)
        }
        return node
    }

    /// Pokal aus Grundkörpern: Fuß, Stiel, Kelch, zwei Henkel
    private static func makeTrophy() -> SCNNode {
        let gold = SCNMaterial()
        gold.lightingModel = .blinn
        gold.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 1)
        gold.emission.contents = UIColor(red: 0.45, green: 0.30, blue: 0.0, alpha: 1)
        gold.specular.contents = UIColor.white
        gold.shininess = 0.6
        let darkGold = material(UIColor(red: 0.55, green: 0.36, blue: 0.05, alpha: 1))

        let node = SCNNode()
        let base = SCNNode(geometry: SCNBox(width: 0.16, height: 0.05, length: 0.16, chamferRadius: 0.01))
        base.geometry?.firstMaterial = darkGold
        base.position = SCNVector3(0, 0.025, 0)
        let stem = SCNNode(geometry: SCNCylinder(radius: 0.022, height: 0.08))
        stem.geometry?.firstMaterial = gold
        stem.position = SCNVector3(0, 0.09, 0)
        let cup = SCNNode(geometry: SCNCone(topRadius: 0.11, bottomRadius: 0.04, height: 0.16))
        cup.geometry?.firstMaterial = gold
        cup.position = SCNVector3(0, 0.21, 0)
        node.addChildNode(base); node.addChildNode(stem); node.addChildNode(cup)
        for side: Float in [-1, 1] {
            let handle = SCNNode(geometry: SCNTorus(ringRadius: 0.045, pipeRadius: 0.011))
            handle.geometry?.firstMaterial = gold
            handle.position = SCNVector3(side * 0.105, 0.22, 0)
            handle.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            node.addChildNode(handle)
        }
        let star = SCNNode(geometry: starShape(radius: 0.045, depth: 0.012))
        star.geometry?.firstMaterial = glow(.white)
        star.position = SCNVector3(0, 0.2, 0.09)
        node.addChildNode(star)
        node.scale = SCNVector3(1.3, 1.3, 1.3)
        return node
    }

    private static func starShape(radius: CGFloat, depth: CGFloat) -> SCNShape {
        let path = UIBezierPath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? radius : radius * 0.45
            let a = CGFloat(i) / 10 * CGFloat.pi * 2 + CGFloat.pi / 2
            let p = CGPoint(x: r * cos(a), y: r * sin(a))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.close()
        path.flatness = 0.002
        return SCNShape(path: path, extrusionDepth: depth)
    }

    private static func spot(color: UIColor, at position: SCNVector3, target: SCNNode) -> SCNNode {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = .spot
        node.light?.intensity = 1000
        node.light?.color = color
        node.light?.spotInnerAngle = 14
        node.light?.spotOuterAngle = 32
        node.position = position
        let look = SCNLookAtConstraint(target: target)
        look.isGimbalLockEnabled = true
        node.constraints = [look]
        return node
    }

    private static func material(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = color
        return m
    }

    /// Selbstleuchtend (ohne Shader – nur Emission)
    private static func glow(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.emission.contents = color
        return m
    }
}

#Preview {
    ResultStageView(winner: .junge, loser: .maedchen, focus: .win)
        .frame(height: 340)
        .background(Color.challengrDark)
}
