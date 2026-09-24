import Foundation

// swiftlint:disable file_length type_body_length

/// The lifecycle of the catalog enrichment job.  This is intentionally not a
/// selection-session state: catalog metadata remains useful while this job is
/// paused or incomplete.
enum LibraryAnalysisCoordinatorState: String, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
    case waitingForCatalog
    case reset
    case failed
}

/// The failure vocabulary exposed by the catalog scheduler.  In particular,
/// an iCloud wait is not folded into the generic transient-failure path.
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

/// Progress is delivered only after a durable catalog transition for newly
/// completed work.  `scheduledAssetCount` is a handoff hint, not completion
/// authority; the catalog work state and evidence store remain authoritative.
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

/// Coordinates one durable, revisioned catalog capability.  The coordinator
/// owns one root task; all image lanes are structured children of that task.
/// A run token is bumped before every new run and reset, so a result from a
/// cancelled or superseded run cannot publish or advance a checkpoint.
actor LibraryAnalysisCoordinator {
    private static let batchSize = 32
    private static let maxConcurrentImageWork = 2
    private static let checkpointAssetInterval = 25
    private static let checkpointTimeInterval: TimeInterval = 10

    private let catalogStore: LibraryCatalogStore
    private let evidenceStore: LibraryAnalysisEvidenceStore
    private let checkpointStore: LibraryAnalysisCheckpointStore
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let imageWorkArbiter: ImageWorkArbiter
    private let capability: AnalysisCapability = .nativeImageFacts
    private let revision: AnalysisCapabilityRevision

    private var rootTask: Task<Void, Never>?
    private var runToken: UInt64 = 0
    private var progressHandler: (@Sendable (LibraryAnalysisProgress) async -> Void)?
    private var state: LibraryAnalysisCoordinatorState = .idle

    // The following values are actor-isolated run bookkeeping.  None of them
    // are used as evidence authority; they only make progress/checkpoints
    // monotonic and useful while a run is in flight.
    private var generationID: UUID?
    private var total = 0
    private var completed = 0
    private var analyzed = 0
    private var unavailable = 0
    private var scheduledAssetCount = 0
    private var countedAssetIDs = Set<AssetID>()
    private var unavailableAssetIDs = Set<AssetID>()
    private var lastCheckpointCursor: AssetID?
    private var completedSinceCheckpoint = 0
    private var lastCheckpointDate = Date()
    private var needsDurableReread = false
    private var latestFailure: LibraryAnalysisFailureStatus?

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

    /// Starts a fresh scheduling pass.  Durable work state is re-read rather
    /// than inferred from the previous run's counters.
    func start(
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void = { _ in }
    ) async {
        await beginRun(retryUnavailable: false, onProgress: onProgress)
    }

    /// Explicit resume is allowed to retry rows previously marked unavailable.
    /// A checkpoint cursor only affects ordering; it never skips a durable
    /// state or evidence validation.
    func resume(
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void = { _ in }
    ) async {
        await beginRun(retryUnavailable: true, onProgress: onProgress)
    }

    /// Cancels the root task, waits for all image lanes to drain, and lets the
    /// root task write the safe checkpoint before returning.
    func pause() async {
        guard state == .running, let task = rootTask else { return }
        task.cancel()
        await task.value
        rootTask = nil
    }

    /// Reset is deliberately ordered: invalidate and drain first, then clear
    /// resumable scheduling/evidence files.  Late catalog commits are rejected
    /// by both the token check here and the catalog's generation guards.
    func reset() async {
        runToken += 1
        await drainRootTask()
        progressHandler = nil
        await checkpointStore.reset()
        await evidenceStore.reset()
        state = .reset
        clearRunBookkeeping()
    }

    func currentState() -> LibraryAnalysisCoordinatorState {
        state
    }

    // MARK: - Root task

    private func beginRun(
        retryUnavailable: Bool,
        onProgress: @escaping @Sendable (LibraryAnalysisProgress) async -> Void
    ) async {
        // Invalidate before draining so the old task cannot publish while its
        // cancellation is unwinding through re-entrant actor calls.
        runToken += 1
        await drainRootTask()
        let token = runToken
        progressHandler = onProgress
        clearRunBookkeeping()
        state = .running
        rootTask = Task { [weak self] in
            guard let self else { return }
            await self.runRoot(token: token, retryUnavailable: retryUnavailable)
        }
    }

    private func drainRootTask() async {
        guard let task = rootTask else { return }
        task.cancel()
        await task.value
        rootTask = nil
    }

    private func runRoot(token: UInt64, retryUnavailable: Bool) async {
        let events = await catalogStore.catalogCommitEvents()
        await withTaskGroup(of: RootChildResult.self) { group in
            group.addTask { [weak self] in
                guard let self else { return .worker }
                await self.runWorker(token: token, retryUnavailable: retryUnavailable)
                return .worker
            }
            group.addTask { [weak self] in
                guard let self else { return .observer }
                await self.observe(events: events, token: token)
                return .observer
            }

            // The observer is intentionally long-lived.  The worker is the
            // completion condition; cancelling the group then drains the
            // observer before this root task can publish terminal state.
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

    private func observe(events: AsyncStream<CatalogCommitEvent>, token: UInt64) async {
        for await event in events {
            guard isCurrentRun(token) else { return }
            // Events are advisory.  Even our own event only sets a bit; the
            // worker always obtains a fresh durable snapshot before using it.
            if event.kind == .generationCommitted || event.kind == .analysisCommitted {
                needsDurableReread = true
            }
        }
    }

    private func runWorker(token: UInt64, retryUnavailable: Bool) async {
        do {
            try await reconcileAndAnalyze(token: token, retryUnavailable: retryUnavailable)
            guard isCurrentRun(token) else { return }
            await saveCheckpoint(force: true, token: token)
            guard isCurrentRun(token) else { return }
            state = .completed
            await publish(token: token, currentAssetID: nil)
        } catch is CancellationError {
            // Structured task groups have already drained all child image work
            // when this catch is reached.  Checkpointing is therefore safe and
            // does not need to trust a cancelled child result.
            guard isCurrentRun(token) else { return }
            await saveCheckpoint(force: true, token: token)
            state = .paused
            await publish(token: token, currentAssetID: nil)
        } catch {
            guard isCurrentRun(token) else { return }
            await saveCheckpoint(force: true, token: token)
            state = .failed
            await publish(token: token, currentAssetID: nil)
        }
    }

    private func reconcileAndAnalyze(token: UInt64, retryUnavailable: Bool) async throws {
        var firstPass = true
        while true {
            try Task.checkCancellation()
            guard isCurrentRun(token) else { throw CancellationError() }

            let generation = try await catalogStore.currentGeneration()
            let observations = try await catalogStore.currentObservations()
            guard let generation else {
                if firstPass {
                    state = .waitingForCatalog
                    await publish(token: token, currentAssetID: nil)
                }
                return
            }
            firstPass = false

            if generationID != generation.id {
                beginGenerationBookkeeping(generationID: generation.id, total: observations.count)
            } else {
                total = observations.count
            }
            guard !observations.isEmpty else {
                state = .waitingForCatalog
                await publish(token: token, currentAssetID: nil)
                return
            }
            needsDurableReread = false

            let ordered = order(observations, after: await loadResumeCursor(for: generation.id))
            var work: [WorkItem] = []
            for observation in ordered {
                try Task.checkCancellation()
                guard isCurrentRun(token) else { throw CancellationError() }
                if let item = try await prepare(
                    observation: observation,
                    generationID: generation.id,
                    retryUnavailable: retryUnavailable
                ) {
                    work.append(item)
                }
            }

            if work.isEmpty {
                // An event can arrive immediately after the read above.  The
                // next pass re-reads state, but only when the advisory bit was
                // set; otherwise this generation is quiescent.
                if needsDurableReread {
                    continue
                }
                return
            }

            for start in stride(from: 0, to: work.count, by: Self.batchSize) {
                try Task.checkCancellation()
                guard isCurrentRun(token) else { throw CancellationError() }
                let end = min(start + Self.batchSize, work.count)
                try await processBatch(Array(work[start ..< end]), token: token)
                if needsDurableReread {
                    break
                }
            }

            // A generation event invalidates all assumptions made by the
            // previous snapshot.  Always begin the next iteration by reading
            // both the generation and observations from durable state.
            if needsDurableReread {
                continue
            }
            return
        }
    }

    // MARK: - Durable work preparation and processing

    private func prepare(
        observation: CatalogAssetObservationSnapshot,
        generationID: UUID,
        retryUnavailable: Bool
    ) async throws -> WorkItem? {
        let asset = observation.asset
        let existing = try await catalogStore.analysisWorkState(for: asset.id, capability: capability)

        if let reference = reusableEvidence(from: existing, for: asset) {
            do {
                // An available SwiftData row is reusable only when its durable
                // evidence also survives and independently validates.
                if let analysis = try await evidenceStore.load(reference, revision: revision) {
                    guard analysis.assetID == asset.id else { return nil }
                    recordDurableCompletion(assetID: asset.id, analyzed: true)
                    return nil
                }
            } catch {
                // Cache loss/mismatch is a miss, not completion.  Requesting
                // work below clears the stale reference under catalog guards.
            }
        }

        if existing?.status == .unavailable, !retryUnavailable {
            return nil
        }

        do {
            let requested = try await catalogStore.requestAnalysis(
                for: asset,
                generationID: generationID,
                revision: revision
            )
            guard requested.requestedAssetFingerprint == asset.modificationFingerprint,
                  requested.requestedRevision == revision
            else { return nil }
            scheduledAssetCount += 1
            return WorkItem(asset: asset, generationID: generationID, revision: revision)
        } catch let error as LibraryCatalogStoreError {
            // A concurrent reconciliation/revision change makes this item
            // obsolete.  It is never converted into a false unavailable row.
            if case .analysisTransitionRejected = error {
                return nil
            }
            throw error
        }
    }

    private func reusableEvidence(
        from state: AnalysisWorkStateSnapshot?,
        for asset: PhotoAsset
    ) -> AnalysisEvidenceReference? {
        guard let state,
              state.status == .available,
              state.requestedAssetFingerprint == asset.modificationFingerprint,
              state.requestedRevision == revision
        else { return nil }
        return state.evidence
    }

    private func processBatch(_ batch: [WorkItem], token: UInt64) async throws {
        try await withThrowingTaskGroup(of: WorkOutcome.self) { group in
            var next = 0
            func submit() {
                guard next < batch.count else { return }
                let item = batch[next]
                next += 1
                group.addTask { [weak self] in
                    guard let self else { throw CancellationError() }
                    return try await self.processOne(item)
                }
            }

            for _ in 0 ..< min(Self.maxConcurrentImageWork, batch.count) {
                submit()
            }
            while let outcome = try await group.next() {
                try Task.checkCancellation()
                guard isCurrentRun(token) else {
                    group.cancelAll()
                    throw CancellationError()
                }
                try await finish(outcome, token: token)
                submit()
            }
        }
    }

    private func processOne(_ item: WorkItem) async throws -> WorkOutcome {
        do {
            let inFlight = placeholderReference(for: item)
            do {
                _ = try await catalogStore.markAnalysisRunning(
                    AnalysisCommitCandidate(
                        generationID: item.generationID,
                        assetID: item.asset.id,
                        assetFingerprint: item.asset.modificationFingerprint,
                        revision: item.revision,
                        evidence: inFlight
                    )
                )
            } catch let error as LibraryCatalogStoreError {
                if case .analysisTransitionRejected = error {
                    return .obsolete(item)
                }
                return .failure(item, .transientFailure)
            }

            let output: ImageAnalysisOutput
            do {
                let imageLoader = self.imageLoader
                let analyzer = self.analyzer
                output = try await imageWorkArbiter.withPermit(priority: .enrichment) {
                    let image = try await imageLoader.analysisImage(for: item.asset.id)
                    try Task.checkCancellation()
                    return try await analyzer.analyze(AnalysisInput(
                        assetID: item.asset.id,
                        image: image,
                        isScreenshotSubtype: item.asset.mediaSubtype == .screenshot
                    ))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch SelectionError.cancelled {
                throw CancellationError()
            } catch let error as PhotoImageLoadError {
                if error == .cancelled {
                    throw CancellationError()
                }
                return .failure(item, .imageLoad(error))
            } catch let error as SelectionError {
                return .failure(item, Self.failure(for: error))
            } catch {
                // Loader implementations that predate PhotoImageLoadError are
                // still classified through the stable loader seam.
                if item.asset.source == .iCloud {
                    return .failure(item, .imageLoad(.classify(error)))
                }
                return .failure(item, .transientFailure)
            }

            try Task.checkCancellation()
            guard output.analysis.assetID == item.asset.id else {
                return .failure(item, .unsupported)
            }
            guard output.analysis.analysisVersion == item.revision.analysisRevision.rawValue else {
                return .failure(item, .revisionStale)
            }
            return .success(item, output.analysis)
        } catch is CancellationError {
            throw CancellationError()
        }
    }

    private func finish(_ outcome: WorkOutcome, token: UInt64) async throws {
        switch outcome {
        case let .obsolete(item):
            needsDurableReread = true
            lastCheckpointCursor = item.asset.id

        case let .success(item, analysis):
            guard isCurrentRun(token) else { throw CancellationError() }
            let reference: AnalysisEvidenceReference
            do {
                // Evidence is the first durable boundary.
                reference = try await evidenceStore.store(
                    analysis,
                    assetFingerprint: item.asset.modificationFingerprint,
                    revision: item.revision
                )
            } catch let error as LibraryAnalysisEvidenceStoreError {
                try await finishFailure(
                    item,
                    failure: Self.failure(for: error),
                    token: token
                )
                return
            } catch {
                try await finishFailure(item, failure: .transientFailure, token: token)
                return
            }

            guard isCurrentRun(token) else { throw CancellationError() }
            try Task.checkCancellation()
            let candidate = AnalysisCommitCandidate(
                generationID: item.generationID,
                assetID: item.asset.id,
                assetFingerprint: item.asset.modificationFingerprint,
                revision: item.revision,
                evidence: reference
            )
            let result = try await catalogStore.commitAnalysis(candidate)
            guard result.committed else {
                // A late result is discarded.  The next durable reread will
                // either find the other commit or request this revision again.
                needsDurableReread = true
                return
            }
            guard isCurrentRun(token) else { return }
            recordDurableCompletion(assetID: item.asset.id, analyzed: true)
            latestFailure = nil
            await publish(token: token, currentAssetID: item.asset.id)
            await saveCheckpointIfDue(token: token)

        case let .failure(item, failure):
            try await finishFailure(item, failure: failure, token: token)
        }
    }

    private func finishFailure(
        _ item: WorkItem,
        failure: LibraryAnalysisFailure,
        token: UInt64
    ) async throws {
        guard isCurrentRun(token) else { throw CancellationError() }
        let reason = Self.catalogReason(for: failure)
        do {
            _ = try await catalogStore.recordAnalysisUnavailable(
                for: item.asset.id,
                generationID: item.generationID,
                fingerprint: item.asset.modificationFingerprint,
                revision: item.revision,
                reason: reason
            )
        } catch let error as LibraryCatalogStoreError {
            if case .analysisTransitionRejected = error {
                needsDurableReread = true
                return
            }
            throw error
        }
        let status = LibraryAnalysisFailureStatus(
            failure: failure,
            retryPolicy: Self.retryPolicy(for: failure)
        )
        latestFailure = status
        recordDurableCompletion(assetID: item.asset.id, analyzed: false)
        await publish(token: token, currentAssetID: item.asset.id)
        await saveCheckpointIfDue(token: token)
    }

    // MARK: - Checkpoints and publication

    private func saveCheckpointIfDue(token: UInt64) async {
        completedSinceCheckpoint += 1
        let dueByCount = completedSinceCheckpoint >= Self.checkpointAssetInterval
        let dueByTime = Date().timeIntervalSince(lastCheckpointDate) >= Self.checkpointTimeInterval
        guard dueByCount || dueByTime else { return }
        await saveCheckpoint(force: true, token: token)
    }

    private func saveCheckpoint(force: Bool, token: UInt64) async {
        guard force, isCurrentRun(token), let generationID else { return }
        let checkpoint = LibraryAnalysisCheckpoint(
            catalogGenerationID: generationID,
            capability: capability,
            revision: revision,
            resumeCursor: lastCheckpointCursor,
            scheduledAssetCount: scheduledAssetCount,
            updatedAt: Date()
        )
        do {
            try await checkpointStore.save(checkpoint)
            completedSinceCheckpoint = 0
            lastCheckpointDate = Date()
        } catch {
            // Evidence and catalog state remain authoritative when a handoff
            // file cannot be written.  The next start performs a full reread.
        }
    }

    private func loadResumeCursor(for generationID: UUID) async -> AssetID? {
        guard let checkpoint = try? await checkpointStore.load(
            catalogGenerationID: generationID,
            capability: capability,
            revision: revision
        ) else { return nil }
        return checkpoint?.resumeCursor
    }

    private func publish(token: UInt64, currentAssetID: AssetID?) async {
        guard isCurrentRun(token), let progressHandler else { return }
        await progressHandler(LibraryAnalysisProgress(
            state: state,
            generationID: generationID,
            capability: capability,
            revision: revision,
            completed: completed,
            total: total,
            analyzed: analyzed,
            unavailable: unavailable,
            scheduledAssetCount: scheduledAssetCount,
            currentAssetID: currentAssetID,
            latestFailure: latestFailure
        ))
    }

    private func recordDurableCompletion(assetID: AssetID, analyzed didAnalyze: Bool) {
        guard countedAssetIDs.insert(assetID).inserted else { return }
        completed += 1
        if didAnalyze {
            analyzed += 1
        } else if unavailableAssetIDs.insert(assetID).inserted {
            unavailable += 1
        }
        lastCheckpointCursor = assetID
    }

    private func beginGenerationBookkeeping(generationID: UUID, total: Int) {
        self.generationID = generationID
        self.total = total
        completed = 0
        analyzed = 0
        unavailable = 0
        scheduledAssetCount = 0
        countedAssetIDs.removeAll()
        unavailableAssetIDs.removeAll()
        lastCheckpointCursor = nil
        completedSinceCheckpoint = 0
        lastCheckpointDate = Date()
        latestFailure = nil
    }

    private func clearRunBookkeeping() {
        generationID = nil
        total = 0
        completed = 0
        analyzed = 0
        unavailable = 0
        scheduledAssetCount = 0
        countedAssetIDs.removeAll()
        unavailableAssetIDs.removeAll()
        lastCheckpointCursor = nil
        completedSinceCheckpoint = 0
        lastCheckpointDate = Date()
        needsDurableReread = false
        latestFailure = nil
    }

    // MARK: - Classification and ordering

    private func order(
        _ observations: [CatalogAssetObservationSnapshot],
        after cursor: AssetID?
    ) -> [CatalogAssetObservationSnapshot] {
        let sorted = observations.sorted { $0.asset.id.rawValue < $1.asset.id.rawValue }
        guard let cursor, let index = sorted.firstIndex(where: { $0.asset.id == cursor }) else { return sorted }
        return Array(sorted.dropFirst(index + 1)) + Array(sorted.prefix(index + 1))
    }

    private func placeholderReference(for item: WorkItem) -> AnalysisEvidenceReference {
        AnalysisEvidenceReference(
            identifier: "in-flight",
            assetID: item.asset.id,
            capability: capability,
            assetFingerprint: item.asset.modificationFingerprint,
            revision: item.revision
        )
    }

    private static func failure(for error: SelectionError) -> LibraryAnalysisFailure {
        switch error {
        case .invalidInput: .unsupported
        case .internal, .memoryCritical: .transientFailure
        case .cancelled: .transientFailure
        }
    }

    private static func failure(for error: LibraryAnalysisEvidenceStoreError) -> LibraryAnalysisFailure {
        switch error {
        case .unsupportedCapability, .assetMismatch, .invalidReference: .unsupported
        case .missingAssetFingerprint, .revisionMismatch: .revisionStale
        }
    }

    private static func catalogReason(for failure: LibraryAnalysisFailure) -> AnalysisWorkReason {
        switch failure {
        case let .imageLoad(error):
            switch error {
            case .accessRequired: .accessRequired
            case .iCloudWaiting: .iCloudWaiting
            case .assetMissing: .unsupported
            case .transientFailure, .cancelled: .transientFailure
            }
        case .modelUnavailable: .modelUnavailable
        case .revisionStale: .revisionStale
        case .unsupported: .unsupported
        case .transientFailure: .transientFailure
        }
    }

    private static func retryPolicy(for failure: LibraryAnalysisFailure) -> LibraryAnalysisRetryPolicy {
        switch failure {
        case let .imageLoad(error):
            switch error {
            case .accessRequired: .accessRequired
            case .iCloudWaiting: .waitForAsset
            case .assetMissing: .doNotRetry
            case .transientFailure, .cancelled: .retryExplicitly
            }
        case .modelUnavailable, .transientFailure: .retryExplicitly
        case .revisionStale: .retryAfterRevisionChange
        case .unsupported: .doNotRetry
        }
    }

    private func isCurrentRun(_ token: UInt64) -> Bool {
        token == runToken
    }

    private enum RootChildResult: Sendable, Equatable {
        case worker
        case observer
    }

    private struct WorkItem: Sendable {
        let asset: PhotoAsset
        let generationID: UUID
        let revision: AnalysisCapabilityRevision
    }

    private enum WorkOutcome: Sendable {
        case success(WorkItem, PhotoAnalysis)
        case failure(WorkItem, LibraryAnalysisFailure)
        case obsolete(WorkItem)
    }
}

// swiftlint:enable file_length type_body_length
