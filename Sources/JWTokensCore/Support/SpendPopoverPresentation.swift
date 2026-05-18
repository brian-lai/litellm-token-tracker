import Foundation

public struct SpendPopoverPresentation: Equatable, Sendable {
    public let rangeName: String
    public let totalText: String
    public let percentText: String
    public let refreshedText: String
    public let statusText: String?
    public let showsKeyUpdateAction: Bool

    public static func make(
        range: SpendRange,
        snapshot: SpendSnapshot?,
        errorMessage: String?,
        requiresSetup: Bool,
        calendar: Calendar = .current
    ) -> SpendPopoverPresentation {
        SpendPopoverPresentation(
            rangeName: range.longDisplayName,
            totalText: MenuBarTitleFormatter.currency(snapshot?.totalSpendUSD ?? 0),
            percentText: MenuBarTitleFormatter.percent(snapshot?.percentOfLimit ?? 0),
            refreshedText: refreshedText(for: snapshot?.refreshedAt, calendar: calendar),
            statusText: errorMessage,
            showsKeyUpdateAction: requiresSetup
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
