import CoreGraphics

// swiftlint:disable file_length
import Foundation
import OSLog

struct SelectionRequest: Sendable {
    let sessionID: SessionID
    let sourceAssetIDs: [AssetID]
    let config: AppConfiguration
    let qualityMode: QualityMode
    let qualityModelAvailableAtStart: Bool

    init(
        sessionID: SessionID,
        sourceAssetIDs: [AssetID],
        config: AppConfiguration,
        qualityMode: QualityMode = .native,
        qualityModelAvailableAtStart: Bool = false
    ) {
        self.sessionID = sessionID
        self.sourceAssetIDs = sourceAssetIDs
        self.config = config
        self.qualityMode = qualityMode
        self.qualityModelAvailableAtStart = qualityModelAvailableAtStart
    }
}

/// Canonical stored stages — data-model.md §10 raw values reused verbatim.
/// This enum is the single stored/checkpoint vocabulary; do NOT add user-phase cases here.
enum ProcessingStage: String, Codable, Sendable {
    case loading, analysis, clustering, momentDetection, ranking, finalSelection
}

struct ProcessingProgress: Sendable, Equatable {
    var stage: ProcessingStage
    var completedUnits: Int
    var totalUnits: Int
    var downloadingCount: Int
    var unavailableCount: Int
    var analyzedCount: Int
    var overallFraction: Double
    static var zero: Self {
        Self(
            stage: .loading, completedUnits: 0, totalUnits: 0,
            downloadingCount: 0, unavailableCount: 0, analyzedCount: 0, overallFraction: 0
        )
    }
}

enum ProcessingState: Equatable {
    case idle
    case preparing
    case running(ProcessingProgress)
    case cancelling
    case paused
    case completed(sessionID: SessionID, analyzed: Int, unavailable: Int)
    case cancelled
    case failed(UserFacingError)
}

/// Small typed recovery actions for the gate paths only (no error-policy hierarchy).
enum RecoveryAction: Equatable, Sendable {
    case retry
    case openSettings
    case continueWithoutUnavailable
    case discard
    case goHome
}

struct UserFacingError: Equatable {
    let code: UserFacingErrorCode
    let primary: RecoveryAction
    let secondary: RecoveryAction
}

enum UserFacingErrorCode: Equatable, Sendable {
    case curationPaused
    case connectionNeeded
    case unableToContinue
    case photosAccessNeeded
}

