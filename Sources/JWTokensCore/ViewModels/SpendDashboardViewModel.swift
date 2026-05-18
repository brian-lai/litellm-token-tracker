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
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
        switch result {
        case let .refreshed(snapshot):
            currentSnapshot = snapshot
            errorMessage = nil
        case let .stale(snapshot, message):
            currentSnapshot = snapshot
            errorMessage = message
        case let .setupRequired(message), let .authFailed(message), let .failed(message):
            errorMessage = message
        }
    }

    public func selectRange(_ range: SpendRange, now: Date = Date(), calendar: Calendar = .current) async {
        selectedRange = range
        await refresh(now: now, calendar: calendar)
    }
}
