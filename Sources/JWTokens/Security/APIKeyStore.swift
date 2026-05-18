import Foundation

enum APIKeyStoreError: Error, Equatable {
    case notImplemented
    case missingKey
    case unavailable
}

protocol APIKeyStoring: Sendable {
    func readAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

struct KeychainAPIKeyStore: APIKeyStoring {
    let service: String
    let account: String

    init(service: String = "net.justworks.jw-tokens", account: String = "litellm-api-key") {
        self.service = service
        self.account = account
    }

    func readAPIKey() throws -> String {
        throw APIKeyStoreError.notImplemented
    }

    func saveAPIKey(_ apiKey: String) throws {
        throw APIKeyStoreError.notImplemented
    }

    func deleteAPIKey() throws {
        throw APIKeyStoreError.notImplemented
    }
}
