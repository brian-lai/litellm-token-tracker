import Foundation
import JWTokensCore

enum JWTokensPreviewFixtures {
    @MainActor
    static func makeViewModelFromArguments(_ arguments: [String] = CommandLine.arguments) -> SpendDashboardViewModel? {
        guard let state = previewState(from: arguments) else {
            return nil
        }
        return SpendDashboardViewModel(
            spendService: PreviewSpendService(state: state),
            menuBarPreferenceStore: UserDefaultsMenuBarPreferenceStore(defaults: previewDefaults(metric: metric(from: arguments)))
        )
    }

    private static func previewState(from arguments: [String]) -> PreviewSpendService.State? {
        guard let index = arguments.firstIndex(of: "--preview-state"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return PreviewSpendService.State(rawValue: arguments[index + 1])
    }

    private static func metric(from arguments: [String]) -> MenuBarMetric {
        guard let index = arguments.firstIndex(of: "--preview-metric"),
              arguments.indices.contains(index + 1),
              let metric = MenuBarMetric(rawValue: arguments[index + 1]) else {
            return .dollars
        }
        return metric
    }

    private static func previewDefaults(metric: MenuBarMetric) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "net.justworks.litellm-token-tracker.preview")!
        defaults.set(metric.rawValue, forKey: UserDefaultsMenuBarPreferenceStore.metricKey)
        return defaults
    }
}

struct PreviewSpendService: SpendServicing {
    enum State: String {
        case normal
        case setup
        case stale
        case authError = "auth_error"
        case overLimit = "over_limit"
        case emptyChart = "empty_chart"
        case longModelNames = "long_model_names"
        case fallbackSource = "fallback_source"
    }

    let state: State

    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult {
        switch state {
        case .normal:
            return .refreshed(snapshot(range: range, total: Decimal(string: "33.42")!, now: now, calendar: calendar))
        case .setup:
            return .setupRequired(message: "LiteLLM API key is missing")
        case .stale:
            return .stale(snapshot(range: range, total: 22, now: now, calendar: calendar, isStale: true), message: "Showing last known spend")
        case .authError:
            return .authFailed(message: "LiteLLM API key was rejected")
        case .overLimit:
            return .refreshed(snapshot(range: range, total: 96, now: now, calendar: calendar))
        case .emptyChart:
            return .refreshed(SpendSnapshot(
                range: range,
                totalSpendUSD: 0,
                limitUSD: 80,
                percentOfLimit: 0,
                dailyPoints: [],
                refreshedAt: now,
                isStale: false
            ))
        case .longModelNames:
            let analytics = SpendAnalyticsPreviewFixture.longModelNames(now: now, calendar: calendar)
            return .refreshed(snapshot(range: range, total: analytics.totalSpendUSD, now: now, calendar: calendar, analytics: analytics))
        case .fallbackSource:
            let analytics = SpendAnalyticsPreviewFixture.fallbackSource(now: now, calendar: calendar)
            return .refreshed(snapshot(range: range, total: analytics.totalSpendUSD, now: now, calendar: calendar, analytics: analytics))
        }
    }

    private func snapshot(range: SpendRange, total: Decimal, now: Date, calendar: Calendar, isStale: Bool = false, analytics: SpendAnalyticsSummary? = nil) -> SpendSnapshot {
        let resolvedAnalytics = analytics ?? SpendAnalyticsPreviewFixture.advanced(now: now, calendar: calendar)
        return SpendSnapshot(
            range: range,
            totalSpendUSD: total,
            limitUSD: 80,
            percentOfLimit: total / 80,
            dailyPoints: resolvedAnalytics.dailyPoints.map(\.spendPoint),
            refreshedAt: now,
            isStale: isStale,
            analytics: resolvedAnalytics
        )
    }
}
