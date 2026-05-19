import Foundation

public protocol MenuBarPreferenceStoring: Sendable {
    func loadMetric() throws -> MenuBarMetric
    func saveMetric(_ metric: MenuBarMetric) throws
}

public final class UserDefaultsMenuBarPreferenceStore: MenuBarPreferenceStoring, @unchecked Sendable {
    public static let metricKey = "net.justworks.jw-tokens.menuBarMetric"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadMetric() throws -> MenuBarMetric {
        guard let rawValue = defaults.string(forKey: Self.metricKey),
              let metric = MenuBarMetric(rawValue: rawValue) else {
            return .dollars
        }
        return metric
    }

    public func saveMetric(_ metric: MenuBarMetric) throws {
        defaults.set(metric.rawValue, forKey: Self.metricKey)
    }
}
