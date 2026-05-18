import Foundation

public enum SpendRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case last7Days
    case last30Days
    case monthToDate
    case yearToDate

    public var id: String { rawValue }
}

public struct DateRange: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date

    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
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

public struct SpendSnapshot: Equatable, Sendable {
    public let range: SpendRange
    public let totalSpendUSD: Decimal
    public let limitUSD: Decimal
    public let percentOfLimit: Decimal
    public let dailyPoints: [DailySpendPoint]
    public let refreshedAt: Date
    public let isStale: Bool

    public init(range: SpendRange, totalSpendUSD: Decimal, limitUSD: Decimal, percentOfLimit: Decimal, dailyPoints: [DailySpendPoint], refreshedAt: Date, isStale: Bool) {
        self.range = range
        self.totalSpendUSD = totalSpendUSD
        self.limitUSD = limitUSD
        self.percentOfLimit = percentOfLimit
        self.dailyPoints = dailyPoints
        self.refreshedAt = refreshedAt
        self.isStale = isStale
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

public protocol SpendServicing: Sendable {
    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult
}

public protocol DateRangeResolving: Sendable {
    func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange
}

public struct SpendRangeResolver: DateRangeResolving {
    public init() {}

    public func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange {
        DateRange(startDate: now, endDate: now)
    }
}
