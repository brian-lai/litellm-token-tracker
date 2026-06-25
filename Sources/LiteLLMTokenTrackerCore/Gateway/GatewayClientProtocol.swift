import Foundation

public enum GatewayClientError: Error, Equatable {
    case notImplemented
    case unauthorized
    case forbidden
    case insufficientScope
    case unavailable
    case malformedResponse
}

public struct GatewayUserContext: Equatable, Sendable {
    public let userID: String?
    public let email: String?
    public let totalSpendUSD: Decimal?
    public let maxBudgetUSD: Decimal?
    public let budgetResetAt: Date?
    public let virtualKeyID: String?
    public let virtualKeyName: String?

    public init(
        userID: String? = nil,
        email: String? = nil,
        totalSpendUSD: Decimal? = nil,
        maxBudgetUSD: Decimal? = nil,
        budgetResetAt: Date? = nil,
        virtualKeyID: String? = nil,
        virtualKeyName: String? = nil
    ) {
        self.userID = userID
        self.email = email
        self.totalSpendUSD = totalSpendUSD
        self.maxBudgetUSD = maxBudgetUSD
        self.budgetResetAt = budgetResetAt
        self.virtualKeyID = virtualKeyID
        self.virtualKeyName = virtualKeyName
    }
}

public protocol GatewayClientProtocol: Sendable {
    func fetchCurrentUserContext() async throws -> GatewayUserContext
    func fetchSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary
    func fetchFallbackSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary
    func fetchSpendRows(range: DateRange, userContext: GatewayUserContext?) async throws -> [SpendLogSummaryRow]
    func fetchCurrentKeyContext(userContext: GatewayUserContext?) async throws -> KeySpendSummary
    func fetchOwnedKeyContexts(userContext: GatewayUserContext?) async throws -> [KeySpendSummary]
}

public extension GatewayClientProtocol {
    func fetchFallbackSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary {
        let rows = try await fetchSpendRows(range: range, userContext: userContext)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = range.timeZone
        let groupedRows = Dictionary(grouping: rows) { row in
            calendar.startOfDay(for: row.date)
        }
        let dailyPoints = groupedRows
            .map { date, rows in
                DailyActivityPoint(
                    date: date,
                    spendUSD: rows.reduce(Decimal(0)) { $0 + $1.spendUSD },
                    totals: .zero
                )
            }
            .sorted { $0.date < $1.date }
        return SpendAnalyticsSummary(
            totalSpendUSD: dailyPoints.reduce(Decimal(0)) { $0 + $1.spendUSD },
            totals: .zero,
            dailyPoints: dailyPoints,
            breakdowns: [:],
            source: .spendLogsFallback
        )
    }
}

public extension GatewayUserContext {
    init(liteLLMUserContext: LiteLLMUserContext) {
        self.init(
            userID: liteLLMUserContext.userID,
            email: liteLLMUserContext.email,
            totalSpendUSD: liteLLMUserContext.totalSpendUSD,
            maxBudgetUSD: liteLLMUserContext.maxBudgetUSD,
            budgetResetAt: liteLLMUserContext.budgetResetAt,
            virtualKeyID: nil,
            virtualKeyName: nil
        )
    }

    var liteLLMUserContext: LiteLLMUserContext? {
        guard let userID else {
            return nil
        }
        return LiteLLMUserContext(
            userID: userID,
            email: email,
            totalSpendUSD: totalSpendUSD ?? 0,
            maxBudgetUSD: maxBudgetUSD,
            budgetResetAt: budgetResetAt
        )
    }
}
