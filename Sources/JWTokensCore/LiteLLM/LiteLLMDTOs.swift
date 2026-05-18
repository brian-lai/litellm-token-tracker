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
        let dateFormatter = DateFormatter.liteLLMDay

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
    static let liteLLMDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
