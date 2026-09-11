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
    private var request: SelectionRequest?
    private var sourceAssets: [PhotoAsset] = []
    private var backgrounded = false
    /// Deferred completion hook, currently unassigned (no auto-routing; feat-012
    /// owns automatic result-present routing). Task 2/feat-009 semantics preserved.
    var onCompleted: ((SessionID) -> Void)?

    init(coordinator: SelectionSessionCoordinator, checkpointStore: SessionCheckpointStore) {
        self.coordinator = coordinator
        self.checkpointStore = checkpointStore
    }

    var sessionID: SessionID? {
        request?.sessionID
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
        do {
            let result = try await coordinator.run(request: request, sourceAssets: sourceAssets) { [weak self] update in
                await self?.apply(update)
            }
            // Unavailable is sourced from BatchResult via coordinator progress —
            // SelectionResult carries no unavailable count, so never derive it here.
            // Fallback is the last known progress count, never a literal.
            let unavailable: Int
            if case let .running(current) = state {
                unavailable = current.unavailableCount
            } else {
                unavailable = progress.unavailableCount
            }
            let analyzed = result.selectedAssetIDs.count + result.rejectedAssetIDs.count
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
                // Failure mapping carries the last known progress count, never a literal.
                let unavailable: Int
                if case let .running(current) = state {
                    unavailable = current.unavailableCount
                } else {
                    unavailable = progress.unavailableCount
                }
                state = .failed(SelectionSessionCoordinator.userError(for: error, unavailable: unavailable))
            }
        }
        backgrounded = false
        task = nil
    }

    private func apply(_ update: ProcessingProgress) {
        if case let .running(current) = state, update.overallFraction + 0.0001 < current.overallFraction {
            return
        }
        progress = update
        state = .running(update)
    }
}
