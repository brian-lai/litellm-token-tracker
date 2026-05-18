import Foundation

public struct AppConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let spendLimitUSD: Decimal

    public init(baseURL: URL = URL(string: "https://litellm.justworksai.net")!, spendLimitUSD: Decimal = 80) {
        self.baseURL = baseURL
        self.spendLimitUSD = spendLimitUSD
    }
}

public protocol AppConfigurationStoring: Sendable {
    func loadConfiguration() throws -> AppConfiguration
}

public struct StaticAppConfigurationStore: AppConfigurationStoring {
    private let configuration: AppConfiguration

    public init(configuration: AppConfiguration = AppConfiguration()) {
        self.configuration = configuration
    }

    public func loadConfiguration() throws -> AppConfiguration {
        configuration
    }
}
