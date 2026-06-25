import Foundation

public struct SpendService: SpendServicing {
    private let apiKeyStore: APIKeyStoring
    private let configurationStore: AppConfigurationStoring
    private let clientFactory: @Sendable (GatewayProvider, URL, String) -> GatewayClientProtocol
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
        self.clientFactory = { _, baseURL, apiKey in clientFactory(baseURL, apiKey) }
        self.rangeResolver = rangeResolver
        self.cache = cache
    }

    public init(
        apiKeyStore: APIKeyStoring,
        configurationStore: AppConfigurationStoring = StaticAppConfigurationStore(),
        gatewayClientFactory: @escaping @Sendable (GatewayProvider, URL, String) -> GatewayClientProtocol,
        rangeResolver: DateRangeResolving = SpendRangeResolver(),
        cache: SpendSnapshotCaching = InMemorySpendSnapshotCache()
    ) {
        self.apiKeyStore = apiKeyStore
        self.configurationStore = configurationStore
        self.clientFactory = gatewayClientFactory
        self.rangeResolver = rangeResolver
        self.cache = cache
    }

    public func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult {
        var currentScope: String?
        do {
            let apiKey = try apiKeyStore.readAPIKey()
            let configuration = try configurationStore.loadConfiguration()
            guard let baseURL = configuration.baseURL else {
                return .setupRequired(message: "LiteLLM base URL is missing")
            }
            let scope = cacheScope(baseURL: baseURL, apiKey: apiKey, gatewayProvider: configuration.gatewayProvider)
            currentScope = scope
            let client = clientFactory(configuration.gatewayProvider, baseURL, apiKey)
            let gatewayUser = try await client.fetchCurrentUserContext()
            let user = gatewayUser.liteLLMUserContext
            let dateRange = rangeResolver.dateRange(for: range, now: now, calendar: calendar)
            let rangeBudgetUSD = budgetForRange(
                dailyBudgetUSD: configuration.spendLimitUSD,
                dateRange: dateRange,
                calendar: calendar
            )
            let snapshot: SpendSnapshot
            do {
                let analytics = try await client.fetchSpendAnalytics(range: dateRange, userContext: gatewayUser)
                snapshot = SpendAggregator.snapshot(
                    analytics: analytics,
                    range: range,
                    limitUSD: rangeBudgetUSD,
                    refreshedAt: now,
                    userContext: user
                )
            } catch {
                let rows = try await client.fetchSpendRows(range: dateRange, userContext: gatewayUser)
                let fallbackSnapshot = SpendAggregator.snapshot(
                    rows: rows,
                    range: range,
                    dateRange: dateRange,
                    limitUSD: rangeBudgetUSD,
                    refreshedAt: now
                )
                let analytics = SpendAnalyticsSummary(
                    totalSpendUSD: fallbackSnapshot.totalSpendUSD,
                    totals: .zero,
                    dailyPoints: fallbackSnapshot.dailyPoints.map {
                        DailyActivityPoint(date: $0.date, spendUSD: $0.spendUSD, totals: .zero)
                    },
                    breakdowns: [:],
                    source: .spendLogsFallback
                )
                snapshot = SpendSnapshot(
                    range: fallbackSnapshot.range,
                    totalSpendUSD: fallbackSnapshot.totalSpendUSD,
                    limitUSD: fallbackSnapshot.limitUSD,
                    percentOfLimit: fallbackSnapshot.percentOfLimit,
                    dailyPoints: fallbackSnapshot.dailyPoints,
                    refreshedAt: fallbackSnapshot.refreshedAt,
                    isStale: fallbackSnapshot.isStale,
                    analytics: analytics,
                    userContext: user
                )
            }
            try? cache.saveSnapshot(snapshot, scope: scope)
            return .refreshed(snapshot)
        } catch APIKeyStoreError.missingKey {
            return .setupRequired(message: "LiteLLM API key is missing")
        } catch LiteLLMClientError.unauthorized, GatewayClientError.unauthorized {
            return .authFailed(message: "LiteLLM API key was rejected")
        } catch {
            if let currentScope, let stale = try? cache.loadSnapshot(for: range, scope: currentScope) {
                return .stale(stale.markingStale(), message: "Showing last known spend")
            }
            return .failed(message: "Unable to refresh spend")
        }
    }

    public func clearCache() {
        cache.clearSnapshots()
    }

    private func cacheScope(baseURL: URL, apiKey: String, gatewayProvider: GatewayProvider) -> String {
        "\(gatewayProvider.rawValue)|\(baseURL.absoluteString)|\(apiKey.hashValue)"
    }

    private func budgetForRange(dailyBudgetUSD: Decimal, dateRange: DateRange, calendar: Calendar) -> Decimal {
        let start = calendar.startOfDay(for: dateRange.startDate)
        let end = calendar.startOfDay(for: dateRange.endDate)
        let dayDelta = calendar.dateComponents([.day], from: start, to: end).day ?? 1
        let dayCount = max(1, dayDelta)
        return dailyBudgetUSD * Decimal(dayCount)
    }
}