// swiftlint:disable:next type_body_length
actor SelectionSessionCoordinator {
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let analysisCache: any AnalysisCache
    private let checkpointStore: SessionCheckpointStore
    private let pipeline: BatchPipeline
    private let engine: SelectionEngine
    private let tierCProvider: any VisualEmbeddingProvider
    private let semanticJuryProvider: any SemanticJuryProvider
    private let semanticJuryAvailability: @Sendable () -> Bool
    private let qualityRunner: QualityCurationRunner?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "selection"
    )

    private var lastEmit = Date.distantPast
    private var lastFraction = 0.0
    private var lastStage: ProcessingStage?
    private var lastProgress: ProcessingProgress?
    private var pendingDownloadIDs = Set<String>()
    private var downloadObserver: NSObjectProtocol?
    /// Run-lifetime scope: bumped per run() so late deliveries from a previous
    /// run (or after a terminal transition) are dropped, never applied.
    private var runGeneration = 0
    private var runInterval: TimeInterval = 0.25
    private var runProgressHandler: (@Sendable (ProcessingProgress) async -> Void)?

    init(
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        analysisCache: any AnalysisCache,
        checkpointStore: SessionCheckpointStore,
        engine: SelectionEngine,
        config: AppConfiguration = .default,
        pressure: MemoryPressureObserver? = nil,
        tierCProvider: any VisualEmbeddingProvider = NativeDerivedEmbeddingProvider(),
        semanticJuryProvider: any SemanticJuryProvider = NoopSemanticJuryProvider(),
        semanticJuryAvailability: @escaping @Sendable () -> Bool = { SemanticJuryPolicy.isAvailableOnProductOS() },
        qualityRunner: QualityCurationRunner? = nil
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.analysisCache = analysisCache
        self.checkpointStore = checkpointStore
        self.engine = engine
        self.tierCProvider = tierCProvider
        self.semanticJuryAvailability = semanticJuryAvailability
        self.semanticJuryProvider = semanticJuryProvider
        self.qualityRunner = qualityRunner
        pipeline = BatchPipeline(
            imageLoader: imageLoader,
            analyzer: analyzer,
            cache: analysisCache,
            checkpoints: checkpointStore,
            config: config,
            pressure: pressure
        )
    }

    func run(
        request: SelectionRequest,
        sourceAssets: [PhotoAsset],
        onProgress: @Sendable @escaping (ProcessingProgress) async -> Void
    ) async throws -> SelectionResult {
        try Task.checkCancellation()
        let interval = 1.0 / request.config.performance.progressMaxHertz
        runGeneration += 1
        let generation = runGeneration
        resetRunState()
        runInterval = interval
        runProgressHandler = onProgress
        subscribeToDownloadProgress(generation: generation)
        defer {
            unsubscribeFromDownloadProgress()
            runProgressHandler = nil
        }
        logger.info("Starting curation session")
        await emit(
            ProcessingProgress.zero,
            interval: interval,
            onProgress: onProgress
        )
        try Task.checkCancellation()
        let batchResult = try await analyze(
            assets: sourceAssets,
            request: request,
            interval: interval,
            onProgress: onProgress,
            generation: generation
        )
        // Delivery from analyze() is fully drained before this stage switch,
        // so no stale analysis update can land after the grouping emit.
        try Task.checkCancellation()
        await emit(
            ProcessingProgress(
                stage: .clustering,
                completedUnits: 0,
                totalUnits: 0,
                downloadingCount: 0,
                unavailableCount: batchResult.unavailableIDs.count,
                analyzedCount: batchResult.analyses.count,
                overallFraction: 0
            ),
            interval: interval,
            onProgress: onProgress
        )
        let result = try await selectResult(
            request: request,
            assets: sourceAssets,
            batchResult: batchResult
        )
        // Cancel-after-analysis checkpoints via the pipeline path below and
        // surfaces as .cancelled — never a persisted success.
        try Task.checkCancellation()
        try await persist(
            request: request,
            batchResult: batchResult,
            result: result
        )
        try Task.checkCancellation()
        logger.info("Finished curation session")
        return result
    }

    /// Background path: write a safe checkpoint now, stop starting new work.
    func checkpointNow(
        sessionID: SessionID,
        completed: [AssetID],
        stage: ProcessingStage,
        qualityIdentity: QualityCheckpointIdentity? = nil
    ) async {
        let stub = SessionCheckpoint(
            sessionID: sessionID,
            stage: stage.rawValue,
            completedAssetIDs: completed,
            sourceAssetIDs: [],
            configVersion: AppConfiguration.default.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            qualityIdentity: qualityIdentity,
            updatedAt: Date()
        )
        try? await checkpointStore.save(stub)
    }

    private func analyze(
        assets: [PhotoAsset],
        request: SelectionRequest,
        interval: TimeInterval,
        onProgress: @Sendable @escaping (ProcessingProgress) async -> Void,
        generation: Int
    ) async throws -> BatchResult {
        let hasCheckpoint = (try? await checkpointStore.load(sessionID: request.sessionID)) != nil
        let qualityIdentity = QualityCheckpointIdentity.expected(for: request.qualityMode)
        // Structured delivery: pipeline progress fans into a per-run stream and
        // a single consumer forwards it. The consumer is awaited before every
        // return/throw, so no unstructured delivery task outlives this run to
        // resurrect a terminal state.
        let (stream, source) = AsyncStream<BatchProgress>.makeStream()
        let consumer = Task {
            for await batch in stream {
                await self.forwardBatch(
                    batch, stage: .analysis, interval: interval, onProgress: onProgress, generation: generation
                )
            }
        }
        do {
            if hasCheckpoint {
                let output = try await pipeline.resume(
                    assets: assets,
                    sessionID: request.sessionID,
                    qualityIdentity: qualityIdentity
                ) {
                    source.yield($0)
                }
                source.finish()
                await consumer.value
                return output
            }
            let output = try await pipeline.run(
                assets: assets,
                sessionID: request.sessionID,
                qualityIdentity: qualityIdentity
            ) {
                source.yield($0)
            }
            source.finish()
            await consumer.value
            return output
        } catch {
            source.finish()
            await consumer.value
            throw error
        }
    }

    /// Shared partial-result entry point for Continue Without Them. Regenerates
    /// transient similarity artifacts for the available IDs through the
    /// pipeline's loader + analyzer in bounded lanes, then runs the same
    /// engine pipeline as the normal path.
    func finalizeAvailable(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        laneCount: Int,
        qualityMode: QualityMode = .native,
        qualityModelAvailableAtStart: Bool = false,
        sessionID: SessionID = SessionID(rawValue: UUID())
    ) async throws -> SelectionResult {
        let candidates = engine.duplicateCandidates(for: assets, configuration: configuration)
        let edges = try await rebuildSimilarityEdges(for: assets, candidates: candidates, laneCount: laneCount)
        if qualityMode.isQualityMode, let qualityRunner {
            return try await qualityRunner.run(
                sessionID: sessionID,
                sourceAssets: assets,
                analyses: analyses,
                similarityEdges: edges,
                configuration: configuration,
                requestedMode: qualityMode,
                modelAvailableAtStart: qualityModelAvailableAtStart,
                generation: runGeneration
            )
        }
        let tierC = tierCEdges(
            forShortlistOf: assets, analyses: analyses, configuration: configuration, similarityEdges: edges
        )
        let deterministic = try engine.select(
            assets: assets, analyses: analyses, configuration: configuration,
            feedback: nil, similarityEdges: edges, tierCEdges: tierC
        )
        return try await applySemanticJury(
            to: deterministic, assets: assets, analyses: analyses, configuration: configuration,
            similarityEdges: edges, tierCEdges: tierC
        )
    }

    private func selectResult(
        request: SelectionRequest,
        assets: [PhotoAsset],
        batchResult: BatchResult
    ) async throws -> SelectionResult {
        let candidates = engine.duplicateCandidates(for: assets, configuration: request.config.selection)
        let edges = try batchResult.similarityEdges(for: candidates)
        if request.qualityMode.isQualityMode, let qualityRunner {
            return try await qualityRunner.run(
                sessionID: request.sessionID,
                sourceAssets: assets,
                analyses: batchResult.analyses,
                similarityEdges: edges,
                configuration: request.config.selection,
                requestedMode: request.qualityMode,
                modelAvailableAtStart: request.qualityModelAvailableAtStart,
                generation: runGeneration
            )
        }
        let tierC = tierCEdges(
            forShortlistOf: assets, analyses: batchResult.analyses,
            configuration: request.config.selection, similarityEdges: edges
        )
        let deterministic = try engine.select(
            assets: assets, analyses: batchResult.analyses, configuration: request.config.selection,
            feedback: nil, similarityEdges: edges, tierCEdges: tierC
        )
        let juried = try await applySemanticJury(
            to: deterministic, assets: assets, analyses: batchResult.analyses,
            configuration: request.config.selection, similarityEdges: edges, tierCEdges: tierC
        )
        return SelectionResult(
            sessionID: request.sessionID,
            selectedAssetIDs: juried.selectedAssetIDs,
            rejectedAssetIDs: juried.rejectedAssetIDs,
            decisions: juried.decisions,
            generatedAt: juried.generatedAt,
            engineVersion: juried.engineVersion
        )
    }

    /// Bounded artifact rebuild for the partial path: analysis images only for
    /// available IDs, existing lane count, failures skipped, cancel-aware.
    private func rebuildSimilarityEdges(
        for assets: [PhotoAsset], candidates: [SimilarityCandidate], laneCount: Int
    ) async throws -> [SimilarityEdge] {
        let lanes = max(1, laneCount)
        let artifacts = try await SimilarityRebuilder(imageLoader: imageLoader, analyzer: analyzer, laneCount: lanes)
            .rebuild(for: assets.map(\.id))
        try Task.checkCancellation()
        var edges: [SimilarityEdge] = []
        edges.reserveCapacity(candidates.count)
        for candidate in candidates {
            try Task.checkCancellation()
            guard let left = artifacts[candidate.first], let right = artifacts[candidate.second] else { continue }
            guard let distance = try? left.distance(to: right) else { continue }
            edges.append(SimilarityEdge(first: candidate.first, second: candidate.second, distance: distance))
        }
        return edges
    }

    /// Bounded Tier-C edges (DEC-037) over the exact `select` shortlist; same FP edges, noop fallback.
    private func tierCEdges(
        forShortlistOf assets: [PhotoAsset], analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration, similarityEdges: [SimilarityEdge]
    ) -> [SimilarityEdge] {
        let scope = engine.shortlistScope(
            for: assets, analyses: analyses, configuration: configuration, similarityEdges: similarityEdges
        )
        let pairs = VisualEmbeddingRouter.tierCCandidates(for: scope.filter { analyses[$0.id] != nil })
        let edges = pairs.isEmpty ? [] : tierCProvider.tierCDistances(for: pairs, analyses: analyses)
        return edges.isEmpty ? NoopVisualEmbeddingProvider().tierCDistances(for: pairs, analyses: analyses) : edges
    }

    // swiftlint:disable:next function_parameter_count
    func applySemanticJury(
        to result: SelectionResult,
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        similarityEdges: [SimilarityEdge],
        tierCEdges: [SimilarityEdge]
    ) async throws -> SelectionResult {
        // The product gate is checked before request construction or image loading:
        // iOS 26 never calls the jury and retains the exact deterministic path.
        guard semanticJuryAvailability() else { return result }
        let baseRequests = SemanticJuryRequestFactory.requests(
            result: result, sourceAssets: assets, analyses: analyses
        )
        guard !baseRequests.isEmpty else { return result }
        var requests: [SemanticJuryRequest] = []
        for request in baseRequests.prefix(SemanticJuryPolicy.maximumRequests) {
            try Task.checkCancellation()
            var images: [AssetID: CGImage] = [:]
            for candidate in request.candidates {
                guard let image = try? await imageLoader.analysisImage(for: candidate.assetID) else {
                    images = [:]
                    break
                }
                images[candidate.assetID] = image
            }
            if let request = request.withImages(images) {
                requests.append(request)
            }
        }
        guard !requests.isEmpty else { return result }
        defer { requests.forEach { $0.releaseImages() } }
        let evaluation = await SemanticJuryRouter(
            provider: semanticJuryProvider, availability: semanticJuryAvailability
        ).evaluate(requests)
        guard !evaluation.overrides.isEmpty else { return result }
        return try engine.applyJuryOverrides(
            to: result,
            assets: assets,
            analyses: analyses,
            configuration: configuration,
            similarityEdges: similarityEdges,
            overrides: evaluation.overrides
        )
    }
}

