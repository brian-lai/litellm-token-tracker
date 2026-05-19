import Foundation

public struct LiteLLMUserInfoResponse: Decodable, Equatable, Sendable {
    public struct UserInfo: Decodable, Equatable, Sendable {
        public let spend: Decimal
        public let maxBudget: Decimal?
        public let budgetResetAt: Date?
        public let userEmail: String?
        public let userRole: String?

        enum CodingKeys: String, CodingKey {
            case spend
            case maxBudget = "max_budget"
            case budgetResetAt = "budget_reset_at"
            case userEmail = "user_email"
            case userRole = "user_role"
        }
    }

    public let userID: String
    public let userInfo: UserInfo

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case userInfo = "user_info"
    }

    public func toDomain() -> LiteLLMUserContext {
        LiteLLMUserContext(
            userID: userID,
            email: userInfo.userEmail,
            totalSpendUSD: userInfo.spend,
            maxBudgetUSD: userInfo.maxBudget,
            budgetResetAt: userInfo.budgetResetAt
        )
    }
}

public struct LiteLLMSpendLogRow: Decodable, Equatable, Sendable {
    public let startTime: String?
    public let spend: Decimal?
    public let models: [String: Decimal]?
    public let users: [String: Decimal]?
}

public struct LiteLLMSpendLogDecodeResult: Equatable, Sendable {
    public let rows: [SpendLogSummaryRow]
    public let skippedRowCount: Int
}

public struct LiteLLMUserDailyActivityResponse: Decodable, Equatable, Sendable {
    public struct Metadata: Decodable, Equatable, Sendable {
        public let totalSpend: Decimal?
        public let totalTokens: Int?
        public let totalPromptTokens: Int?
        public let totalCompletionTokens: Int?
        public let totalCacheCreationInputTokens: Int?
        public let totalCacheReadInputTokens: Int?
        public let totalAPIRequests: Int?
        public let totalSuccessfulRequests: Int?
        public let totalFailedRequests: Int?

        enum CodingKeys: String, CodingKey {
            case totalSpend = "total_spend"
            case totalTokens = "total_tokens"
            case totalPromptTokens = "total_prompt_tokens"
            case totalCompletionTokens = "total_completion_tokens"
            case totalCacheCreationInputTokens = "total_cache_creation_input_tokens"
            case totalCacheReadInputTokens = "total_cache_read_input_tokens"
            case totalAPIRequests = "total_api_requests"
            case totalSuccessfulRequests = "total_successful_requests"
            case totalFailedRequests = "total_failed_requests"
        }

        public var totals: SpendUsageTotals {
            SpendUsageTotals(
                totalTokens: totalTokens ?? 0,
                promptTokens: totalPromptTokens ?? 0,
                completionTokens: totalCompletionTokens ?? 0,
                cacheCreationTokens: totalCacheCreationInputTokens ?? 0,
                cacheReadTokens: totalCacheReadInputTokens ?? 0,
                apiRequests: totalAPIRequests ?? 0,
                successfulRequests: totalSuccessfulRequests ?? 0,
                failedRequests: totalFailedRequests ?? 0
            )
        }
    }

    public struct Result: Decodable, Equatable, Sendable {
        public struct Metrics: Decodable, Equatable, Sendable {
            public let spend: Decimal?
            public let totalTokens: Int?
            public let promptTokens: Int?
            public let completionTokens: Int?
            public let cacheCreationInputTokens: Int?
            public let cacheReadInputTokens: Int?
            public let apiRequests: Int?
            public let successfulRequests: Int?
            public let failedRequests: Int?

            enum CodingKeys: String, CodingKey {
                case spend
                case totalTokens = "total_tokens"
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
                case apiRequests = "api_requests"
                case successfulRequests = "successful_requests"
                case failedRequests = "failed_requests"
            }

            public var totals: SpendUsageTotals {
                SpendUsageTotals(
                    totalTokens: totalTokens ?? 0,
                    promptTokens: promptTokens ?? 0,
                    completionTokens: completionTokens ?? 0,
                    cacheCreationTokens: cacheCreationInputTokens ?? 0,
                    cacheReadTokens: cacheReadInputTokens ?? 0,
                    apiRequests: apiRequests ?? 0,
                    successfulRequests: successfulRequests ?? 0,
                    failedRequests: failedRequests ?? 0
                )
            }
        }

