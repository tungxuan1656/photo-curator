import Foundation
import SwiftData

enum LibraryCatalogStoreError: Error, Sendable, Equatable {
    case accessRequired
    case authorizationChanged
    case duplicateAssetID
    case fetchFailed
    case incompleteGeneration
    case analysisTransitionRejected(AnalysisCommitRejection)
    case persistenceFailed
    case reconciliationInProgress
    case unavailable
}

struct CatalogStateSnapshot: Sendable, Equatable {
    let currentGenerationID: UUID?
    let latestAttemptID: UUID?
    let availability: CatalogAvailability
    let updatedAt: Date?
}

struct CatalogGenerationSnapshot: Sendable, Equatable {
    let id: UUID
    let status: CatalogGenerationStatus
    let authorization: CatalogAuthorizationSnapshot
    let startedAt: Date
    let completedAt: Date?
    let assetCount: Int
    let failureCategory: CatalogFailureCategory?
}

struct CatalogAssetObservationSnapshot: Sendable, Equatable {
    let generationID: UUID
    let asset: PhotoAsset
}

struct CatalogReconciliationResult: Sendable, Equatable {
    let generationID: UUID
    let assetCount: Int
    let changedAssetIDs: [AssetID]
}

/// Actor-isolated owner of immutable catalog observations. Fetching Photos
/// metadata is intentionally performed before any observation write
/// transaction; only complete generations are published through CatalogState.
actor LibraryCatalogStore {
    static let observationBatchSize = 250
    static let retainedAbandonedGenerationCount = 2
    static let retainedSupersededGenerationCount = 2

    let modelContainer: ModelContainer
    private let context: ModelContext
    private var reconciliationInFlight = false
    private var reconciliationQueued = false
    private var reconciliationPending = false
    private var commitEventContinuations: [UUID: AsyncStream<CatalogCommitEvent>.Continuation] = [:]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        context = ModelContext(modelContainer)
        try? Self.recoverInterruptedGenerations(in: context)
        try? Self.pruneCatalogHistory(in: context)
    }

    /// Queues lifecycle work without making startup, recovery, or resume await
    /// Photos enumeration. Notifications received during a scan set a single
    /// pending bit and produce one follow-up scan after the active one.
    func enqueueReconciliation(using photoLibrary: any PhotoLibraryService) {
        if reconciliationInFlight || reconciliationQueued {
            reconciliationPending = true
            return
        }
        reconciliationQueued = true
        Task { await drainReconciliationQueue(using: photoLibrary) }
    }

    /// Hides retained observations as soon as lifecycle code observes loss of
    /// Photos access. It never promotes a store to available; only a complete
    /// reconciliation may publish that state.
    func recordAuthorization(_ authorization: PhotoLibraryAuthorization) {
        guard !Self.isAccessible(authorization) else { return }
        do {
            try context.transaction {
                let state = try stateOrCreate(availability: .accessRequired)
                state.availability = .accessRequired
                state.updatedAt = Date()
                try context.save()
            }
        } catch {
            // Reconciliation will surface persistence failure without changing
            // the committed generation pointer.
        }
    }

    func state() throws -> CatalogStateSnapshot {
        guard let state = try fetchState() else {
            return CatalogStateSnapshot(
                currentGenerationID: nil,
                latestAttemptID: nil,
                availability: .unavailable,
                updatedAt: nil
            )
        }
        return CatalogStateSnapshot(
            currentGenerationID: state.currentGenerationID,
            latestAttemptID: state.latestAttemptID,
            availability: state.availability,
            updatedAt: state.updatedAt
        )
    }

    func currentGeneration() throws -> CatalogGenerationSnapshot? {
        guard let state = try fetchState(),
              state.availability == .available || state.availability == .stale,
              let generationID = state.currentGenerationID
        else { return nil }
        guard let generation = try fetchGeneration(id: generationID) else { return nil }
        return Self.snapshot(generation)
    }

    /// Reads only the generation published by CatalogState. Building and
    /// abandoned rows are never browseable through this API.
    func currentObservations() throws -> [CatalogAssetObservationSnapshot] {
        guard let state = try fetchState(),
              state.availability == .available || state.availability == .stale,
              let generationID = state.currentGenerationID
        else { return [] }
        return try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.generationID == generationID }
        ))
        .sorted { $0.assetID < $1.assetID }
        .map { CatalogAssetObservationSnapshot(generationID: generationID, asset: $0.photoAsset) }
    }

    /// Events are advisory. A consumer must re-read durable state after an
    /// event; an event is yielded only after its catalog transaction saves.
    func catalogCommitEvents() -> AsyncStream<CatalogCommitEvent> {
        let streamID = UUID()
        let (stream, continuation) = AsyncStream<CatalogCommitEvent>.makeStream()
        commitEventContinuations[streamID] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeCommitEventContinuation(streamID) }
        }
        return stream
    }

    func commitEvents() -> AsyncStream<CatalogCommitEvent> {
        catalogCommitEvents()
    }

    func analysisWorkStates() throws -> [AnalysisWorkStateSnapshot] {
        try context.fetch(FetchDescriptor<AnalysisWorkState>())
            .sorted { $0.identity < $1.identity }
            .map { $0.snapshot() }
    }

    func analysisWorkState(
        for assetID: AssetID,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkStateSnapshot? {
        try fetchAnalysisWorkState(assetID: assetID.rawValue, capability: capability)?.snapshot()
    }
}

