import Foundation

public protocol RefreshScheduling: AnyObject, Sendable {
    func start(every seconds: TimeInterval, operation: @escaping @Sendable () async -> Void)
    func stop()
}

public final class TimerRefreshScheduler: RefreshScheduling, @unchecked Sendable {
    private var timer: Timer?
    private let lock = NSLock()

    public init() {}

    public func start(every seconds: TimeInterval, operation: @escaping @Sendable () async -> Void) {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            Task {
                await operation()
            }
        }
        lock.lock()
        self.timer = timer
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        let existingTimer = timer
        timer = nil
        lock.unlock()
        existingTimer?.invalidate()
    }
}
