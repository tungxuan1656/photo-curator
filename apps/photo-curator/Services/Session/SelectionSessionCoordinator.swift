import Foundation
import OSLog

struct SelectionRequest: Sendable {
    let sessionID: SessionID
    let sourceAssetIDs: [AssetID]
    let config: AppConfiguration
}

/// Canonical stored stages — data-model.md §10 raw values reused verbatim.
/// This enum is the single stored/checkpoint vocabulary; do NOT add user-phase cases here.
enum ProcessingStage: String, Codable, Sendable {
    case loading, analysis, clustering, momentDetection, ranking, finalSelection
}

/// UI-only display string — a computed property, NOT a separate enum. Never persisted,
/// never written to checkpoint.stage.
extension ProcessingStage {
    var userPhase: String {
        switch self {
        case .loading:
            return "Preparing photos"
        case .analysis:
            return "Analyzing photos"
        case .clustering, .momentDetection:
            return "Grouping similar shots"
        case .ranking:
            return "Choosing the best photos"
        case .finalSelection:
            return "Finishing your album"
        }
    }
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
    case paused(reason: String)
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
    let title: String
    let message: String
    let primary: RecoveryAction
    let secondary: RecoveryAction
}

actor SelectionSessionCoordinator {
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let analysisCache: any AnalysisCache
    private let checkpointStore: SessionCheckpointStore
    private let pipeline: BatchPipeline
    private let engine: SelectionEngine
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
        config: AppConfiguration = .default
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.analysisCache = analysisCache
        self.checkpointStore = checkpointStore
        self.engine = engine
        pipeline = BatchPipeline(
            imageLoader: imageLoader,
            analyzer: analyzer,
            cache: analysisCache,
            checkpoints: checkpointStore,
            config: config
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
        let result = try selectResult(
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
    func checkpointNow(sessionID: SessionID, completed: [AssetID], stage: ProcessingStage) async {
        let stub = SessionCheckpoint(
            sessionID: sessionID,
            stage: stage.rawValue,
            completedAssetIDs: completed,
            sourceAssetIDs: [],
            configVersion: AppConfiguration.default.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
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
                let output = try await pipeline.resume(assets: assets, sessionID: request.sessionID) {
                    source.yield($0)
                }
                source.finish()
                await consumer.value
                return output
            }
            let output = try await pipeline.run(assets: assets, sessionID: request.sessionID) {
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

    private func selectResult(
        request: SelectionRequest,
        assets: [PhotoAsset],
        batchResult: BatchResult
    ) throws -> SelectionResult {
        let engineOut = try engine.select(
            assets: assets,
            analyses: batchResult.analyses,
            configuration: request.config.selection,
            feedback: nil
        )
        return SelectionResult(
            sessionID: request.sessionID,
            selectedAssetIDs: engineOut.selectedAssetIDs,
            rejectedAssetIDs: engineOut.rejectedAssetIDs,
            decisions: engineOut.decisions,
            generatedAt: engineOut.generatedAt,
            engineVersion: engineOut.engineVersion
        )
    }

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
                title: "Curation Paused",
                message: "Your progress is saved. Curation will continue when the app is active again.",
                primary: .goHome,
                secondary: .discard
            )
        }
        if error is CancellationError {
            return UserFacingError(
                title: "Curation Paused",
                message: "Your progress is saved. Curation will continue when the app is active again.",
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
                title: "Connection Needed",
                message: "Some photos need to download from iCloud. Connect and try again — saved work is kept.",
                primary: .retry,
                secondary: secondary
            )
        }
        return UserFacingError(
            title: "Couldn't Continue Curation",
            message: "Your progress is saved. Try again to continue processing.",
            primary: .retry,
            secondary: .goHome
        )
    }

    /// Permission-removed path (called by ProcessingModel when authorization is denied/restricted).
    nonisolated static func permissionError() -> UserFacingError {
        UserFacingError(
            title: "Photos Access Needed",
            message: "Allow photo access to continue. Your progress is saved.",
            primary: .openSettings,
            secondary: .goHome
        )
    }
}
