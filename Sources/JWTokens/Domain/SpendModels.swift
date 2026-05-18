import Foundation

enum SpendRange: String, CaseIterable, Identifiable, Sendable {
    case today
    case last7Days
    case last30Days
    case monthToDate
    case yearToDate

    var id: String { rawValue }
}

struct DateRange: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
}

struct DailySpendPoint: Equatable, Identifiable, Sendable {
    let date: Date
    let spendUSD: Decimal

    var id: Date { date }
}

struct SpendLogSummaryRow: Equatable, Identifiable, Sendable {
    let date: Date
    let spendUSD: Decimal

    var id: Date { date }
}

struct SpendSnapshot: Equatable, Sendable {
    let range: SpendRange
    let totalSpendUSD: Decimal
    let limitUSD: Decimal
    let percentOfLimit: Decimal
    let dailyPoints: [DailySpendPoint]
    let refreshedAt: Date
    let isStale: Bool
}

enum SpendRefreshResult: Equatable, Sendable {
    case refreshed(SpendSnapshot)
    case stale(SpendSnapshot, message: String)
    case setupRequired(message: String)
    case authFailed(message: String)
    case failed(message: String)
}

struct LiteLLMUserContext: Equatable, Sendable {
    let userID: String
    let email: String?
    let totalSpendUSD: Decimal
    let maxBudgetUSD: Decimal?
    let budgetResetAt: Date?
}

protocol SpendServicing: Sendable {
    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult
}

protocol DateRangeResolving: Sendable {
    func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange
}

struct SpendRangeResolver: DateRangeResolving {
    func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange {
        DateRange(startDate: now, endDate: now)
    }
}
