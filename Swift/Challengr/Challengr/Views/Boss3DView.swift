import SwiftUI
import SceneKit

/// Riss-Wächter als 3D-Modell im Kampf: atmet und wiegt sich, zuckt bei Treffern, springt und stampft beim
/// Riss-Schlag, glüht rot in der Raserei. Bis das erste Bild gezeichnet ist (oder falls SceneKit nur Magenta
/// zeichnet), ist das gerenderte Bild zu sehen – wie bei `Character3DView`.
struct Boss3DView: View {
    let hitCount: Int
    let slamCount: Int
    let rage: Bool
    let finale: Bool

    @State private var showsModel = false

    var body: some View {
        ZStack {
            if !showsModel {
                Image(RiftBoss.imageName).resizable().scaledToFit()
            }
            BossSceneView(hitCount: hitCount, slamCount: slamCount, rage: rage, finale: finale) { ok in
                showsModel = ok
            }
            .opacity(showsModel ? 1 : 0.011)
        }
    }
}

private struct BossSceneView: UIViewRepresentable {
    let hitCount: Int
    let slamCount: Int
    let rage: Bool
    let finale: Bool
    let onResult: (Bool) -> Void

    static let sceneName = "RissWaechter"

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
        let c = context.coordinator
        c.view = view
        guard let url = Bundle.main.url(forResource: Self.sceneName, withExtension: "scn"),
              let loaded = try? SCNScene(url: url),
              let model = loaded.rootNode.childNodes.first else {
            onResult(false)
            return view
        }
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let holder = SCNNode()
        holder.eulerAngles.y = -0.35
        holder.addChildNode(model)
        scene.rootNode.addChildNode(holder)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        ambient.light?.color = UIColor(red: 0.85, green: 0.8, blue: 1.0, alpha: 1)
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 700
        key.eulerAngles = SCNVector3(-0.75, -0.5, 0)
        scene.rootNode.addChildNode(key)
        // Raserei-Licht: rotes Glühen von unten, anfangs aus
        let glow = SCNNode()
        glow.light = SCNLight()
        glow.light?.type = .omni
        glow.light?.color = UIColor(red: 1, green: 0.15, blue: 0.2, alpha: 1)
        glow.light?.intensity = 0
        glow.position = SCNVector3(0, 0.3, 1.2)
        scene.rootNode.addChildNode(glow)

        // Modell ist ca. 2 m hoch (doppelte Figurengröße)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        camera.position = SCNVector3(0, 1.15, 4.6)
        camera.look(at: SCNVector3(0, 0.95, 0))
        scene.rootNode.addChildNode(camera)

        // Atmen und Wiegen
        let breathe = SCNAction.sequence([.scale(to: 1.03, duration: 1.2), .scale(to: 1.0, duration: 1.2)])
        breathe.timingMode = .easeInEaseOut
        model.runAction(.repeatForever(breathe))
        let sway = SCNAction.sequence([.rotateBy(x: 0, y: 0.12, z: 0, duration: 1.8), .rotateBy(x: 0, y: -0.12, z: 0, duration: 1.8)])
        sway.timingMode = .easeInEaseOut
        holder.runAction(.repeatForever(sway))

        c.model = model
        c.glow = glow
        c.hitCount = hitCount
        c.slamCount = slamCount
        c.awaitingFirstFrame = true
        view.scene = scene
        view.pointOfView = camera
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.onResult = onResult
        if hitCount != c.hitCount {
            c.hitCount = hitCount
            // kurz zurückzucken
            c.model?.runAction(.sequence([.moveBy(x: 0.06, y: 0, z: -0.05, duration: 0.05),
                                          .moveBy(x: -0.06, y: 0, z: 0.05, duration: 0.12)]), forKey: "hit")
        }
        if slamCount != c.slamCount {
            c.slamCount = slamCount
            // hochspringen und auf den Boden stampfen
            let jump = SCNAction.sequence([.moveBy(x: 0, y: 0.45, z: 0, duration: 0.25), .moveBy(x: 0, y: -0.45, z: 0, duration: 0.12)])
            jump.timingMode = .easeIn
            c.model?.runAction(jump, forKey: "slam")
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        c.glow?.light?.intensity = finale ? 2500 : rage ? 1400 : 0
        c.glow?.light?.color = finale ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : UIColor(red: 1, green: 0.15, blue: 0.2, alpha: 1)
        SCNTransaction.commit()
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        weak var view: SCNView?
        var model: SCNNode?
        var glow: SCNNode?
        var hitCount = 0
        var slamCount = 0
        var awaitingFirstFrame = false
        var onResult: (Bool) -> Void

        init(onResult: @escaping (Bool) -> Void) { self.onResult = onResult }

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard awaitingFirstFrame else { return }
            awaitingFirstFrame = false
            DispatchQueue.main.async { [weak self] in
                guard let self, let view = self.view else { return }
                if let image = view.snapshot().cgImage, MagentaCheck.isMostlyMagenta(image) {
                    view.isHidden = true
                    view.isPlaying = false
                    self.onResult(false)
                } else {
                    self.onResult(true)
                }
            }
        }
    }
}
