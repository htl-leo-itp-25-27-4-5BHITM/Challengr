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
    private var refreshToken:    String? = nil
    @Published var playerId:     String?  = nil
    @Published var playerName:   String  = ""
    @Published var keycloakUserId: String? = nil

    // MARK: - PKCE helpers
    private var codeVerifier: String = ""

    override init() {
        super.init()
        #if DEBUG
        // Nur UI-Tests im Test-Harness (lokales Backend ohne Keycloak, Login über X-Player-Id)
        let env = ProcessInfo.processInfo.environment
        if let pid = env["AUDIT_PLAYER_ID"], !pid.isEmpty {
            playerId = pid
            playerName = env["AUDIT_PLAYER_NAME"] ?? "AuditTester"
            keycloakUserId = pid
            isAuthenticated = true
        }
        #endif
        // Abgelaufener Login (Refresh fehlgeschlagen, 401) → zurück zum Login
        NotificationCenter.default.addObserver(forName: .authExpired, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleExpiredLogin() }
        }
        // Noch angemeldet vom letzten Mal? Dann ohne Klick wieder rein.
        if !isAuthenticated, TokenStore.load(TokenStore.refreshTokenKey) != nil {
            isLoading = true
            Task { await restoreSession() }
        }
    }

    /// Mit dem gespeicherten Refresh-Token still neu anmelden (kein Browser).
    func restoreSession() async {
        refreshToken = TokenStore.load(TokenStore.refreshTokenKey)
        idToken = TokenStore.load(TokenStore.idTokenKey)
        guard await refresh(), let accessToken else {
            // abgelaufen oder offline → normaler Login (ungültige Tokens löscht refresh() selbst)
            refreshToken = nil
            isLoading = false
            return
        }
        parseToken(accessToken)
        if playerId == nil, let keycloakUserId,
           let cached = UserDefaults.standard.string(forKey: "playerId.\(keycloakUserId)") {
            playerId = cached
        }
        if playerId == nil {
            await ensurePlayerId()
        }
        isAuthenticated = true
        isLoading = false
    }

    private func handleExpiredLogin() {
        guard isAuthenticated else { return }
        clearSession()
        errorMessage = "Deine Anmeldung ist abgelaufen – bitte neu anmelden."
    }

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
            // offline_access: Refresh-Token bleibt auch nach Wochen gültig (sonst nach 30 min ohne App weg)
            .init(name: "scope",                 value: "openid profile email offline_access"),
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
            apply(json)
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

    /// Neue Tokens übernehmen und an alle Anfragen weitergeben.
    private func apply(_ json: TokenResponse) {
        accessToken = json.access_token
        if let id = json.id_token {
            idToken = id
            TokenStore.save(id, for: TokenStore.idTokenKey)
        }
        if let refresh = json.refresh_token {
            refreshToken = refresh
            TokenStore.save(refresh, for: TokenStore.refreshTokenKey)
        }
        AuthSession.shared.update(accessToken: json.access_token, expiresIn: json.expires_in.map(TimeInterval.init))
        AuthSession.shared.setRefresher { [weak self] in
            await self?.refresh() ?? false
        }
    }

    /// Access-Token mit dem Refresh-Token erneuern (Keycloak gibt nur wenige Minuten gültige Tokens aus).
    func refresh() async -> Bool {
        guard let refreshToken else { return false }
        var body = URLComponents()
        body.queryItems = [
            .init(name: "grant_type",    value: "refresh_token"),
            .init(name: "client_id",     value: clientId),
            .init(name: "refresh_token", value: refreshToken),
        ]
        var req = URLRequest(url: URL(string: "\(keycloakBase)/protocol/openid-connect/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.query?.data(using: .utf8)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (400..<500).contains(status) {
                // Keycloak lehnt das Token ab (abgelaufen, widerrufen) – nicht mehr verwenden
                TokenStore.clear()
            }
            guard status == 200 else { return false }
            apply(try JSONDecoder().decode(TokenResponse.self, from: data))
            return true
        } catch {
            return false
        }
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
        if let pid = payload["player_id"] as? String {
            playerId = pid
        } else if let pid = payload["player_id"] as? Int64 {
            playerId = String(pid)
        } else if let pid = payload["player_id"] as? Int {
            playerId = String(pid)
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
                UserDefaults.standard.set(dto.id, forKey: "playerId.\(keycloakUserId)")
                UserDefaults.standard.set(dto.id, forKey: "playerId.\(trimmedName)")
                return
            } catch {
                errorMessage = "Spieler konnte nicht erstellt werden: \(error.localizedDescription)"
                return
            }
        }

        let key = "playerId.\(trimmedName)"
        if let storedId = UserDefaults.standard.string(forKey: key), !storedId.isEmpty {
            playerId = storedId
            return
        }

        do {
            let dto = try await playerService.createPlayer(name: trimmedName)
            playerId = dto.id
            UserDefaults.standard.set(dto.id, forKey: key)
        } catch {
            errorMessage = "Spieler konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Logout
    func logout() {
        revokeRefreshToken()
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

    /// Nach dem Löschen des Kontos: lokale Spieler-Zuordnungen entfernen und abmelden.
    func accountDeleted() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("playerId.") {
            defaults.removeObject(forKey: key)
        }
        clearSession()
    }

    /// Offline-Token bei Keycloak ungültig machen (das normale Logout beendet nur die Browser-Sitzung).
    private func revokeRefreshToken() {
        guard let refreshToken else { return }
        var body = URLComponents()
        body.queryItems = [
            .init(name: "client_id",       value: clientId),
            .init(name: "token",           value: refreshToken),
            .init(name: "token_type_hint", value: "refresh_token"),
        ]
        var req = URLRequest(url: URL(string: "\(keycloakBase)/protocol/openid-connect/revoke")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.query?.data(using: .utf8)
        Task { _ = try? await URLSession.shared.data(for: req) }
    }

    private func clearSession() {
        TokenStore.clear()
        AuthSession.shared.clear()
        accessToken     = nil
        refreshToken    = nil
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
    let refresh_token: String?
    /// Gültigkeit des Access-Tokens in Sekunden
    let expires_in: Int?
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
