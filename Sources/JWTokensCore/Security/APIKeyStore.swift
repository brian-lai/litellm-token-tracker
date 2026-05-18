import Foundation

public enum APIKeyStoreError: Error, Equatable {
    case notImplemented
    case missingKey
    case unavailable
}

public protocol APIKeyStoring: Sendable {
    func readAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

public struct KeychainAPIKeyStore: APIKeyStoring {
    public let service: String
    public let account: String

    public init(service: String = "net.justworks.jw-tokens", account: String = "litellm-api-key") {
        self.service = service
        self.account = account
    }

    public func readAPIKey() throws -> String {
        throw APIKeyStoreError.notImplemented
    }

    public func saveAPIKey(_ apiKey: String) throws {
        throw APIKeyStoreError.notImplemented
    }

    public func deleteAPIKey() throws {
        throw APIKeyStoreError.notImplemented
    }
}
