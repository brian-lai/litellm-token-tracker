import Foundation
import Observation

@Observable
@MainActor
final class SpendDashboardViewModel {
    private let spendService: SpendServicing

    var selectedRange: SpendRange = .today
    var currentSnapshot: SpendSnapshot?
    var userContext: LiteLLMUserContext?
    var errorMessage: String?
    var isRefreshing = false

    init(
        spendService: SpendServicing
    ) {
        self.spendService = spendService
    }

    func refresh(now: Date = Date(), calendar: Calendar = .current) async {
        errorMessage = "Not implemented"
    }
}
