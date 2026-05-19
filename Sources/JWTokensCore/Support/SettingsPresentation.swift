import Foundation

public struct SettingsPresentation: Equatable, Sendable {
    public struct Row: Equatable, Identifiable, Sendable {
        public let label: String
        public let value: String

        public var id: String { label }
    }

    public let baseURLText: String
    public let spendLimitText: String
    public let diagnosticRows: [Row]
    public let warningText: String
    public let errorText: String?

    public static func make(
        baseURLText: String,
        spendLimitText: String,
        snapshot: SpendSnapshot?,
        settingsError: String?,
        credentialSource: String = "Local file"
    ) -> SettingsPresentation {
        var rows = [
            Row(label: "Credential", value: credentialSource),
            Row(label: "Credential path", value: "Hidden by default"),
            Row(label: "Base URL", value: baseURLText.isEmpty ? AppConfiguration().baseURL.absoluteString : baseURLText),
            Row(label: "Source", value: snapshot?.analytics?.source.displayName ?? "Not refreshed")
        ]
        if let userID = snapshot?.userContext?.userID, !userID.isEmpty {
            rows.append(Row(label: "User", value: userID))
        }

        return SettingsPresentation(
            baseURLText: baseURLText,
            spendLimitText: spendLimitText,
            diagnosticRows: rows,
            warningText: "Local file credential storage is a local-development exception. Company builds should use Keychain or managed storage.",
            errorText: settingsError
        )
    }
}
