import Foundation

public enum BifrostResponseDecoder {
    public static func decodeDashboard(from data: Data, calendar: Calendar) throws -> SpendAnalyticsSummary {
        let payload: DashboardPayload
        do {
            payload = try JSONDecoder.bifrost.decode(DashboardPayload.self, from: data)
        } catch {
            throw GatewayClientError.malformedResponse
        }

        guard let overview = payload.overview, let stats = overview.stats else {
            throw GatewayClientError.malformedResponse
        }

        let tokenBuckets = Dictionary(uniqueKeysWithValues: (overview.tokens?.buckets ?? []).compactMap { bucket in
            bucket.date.map { ($0, bucket) }
        })
        let requestBuckets = Dictionary(uniqueKeysWithValues: (overview.requests?.buckets ?? []).compactMap { bucket in
            bucket.date.map { ($0, bucket) }
        })

        let dailyPoints = (overview.cost?.buckets ?? []).compactMap { bucket -> DailyActivityPoint? in
            guard let date = bucket.date, let spendUSD = bucket.totalCost else {
                return nil
            }
            let tokens = tokenBuckets[date]
            let requests = requestBuckets[date]
            return DailyActivityPoint(
                date: calendar.startOfDay(for: date),
                spendUSD: spendUSD,
                totals: SpendUsageTotals(
                    totalTokens: tokens?.totalTokens ?? 0,
                    promptTokens: tokens?.promptTokens ?? 0,
                    completionTokens: tokens?.completionTokens ?? 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    apiRequests: requests?.totalRequests ?? 0,
                    successfulRequests: 0,
                    failedRequests: 0
                )
            )
        }.sorted { $0.date < $1.date }

        return SpendAnalyticsSummary(
            totalSpendUSD: stats.totalCost ?? 0,
            totals: SpendUsageTotals(
                totalTokens: stats.totalTokens ?? 0,
                promptTokens: 0,
                completionTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                apiRequests: stats.totalRequests ?? 0,
                successfulRequests: stats.successfulRequests ?? 0,
                failedRequests: stats.failedRequests ?? 0
            ),
            dailyPoints: dailyPoints,
            breakdowns: [:],
            source: .userDailyActivity
        )
    }

    public static func decodeLogsRows(from data: Data) throws -> [SpendLogSummaryRow] {
        let payload = try decodeLogsPayload(from: data)
        return payload.logs.compactMap { log in
            guard let date = log.timestamp, let spendUSD = log.resolvedCost else {
                return nil
            }
            return SpendLogSummaryRow(date: date, spendUSD: spendUSD)
        }
    }

    public static func decodeLogsAnalytics(from data: Data, calendar: Calendar) throws -> SpendAnalyticsSummary {
        let payload = try decodeLogsPayload(from: data)
        let rows = payload.logs.compactMap { log -> (date: Date, spendUSD: Decimal, usage: LogTokenUsage?)? in
            guard let date = log.timestamp, let spendUSD = log.resolvedCost else {
                return nil
            }
            return (date, spendUSD, log.tokenUsage)
        }

        let groupedRows = Dictionary(grouping: rows) { row in
            calendar.startOfDay(for: row.date)
        }
        let dailyPoints = groupedRows.map { date, rows in
            let spend = rows.reduce(Decimal(0)) { partial, row in partial + row.spendUSD }
            let promptTokens = rows.reduce(0) { partial, row in partial + (row.usage?.promptTokens ?? 0) }
            let completionTokens = rows.reduce(0) { partial, row in partial + (row.usage?.completionTokens ?? 0) }
            let totalTokens = rows.reduce(0) { partial, row in partial + (row.usage?.totalTokens ?? 0) }
            return DailyActivityPoint(
                date: date,
                spendUSD: spend,
                totals: SpendUsageTotals(
                    totalTokens: totalTokens,
                    promptTokens: promptTokens,
                    completionTokens: completionTokens,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    apiRequests: rows.count,
                    successfulRequests: 0,
                    failedRequests: 0
                )
            )
        }.sorted { $0.date < $1.date }

        return SpendAnalyticsSummary(
            totalSpendUSD: payload.stats?.totalCost ?? rows.reduce(Decimal(0)) { $0 + $1.spendUSD },
            totals: SpendUsageTotals(
                totalTokens: payload.stats?.totalTokens ?? rows.reduce(0) { $0 + ($1.usage?.totalTokens ?? 0) },
                promptTokens: rows.reduce(0) { $0 + ($1.usage?.promptTokens ?? 0) },
                completionTokens: rows.reduce(0) { $0 + ($1.usage?.completionTokens ?? 0) },
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                apiRequests: payload.stats?.totalRequests ?? rows.count,
                successfulRequests: payload.stats?.successfulRequests ?? 0,
                failedRequests: payload.stats?.failedRequests ?? 0
            ),
            dailyPoints: dailyPoints,
            breakdowns: [:],
            source: .spendLogsFallback
        )
    }

    private static func decodeLogsPayload(from data: Data) throws -> LogsPayload {
        do {
            return try JSONDecoder.bifrost.decode(LogsPayload.self, from: data)
        } catch {
            throw GatewayClientError.malformedResponse
        }
    }
}

private struct DashboardPayload: Decodable {
    let overview: DashboardOverview?
}

private struct DashboardOverview: Decodable {
    let stats: BifrostStats?
    let cost: DashboardBucketList<CostBucket>?
    let tokens: DashboardBucketList<TokenBucket>?
    let requests: DashboardBucketList<RequestBucket>?
}

private struct DashboardBucketList<Bucket: Decodable>: Decodable {
    let buckets: [Bucket]
}

private struct BifrostStats: Decodable {
    let totalCost: Decimal?
    let totalTokens: Int?
    let totalRequests: Int?
    let successfulRequests: Int?
    let failedRequests: Int?

    enum CodingKeys: String, CodingKey {
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case totalRequests = "total_requests"
        case successfulRequests = "successful_requests"
        case failedRequests = "failed_requests"
    }
}

private struct CostBucket: Decodable {
    let timestamp: Date?
    let totalCost: Decimal?

    var date: Date? { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case totalCost = "total_cost"
    }
}

private struct TokenBucket: Decodable {
    let timestamp: Date?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    var date: Date? { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct RequestBucket: Decodable {
    let timestamp: Date?
    let totalRequests: Int?

    var date: Date? { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case totalRequests = "total_requests"
    }
}

private struct LogsPayload: Decodable {
    let logs: [LogEntry]
    let stats: BifrostStats?
}

private struct LogEntry: Decodable {
    let timestamp: Date?
    let cost: Decimal?
    let tokenUsage: LogTokenUsage?

    var resolvedCost: Decimal? {
        cost ?? tokenUsage?.cost?.totalCost
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case cost
        case tokenUsage = "token_usage"
    }
}

private struct LogTokenUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let cost: LogTokenCost?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cost
    }
}

private struct LogTokenCost: Decodable {
    let totalCost: Decimal?

    enum CodingKeys: String, CodingKey {
        case totalCost = "total_cost"
    }
}

private extension JSONDecoder {
    static var bifrost: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.bifrostWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.bifrost.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid RFC3339 date")
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let bifrost: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let bifrostWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
