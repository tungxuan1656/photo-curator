import Foundation
import Observation

/// Task-3 coordinator bridge. Moved from AppModel.swift (Task-2 wiring) and
/// merged with the feat-006 Task-3 spec: owns the run Task, applies
/// coordinator progress on the MainActor, derives the unavailable bucket from
/// coordinator progress only, and reports completion via `onCompleted`
/// (feat-012 owns automatic routing; completion here does NOT navigate).
/// Views read `state`; navigation stays in AppModel (no path access here).
@MainActor
@Observable
final class ProcessingModel {
    private(set) var state: ProcessingState = .idle
    var progress: ProcessingProgress = .zero

    private var task: Task<Void, Never>?
    private let coordinator: SelectionSessionCoordinator
    private let checkpointStore: SessionCheckpointStore
    private let authorization: @Sendable () async -> PhotoLibraryAuthorization
    private var request: SelectionRequest?
    private var sourceAssets: [PhotoAsset] = []
    private var backgrounded = false
    /// Deferred completion hook, currently unassigned (no auto-routing; feat-012
    /// owns automatic result-present routing). Task 2/feat-009 semantics preserved.
    var onCompleted: ((SessionID) -> Void)?

    init(
        coordinator: SelectionSessionCoordinator,
        checkpointStore: SessionCheckpointStore,
        authorization: @escaping @Sendable () async -> PhotoLibraryAuthorization
    ) {
        self.coordinator = coordinator
        self.checkpointStore = checkpointStore
        self.authorization = authorization
    }

    var sessionID: SessionID? {
        request?.sessionID
    }

    /// True while a run task exists (starting, running, or finishing).
    /// AppModel's start gate reads this so a double-tap cannot desync the route.
    var isRunning: Bool {
        task != nil
    }

    /// Discard path: waits for the run task to finish so the pipeline's final
    /// cancel checkpoint lands BEFORE the caller deletes data.
    func awaitTermination() async {
        await task?.value
    }

    func start(request: SelectionRequest, sourceAssets: [PhotoAsset]) {
        guard task == nil else { return }
        self.request = request
        self.sourceAssets = sourceAssets
        backgrounded = false
        progress = .zero
        state = .preparing
        task = Task { await execute(request: request, sourceAssets: sourceAssets) }
    }

    /// Synchronous <250 ms UI ack: `.cancelling` renders before the run Task
    /// observes cancellation. No new expensive work starts after cancel.
    func cancel() {
        if case .running = state {
            state = .cancelling
        }
        task?.cancel()
    }

    /// Retry resumes failed work via the pipeline resume path (checkpoint
    /// reuse); it never clears valid work.
    func retry() {
        guard task == nil, let request else { return }
        start(request: request, sourceAssets: sourceAssets)
    }

    /// Foreground resume: retries ONLY when paused/cancelled with a saved checkpoint.
    /// Never restarts completed jobs.
    func resumeIfPaused() async {
        guard let request else { return }
        switch state {
        case .paused, .cancelled:
            break
        case .idle, .preparing, .running, .cancelling, .completed, .failed:
            return
        }
        guard (try? await checkpointStore.load(sessionID: request.sessionID)) != nil else { return }
        retry()
    }

    /// Background path: writes a safe checkpoint now (preserving already-completed
    /// IDs), then cancels the run so no new work starts while backgrounded.
    /// The pipeline's cancel path checkpoints again before throwing, so resume
    /// never drops completed work.
    func pauseForBackground() async {
        switch state {
        case .preparing, .running:
            break
        case .idle, .cancelling, .paused, .completed, .cancelled, .failed:
            return
        }
        guard let request else { return }
        let completed = (try? await checkpointStore.load(sessionID: request.sessionID))?.completedAssetIDs ?? []
        let stage: ProcessingStage
        if case let .running(live) = state {
            stage = live.stage
        } else {
            stage = .loading
        }
        backgrounded = true
        await coordinator.checkpointNow(sessionID: request.sessionID, completed: completed, stage: stage)
        task?.cancel()
    }

    private func execute(request: SelectionRequest, sourceAssets: [PhotoAsset]) async {
        defer {
            backgrounded = false
            task = nil
        }
        do {
            // Live permission gate at processing start: a cached AppModel flag
            // can go stale when access is revoked mid-flow, which would
            // otherwise degrade silently into per-asset failures.
            let status = await authorization()
            if status == .denied || status == .restricted {
                state = .failed(SelectionSessionCoordinator.permissionError())
                return
            }
            // Counts come from coordinator progress end-to-end: the real
            // analyzed tally (BatchProgress.analyzed) and the unavailable
            // bucket. The run result carries neither count (unavailable assets
            // land in the engine's rejected set), so engine counts are never
            // used here. Fallback is the last known progress count, never a literal.
            _ = try await coordinator.run(request: request, sourceAssets: sourceAssets) { [weak self] update in
                await self?.apply(update)
            }
            let analyzed: Int
            let unavailable: Int
            if case let .running(current) = state {
                analyzed = current.analyzedCount
                unavailable = current.unavailableCount
            } else {
                analyzed = progress.analyzedCount
                unavailable = progress.unavailableCount
            }
            state = .completed(sessionID: request.sessionID, analyzed: analyzed, unavailable: unavailable)
            onCompleted?(request.sessionID)
        } catch {
            if case SelectionError.cancelled = error {
                if backgrounded {
                    state = .paused(reason: "Curation paused. Progress is saved.")
                } else {
                    state = .cancelled
                }
            } else if error is CancellationError {
                if backgrounded {
                    state = .paused(reason: "Curation paused. Progress is saved.")
                } else {
                    state = .cancelled
                }
            } else {
                // Failure mapping carries the last known progress counts, never literals.
                let analyzed: Int
                let unavailable: Int
                if case let .running(current) = state {
                    analyzed = current.analyzedCount
                    unavailable = current.unavailableCount
                } else {
                    analyzed = progress.analyzedCount
                    unavailable = progress.unavailableCount
                }
                state = .failed(SelectionSessionCoordinator.userError(
                    for: error,
                    unavailable: unavailable,
                    analyzed: analyzed
                ))
            }
        }
    }

    private func apply(_ update: ProcessingProgress) {
        // Terminal states never accept running updates: a late delivery racing
        // completion/cancel must not revert to .running (which would hide
        // Continue, break cancel, and corrupt counts). Terminal states exit
        // only via explicit retry/discard/start.
        switch state {
        case .completed, .cancelled, .failed, .cancelling, .paused:
            return
        case .idle, .preparing:
            progress = update
            state = .running(update)
        case let .running(current):
            // Stage transitions always win and re-baseline the fraction, so the
            // grouping emit (fraction 0) is never rejected by the determinate
            // gate. Same-stage determinate updates stay monotonic.
            if update.stage != current.stage {
                progress = update
                state = .running(update)
                return
            }
            guard update.overallFraction + 0.0001 >= current.overallFraction else { return }
            progress = update
            state = .running(update)
        }
    }
}
