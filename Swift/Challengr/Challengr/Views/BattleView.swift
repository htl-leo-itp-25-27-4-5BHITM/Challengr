import SwiftUI

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

    // MARK: - Entrance choreography (Eintritts-Animation)
    @State private var headerAppeared = false
    @State private var stripsAppeared = false
    @State private var vsAppeared = false
    @State private var vsFlash = false
    @State private var idleBounce = false

    // MARK: - Body (UI-Aufbau)
    var body: some View {
        GeometryReader { geo in
            ZStack {
                vsaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        header
                            .opacity(headerAppeared ? 1 : 0)
                            .offset(y: headerAppeared ? 0 : -16)

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
                        .opacity(stripsAppeared ? 1 : 0)
                        .offset(y: stripsAppeared ? 0 : 24)
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
        .onAppear { playEntrance() }
    }

    private func playEntrance() {
        withAnimation(.easeOut(duration: 0.35)) {
            headerAppeared = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.15)) {
            stripsAppeared = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.5)) {
            vsAppeared = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            vsFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                idleBounce = true
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
    // MARK: - Battle stage (Kampf-Bühne)

    private func battleStage(stageHeight: CGFloat) -> some View {
        ZStack {
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
                    .offset(x: stripsAppeared ? 0 : -260)
                    .opacity(stripsAppeared ? 1 : 0)

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
                    .offset(x: stripsAppeared ? 0 : 260)
                    .opacity(stripsAppeared ? 1 : 0)
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
        let modelSize = compact ? CGSize(width: 200, height: 155) : CGSize(width: 250, height: 185)
        let stripHeight = modelSize.height + 34
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
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                CharacterAvatarView(imageName: imageName, flip: flip, bounce: idleBounce)
                    .frame(width: modelSize.width, height: modelSize.height, alignment: .bottom)
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                    .padding(.trailing, 6)
            } else {
                CharacterAvatarView(imageName: imageName, flip: flip, bounce: idleBounce)
                    .frame(width: modelSize.width, height: modelSize.height, alignment: .bottom)
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
                    .padding(.leading, 6)

                Text(name.uppercased())
                    .font(.system(size: nameFont, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .frame(minWidth: 110, maxWidth: 170, alignment: .trailing)
                    .padding(.trailing, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
        }
        .frame(height: stripHeight)
        .background {
            ZStack {
                battleStripBackground(color: color, alignRight: alignRight)

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
        .clipShape(ChamferedCard(alignRight: alignRight))
        .overlay(
            ChamferedCard(alignRight: alignRight)
                .stroke(color.opacity(0.45), lineWidth: 1.5)
        )
    }

    /// On-brand player strip backdrop: dark base + team-colored glow + faint
    /// diagonal speed lines. Replaces a mismatched stock "war photo" image.
    private func battleStripBackground(color: Color, alignRight: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.challengrDark, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [color.opacity(0.45), Color.clear],
                center: alignRight ? .bottomLeading : .bottomTrailing,
                startRadius: 4,
                endRadius: 220
            )

            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 22
                    var x: CGFloat = -geo.size.height
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                        x += spacing
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 3)
            }
        }
    }

    private var vsCenter: some View {
        ZStack {
            // Expanding impact ring on entrance.
            Circle()
                .stroke(Color.white.opacity(vsFlash ? 0 : 0.85), lineWidth: 3)
                .frame(width: vsFlash ? 150 : 40, height: vsFlash ? 150 : 40)

            // Split-color disc (each fighter's color) glowing behind the badge,
            // instead of a busy radiating pattern.
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            .challengrYellow, .challengrYellow,
                            .challengrRed, .challengrRed,
                            .challengrYellow
                        ],
                        center: .center
                    )
                )
                .frame(width: 84, height: 84)
                .blur(radius: 18)
                .opacity(0.55)

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

            Text("VS")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white)
        }
        .frame(width: 70, height: 66)
        .scaleEffect(vsAppeared ? 1 : 0.2)
        .opacity(vsAppeared ? 1 : 0)
        .accessibilityLabel("VS")
    }
}

/// Card shape with one corner chamfered off, angled toward the VS badge.
/// Gives the two fighter cards a "clash" feel instead of two plain boxes.
private struct ChamferedCard: Shape {
    let alignRight: Bool
    var chamfer: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        let c = min(chamfer, min(rect.width, rect.height) * 0.35)
        var path = Path()

        if alignRight {
            // Bottom-right card: chamfer the top-left corner (faces up/left toward VS).
            path.move(to: CGPoint(x: c, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: c))
            path.closeSubpath()
        } else {
            // Top-left card: chamfer the bottom-right corner (faces down/right toward VS).
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - c))
            path.addLine(to: CGPoint(x: rect.width - c, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }

        return path
    }
}

/// A player's 2D character illustration, planted on a grounding shadow with a
/// subtle idle breathing loop so the VS screen doesn't feel static.
private struct CharacterAvatarView: View {
    let imageName: String
    let flip: Bool
    let bounce: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(width: 96, height: 18)
                .blur(radius: 8)
                .offset(y: 12)

            Image(imageName)
                .resizable()
                .scaledToFit()
                // Right-side fighter should face left; left-side fighter should face right.
                .scaleEffect(x: flip ? -1 : 1, y: 1)
                .scaleEffect(bounce ? 1.035 : 1.0, anchor: .bottom)
        }
    }
}
