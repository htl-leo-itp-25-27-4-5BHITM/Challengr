import Foundation

extension Notification.Name {
    /// Login abgelaufen und nicht erneuerbar → zurück zum Login-Screen.
    static let authExpired = Notification.Name("challengr.authExpired")
}

/// Zentrale Stelle für das Keycloak-Token: jede Anfrage ans Backend bekommt
/// `Authorization: Bearer …`, abgelaufene Tokens werden mit dem Refresh-Token erneuert.
/// `nonisolated` + Lock, weil Services und der WebSocket von verschiedenen Threads aus fragen.
nonisolated final class AuthSession: @unchecked Sendable {
    static let shared = AuthSession()

    private let lock = NSLock()
    private var accessToken: String?
    private var expiresAt: Date?
    private var refreshing: Task<Bool, Never>?
    /// Erneuert das Token (gesetzt von `KeycloakAuthService`); `true` = neues Token liegt bereit.
    private var refresher: (@Sendable () async -> Bool)?

    /// Nur Debug-Builds im Test-Harness: dort gibt es kein Keycloak und das lokale Test-Backend
    /// akzeptiert stattdessen den Header X-Player-Id. Der echte Server ignoriert ihn.
    private let devPlayerId: String? = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["AUDIT_PLAYER_ID"]
        #else
        return nil
        #endif
    }()

    /// Token gilt als abgelaufen, wenn es in weniger als 30 s abläuft.
    static let refreshMargin: TimeInterval = 30

    func update(accessToken: String?, expiresIn: TimeInterval?, now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        self.accessToken = accessToken
        self.expiresAt = expiresIn.map { now.addingTimeInterval($0) }
    }

    func setRefresher(_ refresher: (@Sendable () async -> Bool)?) {
        lock.lock(); defer { lock.unlock() }
        self.refresher = refresher
    }

    func clear() {
        update(accessToken: nil, expiresIn: nil)
        setRefresher(nil)
    }

    var currentToken: String? {
        lock.lock(); defer { lock.unlock() }
        return accessToken
    }

    func needsRefresh(now: Date = Date()) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard accessToken != nil, let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) < Self.refreshMargin
    }

    /// Erneuert das Token, falls es bald abläuft. Gleichzeitige Aufrufe teilen sich eine Erneuerung.
    @discardableResult
    func refreshIfNeeded(force: Bool = false) async -> Bool {
        guard force || needsRefresh() else { return currentToken != nil }
        let task: Task<Bool, Never>? = {
            lock.lock(); defer { lock.unlock() }
            if let refreshing { return refreshing }
            guard let refresher else { return nil }
            let t = Task { await refresher() }
            refreshing = t
            return t
        }()
        guard let task else { return false }
        let ok = await task.value
        lock.lock(); refreshing = nil; lock.unlock()
        return ok
    }

    /// Login-Header an eine Anfrage hängen.
    func authorize(_ request: inout URLRequest) {
        if let token = currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let devPlayerId {
            request.setValue(devPlayerId, forHTTPHeaderField: "X-Player-Id")
        }
    }
}

/// Alle Backend-Anfragen der App: mit Login, Token-Erneuerung und Rückfall zum Login bei 401.
nonisolated enum API {
    static func data(from url: URL) async throws -> (Data, URLResponse) {
        try await data(for: URLRequest(url: url))
    }

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let session = AuthSession.shared
        await session.refreshIfNeeded()
        var authorized = request
        session.authorize(&authorized)
        let (data, response) = try await URLSession.shared.data(for: authorized)

        guard (response as? HTTPURLResponse)?.statusCode == 401, session.currentToken != nil else {
            return (data, response)
        }
        // Token abgelaufen oder widerrufen: einmal erneuern und wiederholen
        if await session.refreshIfNeeded(force: true) {
            var retry = request
            session.authorize(&retry)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retry)
            if (retryResponse as? HTTPURLResponse)?.statusCode != 401 {
                return (retryData, retryResponse)
            }
        }
        await MainActor.run { NotificationCenter.default.post(name: .authExpired, object: nil) }
        return (data, response)
    }
}
