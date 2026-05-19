import Foundation

public enum SpendRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case last7Days
    case last30Days
    case monthToDate
    case yearToDate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .today:
            return "Today"
        case .last7Days:
            return "7D"
        case .last30Days:
            return "30D"
        case .monthToDate:
            return "MTD"
        case .yearToDate:
            return "YTD"
        }
    }
}

public struct DateRange: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let timeZone: TimeZone

    public init(startDate: Date, endDate: Date, timeZone: TimeZone = .current) {
        self.startDate = startDate
        self.endDate = endDate
        self.timeZone = timeZone
    }
}

public struct DailySpendPoint: Equatable, Identifiable, Sendable {
    public let date: Date
    public let spendUSD: Decimal

    public var id: Date { date }

    public init(date: Date, spendUSD: Decimal) {
        self.date = date
        self.spendUSD = spendUSD
    }
}

public struct SpendLogSummaryRow: Equatable, Identifiable, Sendable {
    public let date: Date
    public let spendUSD: Decimal

    public var id: Date { date }

    public init(date: Date, spendUSD: Decimal) {
        self.date = date
        self.spendUSD = spendUSD
    }
}

public struct SpendActivitySummary: Equatable, Sendable {
    public let totalSpendUSD: Decimal
    public let dailyPoints: [DailySpendPoint]

    public init(totalSpendUSD: Decimal, dailyPoints: [DailySpendPoint]) {
        self.totalSpendUSD = totalSpendUSD
        self.dailyPoints = dailyPoints
    }
}

public struct SpendUsageTotals: Equatable, Sendable {
    public static let zero = SpendUsageTotals(
        totalTokens: 0,
        promptTokens: 0,
        completionTokens: 0,
        cacheCreationTokens: 0,
        cacheReadTokens: 0,
        apiRequests: 0,
        successfulRequests: 0,
        failedRequests: 0
    )

    public let totalTokens: Int
    public let promptTokens: Int
    public let completionTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let apiRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int

    public init(
        totalTokens: Int,
        promptTokens: Int,
        completionTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        apiRequests: Int,
        successfulRequests: Int,
        failedRequests: Int
    ) {
        self.totalTokens = totalTokens
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.apiRequests = apiRequests
        self.successfulRequests = successfulRequests
        self.failedRequests = failedRequests
    }
}

public struct DailyActivityPoint: Equatable, Identifiable, Sendable {
    public let date: Date
    public let spendUSD: Decimal
    public let totals: SpendUsageTotals

    public var id: Date { date }

    public init(date: Date, spendUSD: Decimal, totals: SpendUsageTotals) {
        self.date = date
        self.spendUSD = spendUSD
        self.totals = totals
    }

    public var spendPoint: DailySpendPoint {
        DailySpendPoint(date: date, spendUSD: spendUSD)
    }
}

public enum SpendBreakdownCategory: String, CaseIterable, Sendable {
    case models
    case providers
    case modelGroups
    case endpoints
    case mcpServers
    case apiKeys
}

public struct SpendBreakdownItem: Equatable, Sendable {
    public let label: String
    public let spendUSD: Decimal
    public let tokens: Int?
    public let requests: Int?

    public init(label: String, spendUSD: Decimal, tokens: Int?, requests: Int?) {
        self.label = label
        self.spendUSD = spendUSD
        self.tokens = tokens
        self.requests = requests
    }
}

public enum SpendDataSource: String, Equatable, Sendable {
    case userDailyActivity
    case spendLogsFallback
    case staleCache
}

public struct SpendAnalyticsSummary: Equatable, Sendable {
    public let totalSpendUSD: Decimal
    public let totals: SpendUsageTotals
    public let dailyPoints: [DailyActivityPoint]
    public let breakdowns: [SpendBreakdownCategory: [SpendBreakdownItem]]
    public let source: SpendDataSource

    public init(
        totalSpendUSD: Decimal,
        totals: SpendUsageTotals,
        dailyPoints: [DailyActivityPoint],
        breakdowns: [SpendBreakdownCategory: [SpendBreakdownItem]],
        source: SpendDataSource
    ) {
        self.totalSpendUSD = totalSpendUSD
        self.totals = totals
        self.dailyPoints = dailyPoints
        self.breakdowns = breakdowns
        self.source = source
    }

