import Foundation

public struct SpendService: SpendServicing {
    private let apiKeyStore: APIKeyStoring
    private let configurationStore: AppConfigurationStoring
    private let clientFactory: @Sendable (URL, String) -> LiteLLMClientProtocol
    private let rangeResolver: DateRangeResolving
    private let cache: SpendSnapshotCaching

    public init(
        apiKeyStore: APIKeyStoring,
        configurationStore: AppConfigurationStoring = StaticAppConfigurationStore(),
        clientFactory: @escaping @Sendable (URL, String) -> LiteLLMClientProtocol,
        rangeResolver: DateRangeResolving = SpendRangeResolver(),
        cache: SpendSnapshotCaching = InMemorySpendSnapshotCache()
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.clientFactory = clientFactory
        self.rangeResolver = rangeResolver
        self.cache = cache
    }

    public func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult {
        do {
            let apiKey = try apiKeyStore.readAPIKey()
            let configuration = try configurationStore.loadConfiguration()
            let client = clientFactory(configuration.baseURL, apiKey)
            let user = try await client.fetchCurrentUser()
            let dateRange = rangeResolver.dateRange(for: range, now: now, calendar: calendar)
            let rows = try await client.fetchSpendRows(range: dateRange, userID: user.userID)
            let snapshot = SpendAggregator.snapshot(
                rows: rows,
                range: range,
                dateRange: dateRange,
                limitUSD: configuration.spendLimitUSD,
                refreshedAt: now
            )
            try? cache.saveSnapshot(snapshot)
            return .refreshed(snapshot)
        } catch APIKeyStoreError.missingKey {
            return .setupRequired(message: "LiteLLM API key is missing")
        } catch LiteLLMClientError.unauthorized {
            return .authFailed(message: "LiteLLM API key was rejected")
        } catch {
            if let stale = try? cache.loadSnapshot(for: range) {
                return .stale(stale, message: "Showing last known spend")
            }
            return .failed(message: "Unable to refresh spend")
        }
    }
}
