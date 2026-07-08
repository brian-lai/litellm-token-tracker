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

    public var defaultBaseURL: URL {
        switch self {
        case .litellm:
            return URL(string: "https://litellm.justworksai.net")!
        case .bifrost:
            return URL(string: "https://llm-proxy.internal-tools.justworks.cc")!
        }
    }
}
