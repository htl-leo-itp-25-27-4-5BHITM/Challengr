import Foundation
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
final class KeycloakAuthService: NSObject, ObservableObject {

    private let playerService = PlayerLocationService()

    // MARK: - Config
    private let keycloakBase  = "https://it220257.cloud.htl-leonding.ac.at/auth/realms/challengr"
    private let clientId      = "challengr-ios"
    private let redirectURI   = "challengr://callback"

    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var isLoading       = false
    @Published var errorMessage: String? = nil

    @Published var accessToken:  String? = nil
    @Published var idToken:      String? = nil
    @Published var playerId:     Int64?  = nil
    @Published var playerName:   String  = ""
    @Published var keycloakUserId: String? = nil

    // MARK: - PKCE helpers
    private var codeVerifier: String = ""

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }

    // MARK: - Login
    func login() {
        isLoading = true
        errorMessage = nil

        codeVerifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: codeVerifier)
        let state     = UUID().uuidString

        var comps = URLComponents(string: "\(keycloakBase)/protocol/openid-connect/auth")!
        comps.queryItems = [
            .init(name: "response_type",         value: "code"),
            .init(name: "client_id",             value: clientId),
            .init(name: "redirect_uri",          value: redirectURI),
            .init(name: "scope",                 value: "openid profile email"),
            .init(name: "state",                 value: state),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = comps.url,
              let callbackScheme = URL(string: redirectURI)?.scheme else {
            errorMessage = "Ungültige Auth-URL"
            isLoading = false
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callback, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                guard let callback,
                      let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.errorMessage = "Kein Auth-Code erhalten"
                    return
                }
                await self.exchangeCode(code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - Token Exchange
    private func exchangeCode(_ code: String) async {
        isLoading = true
        let tokenURL = URL(string: "\(keycloakBase)/protocol/openid-connect/token")!

        var body = URLComponents()
        body.queryItems = [
            .init(name: "grant_type",    value: "authorization_code"),
            .init(name: "client_id",     value: clientId),
            .init(name: "code",          value: code),
            .init(name: "redirect_uri",  value: redirectURI),
            .init(name: "code_verifier", value: codeVerifier),
        ]

        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.query?.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken = json.access_token
            idToken = json.id_token
            parseToken(json.access_token)
            if playerId == nil {
                await ensurePlayerId()
            }
            isAuthenticated = true
        } catch {
            errorMessage = "Token-Fehler: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - JWT-Payload parsen (playerId + name)
    private func parseToken(_ token: String) {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let payloadData = Data(base64URLEncoded: parts[1]),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return }

        playerName = payload["preferred_username"] as? String
                  ?? payload["name"] as? String
                  ?? ""

    keycloakUserId = payload["sub"] as? String

        // Keycloak-Claim: "player_id" (wird im Backend gesetzt)
        if let pid = payload["player_id"] as? Int64 {
            playerId = pid
        } else if let pid = payload["player_id"] as? Int {
            playerId = Int64(pid)
        }
    }

    private func ensurePlayerId() async {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let keycloakUserId, !keycloakUserId.isEmpty {
            do {
                let dto = try await playerService.createPlayer(
                    name: trimmedName,
                    keycloakId: keycloakUserId
                )
                playerId = dto.id
                UserDefaults.standard.set(Int(dto.id), forKey: "playerId.\(keycloakUserId)")
                UserDefaults.standard.set(Int(dto.id), forKey: "playerId.\(trimmedName)")
                return
            } catch {
                errorMessage = "Spieler konnte nicht erstellt werden: \(error.localizedDescription)"
                return
            }
        }

        let key = "playerId.\(trimmedName)"
        let storedId = UserDefaults.standard.integer(forKey: key)
        if storedId > 0 {
            playerId = Int64(storedId)
            return
        }

        do {
            let dto = try await playerService.createPlayer(name: trimmedName)
            playerId = dto.id
            UserDefaults.standard.set(Int(dto.id), forKey: key)
        } catch {
            errorMessage = "Spieler konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Logout
    func logout() {
        guard let idToken else {
            clearSession()
            return
        }

        var comps = URLComponents(string: "\(keycloakBase)/protocol/openid-connect/logout")!
        comps.queryItems = [
            .init(name: "id_token_hint", value: idToken),
            .init(name: "post_logout_redirect_uri", value: redirectURI)
        ]

        guard let logoutUrl = comps.url,
              let callbackScheme = URL(string: redirectURI)?.scheme else {
            clearSession()
            return
        }

        let session = ASWebAuthenticationSession(
            url: logoutUrl,
            callbackURLScheme: callbackScheme
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.clearSession()
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    private func clearSession() {
        accessToken     = nil
        idToken         = nil
        playerId        = nil
        playerName      = ""
        keycloakUserId  = nil
        isAuthenticated = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension KeycloakAuthService: ASWebAuthenticationPresentationContextProviding {
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Token Response DTO
private struct TokenResponse: Decodable {
    let access_token: String
    let id_token: String?
}

// MARK: - Data Base64URL Helpers
private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: base64)
    }
}
