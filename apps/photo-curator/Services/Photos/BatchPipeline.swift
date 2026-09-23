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
/// `similarities` holds transient run-local feature prints: never persisted, never
/// cached, released after `similarityEdges(for:)` runs for selection.
struct BatchResult: Sendable {
    let analyses: [AssetID: PhotoAnalysis]
    let unavailableIDs: [AssetID]
    let similarities: [AssetID: ImageSimilarityArtifact]

    /// Raw Vision distances in stable candidate order. Missing artifacts skip
    /// that pair; per-pair distance failure skips that edge. Throws only on
    /// task cancellation, so one bad signal never fails the session.
    func similarityEdges(for candidates: [SimilarityCandidate]) throws -> [SimilarityEdge] {
        var edges: [SimilarityEdge] = []
        edges.reserveCapacity(candidates.count)
        for candidate in candidates {
            try Task.checkCancellation()
            guard let left = similarities[candidate.first], let right = similarities[candidate.second] else { continue }
            guard let distance = try? left.distance(to: right) else { continue }
            edges.append(SimilarityEdge(first: candidate.first, second: candidate.second, distance: distance))
        }
        return edges
    }
}

// swiftlint:disable type_body_length
/// Bounded batch analysis with checkpoint/resume.
///
/// Lanes: `performance.maxConcurrentImageRequests` (2). Batches:
/// `performance.analysisBatchSize` (32). Checkpoints: every
/// `performance.checkpointEveryAssets` (25) or `performance.checkpointEverySeconds`
/// (10 s), plus a cancel/exit checkpoint so resume never drops completed work.
/// Version and asset-revision reuse is owned by `AnalysisCache` (stale rows read
/// as miss); a stale checkpoint (analysisVersion mismatch) is ignored so a
/// version bump re-queues instead of marking prior work unavailable.
final class BatchPipeline: Sendable {
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let cache: any AnalysisCache
    private let checkpoints: SessionCheckpointStore
    private let config: AppConfiguration
    private let pressure: MemoryPressureObserver?

    init(
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        cache: any AnalysisCache,
        checkpoints: SessionCheckpointStore,
        config: AppConfiguration = .default,
        pressure: MemoryPressureObserver? = nil
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.cache = cache
        self.checkpoints = checkpoints
        self.config = config
        self.pressure = pressure
    }