    public var activitySummary: SpendActivitySummary {
        SpendActivitySummary(totalSpendUSD: totalSpendUSD, dailyPoints: dailyPoints.map(\.spendPoint))
    }

    public func markingSource(_ source: SpendDataSource) -> SpendAnalyticsSummary {
        SpendAnalyticsSummary(
            totalSpendUSD: totalSpendUSD,
            totals: totals,
            dailyPoints: dailyPoints,
            breakdowns: breakdowns,
            source: source
        )
    }
}

public struct SpendSnapshot: Equatable, Sendable {
    public let range: SpendRange
    public let totalSpendUSD: Decimal
    public let limitUSD: Decimal
    public let percentOfLimit: Decimal
    public let dailyPoints: [DailySpendPoint]
    public let refreshedAt: Date
    public let isStale: Bool
    public let analytics: SpendAnalyticsSummary?
    public let userContext: LiteLLMUserContext?

    public init(
        range: SpendRange,
        totalSpendUSD: Decimal,
        limitUSD: Decimal,
        percentOfLimit: Decimal,
        dailyPoints: [DailySpendPoint],
        refreshedAt: Date,
        isStale: Bool,
        analytics: SpendAnalyticsSummary? = nil,
        userContext: LiteLLMUserContext? = nil
    ) {
        self.range = range
        self.totalSpendUSD = totalSpendUSD
        self.limitUSD = limitUSD
        self.percentOfLimit = percentOfLimit
        self.dailyPoints = dailyPoints
        self.refreshedAt = refreshedAt
        self.isStale = isStale
        self.analytics = analytics
        self.userContext = userContext
    }

    public func markingStale() -> SpendSnapshot {
        SpendSnapshot(
            range: range,
            totalSpendUSD: totalSpendUSD,
            limitUSD: limitUSD,
            percentOfLimit: percentOfLimit,
            dailyPoints: dailyPoints,
            refreshedAt: refreshedAt,
            isStale: true,
            analytics: analytics?.markingSource(.staleCache),
            userContext: userContext
        )
    }

    public func applyingLimit(_ limitUSD: Decimal) -> SpendSnapshot {
        SpendSnapshot(
            range: range,
            totalSpendUSD: totalSpendUSD,
            limitUSD: limitUSD,
            percentOfLimit: limitUSD == 0 ? 0 : totalSpendUSD / limitUSD,
            dailyPoints: dailyPoints,
            refreshedAt: refreshedAt,
            isStale: isStale,
            analytics: analytics,
            userContext: userContext
        )
    }
}

public enum SpendAggregator {
    public static func snapshot(
        activity: SpendActivitySummary,
        range: SpendRange,
        limitUSD: Decimal,
        refreshedAt: Date,
        isStale: Bool = false
    ) -> SpendSnapshot {
        let percent = limitUSD == 0 ? 0 : activity.totalSpendUSD / limitUSD
        return SpendSnapshot(
            range: range,
            totalSpendUSD: activity.totalSpendUSD,
            limitUSD: limitUSD,
            percentOfLimit: percent,
            dailyPoints: activity.dailyPoints.sorted { $0.date < $1.date },
            refreshedAt: refreshedAt,
            isStale: isStale
        )
    }

    public static func snapshot(
        analytics: SpendAnalyticsSummary,
        range: SpendRange,
        limitUSD: Decimal,
        refreshedAt: Date,
        isStale: Bool = false,
        userContext: LiteLLMUserContext? = nil
    ) -> SpendSnapshot {
        let percent = limitUSD == 0 ? 0 : analytics.totalSpendUSD / limitUSD
        return SpendSnapshot(
            range: range,
            totalSpendUSD: analytics.totalSpendUSD,
            limitUSD: limitUSD,
            percentOfLimit: percent,
            dailyPoints: analytics.dailyPoints.map(\.spendPoint).sorted { $0.date < $1.date },
            refreshedAt: refreshedAt,
            isStale: isStale,
            analytics: analytics,
            userContext: userContext
        )
    }

