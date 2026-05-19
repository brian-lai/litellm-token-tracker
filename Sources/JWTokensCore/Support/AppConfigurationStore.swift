import Foundation

public struct AppConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let spendLimitUSD: Decimal

    public init(baseURL: URL = URL(string: "https://litellm.justworksai.net")!, spendLimitUSD: Decimal = 80) {
        self.baseURL = baseURL
        self.spendLimitUSD = spendLimitUSD
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

    public init(configuration: AppConfiguration = AppConfiguration()) {
        self.configuration = configuration
    }

    public func loadConfiguration() throws -> AppConfiguration {
        configuration
    }
}

public struct LocalAppConfigurationStore: MutableAppConfigurationStoring {
    public let fileURL: URL
    private let defaults: AppConfiguration

    public init(fileURL: URL = LocalAppConfigurationStore.defaultFileURL(), defaults: AppConfiguration = AppConfiguration()) {
        self.fileURL = fileURL
        self.defaults = defaults
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("jw_tokens", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    public func loadConfiguration() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return defaults
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try JSONDecoder().decode(StoredConfiguration.self, from: data)
            return AppConfiguration(
                baseURL: stored.validBaseURL ?? defaults.baseURL,
                spendLimitUSD: stored.validSpendLimit ?? defaults.spendLimitUSD
            )
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
                baseURL: configuration.baseURL.normalizedForConfiguration?.absoluteString ?? defaults.baseURL.absoluteString,
                spendLimitUSD: NSDecimalNumber(decimal: configuration.spendLimitUSD).stringValue
            )
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            throw AppConfigurationStoreError.unavailable
        }
    }
}

public enum AppConfigurationStoreError: Error, Equatable {
    case unavailable
}

private struct StoredConfiguration: Codable {
    let baseURL: String?
    let spendLimitUSD: String?

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
