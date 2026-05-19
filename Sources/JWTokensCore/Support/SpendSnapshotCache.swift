import Foundation

public protocol SpendSnapshotCaching: Sendable {
    func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot?
    func saveSnapshot(_ snapshot: SpendSnapshot) throws
    func clearSnapshots()
}

public final class InMemorySpendSnapshotCache: SpendSnapshotCaching, @unchecked Sendable {
    private var snapshots: [SpendRange: SpendSnapshot] = [:]
    private let lock = NSLock()

    public init() {}

    public func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[range]
    }

    public func saveSnapshot(_ snapshot: SpendSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        snapshots[snapshot.range] = snapshot
    }

    public func clearSnapshots() {
        lock.lock()
        defer { lock.unlock() }
        snapshots.removeAll()
    }
}
