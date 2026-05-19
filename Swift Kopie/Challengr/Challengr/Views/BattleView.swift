import SwiftUI
import RealityKit
import simd

// MARK: - View (UI)

struct BattleView: View {
    // MARK: - Input (Eingaben)
    let challengeName: String
    let category: String
    let playerLeft: String
    let playerRight: String
    let onClose: () -> Void
    let onSurrender: () -> Void
    let onFinished: () -> Void

    // MARK: - UI States (keine Animationen)
    // Intentionally no animated state—screen should be static.

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        GeometryReader { geo in
            ZStack {
                vsaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        header

                        // Give the challenge title more breathing room above the stage.
                        // (We intentionally push the stage down; there's free space below.)
                        Spacer(minLength: 44)

                        battleStage(stageHeight: cappedStageHeight(for: geo.size))
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom) {
                    bottomBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }

    private func cappedStageHeight(for size: CGSize) -> CGFloat {
        // Keep stage responsive so header + stage + bottomBar fit on small screens.
        // Rough cap: 38% of available height, but within sensible bounds.
        let proposed = size.height * 0.44
        return min(max(proposed, 240), 360)
    }

    private var vsaBackground: some View {
        ZStack {
            // Subtle, readable overall background (photo should be only inside player strips)
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.92),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft left / right accent so it still feels like a "VS" screen.
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color.challengrYellow.opacity(0.16),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        Color.challengrRed.opacity(0.16),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            RadialGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.black.opacity(0.85)
                ],
                center: .top,
                startRadius: 50,
                endRadius: 520
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.challengrYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )

