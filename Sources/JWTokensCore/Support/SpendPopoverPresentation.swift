import Foundation

public enum SpendPopoverMode: String, CaseIterable, Identifiable, Sendable {
    case overview
    case trends
    case breakdown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .overview:
            return "Overview"
        case .trends:
            return "Trends"
        case .breakdown:
            return "Breakdown"
        }
    }
}

public struct SpendPopoverPresentation: Equatable, Sendable {
    public struct DetailRow: Equatable, Identifiable, Sendable {
        public let label: String
        public let value: String

        public var id: String { label }
    }

    public let primaryGauge: RingProgressPresentation
    public let rangeName: String
    public let totalText: String
    public let percentText: String
    public let limitText: String
    public let overLimitText: String?
    public let refreshedText: String
    public let detailRows: [DetailRow]
    public let statusText: String?
    public let showsKeyUpdateAction: Bool
    public let menuBarMetric: MenuBarMetric

    public static func make(
        range: SpendRange,
        snapshot: SpendSnapshot?,
        errorMessage: String?,
        requiresSetup: Bool,
        menuBarMetric: MenuBarMetric = .dollars,
        calendar: Calendar = .current
    ) -> SpendPopoverPresentation {
        let total = snapshot?.totalSpendUSD ?? 0
        let limit = snapshot?.limitUSD ?? 80
        let overLimit = total > limit
        let analyticsRows = analyticsDetailRows(for: snapshot?.analytics)
        return SpendPopoverPresentation(
            primaryGauge: RingProgressPresentation.make(
                snapshot: snapshot,
                metric: .dollars,
                rangeName: range.longDisplayName,
                requiresSetup: requiresSetup
            ),
            rangeName: range.longDisplayName,
            totalText: MenuBarTitleFormatter.currency(total),
            percentText: MenuBarTitleFormatter.percent(snapshot?.percentOfLimit ?? 0),
            limitText: "Limit \(MenuBarTitleFormatter.currency(limit))",
            overLimitText: overLimit ? "\(MenuBarTitleFormatter.currency(total - limit)) over limit" : nil,
            refreshedText: refreshedText(for: snapshot?.refreshedAt, calendar: calendar),
            detailRows: [
                DetailRow(label: "Spend", value: MenuBarTitleFormatter.currency(total)),
                DetailRow(label: "Usage", value: MenuBarTitleFormatter.percent(snapshot?.percentOfLimit ?? 0)),
                DetailRow(label: "Limit", value: MenuBarTitleFormatter.currency(limit)),
                DetailRow(label: "Updated", value: refreshedText(for: snapshot?.refreshedAt, calendar: calendar).replacingOccurrences(of: "Updated ", with: ""))
            ] + analyticsRows,
            statusText: errorMessage,
            showsKeyUpdateAction: requiresSetup,
            menuBarMetric: menuBarMetric
        )
    }

    private static func refreshedText(for date: Date?, calendar: Calendar) -> String {
        guard let date else {
            return "Not refreshed"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        return "Updated \(formatter.string(from: date))"
    }

    private static func analyticsDetailRows(for analytics: SpendAnalyticsSummary?) -> [DetailRow] {
        guard let analytics else {
            return []
        }

        return [
            DetailRow(label: "Tokens", value: integerText(analytics.totals.totalTokens)),
            DetailRow(
                label: "Requests",
                value: "\(integerText(analytics.totals.apiRequests)) (\(integerText(analytics.totals.successfulRequests)) ok, \(integerText(analytics.totals.failedRequests)) fail)"
            ),
            DetailRow(label: "Source", value: analytics.source.displayName)
        ]
    }

    private static func integerText(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

public extension SpendDataSource {
    var displayName: String {
        switch self {
        case .userDailyActivity:
            return "Daily activity"
        case .spendLogsFallback:
            return "Spend logs fallback"
        case .staleCache:
            return "Stale cache"
        }
    }
}

public extension SpendRange {
    var longDisplayName: String {
        switch self {
        case .today:
            return "Today"
        case .last7Days:
            return "Last 7 days"
        case .last30Days:
            return "Last 30 days"
        case .monthToDate:
            return "Month to date"
        case .yearToDate:
            return "Year to date"
        }
    }
}
