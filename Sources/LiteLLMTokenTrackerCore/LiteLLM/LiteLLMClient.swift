import Foundation

public enum LiteLLMClientError: Error, Equatable {
    case notImplemented
    case unauthorized
    case unavailable
    case malformedResponse
}

public protocol LiteLLMClientProtocol: GatewayClientProtocol {
    func fetchCurrentUser() async throws -> LiteLLMUserContext
    func fetchUserDailyActivity(range: DateRange, userID: String) async throws -> SpendAnalyticsSummary
    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow]
    func fetchCurrentKey() async throws -> KeySpendSummary
    func fetchUserKeys(userID: String) async throws -> [KeySpendSummary]
}

public extension LiteLLMClientProtocol {
    func fetchCurrentUserContext() async throws -> GatewayUserContext {
        try await GatewayUserContext(liteLLMUserContext: fetchCurrentUser())
    }

    func fetchSpendAnalytics(range: DateRange, userContext: GatewayUserContext?) async throws -> SpendAnalyticsSummary {
        let userID = try liteLLMUserID(from: userContext)
        return try await fetchUserDailyActivity(range: range, userID: userID)
    }

    func fetchSpendRows(range: DateRange, userContext: GatewayUserContext?) async throws -> [SpendLogSummaryRow] {
        let userID = try liteLLMUserID(from: userContext)
        return try await fetchSpendRows(range: range, userID: userID)
    }

    func fetchCurrentKeyContext(userContext: GatewayUserContext?) async throws -> KeySpendSummary {
        try await fetchCurrentKey()
    }

    func fetchOwnedKeyContexts(userContext: GatewayUserContext?) async throws -> [KeySpendSummary] {
        let userID = try liteLLMUserID(from: userContext)
        return try await fetchUserKeys(userID: userID)
    }

    private func liteLLMUserID(from userContext: GatewayUserContext?) throws -> String {
        guard let userID = userContext?.userID, !userID.isEmpty else {
            throw LiteLLMClientError.malformedResponse
        }
        return userID
    }
}

public struct LiteLLMClient: LiteLLMClientProtocol {
    public let baseURL: URL
    public let apiKey: String
    private let loader: URLLoading
    private let logger: AppLogging

    public init(baseURL: URL, apiKey: String, loader: URLLoading = URLSessionLoader(), logger: AppLogging = NoopAppLogger()) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.loader = loader
        self.logger = logger
    }

    public func fetchCurrentUser() async throws -> LiteLLMUserContext {
        let request = makeRequest(path: "/user/info")
        let data = try await perform(request, endpoint: "/user/info").data
        return try LiteLLMResponseDecoder.decodeUserInfo(from: data)
    }

    public func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow] {
        let request = try makeSpendRowsRequest(range: range, userID: userID)
        let data = try await perform(request, endpoint: "/spend/logs").data
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = range.timeZone
        let result = try LiteLLMResponseDecoder.decodeSpendRows(from: data, calendar: calendar)
        logger.log(AppLogEvent(correlationID: correlationID(), gatewayProvider: .litellm, endpoint: "/spend/logs", rowCount: result.rows.count, skippedRowCount: result.skippedRowCount))
        return result.rows
    }

    public func fetchUserDailyActivity(range: DateRange, userID: String) async throws -> SpendAnalyticsSummary {
        let request = try makeUserDailyActivityRequest(range: range, userID: userID)
        let data = try await perform(request, endpoint: "/user/daily/activity").data
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = range.timeZone
        let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(from: data, calendar: calendar)
        logger.log(AppLogEvent(correlationID: correlationID(), gatewayProvider: .litellm, endpoint: "/user/daily/activity", rowCount: result.summary.dailyPoints.count, skippedRowCount: result.skippedRowCount))
        return result.analytics
    }

    public func fetchCurrentKey() async throws -> KeySpendSummary {
        let request = makeRequest(path: "/key/info")
        let data = try await perform(request, endpoint: "/key/info").data
        return try LiteLLMResponseDecoder.decodeCurrentKey(from: data)
    }

    public func fetchUserKeys(userID: String) async throws -> [KeySpendSummary] {
        let request = try makeUserKeysRequest(userID: userID)
        let data = try await perform(request, endpoint: "/key/list").data
        return try LiteLLMResponseDecoder.decodeUserKeys(from: data)
    }

    public func makeSpendRowsRequest(range: DateRange, userID: String) throws -> URLRequest {
        let formatter = DateFormatter.liteLLMRequestDay(timeZone: range.timeZone)
        var components = URLComponents(url: baseURL.appendingPathComponent("spend/logs"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "start_date", value: formatter.string(from: range.startDate)),
            URLQueryItem(name: "end_date", value: formatter.string(from: range.endDate)),
            URLQueryItem(name: "summarize", value: "true")
        ]
        guard let url = components?.url else {
            throw LiteLLMClientError.malformedResponse
        }
        return makeRequest(url: url)
    }

    public func makeUserDailyActivityRequest(range: DateRange, userID: String) throws -> URLRequest {
        let formatter = DateFormatter.liteLLMRequestDay(timeZone: range.timeZone)
        let inclusiveEndDate = Calendar.gregorian(timeZone: range.timeZone).date(byAdding: .day, value: -1, to: range.endDate) ?? range.endDate
        var components = URLComponents(url: baseURL.appendingPathComponent("user/daily/activity"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "start_date", value: formatter.string(from: range.startDate)),
            URLQueryItem(name: "end_date", value: formatter.string(from: inclusiveEndDate)),
            URLQueryItem(name: "timezone", value: String(range.timeZone.liteLLMTimezoneOffsetMinutes(for: range.startDate))),
            URLQueryItem(name: "page_size", value: "1000")
        ]
        guard let url = components?.url else {
            throw LiteLLMClientError.malformedResponse
        }
        return makeRequest(url: url)
    }

    public func makeUserKeysRequest(userID: String) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent("key/list"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userID),
            URLQueryItem(name: "size", value: "100")
        ]
        guard let url = components?.url else {
            throw LiteLLMClientError.malformedResponse
        }
        return makeRequest(url: url)
    }

    public func makeRequest(path: String) -> URLRequest {
        makeRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest, endpoint: String) async throws -> (data: Data, response: HTTPURLResponse) {
        let started = Date()
        let correlationID = correlationID()
        do {
            let result = try await loader.data(for: request)
            logger.log(AppLogEvent(
                correlationID: correlationID,
                gatewayProvider: .litellm,
                endpoint: endpoint,
                statusCode: result.1.statusCode,
                durationMilliseconds: Int(Date().timeIntervalSince(started) * 1000)
            ))
            switch result.1.statusCode {
            case 200..<300:
                return result
            case 401, 403:
                throw LiteLLMClientError.unauthorized
            case 500..<600:
                throw LiteLLMClientError.unavailable
            default:
                throw LiteLLMClientError.malformedResponse
            }
        } catch let error as LiteLLMClientError {
            throw error
        } catch {
            throw LiteLLMClientError.unavailable
        }
    }

    private func correlationID() -> String {
        UUID().uuidString
    }
}

private extension DateFormatter {
    static func liteLLMRequestDay(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

private extension Calendar {
    static func gregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

private extension TimeZone {
    func liteLLMTimezoneOffsetMinutes(for date: Date) -> Int {
        -secondsFromGMT(for: date) / 60
    }
}