extension SelectionSessionCoordinator {
    private func persist(
        request: SelectionRequest,
        batchResult: BatchResult,
        result: SelectionResult
    ) async throws {
        try await checkpointStore.saveResult(result)
        let done = SessionCheckpoint(
            sessionID: request.sessionID,
            stage: ProcessingStage.finalSelection.rawValue,
            completedAssetIDs: Array(batchResult.analyses.keys) + batchResult.unavailableIDs,
            sourceAssetIDs: request.sourceAssetIDs,
            configVersion: request.config.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            qualityIdentity: QualityCheckpointIdentity.expected(for: request.qualityMode),
            updatedAt: Date()
        )
        try await checkpointStore.save(done)
    }

    private func resetRunState() {
        lastEmit = .distantPast
        lastFraction = 0
        lastStage = nil
        lastProgress = nil
        pendingDownloadIDs = []
    }

    private func emit(
        _ progress: ProcessingProgress,
        interval: TimeInterval,
        onProgress: @Sendable @escaping (ProcessingProgress) async -> Void
    ) async {
        let now = Date()
        if progress.stage != lastStage {
            // Stage transitions always emit: the grouping/select phases would otherwise be
            // swallowed by the monotonic baseline (their fraction resets to 0). Transitions are
            // rare discrete events (a few per run), so this never defeats the 4 Hz throttle on
            // continuous determinate progress.
            lastStage = progress.stage
            lastEmit = now
            lastFraction = progress.overallFraction
            lastProgress = progress
            await onProgress(progress)
            return
        }
        // Terminal bypass requires a real denominator: indeterminate totalUnits == 0 never counts.
        let isTerminal = progress.totalUnits > 0 && progress.completedUnits == progress.totalUnits
        let timeDue = now.timeIntervalSince(lastEmit) >= interval
        guard progress.overallFraction + 0.0001 >= lastFraction, timeDue || isTerminal else { return }
        lastEmit = now
        lastFraction = max(lastFraction, progress.overallFraction)
        lastProgress = progress
        await onProgress(progress)
    }

