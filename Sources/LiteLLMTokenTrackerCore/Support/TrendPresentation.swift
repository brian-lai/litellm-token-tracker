import Foundation

public struct TrendPresentation: Equatable, Sendable {
    public static let maximumRenderedDays = 45

    public struct Day: Equatable, Identifiable, Sendable {
        public let date: Date
        public let dateText: String
        public let amountText: String
        public let tokenText: String
        public let requestText: String
        public let heightRatio: Double

        public var id: Date { date }
    }

    public let totalText: String
    public let tokenSummary: String
    public let requestSummary: String
    public let days: [Day]
    public let isEmpty: Bool
    public let accessibilityLabel: String

    public static func make(analytics: SpendAnalyticsSummary?, calendar: Calendar = .current) -> TrendPresentation {
        guard let analytics, !analytics.dailyPoints.isEmpty else {
            return TrendPresentation(
                totalText: "$0.00",
                tokenSummary: "0 tokens",
                requestSummary: "0 requests",
                days: [],
                isEmpty: true,
                accessibilityLabel: "Spend trend, no daily activity"
            )
        }

        let sourcePoints = bucketedPoints(analytics.dailyPoints)
        let maxSpend = sourcePoints.map(\.spendUSD).max() ?? 0
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = sourcePoints.count > 14 ? "M/d" : "EEE M/d"

        let days = sourcePoints.map { point in
            Day(
                date: point.date,
                dateText: formatter.string(from: point.date),
                amountText: MenuBarTitleFormatter.currency(point.spendUSD),
                tokenText: "\(integerText(point.totals.totalTokens)) tokens",
                requestText: "\(integerText(point.totals.apiRequests)) requests",
                heightRatio: maxSpend == 0 ? 0 : (point.spendUSD as NSDecimalNumber).doubleValue / (maxSpend as NSDecimalNumber).doubleValue
            )
        }

        return TrendPresentation(
            totalText: MenuBarTitleFormatter.currency(analytics.totalSpendUSD),
            tokenSummary: "\(integerText(analytics.totals.totalTokens)) tokens",
            requestSummary: "\(integerText(analytics.totals.apiRequests)) requests",
            days: days,
            isEmpty: false,
            accessibilityLabel: "Spend trend, \(analytics.dailyPoints.count) days, total \(MenuBarTitleFormatter.currency(analytics.totalSpendUSD))"
        )
    }

    private static func bucketedPoints(_ points: [DailyActivityPoint]) -> [DailyActivityPoint] {
        guard points.count > maximumRenderedDays else {
            return points
        }

        let bucketSize = Int(ceil(Double(points.count) / Double(maximumRenderedDays)))
        return stride(from: 0, to: points.count, by: bucketSize).map { start in
            let bucket = Array(points[start..<min(start + bucketSize, points.count)])
            let totalSpend = bucket.reduce(Decimal(0)) { $0 + $1.spendUSD }
            let totals = bucket.reduce(SpendUsageTotals.zero) { partial, point in
                partial.adding(point.totals)
            }
            return DailyActivityPoint(date: bucket.first?.date ?? points[start].date, spendUSD: totalSpend, totals: totals)
        }
    }

    private static func integerText(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private extension SpendUsageTotals {
    func adding(_ other: SpendUsageTotals) -> SpendUsageTotals {
        SpendUsageTotals(
            totalTokens: totalTokens + other.totalTokens,
            promptTokens: promptTokens + other.promptTokens,
            completionTokens: completionTokens + other.completionTokens,
            cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
            cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
            apiRequests: apiRequests + other.apiRequests,
            successfulRequests: successfulRequests + other.successfulRequests,
            failedRequests: failedRequests + other.failedRequests
        )
    }
}