                Spacer()
            }

            Text(challengeName)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 6)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Text("CHALLENGE GESCHAFFT?")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.85))

            HStack(spacing: 14) {
                GamePrimaryButton(title: "Geschafft", color: .challengrGreen) {
                    onFinished()
                }

                Button(action: onSurrender) {
                    HStack(spacing: 8) {
                        Text("AUFGEBEN")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .tracking(1)
                        Text("✖")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.55),
                                        Color.black.opacity(0.30)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.challengrRed,
                                        Color.challengrRed.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                    .shadow(color: Color.challengrRed.opacity(0.35), radius: 18, x: 0, y: 0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    // MARK: - Subviews (Unteransichten)
    // MARK: - Player Panel (Spieler-Panel)

    private func playerPanel(
        name: String,
        color: Color,
        imageName: String,
        flip: Bool
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.white)
                    .frame(width: 120, height: 180)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

                RoundedRectangle(cornerRadius: 22)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 110, height: 170)

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 170)
                    .scaleEffect(x: flip ? -1 : 1, y: 1)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 22)
                    )
            }

            Text(name.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)
        }
    }

    private func battleStage(stageHeight: CGFloat) -> some View {
        ZStack {
            // Top-left Challenger strip (extends right)
            VStack {
                HStack {
                    playerStrip(
                        name: playerLeft,
                        color: .challengrYellow,
                        imageName: AvatarPresets.persistedImageName(),
                        flip: false,
                        alignRight: false,
                        compact: stageHeight < 300
                    )

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                vsCenter

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    playerStrip(
                        name: playerRight,
                        color: .challengrRed,
                        imageName: "playerGirl",
                        flip: true,
                        alignRight: true,
                        compact: stageHeight < 300
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(height: stageHeight)
        .padding(.top, 4)
    }

    private func playerStrip(
        name: String,
        color: Color,
        imageName: String,
        flip: Bool,
        alignRight: Bool,
        compact: Bool
    ) -> some View {
        let modelSize = compact ? CGSize(width: 190, height: 140) : CGSize(width: 230, height: 160)
        let stripHeight = modelSize.height + 46
        let corner: UIRectCorner = alignRight ? [.topLeft, .bottomLeft] : [.topRight, .bottomRight]
        let nameFont: CGFloat = compact ? 12 : 13

        return HStack(alignment: .bottom, spacing: 12) {
            if alignRight {
                Text(name.uppercased())
                    .font(.system(size: nameFont, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .frame(minWidth: 110, maxWidth: 170, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.vertical, 10)

                characterModelView(flip: flip, fallbackImage: imageName)
                    // Make the character sit on the bottom edge of the strip.
                    .frame(width: modelSize.width, height: modelSize.height, alignment: .bottom)
                    .frame(height: stripHeight - 10, alignment: .bottom)
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                    .padding(.trailing, 10)
            } else {
                characterModelView(flip: flip, fallbackImage: imageName)
                    // Make the character sit on the bottom edge of the strip.
                    .frame(width: modelSize.width, height: modelSize.height, alignment: .bottom)
                    .frame(height: stripHeight - 10, alignment: .bottom)
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                    .padding(.leading, 10)

                Text(name.uppercased())
                    .font(.system(size: nameFont, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .frame(minWidth: 110, maxWidth: 170, alignment: .trailing)
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(height: stripHeight)
        .background {
            ZStack {
                // Player strip background image (the "box" background)
                Image("basic")
                    .resizable()
                    .scaledToFill()

                // Readability + team tint
                Color.black.opacity(0.45)

                LinearGradient(
                    colors: [
                        color.opacity(0.32),
                        Color.clear
                    ],
                    startPoint: alignRight ? .trailing : .leading,
                    endPoint: alignRight ? .leading : .trailing
                )

                // Slight highlight to keep it from looking flat
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped() // prevent any image bleed
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private var vsCenter: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
                .shadow(color: Color.challengrYellow.opacity(0.12), radius: 18, x: 0, y: 0)
                .shadow(color: Color.challengrRed.opacity(0.12), radius: 18, x: 0, y: 0)

            VStack(spacing: 6) {
                Text("VS")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(width: 66, height: 62)
        .accessibilityLabel("VS")
    }

    private func characterCard(
        name: String,
        color: Color,
        imageName: String,
        flip: Bool,
        compact: Bool
    ) -> some View {
        let modelSize = compact ? CGSize(width: 180, height: 140) : CGSize(width: 220, height: 170)
        let nameWidth: CGFloat = compact ? 220 : 260

        return VStack(spacing: 6) {
            characterModelView(flip: flip, fallbackImage: imageName)
                .frame(width: modelSize.width, height: modelSize.height)
                .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 14)
                .background(
                    RadialGradient(
                        colors: [
                            color.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 150
                    )
                )

            Text(name.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .lineLimit(1)
                .minimumScaleFactor(0.60)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
                .frame(width: nameWidth)
        }
    }

    @ViewBuilder
    private func characterModelView(flip: Bool, fallbackImage: String) -> some View {
        CharacterModelContainer(flip: flip, fallbackImage: fallbackImage)
    }
}

private struct CharacterModelContainer: View {
    let flip: Bool
    let fallbackImage: String

    @State private var model: ModelEntity?
    @State private var didTryLoad = false

    var body: some View {
        ZStack {
            if model == nil {
                Image(fallbackImage)
                    .resizable()
                    .scaledToFit()
                    // Right-side fighter should face left; left-side fighter should face right.
                    .scaleEffect(x: flip ? 1 : -1, y: 1)
            }

            if #available(iOS 17.0, *), let model {
                RealityView { content in
                    // Anchor: otherwise entities can appear in an unexpected coordinate space.
                    let anchor = AnchorEntity(world: .zero)

                    let clone = model.clone(recursive: true)
                    // Rotate the right-side fighter towards center.
                    let rotation = simd_quatf(angle: flip ? 0 : .pi, axis: SIMD3<Float>(0, 1, 0))

                    // Basic staging so the model looks consistent even without custom cameras.
                    clone.transform = Transform(
                        scale: SIMD3<Float>(repeating: 1.10),
                        rotation: rotation,
                        translation: SIMD3<Float>(0, -0.55, 0)
                    )

                    // Light
                    let light = DirectionalLight()
                    light.light.intensity = 22_000
                    light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4.0)
                    light.look(at: SIMD3<Float>(0, 0, 0), from: SIMD3<Float>(1.5, 2.0, 1.5), relativeTo: nil)
                    anchor.addChild(light)

                    // Ground plane for softer shadows / grounding cue
                    let ground = ModelEntity(
                        mesh: .generatePlane(width: 2.2, depth: 2.2),
                        materials: [SimpleMaterial(color: .black.withAlphaComponent(0.12), isMetallic: false)]
                    )
                    ground.position = SIMD3<Float>(0, -0.75, 0)
                    anchor.addChild(ground)
                    anchor.addChild(clone)

                    content.add(anchor)
                }
            }
        }
        .task {
            guard model == nil else { return }
            await loadModel()
        }
    }

    private func loadModel() async {
        didTryLoad = true

        // Preferred: load from Asset Catalog dataset `character.dataset/character.usdc`
        if let fromCatalog = try? await ModelEntity(named: "character") {
            model = fromCatalog
            return
        }

        // Fallbacks: in case the asset is shipped as a standalone file.
        if let usdzURL = Bundle.main.url(forResource: "character", withExtension: "usdz"),
           let fromUsdz = try? await ModelEntity(contentsOf: usdzURL) {
            model = fromUsdz
            return
        }

        if let usdcURL = Bundle.main.url(forResource: "character", withExtension: "usdc"),
           let fromUsdc = try? await ModelEntity(contentsOf: usdcURL) {
            model = fromUsdc
        }
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
