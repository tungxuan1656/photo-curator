import Foundation

protocol QualityPairJudging: Sendable {
    func judge(_ request: QualityPairRequest) async throws -> QualityPairJudgment
    func cancel(generation: Int) async
}

extension QwenPairJudge: QualityPairJudging {}

protocol QualityPairModelManaging: QualityPairJudging {
    func load(from installation: ModelInstallation) async throws -> QwenLoadResult
    func unload() async throws
}

extension QwenPairJudge: QualityPairModelManaging {}

struct QualityComparisonRun: Sendable {
    let comparisons: [QualityPairComparison]
    let counts: QualityComparisonCounts
    let degradationReason: QualityDegradationReason?
}

struct QualityPairComparison: Sendable {
    let first: AssetID
    let second: AssetID
    let judgment: QualityPairJudgment
}

/// Runs one serial, bounded comparison queue. Invalid evidence never becomes a pick.
struct QualityComparisonScheduler: Sendable {
    let judge: any QualityPairJudging
    let policy: QualityCurationPolicy

    func run(_ requests: [QualityPairRequest]) async -> QualityComparisonRun {
        guard policy.validationErrors().isEmpty else {
            return QualityComparisonRun(
                comparisons: [],
                counts: QualityComparisonCounts(
                    planned: 0,
                    attempted: 0,
                    applied: 0,
                    skipped: requests.count,
                    failed: 0
                ),
                degradationReason: .invalidJudgment
            )
        }

        let plannedRequests = Array(requests.prefix(policy.maxQwenRequests))
        var counts = QualityComparisonCounts(planned: plannedRequests.count)
        counts.skipped = requests.count - plannedRequests.count
        var comparisons: [QualityPairComparison] = []
        var degradationReason: QualityDegradationReason?
        let started = ContinuousClock.now

        for (index, request) in plannedRequests.enumerated() {
            guard !Task.isCancelled else {
                counts.skipped += plannedRequests.count - index
                degradationReason = .cancellation
                break
            }
            guard elapsed(since: started) < policy.qwenWallBudget else {
                counts.skipped += plannedRequests.count - index
                degradationReason = .deadlineExceeded
                break
            }

            counts.attempted += 1
            switch await compare(request) {
            case let .applied(comparison):
                comparisons.append(comparison)
                counts.applied += 1
            case .stale, .failed:
                counts.failed += 1
                degradationReason = degradationReason ?? .invalidJudgment
            case .deadline:
                counts.failed += 1
                degradationReason = degradationReason ?? .deadlineExceeded
            case .cancelled:
                counts.skipped += plannedRequests.count - index - 1
                degradationReason = degradationReason ?? .cancellation
            }
        }

        return QualityComparisonRun(
            comparisons: comparisons,
            counts: counts,
            degradationReason: degradationReason
        )
    }

    private enum ComparisonOutcome: Sendable {
        case applied(QualityPairComparison)
        case stale
        case deadline
        case cancelled
        case failed
    }

    private func compare(_ request: QualityPairRequest) async -> ComparisonOutcome {
        do {
            let judgment = try await Self.withDeadline(
                nanoseconds: Self.nanoseconds(policy.qwenRequestDeadline),
                operation: { try await self.judge.judge(request) },
                onTimeout: { Task { await self.judge.cancel(generation: request.generation) } },
                onCancel: { Task { await self.judge.cancel(generation: request.generation) } }
            )
            guard judgment.requestID == request.requestID,
                  judgment.generation == request.generation
            else { return .stale }
            return .applied(
                QualityPairComparison(first: request.first, second: request.second, judgment: judgment)
            )
        } catch is DeadlineExceeded {
            return .deadline
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed
        }
    }

    private func elapsed(since started: ContinuousClock.Instant) -> TimeInterval {
        let duration = started.duration(to: .now)
        let components = duration.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }

    private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        UInt64(max(1, seconds * 1_000_000_000))
    }

    private struct DeadlineExceeded: Error {}

    private static func withDeadline<T: Sendable>(
        nanoseconds: UInt64,
        operation: @escaping @Sendable () async throws -> T,
        onTimeout: @escaping @Sendable () -> Void,
        onCancel: @escaping @Sendable () -> Void
    ) async throws -> T {
        let race = DeadlineRace<T>()
        return try await withTaskCancellationHandler(operation: {
            let operationTask = Task.detached {
                do {
                    try race.finish(.success(await operation()))
                } catch {
                    race.finish(.failure(error))
                }
            }
            let timeoutTask = Task.detached {
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                    race.finish(.failure(DeadlineExceeded()), beforeResume: onTimeout)
                } catch {
                    // The losing timer is cancelled by DeadlineRace.
                }
            }
            race.install(operationTask: operationTask, timeoutTask: timeoutTask)
            if Task.isCancelled {
                race.finish(.failure(CancellationError()), beforeResume: onCancel)
            }
            return try await withCheckedThrowingContinuation { continuation in
                race.install(continuation)
            }
        }, onCancel: {
            race.finish(.failure(CancellationError()), beforeResume: onCancel)
        })
    }

    private final class DeadlineRace<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Value, Error>?
        private var continuation: CheckedContinuation<Value, Error>?
        private var operationTask: Task<Void, Never>?
        private var timeoutTask: Task<Void, Never>?

        func install(_ continuation: CheckedContinuation<Value, Error>) {
            lock.lock()
            guard let result else {
                self.continuation = continuation
                lock.unlock()
                return
            }
            lock.unlock()
            continuation.resume(with: result)
        }

        func install(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
            lock.lock()
            guard result == nil else {
                lock.unlock()
                operationTask.cancel()
                timeoutTask.cancel()
                return
            }
            self.operationTask = operationTask
            self.timeoutTask = timeoutTask
            lock.unlock()
        }

        func finish(_ result: Result<Value, Error>, beforeResume: (() -> Void)? = nil) {
            lock.lock()
            guard self.result == nil else {
                lock.unlock()
                return
            }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            let operationTask = self.operationTask
            self.operationTask = nil
            let timeoutTask = self.timeoutTask
            self.timeoutTask = nil
            lock.unlock()
            beforeResume?()
            operationTask?.cancel()
            timeoutTask?.cancel()
            continuation?.resume(with: result)
        }
    }
}
