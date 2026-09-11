import CoreGraphics
import Foundation

/// Throttled progress snapshot. Emitted from the parent task only, at most
/// `performance.progressMaxHertz` (4 Hz) via a local timestamp gate.
struct BatchProgress: Sendable {
    let completed: Int
    let total: Int
    let analyzed: Int
    let unavailable: Int
}

/// Batch outcome. One bad asset lands in `unavailableIDs` and never fails the batch.
struct BatchResult: Sendable {
    let analyses: [AssetID: PhotoAnalysis]
    let unavailableIDs: [AssetID]
}

/// Bounded batch analysis with checkpoint/resume.
///
/// Lanes: `performance.maxConcurrentImageRequests` (2). Batches:
/// `performance.analysisBatchSize` (32). Checkpoints: every
/// `performance.checkpointEveryAssets` (25) or `performance.checkpointEverySeconds`
/// (10 s), plus a cancel/exit checkpoint so resume never drops completed work.
/// Version reuse is owned by `AnalysisCache` (stale rows read as miss); a stale
/// checkpoint (analysisVersion mismatch) is ignored so a version bump re-queues
/// instead of marking prior work unavailable.
final class BatchPipeline: Sendable {
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let cache: any AnalysisCache
    private let checkpoints: SessionCheckpointStore
    private let config: AppConfiguration

    init(
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        cache: any AnalysisCache,
        checkpoints: SessionCheckpointStore,
        config: AppConfiguration = .default
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.cache = cache
        self.checkpoints = checkpoints
        self.config = config
    }

