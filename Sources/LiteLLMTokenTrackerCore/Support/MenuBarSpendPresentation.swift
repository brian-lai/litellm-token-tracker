import Foundation

public enum MenuBarMetric: String, CaseIterable, Sendable {
    case dollars
    case percent

    public var displayName: String {
        switch self {
        case .dollars:
            return "Dollars"
        case .percent:
            return "Percent"
        }
    }
}

public struct SpendStatusBand: Equatable, Sendable {
    public let id: String
    public let accessibleName: String
    public let swiftUIColorName: String

    public static let green = SpendStatusBand(id: "green", accessibleName: "green", swiftUIColorName: "green")
    public static let yellow = SpendStatusBand(id: "yellow", accessibleName: "yellow", swiftUIColorName: "yellow")
    public static let orange = SpendStatusBand(id: "orange", accessibleName: "orange", swiftUIColorName: "orange")
    public static let red = SpendStatusBand(id: "red", accessibleName: "red", swiftUIColorName: "red")

    public static func band(for percentOfLimit: Decimal) -> SpendStatusBand {
        if percentOfLimit < Decimal(string: "0.5")! {
            return .green
        }
        if percentOfLimit < Decimal(string: "0.75")! {
            return .yellow
        }
        if percentOfLimit < Decimal(string: "0.9")! {
            return .orange
        }
        return .red
    }
}

public struct RingProgressPresentation: Equatable, Sendable {
    public let progress: Double
    public let band: SpendStatusBand
    public let label: String
    public let accessibilityLabel: String

    public static func make(snapshot: SpendSnapshot?, metric: MenuBarMetric, rangeName: String, requiresSetup: Bool) -> RingProgressPresentation {
        if requiresSetup {
            return RingProgressPresentation(
                progress: 0,
                band: .green,
                label: MenuBarTitleFormatter.setupTitle(),
                accessibilityLabel: "LiteLLM configuration required"
            )
        }
        guard let snapshot else {
            return RingProgressPresentation(
                progress: 0,
                band: .green,
                label: label(totalSpendUSD: 0, percentOfLimit: 0, metric: metric),
                accessibilityLabel: "\(rangeName) spend unavailable, green band"
            )
        }
        let band = SpendStatusBand.band(for: snapshot.percentOfLimit)
        let progress = min(1, max(0, (snapshot.percentOfLimit as NSDecimalNumber).doubleValue))
        let label = label(totalSpendUSD: snapshot.totalSpendUSD, percentOfLimit: snapshot.percentOfLimit, metric: metric)
        let staleText = snapshot.isStale ? ", stale" : ""
        return RingProgressPresentation(
            progress: progress,
            band: band,
            label: label,
            accessibilityLabel: "\(rangeName) spend \(label), \(MenuBarTitleFormatter.percent(snapshot.percentOfLimit)) of limit, \(band.accessibleName) band\(staleText)"
        )
    }

    private static func label(totalSpendUSD: Decimal, percentOfLimit: Decimal, metric: MenuBarMetric) -> String {
        switch metric {
        case .dollars:
            return MenuBarTitleFormatter.compactCurrency(totalSpendUSD)
        case .percent:
            return MenuBarTitleFormatter.percent(percentOfLimit)
        }
    }
}

public struct MenuBarSpendPresentation: Equatable, Sendable {
    public let progress: Double
    public let band: SpendStatusBand
    public let label: String
    public let metric: MenuBarMetric
    public let setupTitle: String?
    public let accessibilityLabel: String

    public static func make(menuBarSnapshot: SpendSnapshot?, requiresSetup: Bool, metric: MenuBarMetric) -> MenuBarSpendPresentation {
        let ring = RingProgressPresentation.make(
            snapshot: menuBarSnapshot,
            metric: metric,
            rangeName: SpendRange.today.longDisplayName,
            requiresSetup: requiresSetup
        )
        return MenuBarSpendPresentation(
            progress: ring.progress,
            band: ring.band,
            label: ring.label,
            metric: metric,
            setupTitle: requiresSetup ? MenuBarTitleFormatter.setupTitle() : nil,
            accessibilityLabel: ring.accessibilityLabel
        )
    }
}
