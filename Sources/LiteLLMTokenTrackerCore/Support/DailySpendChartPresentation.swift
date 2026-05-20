import Foundation

public struct DailySpendChartPresentation: Equatable, Sendable {
    public struct Bar: Equatable, Identifiable, Sendable {
        public let id: Date
        public let date: Date
        public let amountText: String
        public let heightRatio: Double
    }

    public let bars: [Bar]
    public let isEmpty: Bool
    public let accessibilityLabel: String

    public static func make(points: [DailySpendPoint]) -> DailySpendChartPresentation {
        let maxSpend = points.map(\.spendUSD).max() ?? 0
        let bars = points.map { point in
            let ratio: Double
            if maxSpend == 0 {
                ratio = 0
            } else {
                ratio = min(1, max(0, (point.spendUSD as NSDecimalNumber).doubleValue / (maxSpend as NSDecimalNumber).doubleValue))
            }
            return Bar(
                id: point.date,
                date: point.date,
                amountText: MenuBarTitleFormatter.currency(point.spendUSD),
                heightRatio: ratio
            )
        }
        let total = points.reduce(Decimal(0)) { $0 + $1.spendUSD }
        let label = bars.isEmpty
            ? "Daily spend chart, no daily spend"
            : "Daily spend chart, \(bars.count) days, total \(MenuBarTitleFormatter.currency(total))"
        return DailySpendChartPresentation(bars: bars, isEmpty: bars.isEmpty, accessibilityLabel: label)
    }
}
