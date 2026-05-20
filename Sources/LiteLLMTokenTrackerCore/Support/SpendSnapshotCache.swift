import Foundation

public protocol SpendSnapshotCaching: Sendable {
    func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot?
    func loadSnapshot(for range: SpendRange, scope: String) throws -> SpendSnapshot?
    func saveSnapshot(_ snapshot: SpendSnapshot) throws
    func saveSnapshot(_ snapshot: SpendSnapshot, scope: String) throws
    func clearSnapshots()
}

public extension SpendSnapshotCaching {
    func loadSnapshot(for range: SpendRange, scope: String) throws -> SpendSnapshot? {
        try loadSnapshot(for: range)
    }

    func saveSnapshot(_ snapshot: SpendSnapshot, scope: String) throws {
        try saveSnapshot(snapshot)
    }
}

public final class InMemorySpendSnapshotCache: SpendSnapshotCaching, @unchecked Sendable {
    private var snapshots: [SpendRange: SpendSnapshot] = [:]
    private var scopedSnapshots: [String: [SpendRange: SpendSnapshot]] = [:]
    private let lock = NSLock()

    public init() {}

    public func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[range]
    }

    public func loadSnapshot(for range: SpendRange, scope: String) throws -> SpendSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return scopedSnapshots[scope]?[range]
    }

    public func saveSnapshot(_ snapshot: SpendSnapshot) throws {
        lock.lock()
        defer { lock.unlock() }
        snapshots[snapshot.range] = snapshot
    }

    public func saveSnapshot(_ snapshot: SpendSnapshot, scope: String) throws {
        lock.lock()
        defer { lock.unlock() }
        scopedSnapshots[scope, default: [:]][snapshot.range] = snapshot
    }

    public func clearSnapshots() {
        lock.lock()
        defer { lock.unlock() }
        snapshots.removeAll()
        scopedSnapshots.removeAll()
    }
}