        public let date: String?
        public let metrics: Metrics?
        public let breakdown: LiteLLMActivityBreakdown?
    }

    public let metadata: Metadata?
    public let results: [Result]
}

public struct LiteLLMActivityBreakdown: Decodable, Equatable, Sendable {
    public let models: [String: LiteLLMActivityBreakdownValue]
    public let providers: [String: LiteLLMActivityBreakdownValue]
    public let modelGroups: [String: LiteLLMActivityBreakdownValue]
    public let endpoints: [String: LiteLLMActivityBreakdownValue]
    public let mcpServers: [String: LiteLLMActivityBreakdownValue]
    public let apiKeys: [String: LiteLLMActivityBreakdownValue]

    enum CodingKeys: String, CodingKey {
        case models
        case providers
        case modelGroups = "model_groups"
        case endpoints
        case mcpServers = "mcp_servers"
        case apiKeys = "api_keys"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        models = container.decodeLossyBreakdownDictionary(forKey: .models)
        providers = container.decodeLossyBreakdownDictionary(forKey: .providers)
        modelGroups = container.decodeLossyBreakdownDictionary(forKey: .modelGroups)
        endpoints = container.decodeLossyBreakdownDictionary(forKey: .endpoints)
        mcpServers = container.decodeLossyBreakdownDictionary(forKey: .mcpServers)
        apiKeys = container.decodeLossyBreakdownDictionary(forKey: .apiKeys)
    }
}

public struct LiteLLMActivityBreakdownValue: Decodable, Equatable, Sendable {
    public let spend: Decimal
    public let tokens: Int?
    public let requests: Int?

    enum CodingKeys: String, CodingKey {
        case metrics
        case spend
        case totalTokens = "total_tokens"
        case apiRequests = "api_requests"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try container.decodeIfPresent(LiteLLMUserDailyActivityResponse.Result.Metrics.self, forKey: .metrics) {
            guard nested.spend != nil || nested.totalTokens != nil || nested.apiRequests != nil else {
                throw DecodingError.dataCorruptedError(forKey: .metrics, in: container, debugDescription: "Empty metrics object")
            }
            spend = nested.spend ?? 0
            tokens = nested.totalTokens
            requests = nested.apiRequests
            return
        }

        let spend = try container.decodeIfPresent(Decimal.self, forKey: .spend)
        let tokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        let requests = try container.decodeIfPresent(Int.self, forKey: .apiRequests)
        guard spend != nil || tokens != nil || requests != nil else {
            throw DecodingError.dataCorruptedError(forKey: .spend, in: container, debugDescription: "Missing breakdown metrics")
        }
        self.spend = spend ?? 0
        self.tokens = tokens
        self.requests = requests
    }
}

public struct LiteLLMUserDailyActivityDecodeResult: Equatable, Sendable {
    public let summary: SpendActivitySummary
    public let analytics: SpendAnalyticsSummary
    public let skippedRowCount: Int
}