    public static func snapshot(
        rows: [SpendLogSummaryRow],
        range: SpendRange,
        dateRange: DateRange,
        limitUSD: Decimal,
        refreshedAt: Date,
        isStale: Bool = false
    ) -> SpendSnapshot {
        let filteredRows = rows.filter { row in
            row.date >= dateRange.startDate && row.date < dateRange.endDate
        }

        var grouped: [Date: Decimal] = [:]
        for row in filteredRows {
            grouped[row.date, default: 0] += row.spendUSD
        }

        let dailyPoints = grouped
            .map { DailySpendPoint(date: $0.key, spendUSD: $0.value) }
            .sorted { $0.date < $1.date }
        let total = dailyPoints.reduce(Decimal(0)) { $0 + $1.spendUSD }
        let percent = limitUSD == 0 ? 0 : total / limitUSD

        return SpendSnapshot(
            range: range,
            totalSpendUSD: total,
            limitUSD: limitUSD,
            percentOfLimit: percent,
            dailyPoints: dailyPoints,
            refreshedAt: refreshedAt,
            isStale: isStale
        )
    }
}

public enum SpendRefreshResult: Equatable, Sendable {
    case refreshed(SpendSnapshot)
    case stale(SpendSnapshot, message: String)
    case setupRequired(message: String)
    case authFailed(message: String)
    case failed(message: String)
}

public struct LiteLLMUserContext: Equatable, Sendable {
    public let userID: String
    public let email: String?
    public let totalSpendUSD: Decimal
    public let maxBudgetUSD: Decimal?
    public let budgetResetAt: Date?

    public init(userID: String, email: String?, totalSpendUSD: Decimal, maxBudgetUSD: Decimal?, budgetResetAt: Date?) {
        self.userID = userID
        self.email = email
        self.totalSpendUSD = totalSpendUSD
        self.maxBudgetUSD = maxBudgetUSD
        self.budgetResetAt = budgetResetAt
    }
}

public struct KeySpendSummary: Equatable, Sendable {
    public let alias: String?
    public let name: String?
    public let spendUSD: Decimal
    public let maxBudgetUSD: Decimal?
    public let budgetResetAt: Date?
    public let lastActiveAt: Date?

    public init(alias: String?, name: String?, spendUSD: Decimal, maxBudgetUSD: Decimal?, budgetResetAt: Date?, lastActiveAt: Date?) {
        self.alias = alias
        self.name = name
        self.spendUSD = spendUSD
        self.maxBudgetUSD = maxBudgetUSD
        self.budgetResetAt = budgetResetAt
        self.lastActiveAt = lastActiveAt
    }

    public var displayName: String {
        if let alias, !alias.isEmpty {
            return alias
        }
        if let name, !name.isEmpty {
            return name
        }
        return "Unnamed key"
    }
}

public protocol SpendServicing: Sendable {
    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult
}

public protocol DateRangeResolving: Sendable {
    func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange
}

public struct SpendRangeResolver: DateRangeResolving {
    public init() {}

    public func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        switch range {
        case .today:
            return DateRange(startDate: today, endDate: tomorrow, timeZone: calendar.timeZone)
        case .last7Days:
            return DateRange(startDate: calendar.date(byAdding: .day, value: -6, to: today)!, endDate: tomorrow, timeZone: calendar.timeZone)
        case .last30Days:
            return DateRange(startDate: calendar.date(byAdding: .day, value: -29, to: today)!, endDate: tomorrow, timeZone: calendar.timeZone)
        case .monthToDate:
            let components = calendar.dateComponents([.year, .month], from: today)
            return DateRange(startDate: calendar.date(from: components)!, endDate: tomorrow, timeZone: calendar.timeZone)
        case .yearToDate:
            let components = calendar.dateComponents([.year], from: today)
            return DateRange(startDate: calendar.date(from: components)!, endDate: tomorrow, timeZone: calendar.timeZone)
        }
    }
}
