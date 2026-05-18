import Foundation
import Observation

@Observable
@MainActor
public final class SpendDashboardViewModel {
    private let spendService: SpendServicing

    public var selectedRange: SpendRange = .today
    public var currentSnapshot: SpendSnapshot?
    public var userContext: LiteLLMUserContext?
    public var errorMessage: String?
    public var isRefreshing = false

    public init(
        spendService: SpendServicing
    ) {
        self.spendService = spendService
    }

    public func refresh(now: Date = Date(), calendar: Calendar = .current) async {
        errorMessage = "Not implemented"
    }
}
