import Foundation

public protocol MenuBarPreferenceStoring: Sendable {
    func loadMetric() throws -> MenuBarMetric
    func saveMetric(_ metric: MenuBarMetric) throws
}

public final class UserDefaultsMenuBarPreferenceStore: MenuBarPreferenceStoring, @unchecked Sendable {
    public static let metricKey = "app.litellm-token-tracker.menuBarMetric"
    public static let legacyMetricKey = "app.litellm-token-tracker.legacy.menuBarMetric"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadMetric() throws -> MenuBarMetric {
        guard let rawValue = defaults.string(forKey: Self.metricKey),
              let metric = MenuBarMetric(rawValue: rawValue) else {
            if let legacyRawValue = defaults.string(forKey: Self.legacyMetricKey),
               let legacyMetric = MenuBarMetric(rawValue: legacyRawValue) {
                defaults.set(legacyMetric.rawValue, forKey: Self.metricKey)
                defaults.removeObject(forKey: Self.legacyMetricKey)
                return legacyMetric
            }
            return .dollars
        }
        return metric
    }

    public func saveMetric(_ metric: MenuBarMetric) throws {
        defaults.set(metric.rawValue, forKey: Self.metricKey)
    }
}
