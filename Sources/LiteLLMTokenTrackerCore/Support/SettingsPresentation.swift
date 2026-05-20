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
        credentialSource: String = "Local file",
        lastError: String? = nil
    ) -> SettingsPresentation {
        let diagnostics = DiagnosticSummary.make(
            baseURLText: baseURLText,
            snapshot: snapshot,
            credentialSource: credentialSource,
            lastError: lastError
        )
        return SettingsPresentation(
            baseURLText: baseURLText,
            spendLimitText: spendLimitText,
            diagnosticRows: diagnostics.rows.map { Row(label: $0.label, value: $0.value) },
            warningText: "Local file credential storage is a local-development exception. Company builds should use Keychain or managed storage.",
            errorText: settingsError
        )
    }
}

public struct DiagnosticSummary: Equatable, Sendable {
    public struct Row: Equatable, Identifiable, Sendable {
        public let label: String
        public let value: String

        public var id: String { label }
    }

    public let rows: [Row]

    public static func make(
        baseURLText: String,
        snapshot: SpendSnapshot?,
        credentialSource: String = "Local file",
        lastError: String? = nil,
        includeCredentialPath: Bool = false
    ) -> DiagnosticSummary {
        var rows = [
            Row(label: "Credential", value: credentialSource),
            Row(label: "Credential path", value: includeCredentialPath ? "Configured locally" : "Hidden by default"),
            Row(label: "Endpoint", value: baseURLText.isEmpty ? "Not configured" : redactedEndpoint(baseURLText)),
            Row(label: "Source", value: snapshot?.analytics?.source.displayName ?? "Not refreshed")
        ]
        if let userID = snapshot?.userContext?.userID, !userID.isEmpty {
            rows.append(Row(label: "User", value: redacted(userID)))
        }
        if let lastError, !lastError.isEmpty {
            rows.append(Row(label: "Last error", value: redacted(lastError)))
        }
        return DiagnosticSummary(rows: rows)
    }

    private static func redacted(_ value: String) -> String {
        var redactedValue = value.replacingOccurrences(of: "secret-token", with: "[redacted]")
        redactedValue = redactedValue.replacingOccurrences(
            of: #"Bearer\s+[A-Za-z0-9._\-]+"#,
            with: "Bearer [redacted]",
            options: .regularExpression
        )
        redactedValue = redactedValue.replacingOccurrences(
            of: #"sk-[A-Za-z0-9._\-]+"#,
            with: "[redacted]",
            options: .regularExpression
        )
        return redactedValue
    }

    private static func redactedEndpoint(_ value: String) -> String {
        guard let url = URL(string: value), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return redacted(value)
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return redacted(components.string ?? value)
    }
}
