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

    public func markingStale() -> SpendSnapshot {
        SpendSnapshot(
            range: range,
            totalSpendUSD: totalSpendUSD,
            limitUSD: limitUSD,
            percentOfLimit: percentOfLimit,
            dailyPoints: dailyPoints,
            refreshedAt: refreshedAt,
            isStale: true
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