extension LibraryCatalogStore {
    func acquireReconciliationFlight() throws {
        guard !reconciliationInFlight, !reconciliationQueued else {
            throw LibraryCatalogStoreError.reconciliationInProgress
        }
        reconciliationInFlight = true
    }

    func releaseReconciliationFlight() {
        reconciliationInFlight = false
    }

    func pruneCatalogHistoryIfNeeded() {
        try? Self.pruneCatalogHistory(in: context)
    }

    func drainReconciliationQueue(using photoLibrary: any PhotoLibraryService) async {
        reconciliationQueued = false
        repeat {
            reconciliationPending = false
            do {
                _ = try await reconcile(using: photoLibrary)
            } catch is CancellationError {
                return
            } catch {
                // The failed attempt and its browseability are recorded by
                // reconcile; a notification can still request one follow-up.
            }
        } while reconciliationPending && !Task.isCancelled
    }

    func beginGeneration(id: UUID, authorization: CatalogAuthorizationSnapshot) throws {
        let now = Date()
        try context.transaction {
            let state = try stateOrCreate(availability: .unavailable)
            context.insert(CatalogGeneration(id: id, authorization: authorization, startedAt: now))
            state.latestAttemptID = id
            state.updatedAt = now
            try context.save()
        }
    }

    func stage(_ assets: [PhotoAsset], generationID: UUID) throws {
        guard !assets.isEmpty else { return }
        try context.transaction {
            for asset in assets {
                context.insert(CatalogAssetObservation(generationID: generationID, asset: asset))
            }
            if let generation = try fetchGeneration(id: generationID) {
                generation.assetCount += assets.count
            }
            try context.save()
        }
    }

    func commit(
        generationID: UUID,
        assets: [PhotoAsset],
        assetIDs: Set<String>,
        authorization: CatalogAuthorizationSnapshot
    ) throws -> [AssetID] {
        let now = Date()
        let previousFingerprints = try currentFingerprints()
        var changedIDs: [AssetID] = []

        try context.transaction {
            guard let generation = try fetchGeneration(id: generationID), generation.status == .building else {
                throw LibraryCatalogStoreError.incompleteGeneration
            }
            let stagedCount = generation.assetCount
            guard stagedCount == assetIDs.count else {
                throw LibraryCatalogStoreError.incompleteGeneration
            }

            let assetIDList = Array(assetIDs)
            let libraryAssets = try context.fetch(FetchDescriptor<LibraryAsset>(
                predicate: #Predicate { assetIDList.contains($0.assetID) }
            ))
            let byID = Dictionary(uniqueKeysWithValues: libraryAssets.map { ($0.assetID, $0) })
            for asset in assets {
                let libraryAsset = byID[asset.id.rawValue]
                    ?? LibraryAsset(assetID: asset.id.rawValue, lastObservedGenerationID: generationID)
                if libraryAsset.modelContext == nil {
                    context.insert(libraryAsset)
                }
                libraryAsset.lastObservedGenerationID = generationID
                libraryAsset.updatedAt = now

                let oldFingerprint = previousFingerprints[asset.id.rawValue]
                if oldFingerprint != asset.modificationFingerprint {
                    changedIDs.append(asset.id)
                }
            }

            try reconcileAnalysisWorkStates(generationID: generationID, assets: assets)

            generation.status = .committed
            generation.authorizationRawValue = authorization.rawValue
            generation.completedAt = now
            generation.assetCount = stagedCount
            generation.failureCategory = nil

            let state = try stateOrCreate(availability: .available)
            state.currentGenerationID = generationID
            state.availability = .available
            state.updatedAt = now
            try context.save()
        }
        emitCommitEvent(CatalogCommitEvent(
            id: UUID(),
            kind: .generationCommitted,
            generationID: generationID,
            assetID: nil,
            capability: nil,
            analysisResult: nil,
            occurredAt: now
        ))
        return changedIDs
    }

