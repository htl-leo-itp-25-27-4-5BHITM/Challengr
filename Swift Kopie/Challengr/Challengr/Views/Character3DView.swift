import SwiftUI
import SceneKit

/// Zeigt eine Spielfigur als 3D-Modell im Toon-Look (transparenter Hintergrund).
/// Bis SceneKit das erste Bild gezeichnet hat – oder falls es auf einem Gerät gar nicht
/// zeichnet – ist das aus demselben Modell gerenderte Bild zu sehen.
struct Character3DView: View {
    enum Facing {
        case front, right, left

        var yaw: Float {
            switch self {
            case .front: return -0.45
            case .right: return 0.6
            case .left:  return -0.6
            }
        }
    }

    let character: GameCharacter
    var facing: Facing = .front
    /// Langsame Dauerdrehung (z. B. im Charakter-Editor).
    var autoRotate = false
    /// Figur lässt sich mit dem Finger drehen.
    var allowsDragRotation = false

    /// 3D ist gezeichnet und geprüft → Ersatzbild ausblenden.
    @State private var showsModel = false

    var body: some View {
        ZStack {
            if !showsModel {
                Image(character.imageName)
                    .resizable()
                    .scaledToFit()
                    // Das Bild schaut leicht nach links – für "nach rechts" spiegeln
                    .scaleEffect(x: facing == .right ? -1 : 1, y: 1)
            }
            SceneKitCharacterView(character: character, facing: facing, autoRotate: autoRotate,
                                  allowsDragRotation: allowsDragRotation) { ok in
                showsModel = ok
            }
            // Bis zur Prüfung fast unsichtbar (bei 0 würde iOS gar nicht zeichnen)
            .opacity(showsModel ? 1 : 0.011)
        }
        .onChange(of: character) { _, _ in showsModel = false }
    }
}

/// Die eigentliche SceneKit-Ansicht.
/// - Szenen werden nacheinander vorbereitet (siehe `CharacterRenderGate`).
/// - Nach dem ersten Bild wird geprüft, ob SceneKit nur eine Magenta-Fläche gezeichnet hat;
///   dann meldet die Ansicht `false` und das Ersatzbild bleibt stehen.
private struct SceneKitCharacterView: UIViewRepresentable {
    let character: GameCharacter
    let facing: Character3DView.Facing
    let autoRotate: Bool
    let allowsDragRotation: Bool
    let onResult: (Bool) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isPlaying = true
        view.delegate = context.coordinator
        view.isUserInteractionEnabled = allowsDragRotation
        if allowsDragRotation {
            view.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator,
                                                             action: #selector(Coordinator.pan(_:))))
        }
        context.coordinator.view = view
        apply(to: view, context: context)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onResult = onResult
        if context.coordinator.character != character { apply(to: view, context: context) }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.releaseGate()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    private func apply(to view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.character = character
        coordinator.generation += 1
        let generation = coordinator.generation
        guard let built = CharacterScene.make(character, yaw: facing.yaw, autoRotate: autoRotate) else {
            print("❌ 3D-Modell konnte nicht geladen werden: \(character.sceneName).scn")
            onResult(false)
            return
        }
        coordinator.turntable = built.turntable
        view.scene = nil

        // Nie zwei 3D-Fenster gleichzeitig zum ersten Mal zeichnen lassen
        CharacterRenderGate.enqueue { release in
            guard coordinator.generation == generation else { return release() }
            coordinator.release = release
            view.prepare([built.scene]) { _ in
                DispatchQueue.main.async {
                    guard coordinator.generation == generation else { return coordinator.releaseGate() }
                    coordinator.awaitingFirstFrame = true
                    view.scene = built.scene
                    view.pointOfView = built.camera
                }
            }
        }
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view: SCNView?
        var character: GameCharacter?
        var turntable: SCNNode?
        var onResult: (Bool) -> Void
        var generation = 0
        var release: (() -> Void)?
        var awaitingFirstFrame = false
        private var startYaw: Float = 0

        init(onResult: @escaping (Bool) -> Void) { self.onResult = onResult }

        func releaseGate() {
            release?()
            release = nil
        }

        // Läuft auf dem SceneKit-Render-Thread
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard awaitingFirstFrame else { return }
            awaitingFirstFrame = false
            DispatchQueue.main.async { self.checkFirstFrame() }
        }

        private func checkFirstFrame() {
            defer { releaseGate() }
            guard let view else { return }
            if let image = view.snapshot().cgImage, MagentaCheck.isMostlyMagenta(image) {
                print("⚠️ SceneKit hat für \(character?.sceneName ?? "?") nur Magenta gezeichnet – zeige Bild statt 3D")
                view.isHidden = true
                view.isPlaying = false
                onResult(false)
            } else {
                onResult(true)
            }
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            guard let turntable, let view = gesture.view else { return }
            if gesture.state == .began { startYaw = turntable.eulerAngles.y }
            let dx = Float(gesture.translation(in: view).x / max(view.bounds.width, 1))
            turntable.eulerAngles.y = startYaw + dx * .pi * 2
        }
    }
}

