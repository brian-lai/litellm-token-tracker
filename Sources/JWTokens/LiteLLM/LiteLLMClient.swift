import Foundation

enum LiteLLMClientError: Error, Equatable {
    case notImplemented
    case unauthorized
    case unavailable
    case malformedResponse
}

protocol LiteLLMClientProtocol: Sendable {
    func fetchCurrentUser() async throws -> LiteLLMUserContext
    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow]
}

struct LiteLLMClient: LiteLLMClientProtocol {
    let baseURL: URL
    let apiKey: String
    let urlSession: URLSession

    init(baseURL: URL, apiKey: String, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    func fetchCurrentUser() async throws -> LiteLLMUserContext {
        throw LiteLLMClientError.notImplemented
    }

    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow] {
        throw LiteLLMClientError.notImplemented
    }
}
