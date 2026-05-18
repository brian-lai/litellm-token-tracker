import Foundation

public protocol SpendSnapshotCaching: Sendable {
    func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot?
    func saveSnapshot(_ snapshot: SpendSnapshot) throws
}

public final class InMemorySpendSnapshotCache: SpendSnapshotCaching, @unchecked Sendable {
    private var snapshots: [SpendRange: SpendSnapshot] = [:]

    public init() {}

    public func loadSnapshot(for range: SpendRange) throws -> SpendSnapshot? {
        snapshots[range]
    }

    public func saveSnapshot(_ snapshot: SpendSnapshot) throws {
        snapshots[snapshot.range] = snapshot
    }
}
