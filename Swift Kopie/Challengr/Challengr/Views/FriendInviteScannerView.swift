import SwiftUI
import AVFoundation

struct FriendInviteScannerView: View {
    let ownPlayerId: String
    var onDidSendRequest: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSending: Bool = false
    @State private var errorText: String? = nil

    private let friendsService = FriendsService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeScannerRepresentable { raw in
                    handleScan(raw)
                }
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    if let err = errorText {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if isSending {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Sende Anfrage…")
                                .font(.footnote)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text("QR-Code scannen")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("QR scannen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.35), for: .navigationBar)
        }
    }

    private func handleScan(_ raw: String) {
        guard !isSending else { return }
        errorText = nil

        guard let fromPlayerId = FriendInvitePayload.parse(raw) else {
            errorText = "Ungültiger QR-Code (kein Challengr Invite)."
            return
        }

        guard fromPlayerId != ownPlayerId else {
            errorText = "Das ist dein eigener Code."
            return
        }

        isSending = true

        Task {
            do {
                try await friendsService.sendFriendRequest(from: ownPlayerId, to: fromPlayerId)
                await MainActor.run {
                    isSending = false
                    onDidSendRequest()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    let details = error.localizedDescription
                    errorText = details.isEmpty ? "Konnte Anfrage nicht senden." : "Konnte Anfrage nicht senden: \(details)"
                }
            }
        }
    }
}

private struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let vc = QRCodeScannerViewController()
        vc.onCode = onCode
        return vc
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput)
        else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        // Simple overlay frame
        let overlay = UIView()
        overlay.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        overlay.layer.borderWidth = 2
        overlay.layer.cornerRadius = 18
        overlay.backgroundColor = UIColor.clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(equalToConstant: 260),
            overlay.heightAnchor.constraint(equalToConstant: 260)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let value = obj.stringValue
        else { return }

        // Stop to prevent duplicate triggers
        session.stopRunning()
        onCode?(value)
    }
}