    // swiftlint:disable:next function_body_length
    func run(
        assets: [PhotoAsset],
        sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity? = nil,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult {
        let total = assets.count
        guard total > 0 else { throw SelectionError.invalidInput }
        // Fresh pressure baseline per run: a sticky warning/critical from a
        // prior run must not throttle this one; mid-run warnings re-escalate.
        pressure?.markRecovered()
        var state = RunState(total: total, progressInterval: progressInterval)
        do {
            // Resume-first WITHOUT dropping work: checkpoint IDs reload from cache.
            // Cache hit → FULL analyses (kept). A completed ID with a missing,
            // stale, or corrupt row is requeued; only an explicitly recorded
            // load/analyzer failure remains unavailable.
            let queue = await restore(
                assets: assets,
                sessionID: sessionID,
                qualityIdentity: qualityIdentity,
                state: &state
            )
            emitProgress(state: &state, progress: progress)
            // Post-restore check THROUGH the catch path: a cache-only cancelled
            // run checkpoints first, then throws — never returns BatchResult.
            try Task.checkCancellation()
            try await throwIfMemoryCritical(
                sessionID: sessionID,
                qualityIdentity: qualityIdentity,
                state: &state
            )
            // Pressure-aware stride: batch size re-read at every boundary so a
            // warning arriving mid-run shrinks the next batch (32→16).
            var cursor = 0
            while cursor < queue.count {
                try Task.checkCancellation()
                try await throwIfMemoryCritical(
                    sessionID: sessionID,
                    qualityIdentity: qualityIdentity,
                    state: &state
                )
                applyPressurePolicy()
                let batchSize = effectiveBatchSize()
                let batch = Array(queue[cursor ..< min(cursor + batchSize, queue.count)])
                cursor += batch.count
                try await drain(batch, state: &state, progress: progress)
                await checkpointIfDue(
                    sessionID: sessionID,
                    qualityIdentity: qualityIdentity,
                    state: &state
                )
            }
            // Late-cancel check THROUGH the catch path: cancel after the final
            // batch still checkpoints first, then throws — never success.
            try Task.checkCancellation()
            // Spec'd final update: force-fires so completed == total is always
            // delivered; every other emission respects the 4 Hz gate.
            emitProgress(state: &state, progress: progress, force: true)
            await saveCheckpoint(
                sessionID: sessionID,
                qualityIdentity: qualityIdentity,
                completed: state.completedIDs,
                unavailable: state.unavailable
            )
            // Cancel during the final save routes through the catch path too.
            try Task.checkCancellation()
            return BatchResult(
                analyses: state.analyses,
                unavailableIDs: state.unavailable,
                similarities: state.similarities
            )
        } catch {
            // Cancel-after-checkpoint: completed work is checkpointed before the
            // throw so resume keeps it. Cancellation maps exactly to .cancelled.
            await saveCheckpoint(
                sessionID: sessionID,
                qualityIdentity: qualityIdentity,
                completed: state.completedIDs,
                unavailable: state.unavailable
            )
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
        qualityIdentity: QualityCheckpointIdentity? = nil,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult {
        // Resume = run with checkpoint reload: run() restores FULL analyses from
        // cache for checkpoint IDs and preserves prior unavailableIDs, so resume
        // never drops completed work and never re-fetches it.
        try await run(
            assets: assets,
            sessionID: sessionID,
            qualityIdentity: qualityIdentity,
            progress: progress
        )
    }

    // MARK: - Run loop helpers

    /// Local mutable tally. Lives on the parent task only; lanes return outcomes.
    private struct RunState {
        let total: Int
        let progressInterval: TimeInterval
        var analyses: [AssetID: PhotoAnalysis] = [:]
        var similarities: [AssetID: ImageSimilarityArtifact] = [:]
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

    private func restore(
        assets: [PhotoAsset],
        sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity?,
        state: inout RunState
    ) async -> [PhotoAsset] {
        let unavailableIDs = await checkpointUnavailableIDs(for: sessionID, qualityIdentity: qualityIdentity)
        var queue: [PhotoAsset] = []
        var cacheHits: [PhotoAsset] = []
        for asset in assets {
            if let hit = await cache.analysis(for: asset.id, assetRevision: asset.modificationFingerprint) {
                state.analyses[asset.id] = hit
                cacheHits.append(asset)
            } else if unavailableIDs.contains(asset.id), state.unavailableSet.insert(asset.id).inserted {
                state.unavailable.append(asset.id)
            } else {
                // This includes checkpoint-completed IDs. A checkpoint is a
                // completion hint, not durable fact availability.
                queue.append(asset)
            }
        }
        state.completed = state.total - queue.count
        await rebuildSimilarities(cacheHits, state: &state)
        return queue
    }

    /// Rebuilds deliberately non-persisted prints for cache hits in the
    /// existing bounded lanes. Failures store nothing and never touch
    /// completed counts, checkpoints, or unavailable.
    private func rebuildSimilarities(_ assets: [PhotoAsset], state: inout RunState) async {
        let laneCount = max(1, effectiveLaneCount())
        for start in stride(from: 0, to: assets.count, by: laneCount) {
            let end = min(start + laneCount, assets.count)
            await withTaskGroup(of: (AssetID, ImageSimilarityArtifact?).self) { group in
                for asset in assets[start ..< end] {
                    group.addTask { [imageLoader, analyzer] in
                        guard let cgImage = try? await imageLoader.analysisImage(for: asset.id) else { return (
                            asset.id,
                            nil
                        ) }
                        let artifact = try? await analyzer.similarityArtifact(for: AnalysisInput(
                            assetID: asset.id,
                            image: cgImage,
                            isScreenshotSubtype: false
                        ))
                        return (asset.id, artifact)
                    }
                }
                for await(id, artifact) in group {
                    if let artifact {
                        state.similarities[id] = artifact
                    }
                }
            }
            if Task.isCancelled {
                return
            }
        }
    }

    /// Drains one batch through bounded lanes, folding each outcome as it lands
    /// so cancel-after-checkpoint keeps partial-batch work.
    private func drain(
        _ batch: [PhotoAsset],
        state: inout RunState,
        progress: (BatchProgress) -> Void
    ) async throws {
        let laneCount = effectiveLaneCount()
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
        case let .analyzed(output, assetRevision):
            state.analyses[output.analysis.assetID] = output.analysis
            await cache.store(output.analysis, assetRevision: assetRevision)
            if let similarity = output.similarity {
                state.similarities[output.analysis.assetID] = similarity
            }
        case let .unavailable(id):
            if state.unavailableSet.insert(id).inserted {
                state.unavailable.append(id)
            }
        }
        state.completed += 1
        state.completedSinceCheckpoint += 1
    }

    /// Checkpoint at batch edges: every 25 assets or 10 s, whichever first.
    private func checkpointIfDue(
        sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity?,
        state: inout RunState
    ) async {
        let dueCount = state.completedSinceCheckpoint >= config.performance.checkpointEveryAssets
        let dueTime = Date().timeIntervalSince(state.lastCheckpoint) >= config.performance.checkpointEverySeconds
        guard dueCount || dueTime else { return }
        await saveCheckpoint(
            sessionID: sessionID,
            qualityIdentity: qualityIdentity,
            completed: state.completedIDs,
            unavailable: state.unavailable
        )
        state.completedSinceCheckpoint = 0
        state.lastCheckpoint = Date()
    }

    // MARK: - Memory pressure policy (performance §3: slow speed, never quality)

    /// Batch size under pressure: warning shrinks toward 16 (the low end of
    /// the 16–64 tuning span); critical never starts a new batch (the caller
    /// throws `.memoryCritical` first). Completed analysis is never dropped.
    private func effectiveBatchSize() -> Int {
        guard pressure?.level == .warning else {
            return config.performance.analysisBatchSize
        }
        return min(config.performance.analysisBatchSize, 16)
    }

    /// Lane count under pressure: warning collapses toward 1 (the constrained
    /// concurrency); completed analysis is never dropped and selection quality
    /// never changes — only speed degrades.
    private func effectiveLaneCount() -> Int {
        guard pressure?.level == .warning else {
            return config.performance.maxConcurrentImageRequests
        }
        return 1
    }

    /// Warning policy: stop speculative preheat. Decoded images already
    /// release by scope exit in `processOne`; nothing retained to clear here.
    private func applyPressurePolicy() {
        guard pressure?.level != .normal else { return }
        (imageLoader as? ImageLoaderService)?.stopPreheat()
    }

    /// Critical policy: checkpoint completed work, then throw `.memoryCritical`
    /// so the run pauses resumably instead of running until an OS kill.
    private func throwIfMemoryCritical(
        sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity?,
        state: inout RunState
    ) async throws {
        guard pressure?.level == .critical else { return }
        (imageLoader as? ImageLoaderService)?.stopPreheat()
        await saveCheckpoint(
            sessionID: sessionID,
            qualityIdentity: qualityIdentity,
            completed: state.completedIDs,
            unavailable: state.unavailable
        )
        state.completedSinceCheckpoint = 0
        state.lastCheckpoint = Date()
        throw SelectionError.memoryCritical
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
        let input = AnalysisInput(
            assetID: asset.id,
            image: cgImage,
            isScreenshotSubtype: asset.mediaSubtype == .screenshot
        )
        do {
            let output = try await analyzer.analyze(input)
            // Post-analysis cancel check: a cancel landing during Vision work
            // must not record as success — route through .cancelled.
            try Task.checkCancellation()
            return .analyzed(output, asset.modificationFingerprint)
        } catch SelectionError.cancelled {
            throw SelectionError.cancelled
        } catch is CancellationError {
            throw SelectionError.cancelled
        } catch {
            // Whole-decode .internal for this asset: unavailable, batch continues.
            return .unavailable(asset.id)
        }
    }

    private func checkpointUnavailableIDs(
        for sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity?
    ) async -> Set<AssetID> {
        guard let checkpoint = try? await checkpoints.load(sessionID: sessionID) else {
            return []
        }
        // Stale checkpoint (version bump since it was written): ignore so prior
        // work re-queues through the version-gated cache instead of being
        // marked unavailable when its old cache rows read as miss.
        guard checkpoint.analysisVersion == PhotoAnalysis.currentVersion else {
            return []
        }
        guard checkpoint.qualityIdentity == qualityIdentity else {
            return []
        }
        return Set(checkpoint.unavailableAssetIDs)
    }

    private func saveCheckpoint(
        sessionID: SessionID,
        qualityIdentity: QualityCheckpointIdentity?,
        completed: [AssetID],
        unavailable: [AssetID]
    ) async {
        let stub = SessionCheckpoint(
            sessionID: sessionID,
            stage: "analysis",
            completedAssetIDs: completed,
            unavailableAssetIDs: unavailable,
            configVersion: config.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            qualityIdentity: qualityIdentity,
            updatedAt: Date()
        )
        try? await checkpoints.save(stub) // best-effort; cache rows remain truth for redo
    }

    private enum AssetOutcome: Sendable {
        case analyzed(ImageAnalysisOutput, AssetModificationFingerprint)
        case unavailable(AssetID)
    }
}

// swiftlint:enable type_body_length