/// Lässt 3D-Fenster nacheinander starten: das nächste erst, wenn das vorige sein erstes
/// Bild gezeichnet hat (oder nach einer Sicherheits-Zeit). Auf echten iPhones zeigte das
/// zweite gleichzeitig startende Fenster sonst nur eine Magenta-Fläche.
enum CharacterRenderGate {
    private static var busy = false
    private static var waiting: [(@escaping () -> Void) -> Void] = []
    static let maxWait: TimeInterval = 3

    /// `work` bekommt eine `release`-Funktion, die genau einmal aufgerufen werden soll.
    static func enqueue(_ work: @escaping (@escaping () -> Void) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        waiting.append(work)
        startNext()
    }

    private static func startNext() {
        guard !busy, !waiting.isEmpty else { return }
        busy = true
        let work = waiting.removeFirst()
        var released = false
        let release = {
            DispatchQueue.main.async {
                guard !released else { return }
                released = true
                busy = false
                startNext()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + maxWait, execute: release)
        work(release)
    }
}

/// Erkennt SceneKits Fehler-Farbe (Magenta) in einem gerenderten Bild.
enum MagentaCheck {
    static func isMostlyMagenta(_ image: CGImage, threshold: Double = 0.3) -> Bool {
        let size = 24
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let ctx = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        var magenta = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2]), a = Int(pixels[i + 3])
            if a > 200, r > 200, b > 200, g < 120 { magenta += 1 }
        }
        return Double(magenta) / Double(size * size) >= threshold
    }
}

/// Lädt die Figuren-Modelle einmal und baut daraus Szenen mit Licht, Kamera und Idle-Animation.
enum CharacterScene {
    struct Built {
        let scene: SCNScene
        let camera: SCNNode
        let turntable: SCNNode
    }

    private static var prototypes: [GameCharacter: SCNNode] = [:]

    /// Modell der Figur (geteilte Geometrie, darf geklont werden).
    static func prototype(for character: GameCharacter) -> SCNNode? {
        if let cached = prototypes[character] { return cached }
        guard let url = Bundle.main.url(forResource: character.sceneName, withExtension: "scn"),
              let scene = try? SCNScene(url: url),
              let model = scene.rootNode.childNodes.first else { return nil }
        // Bewusst KEINE eigenen Shader (shaderModifiers): ein Toon-Shader kompilierte auf
        // echten iPhones im zweiten 3D-Fenster nicht und SceneKit zeigte eine Magenta-Fläche.
        // Lambert-Licht + schwarze Outline-Hülle ergeben fast denselben Look.
        prototypes[character] = model
        return model
    }

    static func make(_ character: GameCharacter, yaw: Float, autoRotate: Bool) -> Built? {
        guard let model = prototype(for: character)?.clone() else { return nil }
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Modell ist ca. 1 m hoch, Füße auf y = 0, Blick nach +z.
        let turntable = SCNNode()
        turntable.eulerAngles.y = yaw
        turntable.addChildNode(model)
        scene.rootNode.addChildNode(turntable)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        ambient.light?.color = UIColor(red: 0.85, green: 0.85, blue: 0.95, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 700
        key.eulerAngles = SCNVector3(-0.75, -0.5, 0)
        scene.rootNode.addChildNode(key)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 24
        camera.position = SCNVector3(0, 0.58, 3.0)
        camera.look(at: SCNVector3(0, 0.53, 0))
        scene.rootNode.addChildNode(camera)

        if autoRotate {
            turntable.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)))
        } else {
            // leichtes Hin- und Herwiegen in Kampfhaltung
            let sway = SCNAction.sequence([.rotateBy(x: 0, y: 0.08, z: 0, duration: 1.4),
                                           .rotateBy(x: 0, y: -0.08, z: 0, duration: 1.4)])
            sway.timingMode = .easeInEaseOut
            model.runAction(.repeatForever(sway))
        }
        let bob = SCNAction.sequence([.moveBy(x: 0, y: 0.015, z: 0, duration: 0.6),
                                      .moveBy(x: 0, y: -0.015, z: 0, duration: 0.6)])
        bob.timingMode = .easeInEaseOut
        model.runAction(.repeatForever(bob))

        return Built(scene: scene, camera: camera, turntable: turntable)
    }
}

#Preview {
    HStack {
        Character3DView(character: .sirBrecht, facing: .right)
        Character3DView(character: .ragnar, facing: .left)
    }
    .frame(height: 260)
    .background(Color.challengrDark)
}
