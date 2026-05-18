import Foundation

public enum MenuBarTitleFormatter {
    public static func title(for snapshot: SpendSnapshot?) -> String {
        guard let snapshot else {
            return "$0.00 (0%)"
        }
        return "\(currency(snapshot.totalSpendUSD)) (\(percent(snapshot.percentOfLimit)))"
    }

    public static func setupTitle() -> String {
        "Set API Key"
    }

    public static func currency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    public static func percent(_ value: Decimal) -> String {
        let percent = (value as NSDecimalNumber).multiplying(by: 100).doubleValue
        return "\(Int(percent.rounded()))%"
    }
}
