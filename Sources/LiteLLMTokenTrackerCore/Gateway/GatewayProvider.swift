import Foundation

public enum GatewayProvider: String, CaseIterable, Equatable, Codable, Sendable {
    case litellm
    case bifrost

    public var displayName: String {
        switch self {
        case .litellm:
            return "LiteLLM"
        case .bifrost:
            return "Bifrost"
        }
    }
}
