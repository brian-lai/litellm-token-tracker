import Foundation

public enum SpendAnalyticsPreviewFixture {
    public static func advanced(now: Date, calendar: Calendar = .current) -> SpendAnalyticsSummary {
        SpendAnalyticsSummary(
            totalSpendUSD: Decimal(string: "33.42")!,
            totals: SpendUsageTotals(
                totalTokens: 183_420,
                promptTokens: 72_000,
                completionTokens: 111_420,
                cacheCreationTokens: 4_000,
                cacheReadTokens: 24_500,
                apiRequests: 42,
                successfulRequests: 40,
                failedRequests: 2
            ),
            dailyPoints: previewPoints(now: now, calendar: calendar),
            breakdowns: [.models: [
                SpendBreakdownItem(label: "claude-sonnet", spendUSD: Decimal(string: "21.32")!, tokens: 122_400, requests: 24),
                SpendBreakdownItem(label: "gpt-4.1", spendUSD: Decimal(string: "8.10")!, tokens: 41_000, requests: 12),
                SpendBreakdownItem(label: "claude-haiku", spendUSD: 4, tokens: 20_020, requests: 6)
            ]],
            source: .userDailyActivity
        )
    }

    public static func longModelNames(now: Date, calendar: Calendar = .current) -> SpendAnalyticsSummary {
        SpendAnalyticsSummary(
            totalSpendUSD: 44,
            totals: SpendUsageTotals(totalTokens: 210_000, promptTokens: 100_000, completionTokens: 110_000, cacheCreationTokens: 0, cacheReadTokens: 0, apiRequests: 31, successfulRequests: 30, failedRequests: 1),
            dailyPoints: previewPoints(now: now, calendar: calendar),
            breakdowns: [.models: [
                SpendBreakdownItem(label: "anthropic/claude-sonnet-4-20250514-very-long-routing-label", spendUSD: 30, tokens: 155_000, requests: 20),
                SpendBreakdownItem(label: "openai/gpt-4.1-mini-production-west-long-context", spendUSD: 14, tokens: 55_000, requests: 11)
            ]],
            source: .userDailyActivity
        )
    }

    public static func fallbackSource(now: Date, calendar: Calendar = .current) -> SpendAnalyticsSummary {
        SpendAnalyticsSummary(
            totalSpendUSD: 22,
            totals: .zero,
            dailyPoints: previewPoints(now: now, calendar: calendar).map {
                DailyActivityPoint(date: $0.date, spendUSD: $0.spendUSD / 2, totals: .zero)
            },
            breakdowns: [:],
            source: .spendLogsFallback
        )
    }

    private static func previewPoints(now: Date, calendar: Calendar) -> [DailyActivityPoint] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) ?? today
            let spend = Decimal(offset + 1) * Decimal(string: "1.75")!
            return DailyActivityPoint(
                date: date,
                spendUSD: spend,
                totals: SpendUsageTotals(
                    totalTokens: (offset + 1) * 4_000,
                    promptTokens: (offset + 1) * 1_500,
                    completionTokens: (offset + 1) * 2_500,
                    cacheCreationTokens: 0,
                    cacheReadTokens: (offset + 1) * 400,
                    apiRequests: offset + 2,
                    successfulRequests: offset + 2,
                    failedRequests: 0
                )
            )
        }
    }
}
