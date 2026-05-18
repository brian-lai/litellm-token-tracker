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

public struct KeychainAPIKeyStore: APIKeyStoring {
    public let service: String
    public let account: String
    private let gateway: KeychainGateway

    public init(service: String = "net.justworks.jw-tokens", account: String = "litellm-api-key", gateway: KeychainGateway = SecItemKeychainGateway()) {
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