    private func forwardBatch(
        _ batch: BatchProgress,
        stage: ProcessingStage,
        interval: TimeInterval,
        onProgress: @Sendable @escaping (ProcessingProgress) async -> Void,
        generation: Int
    ) async {
        // Run-lifetime scope: a delivery racing a terminal transition (or a
        // previous run) is dropped here, before it can resurrect state.
        guard generation == runGeneration else { return }
        let total = max(batch.total, 1)
        let fraction = Double(batch.completed) / Double(total)
        await emit(
            ProcessingProgress(
                stage: stage,
                completedUnits: batch.completed,
                totalUnits: batch.total,
                downloadingCount: pendingDownloadIDs.count,
                unavailableCount: batch.unavailable,
                analyzedCount: batch.analyzed,
                overallFraction: fraction
            ),
            interval: interval,
            onProgress: onProgress
        )
    }

    private func subscribeToDownloadProgress(generation: Int) {
        downloadObserver = NotificationCenter.default.addObserver(
            forName: .imageDownloadProgress,
            object: nil,
            queue: nil
        ) { [weak self] note in
            Task { [weak self] in await self?.handleDownloadNote(note, generation: generation) }
        }
    }

    private func unsubscribeFromDownloadProgress() {
        if let observer = downloadObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        downloadObserver = nil
    }

