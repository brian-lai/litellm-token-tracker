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
        let result = try LiteLLMResponseDecoder.decodeSpendRows(from: data)
        logger.log(AppLogEvent(correlationID: correlationID(), endpoint: "/spend/logs", rowCount: result.rows.count, skippedRowCount: result.skippedRowCount))
        return result.rows
    }

    public func makeSpendRowsRequest(range: DateRange, userID: String) throws -> URLRequest {
        let formatter = DateFormatter.liteLLMRequestDay
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
    static let liteLLMRequestDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
