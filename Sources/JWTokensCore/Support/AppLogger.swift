import Foundation

public struct AppLogEvent: Equatable, Sendable {
    public let correlationID: String
    public let endpoint: String
    public let statusCode: Int?
    public let durationMilliseconds: Int?
    public let rowCount: Int?
    public let skippedRowCount: Int?
    public let message: String?

    public init(
        correlationID: String,
        endpoint: String,
        statusCode: Int? = nil,
        durationMilliseconds: Int? = nil,
        rowCount: Int? = nil,
        skippedRowCount: Int? = nil,
        message: String? = nil
    ) {
        self.correlationID = correlationID
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.durationMilliseconds = durationMilliseconds
        self.rowCount = rowCount
        self.skippedRowCount = skippedRowCount
        self.message = message
    }
}

public protocol AppLogging: Sendable {
    func log(_ event: AppLogEvent)
}

public struct NoopAppLogger: AppLogging {
    public init() {}
    public func log(_ event: AppLogEvent) {}
}
