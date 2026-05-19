import Foundation

public struct SpendPopoverPresentation: Equatable, Sendable {
    public let primaryGauge: RingProgressPresentation
    public let rangeName: String
    public let totalText: String
    public let percentText: String
    public let limitText: String
    public let overLimitText: String?
    public let refreshedText: String
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
