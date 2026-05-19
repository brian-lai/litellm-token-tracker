import Foundation

public struct KeyContextSnapshot: Equatable, Sendable {
    public let currentKey: KeySpendSummary?
    public let ownedKeys: [KeySpendSummary]
    public let refreshedAt: Date
    public let isStale: Bool

    public init(currentKey: KeySpendSummary?, ownedKeys: [KeySpendSummary], refreshedAt: Date, isStale: Bool) {
        self.currentKey = currentKey
        self.ownedKeys = ownedKeys
        self.refreshedAt = refreshedAt
        self.isStale = isStale
    }

    public func markingStale() -> KeyContextSnapshot {
        KeyContextSnapshot(currentKey: currentKey, ownedKeys: ownedKeys, refreshedAt: refreshedAt, isStale: true)
    }
}

public enum KeyContextResult: Equatable, Sendable {
    case refreshed(KeyContextSnapshot)
    case stale(KeyContextSnapshot, message: String)
    case authFailed(message: String)
    case failed(message: String)
}

public protocol KeyContextServicing: Sendable {
    func refresh(userContext: LiteLLMUserContext?, now: Date) async -> KeyContextResult
    func clearCache()
}

public final class KeyContextService: KeyContextServicing, @unchecked Sendable {
    private let apiKeyStore: APIKeyStoring
    private let configurationStore: AppConfigurationStoring
    private let clientFactory: @Sendable (URL, String) -> LiteLLMClientProtocol
    private let cacheTTL: TimeInterval
    private let lock = NSLock()
    private var cachedSnapshot: KeyContextSnapshot?
    private var cachedUserContext: LiteLLMUserContext?
    private var cachedScope: String?

    public init(
        apiKeyStore: APIKeyStoring,
        configurationStore: AppConfigurationStoring = StaticAppConfigurationStore(),
        clientFactory: @escaping @Sendable (URL, String) -> LiteLLMClientProtocol,
        cacheTTL: TimeInterval = 300
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.clientFactory = clientFactory
        self.cacheTTL = cacheTTL
    }

    public func refresh(userContext: LiteLLMUserContext?, now: Date) async -> KeyContextResult {
        do {
            let apiKey = try apiKeyStore.readAPIKey()
            let configuration = try configurationStore.loadConfiguration()
            let scope = cacheScope(baseURL: configuration.baseURL, apiKey: apiKey)
            if let cached = loadFreshCache(now: now, scope: scope) {
                return .refreshed(cached)
            }
            let client = clientFactory(configuration.baseURL, apiKey)
            let user = try await resolvedUserContext(userContext, client: client)
            let currentKey = try await client.fetchCurrentKey()
            let ownedKeys = try await client.fetchUserKeys(userID: user.userID)
            let snapshot = KeyContextSnapshot(currentKey: currentKey, ownedKeys: ownedKeys, refreshedAt: now, isStale: false)
            save(snapshot: snapshot, userContext: user, scope: scope)
            return .refreshed(snapshot)
        } catch LiteLLMClientError.unauthorized {
            return .authFailed(message: "LiteLLM key context was rejected")
        } catch {
            if let stale = loadAnyCache() {
                return .stale(stale.markingStale(), message: "Showing last known key context")
            }
            return .failed(message: "Unable to load key context")
        }
    }

    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedSnapshot = nil
        cachedUserContext = nil
        cachedScope = nil
    }

    private func resolvedUserContext(_ userContext: LiteLLMUserContext?, client: LiteLLMClientProtocol) async throws -> LiteLLMUserContext {
        if let userContext {
            return userContext
        }
        if let cached = loadCachedUserContext() {
            return cached
        }
        return try await client.fetchCurrentUser()
    }

    private func loadFreshCache(now: Date, scope: String) -> KeyContextSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let cachedSnapshot, cachedScope == scope, now.timeIntervalSince(cachedSnapshot.refreshedAt) < cacheTTL else {
            return nil
        }
        return cachedSnapshot
    }

    private func loadAnyCache() -> KeyContextSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSnapshot
    }

    private func loadCachedUserContext() -> LiteLLMUserContext? {
        lock.lock()
        defer { lock.unlock() }
        return cachedUserContext
    }

    private func save(snapshot: KeyContextSnapshot, userContext: LiteLLMUserContext, scope: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedSnapshot = snapshot
        cachedUserContext = userContext
        cachedScope = scope
    }

    private func cacheScope(baseURL: URL, apiKey: String) -> String {
        "\(baseURL.absoluteString)|\(apiKey.hashValue)"
    }
}
