import Foundation

public struct LiteLLMKeyInfoResponse: Decodable, Equatable, Sendable {
    public let keyAlias: String?
    public let keyName: String?
    public let spend: Decimal?
    public let maxBudget: Decimal?
    public let budgetResetAt: Date?
    public let lastActive: Date?

    enum CodingKeys: String, CodingKey {
        case keyAlias = "key_alias"
        case keyName = "key_name"
        case spend
        case maxBudget = "max_budget"
        case budgetResetAt = "budget_reset_at"
        case lastActive = "last_active"
    }

    public func toDomain() -> KeySpendSummary {
        KeySpendSummary(
            alias: keyAlias,
            name: keyName,
            spendUSD: spend ?? 0,
            maxBudgetUSD: maxBudget,
            budgetResetAt: budgetResetAt,
            lastActiveAt: lastActive
        )
    }
}

public struct LiteLLMKeyListResponse: Decodable, Equatable, Sendable {
    public let keys: [LiteLLMKeyInfoResponse]
}

public extension LiteLLMResponseDecoder {
    static func decodeCurrentKey(from data: Data) throws -> KeySpendSummary {
        do {
            return try makeJSONDecoder().decode(LiteLLMKeyInfoResponse.self, from: data).toDomain()
        } catch {
            throw LiteLLMClientError.malformedResponse
        }
    }

    static func decodeUserKeys(from data: Data) throws -> [KeySpendSummary] {
        do {
            let decoder = makeJSONDecoder()
            if let wrapped = try? decoder.decode(LiteLLMKeyListResponse.self, from: data) {
                return wrapped.keys.map { $0.toDomain() }
            }
            return try decoder.decode([LiteLLMKeyInfoResponse].self, from: data).map { $0.toDomain() }
        } catch {
            throw LiteLLMClientError.malformedResponse
        }
    }
}
