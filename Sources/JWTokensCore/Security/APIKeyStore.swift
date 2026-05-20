import Foundation

public enum APIKeyStoreError: Error, Equatable {
    case notImplemented
    case missingKey
    case unavailable
}

extension APIKeyStoreError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notImplemented:
            "API key store is not implemented"
        case .missingKey:
            "LiteLLM API key is missing"
        case .unavailable:
            "API key store is unavailable"
        }
    }
}

public protocol APIKeyStoring: Sendable {
    func readAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

public protocol EnvironmentValueProviding: Sendable {
    func value(for key: String) -> String?
}

public struct ProcessEnvironmentProvider: EnvironmentValueProviding {
    public init() {}

    public func value(for key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}

public struct KeychainAPIKeyStore: APIKeyStoring {
    public let service: String
    public let account: String
    private let gateway: KeychainGateway

    public init(service: String = "net.justworks.litellm-token-tracker", account: String = "litellm-api-key", gateway: KeychainGateway = SecItemKeychainGateway()) {
        self.service = service
        self.account = account
        self.gateway = gateway
    }

    public func readAPIKey() throws -> String {
        guard let key = try gateway.read(service: service, account: account), !key.isEmpty else {
            throw APIKeyStoreError.missingKey
        }
        return key
    }

    public func saveAPIKey(_ apiKey: String) throws {
        try gateway.save(apiKey, service: service, account: account)
    }

    public func deleteAPIKey() throws {
        try gateway.delete(service: service, account: account)
    }
}

public struct LocalFileAPIKeyStore: APIKeyStoring {
    public let fileURL: URL
    public let legacyFileURL: URL

    public init(
        fileURL: URL = LocalFileAPIKeyStore.defaultFileURL(),
        legacyFileURL: URL = LocalFileAPIKeyStore.legacyFileURL()
    ) {
        self.fileURL = fileURL
        self.legacyFileURL = legacyFileURL
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("litellm_token_tracker", isDirectory: true)
            .appendingPathComponent("litellm_api_key", isDirectory: false)
    }

    public static func legacyFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("jw_tokens", isDirectory: true)
            .appendingPathComponent("litellm_api_key", isDirectory: false)
    }

    public func readAPIKey() throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if FileManager.default.fileExists(atPath: legacyFileURL.path) {
                let legacyValue = try readAPIKey(from: legacyFileURL)
                try saveAPIKey(legacyValue)
                return legacyValue
            }
            throw APIKeyStoreError.missingKey
        }
        return try readAPIKey(from: fileURL)
    }

    private func readAPIKey(from url: URL) throws -> String {
        do {
            let value = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                throw APIKeyStoreError.missingKey
            }
            return value
        } catch let error as APIKeyStoreError {
            throw error
        } catch {
            throw APIKeyStoreError.unavailable
        }
    }

    public func saveAPIKey(_ apiKey: String) throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try Data(apiKey.utf8).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            throw APIKeyStoreError.unavailable
        }
    }

    public func deleteAPIKey() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw APIKeyStoreError.unavailable
        }
    }
}

public struct EnvironmentFallbackAPIKeyStore: APIKeyStoring {
    public let primary: APIKeyStoring
    public let environment: EnvironmentValueProviding
    public let environmentKey: String

    public init(
        primary: APIKeyStoring,
        environment: EnvironmentValueProviding = ProcessEnvironmentProvider(),
        environmentKey: String = "LITELLM_API_KEY"
    ) {
        self.primary = primary
        self.environment = environment
        self.environmentKey = environmentKey
    }

    public func readAPIKey() throws -> String {
        do {
            return try primary.readAPIKey()
        } catch APIKeyStoreError.missingKey {
            guard let envValue = environment.value(for: environmentKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !envValue.isEmpty else {
                throw APIKeyStoreError.missingKey
            }
            try primary.saveAPIKey(envValue)
            return envValue
        }
    }

    public func saveAPIKey(_ apiKey: String) throws {
        try primary.saveAPIKey(apiKey)
    }

    public func deleteAPIKey() throws {
        try primary.deleteAPIKey()
    }
}