    func abandon(
        generationID: UUID,
        category: CatalogFailureCategory
    ) throws {
        let now = Date()
        try context.transaction {
            guard let generation = try fetchGeneration(id: generationID) else { return }
            if generation.status == .building {
                generation.status = .abandoned
                generation.completedAt = now
                generation.failureCategory = category
            }
            let state = try stateOrCreate(availability: .unavailable)
            state.availability = Self.availability(
                for: category,
                hasPriorGeneration: state.currentGenerationID != nil
            )
            state.updatedAt = now
            try context.save()
        }
    }

    func currentFingerprints() throws -> [String: AssetModificationFingerprint] {
        guard let generationID = try fetchState()?.currentGenerationID else { return [:] }
        return try Dictionary(
            uniqueKeysWithValues: context.fetch(FetchDescriptor<CatalogAssetObservation>(
                predicate: #Predicate { $0.generationID == generationID }
            ))
            .map { ($0.assetID, $0.modificationFingerprint) }
        )
    }

    func fetchState() throws -> CatalogState? {
        let singletonKey = CatalogState.singletonID
        return try context.fetch(FetchDescriptor<CatalogState>(
            predicate: #Predicate { $0.singletonKey == singletonKey }
        )).first
    }

    func stateOrCreate(availability: CatalogAvailability) throws -> CatalogState {
        if let state = try fetchState() {
            return state
        }
        let state = CatalogState(availability: availability)
        context.insert(state)
        return state
    }

    func fetchGeneration(id: UUID) throws -> CatalogGeneration? {
        try context.fetch(FetchDescriptor<CatalogGeneration>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    func removeCommitEventContinuation(_ id: UUID) {
        commitEventContinuations.removeValue(forKey: id)
    }

    func emitCommitEvent(_ event: CatalogCommitEvent) {
        for id in Array(commitEventContinuations.keys) {
            guard let continuation = commitEventContinuations[id] else { continue }
            if case .terminated = continuation.yield(event) {
                commitEventContinuations.removeValue(forKey: id)
            }
        }
    }

    func fetchAnalysisWorkState(
        assetID: String,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkState? {
        let workIdentity = AnalysisWorkState.identity(assetID: assetID, capability: capability)
        return try context.fetch(FetchDescriptor<AnalysisWorkState>(
            predicate: #Predicate { $0.identity == workIdentity }
        )).first
    }

    func requestAnalysis(
        for asset: PhotoAsset,
        generationID: UUID,
        revision: AnalysisCapabilityRevision = .currentNativeImageFacts
    ) throws -> AnalysisWorkStateSnapshot {
        guard revision.capability == .nativeImageFacts else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard try isCurrentGeneration(generationID) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: asset.id.rawValue,
            generationID: generationID
        ), observation.modificationFingerprint == asset.modificationFingerprint else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged)
        }

        let state = try fetchAnalysisWorkState(assetID: asset.id.rawValue, capability: revision.capability)
            ?? AnalysisWorkState(
                assetID: asset.id.rawValue,
                generationID: generationID,
                fingerprint: asset.modificationFingerprint,
                revision: revision
            )
        try context.transaction {
            if state.modelContext == nil {
                context.insert(state)
            }
            state.generationID = generationID
            state.requestedModificationDate = asset.modificationFingerprint.modificationDate
            state.requestedFingerprintIsPresent = asset.modificationFingerprint.isPresent
            state.requestedAnalysisRevision = revision.analysisRevision.rawValue
            state.requestedProviderRuntimeRevision = revision.providerRuntimeRevision.rawValue
            state.status = .pending
            state.reason = nil
            clearCompletedEvidence(from: state)
            try context.save()
        }
        return state.snapshot()
    }

