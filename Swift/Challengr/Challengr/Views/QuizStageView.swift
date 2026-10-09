import SwiftUI
import SceneKit

/// Was gerade auf der Quiz-Bühne passiert – jede Änderung löst Animationen aus.
struct QuizStageEvent: Equatable {
    enum Kind: Equatable {
        /// Kamerafahrt ins Studio, Moderator begrüßt
        case intro
        /// Neue Frage: Moderator präsentiert, Scheinwerfer schwenken
        case question(round: Int)
        /// Ein Spieler hat geantwortet (drückt den Buzzer)
        case answered(own: Bool)
        /// Auflösung: wer lag richtig?
        case reveal(ownCorrect: Bool, opponentCorrect: Bool)
        /// Letzte Runde vorbei: Sieger jubelt (nil = Gleichstand)
        case finished(ownWins: Bool?)
    }

    let kind: Kind
    /// Damit dasselbe Ereignis zweimal hintereinander auch zweimal abläuft
    let id: Int
}

/// 3D-Fernsehstudio der Quiz-Show: beide Spieler hinter ihren Pulten, Merlo als Quizmaster.
/// Bewusst EIN SceneKit-Fenster für alle drei Figuren (mehrere Fenster gleichzeitig führten
/// auf echten iPhones zu Magenta-Flächen). Zeichnet SceneKit nicht, bleibt ein 2D-Ersatz stehen.
struct QuizStageView: View {
    let ownCharacter: GameCharacter
    let opponentCharacter: GameCharacter
    let event: QuizStageEvent

    @State private var showsModel = false

    /// Moderator: Merlo (Magier · Wissen), außer ein Spieler hat ihn selbst gewählt.
    static func host(own: GameCharacter, opponent: GameCharacter) -> GameCharacter {
        [GameCharacter.merlo, .sirBrecht, .kaeptnRex].first { $0 != own && $0 != opponent } ?? .merlo
    }

    var body: some View {
        ZStack {
            if !showsModel { fallback }
            QuizStageSceneView(own: ownCharacter, opponent: opponentCharacter,
                               host: Self.host(own: ownCharacter, opponent: opponentCharacter),
                               event: event) { ok in
                showsModel = ok
            }
            .opacity(showsModel ? 1 : 0.011)
        }
        .accessibilityElement()
        .accessibilityLabel("Quiz-Studio mit beiden Spielern und dem Quizmaster")
    }

    /// 2D-Ersatz: dieselben Figuren als Bilder auf Pulten.
    private var fallback: some View {
        HStack(alignment: .bottom, spacing: 0) {
            podium2D(ownCharacter, color: .challengrYellow, mirrored: true)
            Image(Self.host(own: ownCharacter, opponent: opponentCharacter).imageName)
                .resizable().scaledToFit()
                .frame(maxHeight: 130)
                .padding(.bottom, 40)
            podium2D(opponentCharacter, color: .challengrRed, mirrored: false)
        }
        .padding(.horizontal, 12)
    }

    private func podium2D(_ character: GameCharacter, color: Color, mirrored: Bool) -> some View {
        VStack(spacing: -24) {
            Image(character.imageName)
                .resizable().scaledToFit()
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                .frame(maxHeight: 120)
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 92, height: 54)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SceneKit

private struct QuizStageSceneView: UIViewRepresentable {
    let own: GameCharacter
    let opponent: GameCharacter
    let host: GameCharacter
    let event: QuizStageEvent
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

        guard let studio = QuizStudio.build(own: own, opponent: opponent, host: host) else {
            print("❌ Quiz-Studio konnte nicht gebaut werden")
            DispatchQueue.main.async { onResult(false) }
            return view
        }
        context.coordinator.studio = studio
        let coordinator = context.coordinator
        CharacterRenderGate.enqueue { release in
            coordinator.release = release
            view.prepare([studio.scene]) { _ in
                DispatchQueue.main.async {
                    coordinator.awaitingFirstFrame = true
                    view.scene = studio.scene
                    view.pointOfView = studio.camera
                    coordinator.play(event)
                }
            }
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onResult = onResult
        context.coordinator.play(event)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.releaseGate()
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view: SCNView?
        var studio: QuizStudio?
        var onResult: (Bool) -> Void
        var release: (() -> Void)?
        var awaitingFirstFrame = false
        private var lastEventId: Int?

        init(onResult: @escaping (Bool) -> Void) { self.onResult = onResult }

        func play(_ event: QuizStageEvent) {
            guard let studio, view?.scene != nil, lastEventId != event.id else { return }
            lastEventId = event.id
            studio.play(event.kind)
        }

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
                print("⚠️ Quiz-Studio zeichnet Magenta – 2D-Ersatz bleibt")
                view.scene = nil
                onResult(false)
            } else {
                onResult(true)
            }
        }
    }
}

