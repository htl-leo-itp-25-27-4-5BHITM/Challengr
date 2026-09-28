import SwiftUI
import AVFoundation
import CoreImage

enum ChallengeColor: String, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case blue
    case violet

    var displayName: String {
        switch self {
        case .red: return "Rot"
        case .orange: return "Orange"
        case .yellow: return "Gelb"
        case .green: return "Grün"
        case .blue: return "Blau"
        case .violet: return "Violett"
        }
    }

    var uiColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .violet: return Color(hue: 0.78, saturation: 0.75, brightness: 0.9)
        }
    }
}

struct DetectedHue: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let fraction: Double
    let hueDegrees: Double
}

struct TargetRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color {
        Color(red: r, green: g, blue: b)
    }
}

struct CameraChallengeView: View {
    let battleId: Int64
    let socket: GameSocketService
    let onClose: () -> Void

    @State private var foundRed = false
    @State private var scanning = true
    @State private var matchFraction: Double = 0.0
    @State private var detectionStrength: Double = 0.0
    @State private var detectedHues: [DetectedHue] = []
    @State private var lastCheckResult: String? = nil
    @State private var showResultColor: Color = .clear
    @State private var targetRGB = TargetRGB(r: 1.0, g: 0.0, b: 0.0)
    @State private var score: Int = 0
    @State private var rgbTolerance: Double = 0.32
    @State private var dotProduct: Double = 0.0
    @State private var hasSentResult = false
    @State private var waitingForResult = false

    var body: some View {
        GeometryReader { geo in
            let scannerRegion = computedScannerRegion(size: geo.size, safeArea: geo.safeAreaInsets)

            ZStack(alignment: .bottom) {
                ZStack {
                    CameraView(
                        foundRed: $foundRed,
                        scanning: $scanning,
                        matchFraction: $matchFraction,
                        detectionStrength: $detectionStrength,
                        detectedHues: $detectedHues,
                        targetRGB: $targetRGB,
                        rgbTolerance: $rgbTolerance,
                        dotProduct: $dotProduct,
                        scanRegion: scannerRegion
                    )
                    ScannerFocusOverlay(scanRegion: scannerRegion)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.18), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    Text("📸 KAMERA CHALLENGE")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Finde diese Farbe")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(targetRGB.color)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )

                        Text("RGB \(Int(targetRGB.r * 255))/\(Int(targetRGB.g * 255))/\(Int(targetRGB.b * 255))")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.12), in: Capsule())
                    }

