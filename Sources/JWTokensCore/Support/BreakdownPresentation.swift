import Foundation

public struct BreakdownPresentation: Equatable, Sendable {
    public struct Row: Equatable, Identifiable, Sendable {
        public let label: String
        public let spendText: String
        public let percentText: String
        public let tokenText: String?
        public let requestText: String?
        public let share: Double

        public var id: String { label }
    }

    public let title: String
    public let rows: [Row]
    public let isEmpty: Bool
    public let emptyText: String
    public let accessibilityLabel: String

    public static func make(analytics: SpendAnalyticsSummary?) -> BreakdownPresentation {
        let items = analytics?.breakdowns[.models] ?? []
        guard !items.isEmpty else {
            return BreakdownPresentation(
                title: "Models",
                rows: [],
                isEmpty: true,
                emptyText: "No model breakdown available",
                accessibilityLabel: "Model breakdown, no data available"
            )
        }

        let sortedItems = items.sorted { $0.spendUSD > $1.spendUSD }
        let total = sortedItems.reduce(Decimal(0)) { $0 + $1.spendUSD }
        let rows = sortedItems.map { item in
            let shareDecimal = total == 0 ? Decimal(0) : item.spendUSD / total
            let share = (shareDecimal as NSDecimalNumber).doubleValue
            return Row(
                label: item.label,
                spendText: MenuBarTitleFormatter.currency(item.spendUSD),
                percentText: MenuBarTitleFormatter.percent(shareDecimal),
                tokenText: item.tokens.map { "\(integerText($0)) tokens" },
                requestText: item.requests.map { "\(integerText($0)) requests" },
                share: share
            )
        }

        return BreakdownPresentation(
            title: "Models",
            rows: rows,
            isEmpty: false,
            emptyText: "",
            accessibilityLabel: "Model breakdown, \(rows.count) models"
        )
    }

    private static func integerText(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