    private func handleDownloadNote(_ note: Notification, generation: Int) async {
        // Active-session scope: notes racing a terminal transition or from a
        // previous run never emit, so no cross-session leakage.
        guard generation == runGeneration else { return }
        guard let assetID = note.userInfo?["assetID"] as? String else { return }
        let fraction = note.userInfo?["fraction"] as? Double ?? 0
        if fraction >= 1.0 {
            pendingDownloadIDs.remove(assetID)
        } else {
            pendingDownloadIDs.insert(assetID)
        }
        // Throttled iCloud-wait line: re-emit the last snapshot with the fresh
        // count through the same 4 Hz gate, so "Waiting for N photos" appears
        // during stalls without spamming determinate progress.
        guard let handler = runProgressHandler, var waiting = lastProgress else { return }
        waiting.downloadingCount = pendingDownloadIDs.count
        await emit(waiting, interval: runInterval, onProgress: handler)
    }
}

extension SelectionSessionCoordinator {
    nonisolated static func userError(
        for error: Error,
        unavailable: Int,
        analyzed: Int
    ) -> UserFacingError {
        if case SelectionError.cancelled = error {
            return UserFacingError(
                code: .curationPaused,
                primary: .goHome,
                secondary: .discard
            )
        }
        if error is CancellationError {
            return UserFacingError(
                code: .curationPaused,
                primary: .goHome,
                secondary: .discard
            )
        }
        if (error as NSError).domain == NSURLErrorDomain {
            // Partial rule: Continue Without Them needs something to skip AND
            // the minimum-analyzable bar (at least one analyzed photo that can
            // anchor a partial result). Otherwise the only stable exit is Home.
            let secondary: RecoveryAction =
                (unavailable > 0 && analyzed > 0) ? .continueWithoutUnavailable : .goHome
            return UserFacingError(
                code: .connectionNeeded,
                primary: .retry,
                secondary: secondary
            )
        }
        return UserFacingError(
            code: .unableToContinue,
            primary: .retry,
            secondary: .goHome
        )
    }

    /// Permission-removed path (called by ProcessingModel when authorization is denied/restricted).
    nonisolated static func permissionError() -> UserFacingError {
        UserFacingError(
            code: .photosAccessNeeded,
            primary: .openSettings,
            secondary: .goHome
        )
    }
}
