import Foundation

public struct KeyBudgetPresentation: Equatable, Sendable {
    public struct KeyRow: Equatable, Identifiable, Sendable {
        public let name: String
        public let spendText: String
        public let budgetText: String?
        public let lastActiveText: String?

        public var id: String { name }
    }

    public let currentKeyName: String
    public let currentKeySpendText: String
    public let currentKeyBudgetText: String?
    public let currentKeyResetText: String?
    public let ownedKeys: [KeyRow]
    public let statusText: String?
    public let isEmpty: Bool

    public static func make(snapshot: KeyContextSnapshot?, errorMessage: String?, calendar: Calendar = .current) -> KeyBudgetPresentation {
        guard let snapshot else {
            return KeyBudgetPresentation(
                currentKeyName: "No current key",
                currentKeySpendText: "$0.00",
                currentKeyBudgetText: nil,
                currentKeyResetText: nil,
                ownedKeys: [],
                statusText: errorMessage,
                isEmpty: true
            )
        }

        let currentKey = snapshot.currentKey
        return KeyBudgetPresentation(
            currentKeyName: currentKey?.displayName ?? "No current key",
            currentKeySpendText: MenuBarTitleFormatter.currency(currentKey?.spendUSD ?? 0),
            currentKeyBudgetText: budgetText(for: currentKey),
            currentKeyResetText: resetText(for: currentKey?.budgetResetAt, calendar: calendar),
            ownedKeys: snapshot.ownedKeys
                .sorted { $0.spendUSD > $1.spendUSD }
                .map { key in
                    KeyRow(
                        name: key.displayName,
                        spendText: MenuBarTitleFormatter.currency(key.spendUSD),
                        budgetText: budgetText(for: key),
                        lastActiveText: lastActiveText(for: key.lastActiveAt, calendar: calendar)
                    )
                },
            statusText: errorMessage ?? (snapshot.isStale ? "Showing last known key context" : nil),
            isEmpty: currentKey == nil && snapshot.ownedKeys.isEmpty
        )
    }

    private static func budgetText(for key: KeySpendSummary?) -> String? {
        guard let key, let maxBudget = key.maxBudgetUSD else {
            return nil
        }
        return "\(MenuBarTitleFormatter.currency(key.spendUSD)) of \(MenuBarTitleFormatter.currency(maxBudget))"
    }

    private static func resetText(for date: Date?, calendar: Calendar) -> String? {
        guard let date else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return "Resets \(formatter.string(from: date))"
    }

    private static func lastActiveText(for date: Date?, calendar: Calendar) -> String? {
        guard let date else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return "Active \(formatter.string(from: date))"
    }
}