    func run(
        assets: [PhotoAsset],
        sessionID: SessionID,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult {
        let total = assets.count
        guard total > 0 else { throw SelectionError.invalidInput }
        var state = RunState(total: total, progressInterval: progressInterval)
        do {
            // Resume-first WITHOUT dropping work: checkpoint IDs reload from cache.
            // Cache hit → FULL analyses (kept). Checkpoint ID with no cache row →
            // prior unavailable (preserved, never re-fetched). Only the remainder queues.
            let queue = await restore(assets: assets, sessionID: sessionID, state: &state)
            emitProgress(state: &state, progress: progress)
            // Post-restore check THROUGH the catch path: a cache-only cancelled
            // run checkpoints first, then throws — never returns BatchResult.
            try Task.checkCancellation()
            for batchStart in stride(from: 0, to: queue.count, by: config.performance.analysisBatchSize) {
                try Task.checkCancellation()
                let batch = Array(queue[batchStart ..< min(
                    batchStart + config.performance.analysisBatchSize,
                    queue.count
                )])
                try await drain(batch, state: &state, progress: progress)
                await checkpointIfDue(sessionID: sessionID, state: &state)
            }
            // Late-cancel check THROUGH the catch path: cancel after the final
            // batch still checkpoints first, then throws — never success.
            try Task.checkCancellation()
            // Spec'd final update: force-fires so completed == total is always
            // delivered; every other emission respects the 4 Hz gate.
            emitProgress(state: &state, progress: progress, force: true)
            await saveCheckpoint(sessionID: sessionID, completed: state.completedIDs)
            // Cancel during the final save routes through the catch path too.
            try Task.checkCancellation()
            return BatchResult(analyses: state.analyses, unavailableIDs: state.unavailable)
        } catch {
            // Cancel-after-checkpoint: completed work is checkpointed before the
            // throw so resume keeps it. Cancellation maps exactly to .cancelled.
            await saveCheckpoint(sessionID: sessionID, completed: state.completedIDs)
            emitProgress(state: &state, progress: progress)
            if error is CancellationError {
                throw SelectionError.cancelled
            }
            throw error
        }
    }

    func resume(
        assets: [PhotoAsset],
        sessionID: SessionID,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult {
        // Resume = run with checkpoint reload: run() restores FULL analyses from
        // cache for checkpoint IDs and preserves prior unavailableIDs, so resume
        // never drops completed work and never re-fetches it.
        try await run(assets: assets, sessionID: sessionID, progress: progress)
    }

    // MARK: - Run loop helpers

    /// Local mutable tally. Lives on the parent task only; lanes return outcomes.
    private struct RunState {
        let total: Int
        let progressInterval: TimeInterval
        var analyses: [AssetID: PhotoAnalysis] = [:]
        var unavailable: [AssetID] = []
        var unavailableSet = Set<AssetID>()
        var completed = 0
        var completedSinceCheckpoint = 0
        var lastCheckpoint = Date()
        var lastProgressDate = Date.distantPast

        var snapshot: BatchProgress {
            BatchProgress(completed: completed, total: total, analyzed: analyses.count, unavailable: unavailable.count)
        }

        var completedIDs: [AssetID] {
            Array(analyses.keys) + unavailable
        }
    }

    private var progressInterval: TimeInterval {
        1.0 / max(1.0, config.performance.progressMaxHertz)
    }

    /// Single 4 Hz gate for EVERY progress emission. Initial, per-result, and
    /// cancel/error paths use force:false; only the spec'd final update forces.
    private func emitProgress(
        state: inout RunState,
        progress: (BatchProgress) -> Void,
        force: Bool = false
    ) {
        let now = Date()
        guard force || now.timeIntervalSince(state.lastProgressDate) >= state.progressInterval else { return }
        progress(state.snapshot)
        state.lastProgressDate = now
    }

    private func restore(assets: [PhotoAsset], sessionID: SessionID, state: inout RunState) async -> [PhotoAsset] {
        let done = await completedIDs(for: sessionID)
        var queue: [PhotoAsset] = []
        for asset in assets {
            if done.contains(asset.id), let hit = await cache.analysis(for: asset.id) {
                state.analyses[asset.id] = hit
            } else if done.contains(asset.id), state.unavailableSet.insert(asset.id).inserted {
                state.unavailable.append(asset.id)
            } else if let hit = await cache.analysis(for: asset.id) {
                state.analyses[asset.id] = hit
            } else {
                queue.append(asset)
            }
        }
        state.completed = state.total - queue.count
        return queue
    }

    /// Drains one batch through bounded lanes, folding each outcome as it lands
    /// so cancel-after-checkpoint keeps partial-batch work.
    private func drain(
        _ batch: [PhotoAsset],
        state: inout RunState,
        progress: (BatchProgress) -> Void
    ) async throws {
        let laneCount = config.performance.maxConcurrentImageRequests
        try await withThrowingTaskGroup(of: AssetOutcome.self) { group in
            var index = 0
            func submitNext() {
                guard index < batch.count else { return }
                let asset = batch[index]
                index += 1
                group.addTask { try await self.processOne(asset) }
            }
            for _ in 0 ..< min(laneCount, batch.count) {
                submitNext()
            }
            for try await outcome in group {
                if Task.isCancelled {
                    group.cancelAll()
                }
                await record(outcome, state: &state)
                // 4 Hz gate: single fire-if-due helper in the result-collection
                // loop; progress emitted from the parent.
                emitProgress(state: &state, progress: progress)
                if Task.isCancelled {
                    group.cancelAll(); throw SelectionError.cancelled
                }
                submitNext()
            }
        }
    }

    private func record(_ outcome: AssetOutcome, state: inout RunState) async {
        switch outcome {
        case let .analyzed(analysis):
            state.analyses[analysis.assetID] = analysis
            await cache.store(analysis)
        case let .unavailable(id):
            if state.unavailableSet.insert(id).inserted {
                state.unavailable.append(id)
            }
        }
        state.completed += 1
        state.completedSinceCheckpoint += 1
    }

    /// Checkpoint at batch edges: every 25 assets or 10 s, whichever first.
    private func checkpointIfDue(sessionID: SessionID, state: inout RunState) async {
        let dueCount = state.completedSinceCheckpoint >= config.performance.checkpointEveryAssets
        let dueTime = Date().timeIntervalSince(state.lastCheckpoint) >= config.performance.checkpointEverySeconds
        guard dueCount || dueTime else { return }
        await saveCheckpoint(sessionID: sessionID, completed: state.completedIDs)
        state.completedSinceCheckpoint = 0
        state.lastCheckpoint = Date()
    }

    private func processOne(_ asset: PhotoAsset) async throws -> AssetOutcome {
        try Task.checkCancellation()
        let cgImage: CGImage
        do {
            cgImage = try await imageLoader.analysisImage(for: asset.id)
        } catch SelectionError.cancelled {
            throw SelectionError.cancelled
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            // Loader .invalidInput/.internal (missing ID, iCloud unavailable,
            // transient I/O): counts as unavailable, never fails the batch.
            return .unavailable(asset.id)
        }
        try Task.checkCancellation()
        // The synchronous Vision work with its autoreleasepool lives inside the
        // analyzer — never autoreleasepool { await … } here. The image releases
        // by scope exit: no stored CGImage outlives this call.
        let input = AnalysisInput(assetID: asset.id, image: cgImage)
        do {
            let analysis = try await analyzer.analyze(input)
            // Post-analysis cancel check: a cancel landing during Vision work
            // must not record as success — route through .cancelled.
            try Task.checkCancellation()
            return .analyzed(analysis)
        } catch SelectionError.cancelled {
            throw SelectionError.cancelled
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            // Whole-decode .internal for this asset: unavailable, batch continues.
            return .unavailable(asset.id)
        }
    }

    private func completedIDs(for sessionID: SessionID) async -> Set<AssetID> {
        guard let checkpoint = try? await checkpoints.load(sessionID: sessionID) else {
            return []
        }
        // Stale checkpoint (version bump since it was written): ignore so prior
        // work re-queues through the version-gated cache instead of being
        // marked unavailable when its old cache rows read as miss.
        guard checkpoint.analysisVersion == PhotoAnalysis.currentVersion else {
            return []
        }
        return Set(checkpoint.completedAssetIDs)
    }

    private func saveCheckpoint(sessionID: SessionID, completed: [AssetID]) async {
        let stub = SessionCheckpoint(
            sessionID: sessionID,
            stage: "analysis",
            completedAssetIDs: completed,
            configVersion: config.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            updatedAt: Date()
        )
        try? await checkpoints.save(stub) // best-effort; cache rows remain truth for redo
    }

    private enum AssetOutcome: Sendable {
        case analyzed(PhotoAnalysis)
        case unavailable(AssetID)
    }
}
