import SwiftUI
import CoreImage.CIFilterBuiltins

/// Shows a QR code that encodes a friend-invite payload.
///
/// Payload format (v1):
/// challengr://friend-invite?from=<playerId>
struct FriendInviteQRView: View {
    let ownPlayerId: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("QR Code vorzeigen")
                    .font(.system(size: 18, weight: .bold))

                Text("Die andere Person scannt den Code und bekommt automatisch eine Freundesanfrage.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                let payload = FriendInvitePayload.v1(fromPlayerId: ownPlayerId).asURLString()

                Image(uiImage: generateQRCode(from: payload))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                Text(payload)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Einladung")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        // Scale up sharply
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cgimg)
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

enum FriendInvitePayload {
    case v1(fromPlayerId: String)

    func asURLString() -> String {
        switch self {
        case .v1(let fromPlayerId):
            // Keep it short, robust, and easy to parse.
            // Example: challengr://friend-invite?from=abc123
            var components = URLComponents()
            components.scheme = "challengr"
            components.host = "friend-invite"
            components.queryItems = [
                URLQueryItem(name: "from", value: fromPlayerId)
            ]
            return components.string ?? "challengr://friend-invite?from=\(fromPlayerId)"
        }
    }

    static func parse(_ raw: String) -> String? {
        // Returns fromPlayerId if the payload matches.
        guard let url = URL(string: raw), url.scheme == "challengr" else { return nil }
        guard url.host == "friend-invite" else { return nil }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == "from" })?.value
    }
}