    func beginAnalysis(_ candidate: AnalysisCommitCandidate) throws -> AnalysisWorkStateSnapshot {
        let state = try guardedWorkState(for: candidate, allowStatuses: [.pending, .running])
        try context.transaction {
            state.status = .running
            state.reason = nil
            try context.save()
        }
        return state.snapshot()
    }

    func markAnalysisRunning(_ candidate: AnalysisCommitCandidate) throws -> AnalysisWorkStateSnapshot {
        try beginAnalysis(candidate)
    }

    func recordAnalysisUnavailable(
        for assetID: AssetID,
        generationID: UUID,
        fingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision,
        reason: AnalysisWorkReason
    ) throws -> AnalysisWorkStateSnapshot {
        guard reason != .completedEmpty else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workNotRequested)
        }
        let candidate = AnalysisCommitCandidate(
            generationID: generationID,
            assetID: assetID,
            assetFingerprint: fingerprint,
            revision: revision,
            evidence: AnalysisEvidenceReference(
                identifier: "unavailable",
                assetID: assetID,
                assetFingerprint: fingerprint,
                revision: revision
            )
        )
        let state = try guardedWorkState(for: candidate, allowStatuses: [.pending, .running, .stale])
        try context.transaction {
            state.status = .unavailable
            state.reason = reason
            clearCompletedEvidence(from: state)
            try context.save()
        }
        return state.snapshot()
    }

    /// Commits only the reference to evidence already durably written by the
    /// evidence boundary. Every guard is evaluated while actor-isolated and
    /// before the SwiftData transaction is saved.
    func commitAnalysis(_ candidate: AnalysisCommitCandidate) throws -> AnalysisCommitResult {
        guard candidate.revision.capability == .nativeImageFacts,
              candidate.evidence.assetID == candidate.assetID,
              candidate.evidence.capability == candidate.revision.capability,
              candidate.evidence.assetFingerprint == candidate.assetFingerprint,
              candidate.evidence.revision == candidate.revision
        else { return .rejected(.evidenceReferenceMismatch) }

        guard try isCurrentGeneration(candidate.generationID) else {
            return .rejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: candidate.assetID.rawValue,
            generationID: candidate.generationID
        ) else { return .rejected(.assetChanged) }
        guard observation.modificationFingerprint == candidate.assetFingerprint else {
            return .rejected(.assetChanged)
        }
        guard let state = try fetchAnalysisWorkState(
            assetID: candidate.assetID.rawValue,
            capability: candidate.revision.capability
        ) else { return .rejected(.workStateMissing) }
        guard state.generationID == candidate.generationID else {
            return .rejected(.generationChanged)
        }
        guard state.requestedAssetFingerprint == candidate.assetFingerprint else {
            return .rejected(.assetChanged)
        }
        guard state.requestedRevision == candidate.revision else {
            return .rejected(.capabilityRevisionChanged)
        }
        guard state.status == .pending || state.status == .running else {
            return state.status == .available
                ? .rejected(.workAlreadyCommitted)
                : .rejected(.workNotRequested)
        }

        try context.transaction {
            state.completedModificationDate = candidate.assetFingerprint.modificationDate
            state.completedFingerprintIsPresent = candidate.assetFingerprint.isPresent
            state.completedAnalysisRevision = candidate.revision.analysisRevision.rawValue
            state.completedProviderRuntimeRevision = candidate.revision.providerRuntimeRevision.rawValue
            state.evidenceIdentifier = candidate.evidence.identifier
            state.status = .available
            state.reason = candidate.outcome == .completedEmpty ? .completedEmpty : nil
            try context.save()
        }

        let snapshot = state.snapshot()
        emitCommitEvent(CatalogCommitEvent(
            id: UUID(),
            kind: .analysisCommitted,
            generationID: candidate.generationID,
            assetID: candidate.assetID,
            capability: candidate.revision.capability,
            analysisResult: .committed(snapshot),
            occurredAt: Date()
        ))
        return .committed(snapshot)
    }

    func commitEvidence(_ candidate: AnalysisCommitCandidate) throws -> AnalysisCommitResult {
        try commitAnalysis(candidate)
    }

    private func clearCompletedEvidence(from state: AnalysisWorkState) {
        state.completedModificationDate = nil
        state.completedFingerprintIsPresent = false
        state.completedAnalysisRevision = nil
        state.completedProviderRuntimeRevision = nil
        state.evidenceIdentifier = nil
    }

    private func isCurrentGeneration(_ generationID: UUID) throws -> Bool {
        guard let state = try fetchState() else { return false }
        return state.currentGenerationID == generationID
            && (state.availability == .available || state.availability == .stale)
    }

    private func fetchObservation(assetID: String, generationID: UUID) throws -> CatalogAssetObservation? {
        let identity = CatalogAssetObservation.identity(generationID: generationID, assetID: assetID)
        return try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.identity == identity }
        )).first
    }

    private func guardedWorkState(
        for candidate: AnalysisCommitCandidate,
        allowStatuses: Set<AnalysisWorkStatus>
    ) throws -> AnalysisWorkState {
        guard candidate.revision.capability == .nativeImageFacts else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard try isCurrentGeneration(candidate.generationID) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: candidate.assetID.rawValue,
            generationID: candidate.generationID
        ), observation.modificationFingerprint == candidate.assetFingerprint else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged)
        }
        guard let state = try fetchAnalysisWorkState(
            assetID: candidate.assetID.rawValue,
            capability: candidate.revision.capability
        ) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workStateMissing)
        }
        guard state.generationID == candidate.generationID,
              state.requestedAssetFingerprint == candidate.assetFingerprint
        else { throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged) }
        guard state.requestedRevision == candidate.revision else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard allowStatuses.contains(state.status) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workNotRequested)
        }
        return state
    }

    /// Reconciliation changes the work projection only after a complete
    /// generation has been staged. Work for changed or removed assets is made
    /// stale, while matching completed work is retained for reuse.
    private func reconcileAnalysisWorkStates(generationID: UUID, assets: [PhotoAsset]) throws {
        let capability = AnalysisCapability.nativeImageFacts
        let revision = AnalysisCapabilityRevision.currentNativeImageFacts
        let currentAssets = Dictionary(uniqueKeysWithValues: assets.map { ($0.id.rawValue, $0) })
        let states = try context.fetch(FetchDescriptor<AnalysisWorkState>()).filter {
            $0.capability == capability
        }
        var byIdentity = Dictionary(uniqueKeysWithValues: states.map { ($0.identity, $0) })

        for asset in assets {
            let identity = AnalysisWorkState.identity(assetID: asset.id.rawValue, capability: capability)
            let state: AnalysisWorkState
            if let existing = byIdentity[identity] {
                state = existing
            } else {
                state = AnalysisWorkState(
                    assetID: asset.id.rawValue,
                    generationID: generationID,
                    fingerprint: asset.modificationFingerprint,
                    revision: revision
                )
                context.insert(state)
                byIdentity[identity] = state
                continue
            }

            let fingerprintChanged = state.requestedAssetFingerprint != asset.modificationFingerprint
            let revisionChanged = state.requestedRevision != revision
            state.generationID = generationID
            if fingerprintChanged || revisionChanged {
                state.requestedModificationDate = asset.modificationFingerprint.modificationDate
                state.requestedFingerprintIsPresent = asset.modificationFingerprint.isPresent
                state.requestedAnalysisRevision = revision.analysisRevision.rawValue
                state.requestedProviderRuntimeRevision = revision.providerRuntimeRevision.rawValue
                state.status = .stale
                state.reason = .revisionStale
                clearCompletedEvidence(from: state)
            } else if state.status == .running {
                // A new generation invalidates the old in-flight token. The
                // same revision/fingerprint can be resumed from pending.
                state.status = .pending
                state.reason = nil
            } else if state.status == .available, state.evidence == nil {
                // Evidence loss is a cache miss, never successful completion.
                state.status = .pending
                state.reason = nil
            }
        }

        for state in states where currentAssets[state.assetID] == nil {
            state.generationID = generationID
            state.status = .stale
            state.reason = .revisionStale
        }
    }

    static func recoverInterruptedGenerations(in context: ModelContext) throws {
        let buildingRawValue = CatalogGenerationStatus.building.rawValue
        let generations = try context.fetch(FetchDescriptor<CatalogGeneration>(
            predicate: #Predicate { $0.statusRawValue == buildingRawValue }
        ))
        guard !generations.isEmpty else { return }

        let now = Date()
        try context.transaction {
            for generation in generations {
                generation.status = .abandoned
                generation.completedAt = now
                generation.failureCategory = .interrupted
            }

            let singletonKey = CatalogState.singletonID
            let state = try context.fetch(FetchDescriptor<CatalogState>(
                predicate: #Predicate { $0.singletonKey == singletonKey }
            )).first
            if let state {
                state.availability = state.currentGenerationID == nil ? .unavailable : .stale
                state.updatedAt = now
            } else {
                context.insert(CatalogState(availability: .unavailable, updatedAt: now))
            }
            try context.save()
        }
    }

    static func pruneCatalogHistory(in context: ModelContext) throws {
        try context.transaction {
            let generations = try context.fetch(FetchDescriptor<CatalogGeneration>())
            let singletonKey = CatalogState.singletonID
            let state = try context.fetch(FetchDescriptor<CatalogState>(
                predicate: #Predicate { $0.singletonKey == singletonKey }
            )).first
            let currentGenerationID = state?.currentGenerationID

            let committed = generations
                .filter { $0.status == .committed }
                .sorted { $0.startedAt > $1.startedAt }
            let abandoned = generations
                .filter { $0.status == .abandoned }
                .sorted { $0.startedAt > $1.startedAt }
            var retainedIDs = Set(committed.prefix(retainedSupersededGenerationCount).map(\.id))
            retainedIDs.formUnion(abandoned.prefix(retainedAbandonedGenerationCount).map(\.id))
            if let currentGenerationID {
                retainedIDs.insert(currentGenerationID)
            }

            for generation in generations where generation.status != .building {
                guard generation.id != currentGenerationID, !retainedIDs.contains(generation.id) else {
                    continue
                }
                let generationID = generation.id
                let observations = try context.fetch(FetchDescriptor<CatalogAssetObservation>(
                    predicate: #Predicate { $0.generationID == generationID }
                ))
                for observation in observations {
                    context.delete(observation)
                }
                context.delete(generation)
            }
            try context.save()
        }
    }

    static func snapshot(for authorization: PhotoLibraryAuthorization) -> CatalogAuthorizationSnapshot {
        switch authorization {
        case .notDetermined: .notDetermined
        case .limited: .limited
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    static func isAccessible(_ authorization: PhotoLibraryAuthorization) -> Bool {
        switch authorization {
        case .authorized, .limited: true
        case .notDetermined, .denied, .restricted: false
        }
    }

    static func failureCategory(for error: LibraryCatalogStoreError) -> CatalogFailureCategory {
        switch error {
        case .accessRequired: .accessRequired
        case .authorizationChanged: .authorizationChanged
        case .duplicateAssetID: .duplicateAssetID
        case .fetchFailed: .fetchFailed
        case .incompleteGeneration: .incomplete
        case .analysisTransitionRejected: .incomplete
        case .persistenceFailed, .unavailable: .persistenceFailed
        case .reconciliationInProgress: .incomplete
        }
    }

    static func availability(
        for category: CatalogFailureCategory,
        hasPriorGeneration: Bool
    ) -> CatalogAvailability {
        switch category {
        case .accessRequired:
            .accessRequired
        case .authorizationChanged, .cancelled, .duplicateAssetID, .fetchFailed, .incomplete,
             .interrupted, .persistenceFailed:
            hasPriorGeneration ? .stale : .unavailable
        }
    }

    static func snapshot(_ generation: CatalogGeneration) -> CatalogGenerationSnapshot {
        CatalogGenerationSnapshot(
            id: generation.id,
            status: generation.status,
            authorization: generation.authorization,
            startedAt: generation.startedAt,
            completedAt: generation.completedAt,
            assetCount: generation.assetCount,
            failureCategory: generation.failureCategory
        )
    }
}
