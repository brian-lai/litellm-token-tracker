import Foundation

public struct BifrostClient: GatewayClientProtocol {
    public let baseURL: URL
    private let apiKey: String

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    public func fetchCurrentUserContext() async throws -> GatewayUserContext {
        throw GatewayClientError.notImplemented
    }

    public func fetchSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary {
        throw GatewayClientError.notImplemented
    }

    public func fetchSpendRows(range: DateRange, userContext: GatewayUserContext?) async throws -> [SpendLogSummaryRow] {
        throw GatewayClientError.notImplemented
    }

    public func fetchCurrentKeyContext(userContext: GatewayUserContext?) async throws -> KeySpendSummary {
        throw GatewayClientError.notImplemented
    }

    public func fetchOwnedKeyContexts(userContext: GatewayUserContext?) async throws -> [KeySpendSummary] {
        throw GatewayClientError.notImplemented
    }
}