                    Text("Halte ein Objekt in dieser Farbe in den Scannerbereich und drücke 'Prüfen'.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.88))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach(ChallengeColor.allCases, id: \.self) { color in
                            Button(action: {
                                targetRGB = presetRGB(for: color)
                                lastCheckResult = nil
                                showResultColor = .clear
                            }) {
                                Circle()
                                    .fill(color.uiColor)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                    )
                            }
                            .accessibilityLabel("Preset \(color.displayName)")
                        }

                        Button(action: {
                            lastCheckResult = nil
                            showResultColor = .clear
                            nextChallenge()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.18), in: Circle())
                        }
                        .accessibilityLabel("Zufallsfarbe")
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            let success = dotProduct >= 0.60
                            lastCheckResult = success
                                ? "Erfolg! Ziel-Farbe erkannt."
                                : "Erkannt: \(detectedHues.map { $0.name }.joined(separator: ", ")) (\(Int(detectionStrength * 100))%). Versuch's nochmal."
                            showResultColor = success ? .green.opacity(0.88) : .red.opacity(0.88)
                            if success {
                                score += 10
                                if !hasSentResult {
                                    hasSentResult = true
                                    waitingForResult = true
                                    socket.sendCameraResult(battleId: battleId, score: dotProduct)
                                    // Don't close immediately; give the battle flow time to transition.
                                    // If the parent listens for `battle-result`, it can close/transition itself.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        onClose()
                                    }
                                }
                            }
                        }) {
                            Text("Prüfen")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(waitingForResult)

                        Button(action: {
                            lastCheckResult = nil
                            showResultColor = .clear
                            nextChallenge()
                        }) {
                            Text("Reset")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }

                    if let res = lastCheckResult {
                        Text(res)
                            .font(.headline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(showResultColor))
                            .foregroundColor(.white)
                    }

                    if waitingForResult {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Warte auf Ergebnis …")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 6)
                    }

                    VStack(spacing: 4) {
                        HStack {
                            Text("Übereinstimmung")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(dotProduct * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red,
                                                Color.yellow,
                                                Color.green
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * dotProduct)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Spacer(minLength: 16)

                        Text("Score: \(score)")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
                .padding(18)
                .frame(maxWidth: 380)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
        }
        .onAppear { nextChallenge() }
        .onDisappear { scanning = false }
    }

    private func computedScannerRegion(size: CGSize, safeArea: EdgeInsets) -> CGRect {
        let top = safeArea.top + 14
        let reservedBottomPanelHeight: CGFloat = 220
        let bottomLimit = size.height - (safeArea.bottom + reservedBottomPanelHeight) - 16

        let availableH = max(120, bottomLimit - top)

        let targetW = min(size.width * 0.84, 360)
        let targetH = min(availableH * 0.92, targetW * 0.70)

        let x = (size.width - targetW) / 2
        let y = top + max(0, (availableH - targetH) * 0.10)

        return CGRect(
            x: x / size.width,
            y: y / size.height,
            width: targetW / size.width,
            height: targetH / size.height
        )
    }

    private func nextChallenge() {
        let colors: [ChallengeColor] = [.red, .orange, .yellow, .green, .blue, .violet]
        if let randomColor = colors.randomElement() {
            targetRGB = presetRGB(for: randomColor)
        }
    }

    private func presetRGB(for color: ChallengeColor) -> TargetRGB {
        switch color {
        case .red:
            return TargetRGB(r: 1.0, g: 0.0, b: 0.0)
        case .orange:
            return TargetRGB(r: 1.0, g: 0.5, b: 0.0)
        case .yellow:
            return TargetRGB(r: 1.0, g: 0.9, b: 0.0)
        case .green:
            return TargetRGB(r: 0.0, g: 0.85, b: 0.15)
        case .blue:
            return TargetRGB(r: 0.0, g: 0.0, b: 1.0)
        case .violet:
            return TargetRGB(r: 0.6, g: 0.2, b: 0.9)
        }
    }
}

struct CameraView: UIViewRepresentable {
    @Binding var foundRed: Bool
    @Binding var scanning: Bool
    @Binding var matchFraction: Double
    @Binding var detectionStrength: Double
    @Binding var detectedHues: [DetectedHue]
    @Binding var targetRGB: TargetRGB
    @Binding var rgbTolerance: Double
    @Binding var dotProduct: Double
    let scanRegion: CGRect

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = context.coordinator.session
        context.coordinator.setupSession()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.scanning = scanning
        context.coordinator.previewSize = uiView.bounds.size
        if scanning {
            context.coordinator.startSession()
        } else {
            context.coordinator.stopSession()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let parent: CameraView
        let session = AVCaptureSession()
        var scanning = true
        var previewSize: CGSize = .zero

        let ciContext = CIContext()
        private var smoothedStrength = 0.0
        private var smoothedFraction = 0.0
        private var smoothedDotProduct = 0.0

        init(parent: CameraView) {
            self.parent = parent
            super.init()
        }

        func setupSession() {
            session.beginConfiguration()
            session.sessionPreset = .vga640x480

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                return
            }

            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
            } catch {
                // ignore
            }

            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            let queue = DispatchQueue(label: "camera.frame.processing")
            output.setSampleBufferDelegate(self, queue: queue)

