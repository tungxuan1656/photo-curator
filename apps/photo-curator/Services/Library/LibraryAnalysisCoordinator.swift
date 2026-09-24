import Foundation

/// The lifecycle of the catalog enrichment job. This is intentionally not a
/// selection-session state: catalog metadata remains useful while paused.
enum LibraryAnalysisCoordinatorState: String, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
    case waitingForCatalog
    case reset
    case failed
}

enum LibraryAnalysisFailure: Error, Sendable, Equatable {
    case imageLoad(PhotoImageLoadError)
    case modelUnavailable
    case revisionStale
    case unsupported
    case transientFailure
}

enum LibraryAnalysisRetryPolicy: String, Sendable, Equatable {
    case accessRequired
    case waitForAsset
    case retryExplicitly
    case retryAfterRevisionChange
    case doNotRetry
}

struct LibraryAnalysisFailureStatus: Sendable, Equatable {
    let failure: LibraryAnalysisFailure
    let retryPolicy: LibraryAnalysisRetryPolicy
}

/// Progress is delivered after durable catalog transitions. The catalog and
/// evidence stores remain completion authority.
struct LibraryAnalysisProgress: Sendable, Equatable {
    let state: LibraryAnalysisCoordinatorState
    let generationID: UUID?
    let capability: AnalysisCapability
    let revision: AnalysisCapabilityRevision
    let completed: Int
    let total: Int
    let analyzed: Int
    let unavailable: Int
    let scheduledAssetCount: Int
    let currentAssetID: AssetID?
    let latestFailure: LibraryAnalysisFailureStatus?
}

/// Coordinates one durable, revisioned catalog capability. The coordinator
/// owns one root task; all image lanes are structured children of that task.
actor LibraryAnalysisCoordinator {
    static let batchSize = 32
    static let maxConcurrentImageWork = 2
    static let checkpointAssetInterval = 25
    static let checkpointTimeInterval: TimeInterval = 10
    static let progressInterval: TimeInterval = 0.25

    let catalogStore: LibraryCatalogStore
    let evidenceStore: LibraryAnalysisEvidenceStore
    let checkpointStore: LibraryAnalysisCheckpointStore
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let imageWorkArbiter: ImageWorkArbiter
    let capability: AnalysisCapability = .nativeImageFacts
    let revision: AnalysisCapabilityRevision

    var rootTask: Task<Void, Never>?
    var runToken: UInt64 = 0
    var progressHandler: (@Sendable (LibraryAnalysisProgress) async -> Void)?
    var state: LibraryAnalysisCoordinatorState = .idle

    var generationID: UUID?
    var total = 0
    var completed = 0
    var analyzed = 0
    var unavailable = 0
    var scheduledAssetCount = 0
    var countedAssetIDs = Set<AssetID>()
    var unavailableAssetIDs = Set<AssetID>()
    var lastCheckpointCursor: AssetID?
    var completedSinceCheckpoint = 0
    var lastCheckpointDate = Date()
    var needsDurableReread = false
    var latestFailure: LibraryAnalysisFailureStatus?
    var lastProgressPublicationDate = Date.distantPast

    init(
        catalogStore: LibraryCatalogStore,
        evidenceStore: LibraryAnalysisEvidenceStore,
        checkpointStore: LibraryAnalysisCheckpointStore,
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        imageWorkArbiter: ImageWorkArbiter = ImageWorkArbiter(),
        revision: AnalysisCapabilityRevision = .currentNativeImageFacts
    ) {
        self.catalogStore = catalogStore
        self.evidenceStore = evidenceStore
        self.checkpointStore = checkpointStore
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.imageWorkArbiter = imageWorkArbiter
        self.revision = revision
    }

    func start(
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void = { _ in }
    ) async {
        await beginRun(schedule: .normal, onProgress: onProgress)
    }

    /// Resume adds only rows whose durable reason is explicitly retryable; it
    /// does not turn every unavailable row into new image work.
    func resume(
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void = { _ in }
    ) async {
        await beginRun(schedule: .explicitRetry, onProgress: onProgress)
    }

    func pause() async {
        guard state == .running, let task = rootTask else { return }
        task.cancel()
        await task.value
        rootTask = nil
    }

    /// Invalidate and drain first, then clear checkpoint, evidence, and V4
    /// catalog work state so no old result can reappear after reset.
    func reset() async throws {
        runToken += 1
        await drainRootTask()
        progressHandler = nil
        await checkpointStore.reset()
        await evidenceStore.reset()
        try await catalogStore.resetAnalysisWork()
        state = .reset
        clearRunBookkeeping()
    }

    func currentState() -> LibraryAnalysisCoordinatorState {
        state
    }

    func beginRun(
        schedule: ScheduleMode,
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void
    ) async {
        runToken += 1
        await drainRootTask()
        let token = runToken
        progressHandler = onProgress
        clearRunBookkeeping()
        state = .running
        do {
            _ = try await catalogStore.reconcilePendingLabelPublications()
        } catch {
            state = .failed
            await publish(token: token, currentAssetID: nil, force: true)
            return
        }
        rootTask = Task { [weak self] in
            guard let self else { return }
            await self.runRoot(token: token, schedule: schedule)
        }
    }

    func drainRootTask() async {
        guard let task = rootTask else { return }
        task.cancel()
        await task.value
        rootTask = nil
    }

    func runRoot(token: UInt64, schedule: ScheduleMode) async {
        let events = await catalogStore.catalogCommitEvents()
        await withTaskGroup(of: RootChildResult.self) { group in
            group.addTask { [weak self] in
                guard let self else { return .worker }
                await self.runWorker(token: token, schedule: schedule)
                return .worker
            }
            group.addTask { [weak self] in
                guard let self else { return .observer }
                await self.observe(events: events, token: token)
                return .observer
            }
            while let result = await group.next() {
                if result == .worker {
                    group.cancelAll()
                    break
                }
            }
            group.cancelAll()
            await group.waitForAll()
        }
    }

    func observe(events: AsyncStream<CatalogCommitEvent>, token: UInt64) async {
        for await event in events {
            guard isCurrentRun(token) else { return }
            if event.kind == .generationCommitted || event.kind == .analysisCommitted {
                needsDurableReread = true
            }
        }
    }

    func runWorker(token: UInt64, schedule: ScheduleMode) async {
        do {
            try await reconcileAndAnalyze(token: token, schedule: schedule)
            guard isCurrentRun(token), state == .running else { return }
            await saveCheckpoint(force: true, token: token)
            guard isCurrentRun(token) else { return }
            state = .completed
            await publish(token: token, currentAssetID: nil, force: true)
        } catch is CancellationError {
            guard isCurrentRun(token) else { return }
            await saveCheckpoint(force: true, token: token)
            state = .paused
            await publish(token: token, currentAssetID: nil, force: true)
        } catch {
            guard isCurrentRun(token) else { return }
            await saveCheckpoint(force: true, token: token)
            state = .failed
            await publish(token: token, currentAssetID: nil, force: true)
        }
    }

    enum RootChildResult: Sendable, Equatable {
        case worker
        case observer
    }

    struct WorkItem: Sendable {
        let asset: PhotoAsset
        let generationID: UUID
        let revision: AnalysisCapabilityRevision
    }

    enum WorkOutcome: Sendable {
        case success(WorkItem, PhotoAnalysis)
        case failure(WorkItem, LibraryAnalysisFailure)
        case obsolete(WorkItem)
    }

    enum ScheduleMode: Sendable, Equatable {
        case normal
        case explicitRetry
    }
}
