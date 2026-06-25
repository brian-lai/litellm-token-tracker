import Foundation

public struct KeyContextSnapshot: Equatable, Sendable {
    public let currentKey: KeySpendSummary?
    public let ownedKeys: [KeySpendSummary]
    public let ownedKeysUnavailableMessage: String?
    public let refreshedAt: Date
    public let isStale: Bool

    public init(currentKey: KeySpendSummary?, ownedKeys: [KeySpendSummary], ownedKeysUnavailableMessage: String? = nil, refreshedAt: Date, isStale: Bool) {
        self.currentKey = currentKey
        self.ownedKeys = ownedKeys
        self.ownedKeysUnavailableMessage = ownedKeysUnavailableMessage
        self.refreshedAt = refreshedAt
        self.isStale = isStale
    }

    public func markingStale() -> KeyContextSnapshot {
        KeyContextSnapshot(currentKey: currentKey, ownedKeys: ownedKeys, ownedKeysUnavailableMessage: ownedKeysUnavailableMessage, refreshedAt: refreshedAt, isStale: true)
    }
}

public enum KeyContextResult: Equatable, Sendable {
    case refreshed(KeyContextSnapshot)
    case stale(KeyContextSnapshot, message: String)
    case authFailed(message: String)
    case failed(message: String)
}

public protocol KeyContextServicing: Sendable {
    func refresh(userContext: LiteLLMUserContext?, now: Date, bypassingCache: Bool) async -> KeyContextResult
    func clearCache()
}

public extension KeyContextServicing {
    func refresh(userContext: LiteLLMUserContext?, now: Date) async -> KeyContextResult {
        await refresh(userContext: userContext, now: now, bypassingCache: false)
    }
}

public final class KeyContextService: KeyContextServicing, @unchecked Sendable {
    private let apiKeyStore: APIKeyStoring
    private let configurationStore: AppConfigurationStoring
    private let clientFactory: @Sendable (GatewayProvider, URL, String) -> GatewayClientProtocol
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
        self.clientFactory = { _, baseURL, apiKey in clientFactory(baseURL, apiKey) }
        self.cacheTTL = cacheTTL
    }

    public init(
        apiKeyStore: APIKeyStoring,
        configurationStore: AppConfigurationStoring = StaticAppConfigurationStore(),
        gatewayClientFactory: @escaping @Sendable (GatewayProvider, URL, String) -> GatewayClientProtocol,
        cacheTTL: TimeInterval = 300
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.clientFactory = gatewayClientFactory
        self.cacheTTL = cacheTTL
    }

    public func refresh(userContext: LiteLLMUserContext?, now: Date, bypassingCache: Bool = false) async -> KeyContextResult {
        var currentScope: String?
        do {
            let apiKey = try apiKeyStore.readAPIKey()
            let configuration = try configurationStore.loadConfiguration()
            guard let baseURL = configuration.baseURL else {
                return .failed(message: "\(configuration.gatewayProvider.displayName) base URL is missing")
            }
            let scope = cacheScope(baseURL: baseURL, apiKey: apiKey, gatewayProvider: configuration.gatewayProvider)
            currentScope = scope
            if !bypassingCache, let cached = loadFreshCache(now: now, scope: scope) {
                return .refreshed(cached)
            }
            let client = clientFactory(configuration.gatewayProvider, baseURL, apiKey)
            let user = try await resolvedUserContext(userContext, client: client, scope: scope)
            let currentKey = try await client.fetchCurrentKeyContext(userContext: user)
            let ownedResult = await ownedKeyResult(client: client, user: user, provider: configuration.gatewayProvider)
            let snapshot = KeyContextSnapshot(
                currentKey: currentKey,
                ownedKeys: ownedResult.keys,
                ownedKeysUnavailableMessage: ownedResult.message,
                refreshedAt: now,
                isStale: false
            )
            if let liteLLMUserContext = user.liteLLMUserContext {
                save(snapshot: snapshot, userContext: liteLLMUserContext, scope: scope)
            } else {
                save(snapshot: snapshot, userContext: nil, scope: scope)
            }
            return .refreshed(snapshot)
        } catch LiteLLMClientError.unauthorized, GatewayClientError.unauthorized {
            clearCache()
            return .authFailed(message: "\(activeProviderName(currentScope: currentScope)) key context was rejected")
        } catch {
            if let currentScope, let stale = loadAnyCache(scope: currentScope) {
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

    private func resolvedUserContext(_ userContext: LiteLLMUserContext?, client: GatewayClientProtocol, scope: String) async throws -> GatewayUserContext {
        if let userContext {
            return GatewayUserContext(liteLLMUserContext: userContext)
        }
        if let cached = loadCachedUserContext(scope: scope) {
            return GatewayUserContext(liteLLMUserContext: cached)
        }
        return try await client.fetchCurrentUserContext()
    }

    private func ownedKeyResult(client: GatewayClientProtocol, user: GatewayUserContext, provider: GatewayProvider) async -> (keys: [KeySpendSummary], message: String?) {
        do {
            return (try await client.fetchOwnedKeyContexts(userContext: user), nil)
        } catch {
            if provider == .bifrost, isOwnedKeyScopeError(error) {
                return ([], "Bifrost owned keys require management API scope")
            }
            return ([], nil)
        }
    }

    private func isOwnedKeyScopeError(_ error: Error) -> Bool {
        switch error {
        case GatewayClientError.unauthorized, GatewayClientError.forbidden, GatewayClientError.insufficientScope:
            return true
        default:
            return false
        }
    }

    private func activeProviderName(currentScope: String?) -> String {
        guard let currentScope else { return "LiteLLM" }
        return currentScope.hasPrefix("\(GatewayProvider.bifrost.rawValue)|") ? "Bifrost" : "LiteLLM"
    }

    private func loadFreshCache(now: Date, scope: String) -> KeyContextSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let cachedSnapshot, cachedScope == scope, now.timeIntervalSince(cachedSnapshot.refreshedAt) < cacheTTL else {
            return nil
        }
        return cachedSnapshot
    }

    private func loadAnyCache(scope: String) -> KeyContextSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard cachedScope == scope else {
            return nil
        }
        return cachedSnapshot
    }

    private func loadCachedUserContext(scope: String) -> LiteLLMUserContext? {
        lock.lock()
        defer { lock.unlock() }
        guard cachedScope == scope else {
            return nil
        }
        return cachedUserContext
    }

    private func save(snapshot: KeyContextSnapshot, userContext: LiteLLMUserContext?, scope: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedSnapshot = snapshot
        cachedUserContext = userContext
        cachedScope = scope
    }

    private func cacheScope(baseURL: URL, apiKey: String, gatewayProvider: GatewayProvider) -> String {
        "\(gatewayProvider.rawValue)|\(baseURL.absoluteString)|\(apiKey.hashValue)"
    }
}
