import Foundation
import SwiftData

enum LibraryCatalogStoreError: Error, Sendable, Equatable {
    case accessRequired
    case authorizationChanged
    case duplicateAssetID
    case fetchFailed
    case incompleteGeneration
    case analysisPageLimitExceeded
    case invalidQuery
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
    static let analysisPageSize = 32
    static let commitEventBufferSize = 1
    static let retainedAbandonedGenerationCount = 2
    static let retainedSupersededGenerationCount = 2

    let modelContainer: ModelContainer
    let context: ModelContext
    private var reconciliationInFlight = false
    private var reconciliationQueued = false
    private var reconciliationPending = false
    private var commitEventContinuations: [UUID: AsyncStream<CatalogCommitEvent>.Continuation] = [:]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        context = ModelContext(modelContainer)
        try? Self.recoverInterruptedGenerations(in: context)
        try? Self.recoverOrphanedAnalysisWork(in: context)
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
        let (stream, continuation) = AsyncStream<CatalogCommitEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(Self.commitEventBufferSize)
        )
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
        case .analysisPageLimitExceeded: .incomplete
        case .analysisTransitionRejected: .incomplete
        case .persistenceFailed, .unavailable, .invalidQuery: .persistenceFailed
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
