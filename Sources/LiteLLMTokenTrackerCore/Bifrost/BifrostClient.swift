import Foundation

public struct BifrostClient: GatewayClientProtocol {
    public let baseURL: URL
    private let apiKey: String
    private let loader: URLLoading
    private let logger: AppLogging

    public init(
        baseURL: URL,
        apiKey: String,
        loader: URLLoading = URLSessionLoader(),
        logger: AppLogging = NoopAppLogger()
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.loader = loader
        self.logger = logger
    }

    public func fetchCurrentUserContext() async throws -> GatewayUserContext {
        GatewayUserContext()
    }

    public func fetchSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary {
        let request = try makeDashboardRequest(range: range)
        let data = try await perform(request, endpoint: "/api/logs/dashboard").data
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = range.timeZone
        let analytics = try BifrostResponseDecoder.decodeDashboard(from: data, calendar: calendar)
        logger.log(AppLogEvent(correlationID: correlationID(), gatewayProvider: .bifrost, endpoint: "/api/logs/dashboard", rowCount: analytics.dailyPoints.count))
        return analytics
    }

    public func fetchSpendRows(range: DateRange, userContext: GatewayUserContext?) async throws -> [SpendLogSummaryRow] {
        let request = try makeLogsRequest(range: range)
        let data = try await perform(request, endpoint: "/api/logs").data
        let rows = try BifrostResponseDecoder.decodeLogsRows(from: data)
        logger.log(AppLogEvent(correlationID: correlationID(), gatewayProvider: .bifrost, endpoint: "/api/logs", rowCount: rows.count))
        return rows
    }

    public func fetchFallbackSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary {
        let request = try makeLogsRequest(range: range)
        let data = try await perform(request, endpoint: "/api/logs").data
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = range.timeZone
        let analytics = try BifrostResponseDecoder.decodeLogsAnalytics(from: data, calendar: calendar)
        logger.log(AppLogEvent(correlationID: correlationID(), gatewayProvider: .bifrost, endpoint: "/api/logs", rowCount: analytics.dailyPoints.count))
        return analytics
    }

    public func fetchCurrentKeyContext(userContext: GatewayUserContext?) async throws -> KeySpendSummary {
        let request = try makeQuotaRequest()
        let data = try await perform(request, endpoint: "/api/governance/virtual-keys/quota").data
        return try BifrostResponseDecoder.decodeQuota(from: data)
    }

    public func fetchOwnedKeyContexts(userContext: GatewayUserContext?) async throws -> [KeySpendSummary] {
        let request = try makeVirtualKeysRequest()
        let data = try await perform(request, endpoint: "/api/governance/virtual-keys").data
        return try BifrostResponseDecoder.decodeVirtualKeys(from: data)
    }

    public func makeLogsRequest(range: DateRange) throws -> URLRequest {
        var components = try components(path: "/api/logs")
        components.queryItems = [
            URLQueryItem(name: "start_time", value: BifrostClient.rfc3339Formatter.string(from: range.startDate)),
            URLQueryItem(name: "end_time", value: BifrostClient.rfc3339Formatter.string(from: range.endDate)),
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "sort_by", value: "timestamp"),
            URLQueryItem(name: "order", value: "asc")
        ]
        return try request(from: components)
    }

    public func makeDashboardRequest(range: DateRange) throws -> URLRequest {
        var components = try components(path: "/api/logs/dashboard")
        components.queryItems = [
            URLQueryItem(name: "start_time", value: BifrostClient.rfc3339Formatter.string(from: range.startDate)),
            URLQueryItem(name: "end_time", value: BifrostClient.rfc3339Formatter.string(from: range.endDate))
        ]
        return try request(from: components)
    }

    public func makeQuotaRequest() throws -> URLRequest {
        var request = try request(from: components(path: "/api/governance/virtual-keys/quota"))
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "x-bf-vk")
        return request
    }

    public func makeVirtualKeysRequest() throws -> URLRequest {
        var components = try components(path: "/api/governance/virtual-keys")
        components.queryItems = [
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "offset", value: "0")
        ]
        return try request(from: components)
    }

    private func components(path: String) throws -> URLComponents {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw GatewayClientError.unavailable
        }
        components.path = path
        return components
    }

    private func request(from components: URLComponents) throws -> URLRequest {
        guard let url = components.url else {
            throw GatewayClientError.unavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest, endpoint: String) async throws -> (data: Data, response: HTTPURLResponse) {
        let correlationID = correlationID()
        let started = Date()
        do {
            let result = try await loader.data(for: request)
            logger.log(AppLogEvent(
                correlationID: correlationID,
                gatewayProvider: .bifrost,
                endpoint: endpoint,
                statusCode: result.1.statusCode,
                durationMilliseconds: Int(Date().timeIntervalSince(started) * 1000)
            ))
            switch result.1.statusCode {
            case 200..<300:
                return result
            case 401:
                throw GatewayClientError.unauthorized
            case 403:
                throw GatewayClientError.forbidden
            default:
                throw GatewayClientError.unavailable
            }
        } catch let error as GatewayClientError {
            throw error
        } catch {
            throw GatewayClientError.unavailable
        }
    }

    private func correlationID() -> String {
        UUID().uuidString
    }

    private static let rfc3339Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