public enum LiteLLMResponseDecoder {
    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.liteLLM.date(from: value)
                ?? ISO8601DateFormatter.liteLLMNoFractionalSeconds.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }

    public static func decodeUserInfo(from data: Data) throws -> LiteLLMUserContext {
        do {
            return try makeJSONDecoder().decode(LiteLLMUserInfoResponse.self, from: data).toDomain()
        } catch {
            throw LiteLLMClientError.malformedResponse
        }
    }

    public static func decodeSpendRows(from data: Data, calendar: Calendar = .current) throws -> LiteLLMSpendLogDecodeResult {
        let decodedRows: [LiteLLMSpendLogRow]
        do {
            decodedRows = try makeJSONDecoder().decode([LiteLLMSpendLogRow].self, from: data)
        } catch {
            throw LiteLLMClientError.malformedResponse
        }

        var skipped = 0
        var rows: [SpendLogSummaryRow] = []
        let dateFormatter = DateFormatter.liteLLMDay(timeZone: calendar.timeZone)

        for decodedRow in decodedRows {
            guard let startTime = decodedRow.startTime,
                  let date = dateFormatter.date(from: startTime) else {
                skipped += 1
                continue
            }
            rows.append(SpendLogSummaryRow(date: date, spendUSD: decodedRow.spend ?? 0))
        }

        return LiteLLMSpendLogDecodeResult(rows: rows, skippedRowCount: skipped)
    }

    public static func decodeUserDailyActivity(from data: Data, calendar: Calendar = .current) throws -> LiteLLMUserDailyActivityDecodeResult {
        let decoded: LiteLLMUserDailyActivityResponse
        do {
            decoded = try makeJSONDecoder().decode(LiteLLMUserDailyActivityResponse.self, from: data)
        } catch {
            throw LiteLLMClientError.malformedResponse
        }

        var skipped = 0
        var points: [DailyActivityPoint] = []
        var breakdowns: [SpendBreakdownCategory: [String: SpendBreakdownAccumulator]] = [:]
        let dateFormatter = DateFormatter.liteLLMDay(timeZone: calendar.timeZone)

        for result in decoded.results {
            guard let dateString = result.date,
                  let date = dateFormatter.date(from: dateString) else {
                skipped += 1
                continue
            }
            points.append(DailyActivityPoint(date: date, spendUSD: result.metrics?.spend ?? 0, totals: result.metrics?.totals ?? .zero))
            mergeBreakdown(result.breakdown?.models, category: .models, into: &breakdowns)
            mergeBreakdown(result.breakdown?.providers, category: .providers, into: &breakdowns)
            mergeBreakdown(result.breakdown?.modelGroups, category: .modelGroups, into: &breakdowns)
            mergeBreakdown(result.breakdown?.endpoints, category: .endpoints, into: &breakdowns)
            mergeBreakdown(result.breakdown?.mcpServers, category: .mcpServers, into: &breakdowns)
            mergeBreakdown(result.breakdown?.apiKeys, category: .apiKeys, into: &breakdowns)
        }

        let fallbackTotal = points.reduce(Decimal(0)) { $0 + $1.spendUSD }
        let analytics = SpendAnalyticsSummary(
            totalSpendUSD: decoded.metadata?.totalSpend ?? fallbackTotal,
            totals: decoded.metadata?.totals ?? .zero,
            dailyPoints: points,
            breakdowns: breakdowns.mapValues { values in
                values
                    .map { $0.value.item(label: $0.key) }
                    .sorted { $0.spendUSD > $1.spendUSD }
            },
            source: .userDailyActivity
        )
        return LiteLLMUserDailyActivityDecodeResult(
            summary: analytics.activitySummary,
            analytics: analytics,
            skippedRowCount: skipped
        )
    }

    private static func mergeBreakdown(
        _ values: [String: LiteLLMActivityBreakdownValue]?,
        category: SpendBreakdownCategory,
        into breakdowns: inout [SpendBreakdownCategory: [String: SpendBreakdownAccumulator]]
    ) {
        guard let values else {
            return
        }
        for (label, value) in values {
            breakdowns[category, default: [:]][label, default: SpendBreakdownAccumulator()].add(value)
        }
    }
}

private struct SpendBreakdownAccumulator {
    private(set) var spendUSD: Decimal = 0
    private var tokenTotal = 0
    private var requestTotal = 0
    private var hasTokens = false
    private var hasRequests = false

    mutating func add(_ value: LiteLLMActivityBreakdownValue) {
        spendUSD += value.spend
        if let tokens = value.tokens {
            hasTokens = true
            tokenTotal += tokens
        }
        if let requests = value.requests {
            hasRequests = true
            requestTotal += requests
        }
    }

    func item(label: String) -> SpendBreakdownItem {
        SpendBreakdownItem(
            label: label,
            spendUSD: spendUSD,
            tokens: hasTokens ? tokenTotal : nil,
            requests: hasRequests ? requestTotal : nil
        )
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyBreakdownDictionary(forKey key: Key) -> [String: LiteLLMActivityBreakdownValue] {
        guard let nested = try? nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key) else {
            return [:]
        }

        var values: [String: LiteLLMActivityBreakdownValue] = [:]
        for dynamicKey in nested.allKeys {
            if let value = try? nested.decode(LiteLLMActivityBreakdownValue.self, forKey: dynamicKey) {
                values[dynamicKey.stringValue] = value
            }
        }
        return values
    }
}

private extension ISO8601DateFormatter {
    static let liteLLM: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let liteLLMNoFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static func liteLLMDay(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