// MARK: - Studio-Aufbau und Animationen

/// Szene mit Boden, Pulten, Scheinwerfern, Kamera und den drei Figuren.
/// Nur Standard-Materialien und -Lichter (keine eigenen Shader).
/// `nonisolated` wie `AvatarCustomizationStore`: sonst stürzt das Freigeben im Back-Deploy-Shim ab.
nonisolated final class QuizStudio {
    let scene: SCNScene
    let camera: SCNNode
    let ownActor: SCNNode
    let opponentActor: SCNNode
    let hostActor: SCNNode
    let ownPodiumTop: SCNMaterial
    let opponentPodiumTop: SCNMaterial
    let ownSpot: SCNNode
    let opponentSpot: SCNNode
    let hostSpot: SCNNode

    static let ownColor = UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)     // challengrYellow
    static let opponentColor = UIColor(red: 0.73, green: 0.12, blue: 0.20, alpha: 1) // challengrRed
    static let correctColor = UIColor(red: 0.20, green: 0.80, blue: 0.40, alpha: 1)
    static let wrongColor = UIColor(red: 0.95, green: 0.20, blue: 0.25, alpha: 1)

    /// Kamera im Normalbetrieb (Pulte und Moderator im Bild)
    static let cameraHome = SCNVector3(0, 1.15, 4.6)
    static let lookAt = SCNVector3(0, 0.62, 0)

    private init(scene: SCNScene, camera: SCNNode, own: SCNNode, opponent: SCNNode, host: SCNNode,
                 ownTop: SCNMaterial, opponentTop: SCNMaterial, ownSpot: SCNNode, opponentSpot: SCNNode, hostSpot: SCNNode) {
        self.scene = scene
        self.camera = camera
        self.ownActor = own
        self.opponentActor = opponent
        self.hostActor = host
        self.ownPodiumTop = ownTop
        self.opponentPodiumTop = opponentTop
        self.ownSpot = ownSpot
        self.opponentSpot = opponentSpot
        self.hostSpot = hostSpot
    }

    static func build(own: GameCharacter, opponent: GameCharacter, host: GameCharacter) -> QuizStudio? {
        guard let ownModel = CharacterScene.prototype(for: own)?.clone(),
              let opponentModel = CharacterScene.prototype(for: opponent)?.clone(),
              let hostModel = CharacterScene.prototype(for: host)?.clone() else { return nil }

        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let root = scene.rootNode

        // Bühnenboden: runde Plattform mit leuchtendem Rand
        let floor = SCNNode(geometry: SCNCylinder(radius: 2.6, height: 0.06))
        floor.geometry?.firstMaterial = material(UIColor(red: 0.16, green: 0.05, blue: 0.22, alpha: 1))
        floor.position = SCNVector3(0, -0.03, -0.2)
        root.addChildNode(floor)
        let rim = SCNNode(geometry: SCNTorus(ringRadius: 2.6, pipeRadius: 0.025))
        rim.geometry?.firstMaterial = glow(ownColor)
        rim.position = SCNVector3(0, 0.0, -0.2)
        root.addChildNode(rim)
        // Lauflichter am Rand
        for i in 0..<24 {
            let a = Float(i) / 24 * .pi * 2
            let bulb = SCNNode(geometry: SCNSphere(radius: 0.035))
            bulb.geometry?.firstMaterial = glow(i % 2 == 0 ? .white : ownColor)
            bulb.position = SCNVector3(2.6 * cos(a), 0.03, -0.2 + 2.6 * sin(a))
            bulb.runAction(.repeatForever(.sequence([.wait(duration: Double(i % 4) * 0.15),
                                                      .fadeOpacity(to: 0.25, duration: 0.3),
                                                      .fadeOpacity(to: 1, duration: 0.3)])))
            root.addChildNode(bulb)
        }

        // Rückwand mit Showtitel-Streifen
        let wall = SCNNode(geometry: SCNPlane(width: 6.5, height: 3.2))
        wall.geometry?.firstMaterial = material(UIColor(red: 0.10, green: 0.02, blue: 0.16, alpha: 1))
        wall.position = SCNVector3(0, 1.4, -2.2)
        root.addChildNode(wall)
        for (i, x) in [-2.2, -1.1, 0.0, 1.1, 2.2].enumerated() {
            let bar = SCNNode(geometry: SCNBox(width: 0.08, height: 2.6, length: 0.04, chamferRadius: 0.02))
            bar.geometry?.firstMaterial = glow(i % 2 == 0 ? .purple : ownColor)
            bar.position = SCNVector3(Float(x), 1.4, -2.15)
            bar.runAction(.repeatForever(.sequence([.wait(duration: Double(i) * 0.2),
                                                     .fadeOpacity(to: 0.3, duration: 0.6),
                                                     .fadeOpacity(to: 1, duration: 0.6)])))
            root.addChildNode(bar)
        }

        // Pulte
        let (ownPodium, ownTop) = podium(color: ownColor)
        ownPodium.position = SCNVector3(-1.05, 0, 0.42)
        root.addChildNode(ownPodium)
        let (opponentPodium, opponentTop) = podium(color: opponentColor)
        opponentPodium.position = SCNVector3(1.05, 0, 0.42)
        root.addChildNode(opponentPodium)

        // Moderatoren-Podest
        let stage = SCNNode(geometry: SCNCylinder(radius: 0.45, height: 0.18))
        stage.geometry?.firstMaterial = material(UIColor(red: 0.30, green: 0.12, blue: 0.40, alpha: 1))
        stage.position = SCNVector3(0, 0.09, -0.75)
        root.addChildNode(stage)

        // Figuren (ca. 1 m hoch, Füße auf y = 0, Blick nach +z)
        let ownActor = actor(ownModel, position: SCNVector3(-1.05, 0, 0.05), yaw: 0.35)
        let opponentActor = actor(opponentModel, position: SCNVector3(1.05, 0, 0.05), yaw: -0.35)
        let hostActor = actor(hostModel, position: SCNVector3(0, 0.18, -0.75), yaw: 0)
        hostActor.scale = SCNVector3(1.12, 1.12, 1.12)
        [ownActor, opponentActor, hostActor].forEach(root.addChildNode)
        idle(ownActor); idle(opponentActor); idle(hostActor, slow: true)

        // Licht
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 380
        ambient.light?.color = UIColor(red: 0.75, green: 0.70, blue: 0.95, alpha: 1)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 520
        key.eulerAngles = SCNVector3(-0.7, -0.3, 0)
        root.addChildNode(key)

        let ownSpot = spot(color: ownColor, at: SCNVector3(-1.05, 3.4, 1.6), target: ownActor)
        let opponentSpot = spot(color: opponentColor, at: SCNVector3(1.05, 3.4, 1.6), target: opponentActor)
        let hostSpot = spot(color: .white, at: SCNVector3(0, 3.6, 1.2), target: hostActor)
        [ownSpot, opponentSpot, hostSpot].forEach(root.addChildNode)

        // Kamera
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 34
        camera.position = cameraHome
        camera.look(at: lookAt)
        root.addChildNode(camera)

        return QuizStudio(scene: scene, camera: camera, own: ownActor, opponent: opponentActor, host: hostActor,
                          ownTop: ownTop, opponentTop: opponentTop,
                          ownSpot: ownSpot, opponentSpot: opponentSpot, hostSpot: hostSpot)
    }

    // MARK: Ereignisse

    func play(_ kind: QuizStageEvent.Kind) {
        switch kind {
        case .intro:
            // Kamerafahrt von weit oben ins Studio
            camera.removeAllActions()
            camera.position = SCNVector3(0, 3.2, 9.0)
            camera.look(at: QuizStudio.lookAt)
            let fly = SCNAction.move(to: QuizStudio.cameraHome, duration: 2.4)
            fly.timingMode = .easeInEaseOut
            camera.runAction(.group([fly, lookAtAction(duration: 2.4)]))
            wave(hostActor, delay: 1.2)
            hop(ownActor, delay: 2.0)
            hop(opponentActor, delay: 2.2)

        case .question:
            resetPodiums()
            // Moderator präsentiert: zu beiden Seiten drehen, Scheinwerfer schwenken
            hostActor.removeAction(forKey: "turn")
            hostActor.runAction(.sequence([turn(to: -0.5, duration: 0.35), .wait(duration: 0.35),
                                           turn(to: 0.5, duration: 0.5), .wait(duration: 0.35),
                                           turn(to: 0, duration: 0.35)]), forKey: "turn")
            sweep(ownSpot); sweep(opponentSpot)
            push(by: 0.35)

        case .answered(let own):
            let actor = own ? ownActor : opponentActor
            let top = own ? ownPodiumTop : opponentPodiumTop
            hop(actor, height: 0.12)
            flash(top, color: .white)

        case .reveal(let ownCorrect, let opponentCorrect):
            react(ownActor, top: ownPodiumTop, spot: ownSpot, correct: ownCorrect)
            react(opponentActor, top: opponentPodiumTop, spot: opponentSpot, correct: opponentCorrect)
            // Moderator wendet sich dem zu, der richtig lag
            let yaw: Float = ownCorrect == opponentCorrect ? 0 : (ownCorrect ? -0.6 : 0.6)
            hostActor.removeAction(forKey: "turn")
            hostActor.runAction(.sequence([turn(to: yaw, duration: 0.4), .wait(duration: 1.8),
                                           turn(to: 0, duration: 0.4)]), forKey: "turn")
            if ownCorrect || opponentCorrect { hop(hostActor, delay: 0.2, height: 0.08) }

        case .finished(let ownWins):
            camera.removeAllActions()
            let target: SCNVector3
            switch ownWins {
            case true?:  target = SCNVector3(-0.7, 1.0, 3.2)
            case false?: target = SCNVector3(0.7, 1.0, 3.2)
            case nil:    target = SCNVector3(0, 1.1, 3.6)
            }
            let move = SCNAction.move(to: target, duration: 1.2)
            move.timingMode = .easeInEaseOut
            camera.runAction(.group([move, lookAtAction(duration: 1.2)]))
            if ownWins != false { celebrate(ownActor); ownSpot.light?.color = QuizStudio.correctColor }
            if ownWins != true { celebrate(opponentActor); opponentSpot.light?.color = QuizStudio.correctColor }
            if let ownWins { slump(ownWins ? opponentActor : ownActor) }
            wave(hostActor, delay: 0.3)
        }
    }

    // MARK: Bausteine

    private func react(_ actor: SCNNode, top: SCNMaterial, spot: SCNNode, correct: Bool) {
        tint(top, correct ? QuizStudio.correctColor : QuizStudio.wrongColor)
        spot.light?.color = correct ? QuizStudio.correctColor : QuizStudio.wrongColor
        correct ? celebrate(actor) : slump(actor)
    }

    private func resetPodiums() {
        tint(ownPodiumTop, QuizStudio.ownColor)
        tint(opponentPodiumTop, QuizStudio.opponentColor)
        ownSpot.light?.color = QuizStudio.ownColor
        opponentSpot.light?.color = QuizStudio.opponentColor
    }

    /// Jubel: hochspringen mit voller Drehung
    private func celebrate(_ actor: SCNNode) {
        guard let body = actor.childNodes.first else { return }
        body.removeAction(forKey: "react")
        let up = SCNAction.moveBy(x: 0, y: 0.35, z: 0, duration: 0.25); up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -0.35, z: 0, duration: 0.25); down.timingMode = .easeIn
        let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 0.5)
        body.runAction(.sequence([.group([.sequence([up, down]), spin]),
                                  .moveBy(x: 0, y: 0.15, z: 0, duration: 0.12),
                                  .moveBy(x: 0, y: -0.15, z: 0, duration: 0.12)]), forKey: "react")
    }

    /// Enttäuschung: schütteln und kurz zusammensacken
    private func slump(_ actor: SCNNode) {
        guard let body = actor.childNodes.first else { return }
        body.removeAction(forKey: "react")
        let shake = SCNAction.sequence((0..<3).flatMap { _ in
            [SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: 0.07), .rotateBy(x: 0, y: 0, z: -0.12, duration: 0.07)]
        })
        let squash = SCNAction.sequence([.scale(to: 0.88, duration: 0.25), .wait(duration: 0.6), .scale(to: 1, duration: 0.3)])
        body.runAction(.group([shake, squash]), forKey: "react")
    }

    private func hop(_ actor: SCNNode, delay: TimeInterval = 0, height: CGFloat = 0.2) {
        guard let body = actor.childNodes.first else { return }
        let up = SCNAction.moveBy(x: 0, y: height, z: 0, duration: 0.14); up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -height, z: 0, duration: 0.14); down.timingMode = .easeIn
        body.runAction(.sequence([.wait(duration: delay), up, down]))
    }

    /// Winken: Ganzkörper-Wippen (die Modelle haben kein Skelett)
    private func wave(_ actor: SCNNode, delay: TimeInterval) {
        guard let body = actor.childNodes.first else { return }
        let tilt = SCNAction.sequence((0..<3).flatMap { _ in
            [SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.15), .rotateBy(x: 0, y: 0, z: -0.15, duration: 0.15)]
        })
        body.runAction(.sequence([.wait(duration: delay), tilt]))
    }

    private func turn(to yaw: Float, duration: TimeInterval) -> SCNAction {
        let a = SCNAction.rotateTo(x: 0, y: CGFloat(yaw), z: 0, duration: duration, usesShortestUnitArc: true)
        a.timingMode = .easeInEaseOut
        return a
    }

    private func sweep(_ spot: SCNNode) {
        guard let target = spot.constraints?.first as? SCNLookAtConstraint else { return }
        target.influenceFactor = 1
        spot.removeAction(forKey: "sweep")
        let start = spot.position
        spot.runAction(.sequence([.move(to: SCNVector3(start.x * -1, start.y, start.z), duration: 0.35),
                                  .move(to: start, duration: 0.45)]), forKey: "sweep")
    }

    /// Kurzer Kamera-Zoom auf die Bühne und zurück
    private func push(by amount: Float) {
        camera.removeAction(forKey: "push")
        let home = QuizStudio.cameraHome
        let near = SCNVector3(home.x, home.y - 0.08, home.z - amount)
        let inA = SCNAction.move(to: near, duration: 0.5); inA.timingMode = .easeOut
        let outA = SCNAction.move(to: home, duration: 1.2); outA.timingMode = .easeInEaseOut
        camera.runAction(.sequence([inA, .wait(duration: 0.4), outA]), forKey: "push")
    }

    private func flash(_ top: SCNMaterial, color: UIColor) {
        let original = top.emission.contents
        tint(top, color)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak top] in
            guard let self, let top, let original = original as? UIColor else { return }
            // Nur zurücksetzen, wenn inzwischen nicht schon aufgelöst wurde
            if (top.emission.contents as? UIColor) == color { self.tint(top, original) }
        }
    }

    /// Leuchtfarbe eines Pults (Grund- und Leuchtfarbe, sonst mischt sich die alte Farbe hinein)
    private func tint(_ material: SCNMaterial, _ color: UIColor) {
        material.diffuse.contents = color
        material.emission.contents = color
    }

    private func lookAtAction(duration: TimeInterval) -> SCNAction {
        .customAction(duration: duration) { node, _ in node.look(at: QuizStudio.lookAt) }
    }

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

    private static func idle(_ actor: SCNNode, slow: Bool = false) {
        guard let model = actor.childNodes.first?.childNodes.first else { return }
        let d = slow ? 1.0 : 0.6
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.015, z: 0, duration: d), .moveBy(x: 0, y: -0.015, z: 0, duration: d)])
        bob.timingMode = .easeInEaseOut
        model.runAction(.repeatForever(bob))
    }

    private static func podium(color: UIColor) -> (SCNNode, SCNMaterial) {
        let node = SCNNode()
        // Niedrig genug, dass die Figur ab der Brust darüber zu sehen ist
        let body = SCNNode(geometry: SCNBox(width: 0.74, height: 0.40, length: 0.36, chamferRadius: 0.05))
        body.geometry?.firstMaterial = material(UIColor(red: 0.18, green: 0.08, blue: 0.26, alpha: 1))
        body.position = SCNVector3(0, 0.20, 0)
        node.addChildNode(body)
        // Leuchtende Front und Kante in Spielerfarbe
        let front = SCNNode(geometry: SCNBox(width: 0.60, height: 0.22, length: 0.02, chamferRadius: 0.03))
        front.geometry?.firstMaterial = glow(color)
        front.position = SCNVector3(0, 0.22, 0.185)
        node.addChildNode(front)
        let top = SCNNode(geometry: SCNBox(width: 0.82, height: 0.04, length: 0.42, chamferRadius: 0.02))
        let topMaterial = glow(color)
        top.geometry?.firstMaterial = topMaterial
        top.position = SCNVector3(0, 0.42, 0)
        node.addChildNode(top)
        // Buzzer
        let buzzer = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.04))
        buzzer.geometry?.firstMaterial = glow(.white)
        buzzer.position = SCNVector3(0.22, 0.46, 0.10)
        node.addChildNode(buzzer)
        return (node, topMaterial)
    }

    private static func spot(color: UIColor, at position: SCNVector3, target: SCNNode) -> SCNNode {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = .spot
        node.light?.intensity = 900
        node.light?.color = color
        node.light?.spotInnerAngle = 14
        node.light?.spotOuterAngle = 34
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
    QuizStageView(ownCharacter: .junge, opponentCharacter: .maedchen,
                  event: QuizStageEvent(kind: .intro, id: 1))
        .frame(height: 280)
        .background(Color.challengrDark)
}
