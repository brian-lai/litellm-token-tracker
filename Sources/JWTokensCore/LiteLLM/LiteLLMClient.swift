import Foundation

public enum LiteLLMClientError: Error, Equatable {
    case notImplemented
    case unauthorized
    case unavailable
    case malformedResponse
}

public protocol LiteLLMClientProtocol: Sendable {
    func fetchCurrentUser() async throws -> LiteLLMUserContext
    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow]
}

public struct LiteLLMClient: LiteLLMClientProtocol {
    public let baseURL: URL
    public let apiKey: String
    public let urlSession: URLSession

    public init(baseURL: URL, apiKey: String, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    public func fetchCurrentUser() async throws -> LiteLLMUserContext {
        throw LiteLLMClientError.notImplemented
    }

    public func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow] {
        throw LiteLLMClientError.notImplemented
    }
}
