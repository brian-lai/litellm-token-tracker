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
        let timer = Timer(timeInterval: seconds, repeats: true) { _ in
            Task {
                await operation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
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
