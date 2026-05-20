import Foundation

@MainActor
public final class SpendRefreshCoordinator {
    private let scheduler: RefreshScheduling
    private let interval: TimeInterval
    private let viewModel: SpendDashboardViewModel

    public init(viewModel: SpendDashboardViewModel, scheduler: RefreshScheduling = TimerRefreshScheduler(), interval: TimeInterval = 300) {
        self.viewModel = viewModel
        self.scheduler = scheduler
        self.interval = interval
    }

    public func start() {
        scheduler.start(every: interval) { [weak viewModel] in
            await viewModel?.refresh(isAutomatic: true)
        }
    }

    public func stop() {
        scheduler.stop()
    }
}
