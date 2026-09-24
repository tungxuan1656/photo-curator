import Foundation

/// Priority assigned to image acquisition followed by image inference.
/// Higher-priority work is admitted before lower-priority queued work; work
/// that already holds a permit is never preempted.
enum ImageWorkPriority: Int, Sendable {
    case enrichment = 0
    case session = 1
    case visible = 2
}

/// Shared two-permit arbiter for image work.
///
/// Queued requests are ordered by priority and then arrival order. Cancellation
/// removes queued requests and resumes them with `CancellationError`; active
/// requests retain their permit until their operation returns.
actor ImageWorkArbiter {
    private struct Waiter {
        let id: UUID
        let priority: ImageWorkPriority
        let sequence: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var availablePermits = 2
    private var nextSequence: UInt64 = 0
    private var waiters: [Waiter] = []
    private var activeIDs = Set<UUID>()
    private var registeredIDs = Set<UUID>()
    private var cancelledBeforeEnqueue = Set<UUID>()

    func withPermit<T: Sendable>(
        priority: ImageWorkPriority,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let id = UUID()
        registeredIDs.insert(id)
        do {
            try await acquire(id: id, priority: priority)
        } catch {
            registeredIDs.remove(id)
            cancelledBeforeEnqueue.remove(id)
            throw error
        }

        defer {
            release(id: id)
            registeredIDs.remove(id)
            cancelledBeforeEnqueue.remove(id)
        }
        try Task.checkCancellation()
        let result = try await operation()
        try Task.checkCancellation()
        return result
    }

    private func acquire(id: UUID, priority: ImageWorkPriority) async throws {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                enqueue(
                    Waiter(
                        id: id,
                        priority: priority,
                        sequence: nextSequence,
                        continuation: continuation
                    )
                )
                nextSequence &+= 1
            }
        }, onCancel: {
            Task { await self.cancelQueued(id: id) }
        })
    }

    private func enqueue(_ waiter: Waiter) {
        if cancelledBeforeEnqueue.remove(waiter.id) != nil {
            waiter.continuation.resume(throwing: CancellationError())
            return
        }

        guard availablePermits == 0 else {
            availablePermits -= 1
            activeIDs.insert(waiter.id)
            waiter.continuation.resume()
            return
        }

        waiters.append(waiter)
        waiters.sort {
            if $0.priority != $1.priority {
                return $0.priority.rawValue > $1.priority.rawValue
            }
            return $0.sequence < $1.sequence
        }
    }

    private func cancelQueued(id: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
            return
        }
        guard registeredIDs.contains(id), !activeIDs.contains(id) else { return }
        cancelledBeforeEnqueue.insert(id)
    }

    private func release(id: UUID) {
        guard activeIDs.remove(id) != nil else { return }
        availablePermits += 1
        admitQueuedWork()
    }

    private func admitQueuedWork() {
        while availablePermits > 0, !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            availablePermits -= 1
            activeIDs.insert(waiter.id)
            waiter.continuation.resume()
        }
    }
}