            if session.canAddOutput(output) { session.addOutput(output) }
            if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            session.commitConfiguration()
            startSession()
        }

        private func imageScanBounds(imageWidth: Int, imageHeight: Int) -> (startX: Int, endX: Int, startY: Int, endY: Int)? {
            guard imageWidth > 0, imageHeight > 0 else { return nil }

            let previewW = max(previewSize.width, 1)
            let previewH = max(previewSize.height, 1)

            let iw = CGFloat(imageWidth)
            let ih = CGFloat(imageHeight)

            let scale = max(previewW / iw, previewH / ih)
            let scaledW = iw * scale
            let scaledH = ih * scale
            let cropX = (scaledW - previewW) / 2
            let cropY = (scaledH - previewH) / 2

            let viewRect = CGRect(
                x: parent.scanRegion.minX * previewW,
                y: parent.scanRegion.minY * previewH,
                width: parent.scanRegion.width * previewW,
                height: parent.scanRegion.height * previewH
            )

            let imageRect = CGRect(
                x: (viewRect.minX + cropX) / scale,
                y: (viewRect.minY + cropY) / scale,
                width: viewRect.width / scale,
                height: viewRect.height / scale
            )

            let startX = max(0, min(imageWidth - 1, Int(imageRect.minX.rounded(.down))))
            let endX = max(startX + 1, min(imageWidth, Int(imageRect.maxX.rounded(.up))))
            let startY = max(0, min(imageHeight - 1, Int(imageRect.minY.rounded(.down))))
            let endY = max(startY + 1, min(imageHeight, Int(imageRect.maxY.rounded(.up))))

            return (startX, endX, startY, endY)
        }

        private func rgbToHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
            let maxValue = max(r, g, b)
            let minValue = min(r, g, b)
            let delta = maxValue - minValue

            var hue: Double = 0.0
            if delta > 0 {
                if maxValue == r {
                    hue = (g - b) / delta
                    hue = hue.truncatingRemainder(dividingBy: 6.0)
                } else if maxValue == g {
                    hue = (b - r) / delta + 2.0
                } else {
                    hue = (r - g) / delta + 4.0
                }
                hue *= 60.0
                if hue < 0 { hue += 360.0 }
            }

            let saturation = maxValue == 0 ? 0 : (delta / maxValue)
            return (h: hue, s: saturation, v: maxValue)
        }

        private let minValue = 0.05

        private let hueBins: [String] = [
            "Rot", "Orange", "Gelb", "Grün-Gelb", "Grün", "Türkis",
            "Cyan", "Blau", "Indigo", "Violett", "Magenta", "Pink"
        ]

        private func blockScore(
            target: TargetRGB,
            tolerance: Double,
            ptr: UnsafePointer<UInt8>,
            imgW: Int,
            x0: Int,
            y0: Int,
            scaleLevel: Int
        ) -> Double? {
            var avgR = 0.0
            var avgG = 0.0
            var avgB = 0.0
            var pixelCount = 0

            let bytesPerPixel = 4
            let blockSize = scaleLevel

            for y in y0..<(y0 + blockSize) {
                var offset = (y * imgW + x0) * bytesPerPixel
                for _ in x0..<(x0 + blockSize) {
                    let r = Double(ptr[offset]) / 255.0
                    let g = Double(ptr[offset + 1]) / 255.0
                    let b = Double(ptr[offset + 2]) / 255.0

                    avgR += r
                    avgG += g
                    avgB += b
                    pixelCount += 1
                    offset += bytesPerPixel
                }
            }

            guard pixelCount > 0 else { return nil }

            avgR /= Double(pixelCount)
            avgG /= Double(pixelCount)
            avgB /= Double(pixelCount)

            let distance = sqrt(
                (avgR - target.r) * (avgR - target.r)
                + (avgG - target.g) * (avgG - target.g)
                + (avgB - target.b) * (avgB - target.b)
            ) / sqrt(3.0)

            let similarity = max(0.0, 1.0 - distance)
            return similarity
        }

        func startSession() {
            guard !session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }

        func stopSession() {
            guard session.isRunning else { return }
            DispatchQueue.global(qos: .background).async {
                self.session.stopRunning()
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard scanning else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            let scale = max(1, min(8, max(width, height) / 160))
            let small = ciImage.transformed(by: CGAffineTransform(scaleX: 1.0 / CGFloat(scale), y: 1.0 / CGFloat(scale)))

            guard let cgImage = ciContext.createCGImage(small, from: small.extent) else { return }

            guard let data = cgImage.dataProvider?.data else { return }
            let ptr = CFDataGetBytePtr(data)!
            let bytesPerPixel = 4
            var dotProductSum = 0.0
            var sampleCount = 0

            let imgW = cgImage.width
            let imgH = cgImage.height
            guard let bounds = imageScanBounds(imageWidth: imgW, imageHeight: imgH) else { return }
            let startX = bounds.startX
            let endX = bounds.endX
            let startY = bounds.startY
            let endY = bounds.endY
            guard (endX - startX) > 2, (endY - startY) > 2 else { return }

            let gridStep = 8
            for y0 in stride(from: startY, to: endY, by: gridStep) {
                for x0 in stride(from: startX, to: endX, by: gridStep) {
                    let blockEndX = min(x0 + gridStep, endX)

                    guard let similarity = blockScore(
                        target: parent.targetRGB,
                        tolerance: parent.rgbTolerance,
                        ptr: ptr,
                        imgW: imgW,
                        x0: x0,
                        y0: y0,
                        scaleLevel: blockEndX - x0
                    ) else { continue }

                    dotProductSum += similarity
                    sampleCount += 1
                }
            }

            let alpha = 0.30
            let rawDotProduct = sampleCount > 0 ? min(1.0, dotProductSum / Double(sampleCount)) : 0.0

            smoothedDotProduct = smoothedDotProduct * (1 - alpha) + rawDotProduct * alpha

            let rawStrength = smoothedDotProduct
            let rawFraction = smoothedDotProduct

            smoothedStrength = smoothedStrength * (1 - alpha) + rawStrength * alpha
            smoothedFraction = smoothedFraction * (1 - alpha) + rawFraction * alpha

            var binCounts = Array(repeating: 0, count: hueBins.count)
            var validPixels = 0
            var valueSum = 0.0
            let strideStep = 2
            for y in stride(from: startY, to: endY, by: strideStep) {
                var offset = (y * imgW + startX) * bytesPerPixel
                for _ in stride(from: startX, to: endX, by: strideStep) {
                    let r = Double(ptr[offset]) / 255.0
                    let g = Double(ptr[offset + 1]) / 255.0
                    let b = Double(ptr[offset + 2]) / 255.0
                    let hsv = rgbToHSV(r: r, g: g, b: b)
                    if hsv.v >= minValue {
                        let index = Int(((hsv.h + 15.0) / 30.0).rounded(.down)) % hueBins.count
                        binCounts[index] += 1
                        validPixels += 1
                        valueSum += hsv.v
                    }
                    offset += bytesPerPixel * strideStep
                }
            }

            var detectedHues = [DetectedHue]()
            if validPixels > 0 {
                for (index, count) in binCounts.enumerated() {
                    let fraction = Double(count) / Double(validPixels)
                    if fraction >= 0.04 {
                        let hueDegrees = Double(index) * 30.0
                        detectedHues.append(DetectedHue(name: hueBins[index], fraction: fraction, hueDegrees: hueDegrees))
                    }
                }
                detectedHues.sort { $0.fraction > $1.fraction }
                if detectedHues.count > 8 {
                    detectedHues = Array(detectedHues.prefix(8))
                }
            }

            DispatchQueue.main.async {
                self.parent.matchFraction = self.smoothedFraction
                self.parent.detectionStrength = self.smoothedStrength
                self.parent.foundRed = self.smoothedStrength > 0.5
                self.parent.detectedHues = detectedHues
                self.parent.dotProduct = self.smoothedDotProduct
            }
        }
    }
}

class PreviewView: UIView {
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        previewLayer.videoGravity = .resizeAspectFill
    }
}

private struct ScannerFocusOverlay: View {
    let scanRegion: CGRect

    var body: some View {
        GeometryReader { geo in
            let holeRect = CGRect(
                x: geo.size.width * scanRegion.minX,
                y: geo.size.height * scanRegion.minY,
                width: geo.size.width * scanRegion.width,
                height: geo.size.height * scanRegion.height
            )

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRoundedRect(in: holeRect, cornerSize: CGSize(width: 16, height: 16))
                }
                .fill(Color.black.opacity(0.38), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    .frame(width: holeRect.width, height: holeRect.height)
                    .position(x: holeRect.midX, y: holeRect.midY)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    .frame(width: holeRect.width, height: holeRect.height)
                    .position(x: holeRect.midX, y: holeRect.midY)

                VStack {
                    Text("Scannerbereich")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                }
                .frame(width: holeRect.width, height: holeRect.height)
                .position(x: holeRect.midX, y: holeRect.midY)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
