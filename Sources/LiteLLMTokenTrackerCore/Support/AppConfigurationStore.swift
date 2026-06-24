import Foundation

public struct AppConfiguration: Equatable, Sendable {
    public let baseURL: URL?
    public let spendLimitUSD: Decimal
    public let gatewayProvider: GatewayProvider

    public init(baseURL: URL? = nil, spendLimitUSD: Decimal = 80, gatewayProvider: GatewayProvider = .litellm) {
        self.baseURL = baseURL
        self.spendLimitUSD = spendLimitUSD
        self.gatewayProvider = gatewayProvider
    }
}

public protocol AppConfigurationStoring: Sendable {
    func loadConfiguration() throws -> AppConfiguration
}

public protocol MutableAppConfigurationStoring: AppConfigurationStoring {
    func saveConfiguration(_ configuration: AppConfiguration) throws
}

public struct StaticAppConfigurationStore: AppConfigurationStoring {
    private let configuration: AppConfiguration

    public init(configuration: AppConfiguration = AppConfiguration(baseURL: URL(string: "https://litellm.example.internal")!)) {
        self.configuration = configuration
    }

    public func loadConfiguration() throws -> AppConfiguration {
        configuration
    }
}

public struct LocalAppConfigurationStore: MutableAppConfigurationStoring {
    public let fileURL: URL
    public let legacyFileURL: URL
    private let defaults: AppConfiguration
    private let environment: EnvironmentValueProviding
    private let environmentKey: String

    public init(
        fileURL: URL = LocalAppConfigurationStore.defaultFileURL(),
        legacyFileURL: URL = LocalAppConfigurationStore.legacyFileURL(),
        defaults: AppConfiguration = AppConfiguration(),
        environment: EnvironmentValueProviding = ProcessEnvironmentProvider(),
        environmentKey: String = "LITELLM_BASE_URL"
    ) {
        self.fileURL = fileURL
        self.legacyFileURL = legacyFileURL
        self.defaults = defaults
        self.environment = environment
        self.environmentKey = environmentKey
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("litellm_token_tracker", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    public static func legacyFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("litellm_token_tracker", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    public func loadConfiguration() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if FileManager.default.fileExists(atPath: legacyFileURL.path) {
                let legacyConfiguration = try loadConfiguration(from: legacyFileURL)
                try saveConfiguration(legacyConfiguration)
                return legacyConfiguration
            }
            if let environmentConfiguration = configurationFromEnvironment() {
                try saveConfiguration(environmentConfiguration)
                return environmentConfiguration
            }
            return defaults
        }
        return try loadConfiguration(from: fileURL)
    }

    private func loadConfiguration(from url: URL) throws -> AppConfiguration {
        do {
            let data = try Data(contentsOf: url)
            let stored = try JSONDecoder().decode(StoredConfiguration.self, from: data)
            let configuration = AppConfiguration(
                baseURL: stored.validBaseURL ?? defaults.baseURL,
                spendLimitUSD: stored.validSpendLimit ?? defaults.spendLimitUSD,
                gatewayProvider: stored.validGatewayProvider ?? defaults.gatewayProvider
            )
            if stored.needsNormalization(comparedTo: configuration) {
                try saveConfiguration(configuration)
            }
            return configuration
        } catch let error as AppConfigurationStoreError {
            throw error
        } catch {
            return defaults
        }
    }

    public func saveConfiguration(_ configuration: AppConfiguration) throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let stored = StoredConfiguration(
                baseURL: configuration.baseURL?.normalizedForConfiguration?.absoluteString,
                spendLimitUSD: NSDecimalNumber(decimal: configuration.spendLimitUSD).stringValue,
                gatewayProvider: configuration.gatewayProvider.rawValue
            )
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            throw AppConfigurationStoreError.unavailable
        }
    }

    private func configurationFromEnvironment() -> AppConfiguration? {
        guard let value = environment.value(for: environmentKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let baseURL = URL(string: value)?.normalizedForConfiguration else {
            return nil
        }
        return AppConfiguration(baseURL: baseURL, spendLimitUSD: defaults.spendLimitUSD, gatewayProvider: defaults.gatewayProvider)
    }
}

public enum AppConfigurationStoreError: Error, Equatable {
    case unavailable
}

private struct StoredConfiguration: Codable {
    let baseURL: String?
    let spendLimitUSD: String?
    let gatewayProvider: String?

    var validBaseURL: URL? {
        guard let baseURL, let url = URL(string: baseURL), let normalizedURL = url.normalizedForConfiguration else {
            return nil
        }
        return normalizedURL
    }

    var validSpendLimit: Decimal? {
        guard let spendLimitUSD, let value = Decimal(string: spendLimitUSD), value > 0 else {
            return nil
        }
        return value
    }

    var validGatewayProvider: GatewayProvider? {
        guard let gatewayProvider else {
            return nil
        }
        return GatewayProvider(rawValue: gatewayProvider)
    }

    func needsNormalization(comparedTo configuration: AppConfiguration) -> Bool {
        baseURL != configuration.baseURL?.absoluteString ||
            spendLimitUSD != NSDecimalNumber(decimal: configuration.spendLimitUSD).stringValue ||
            gatewayProvider != configuration.gatewayProvider.rawValue
    }
}

public extension URL {
    var isHTTPURL: Bool {
        guard let scheme = scheme?.lowercased(), host != nil else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    var normalizedForConfiguration: URL? {
        guard isHTTPURL, var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
