import Foundation
import SwiftData

enum LibraryCatalogStoreError: Error, Sendable, Equatable {
    case accessRequired
    case authorizationChanged
    case duplicateAssetID
    case fetchFailed
    case incompleteGeneration
    case persistenceFailed
    case reconciliationInProgress
    case reconciliationTimedOut
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
    static let startupTimeoutNanoseconds: UInt64 = 15_000_000_000

    let modelContainer: ModelContainer
    private let context: ModelContext
    private var reconciliationInFlight = false

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        context = ModelContext(modelContainer)
    }

    /// Reconciles one complete Photos enumeration. Actor isolation provides
    /// single-flight behavior for callers and preserves the prior pointer on
    /// every failure path.
    func reconcile(using photoLibrary: any PhotoLibraryService) async throws -> CatalogReconciliationResult {
        guard !Task.isCancelled else { throw CancellationError() }
        guard !reconciliationInFlight else {
            throw LibraryCatalogStoreError.reconciliationInProgress
        }
        reconciliationInFlight = true
        defer { reconciliationInFlight = false }

        let authorization = await photoLibrary.authorizationStatus()
        let initialAuthorization = Self.snapshot(for: authorization)
        let generationID = UUID()
        do {
            try beginGeneration(id: generationID, authorization: initialAuthorization)
        } catch {
            throw LibraryCatalogStoreError.persistenceFailed
        }

        do {
            guard Self.isAccessible(authorization) else {
                throw LibraryCatalogStoreError.accessRequired
            }
            guard !Task.isCancelled else { throw CancellationError() }

            let assets: [PhotoAsset]
            do {
                assets = try await photoLibrary.fetchAssets()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw LibraryCatalogStoreError.fetchFailed
            }
            guard !Task.isCancelled else { throw CancellationError() }

            var seenIDs = Set<String>()
            for asset in assets {
                guard seenIDs.insert(asset.id.rawValue).inserted else {
                    throw LibraryCatalogStoreError.duplicateAssetID
                }
            }

            for batch in assets.chunked(into: Self.observationBatchSize) {
                guard !Task.isCancelled else { throw CancellationError() }
                do {
                    try stage(batch, generationID: generationID)
                } catch {
                    throw LibraryCatalogStoreError.persistenceFailed
                }
            }

            let stagedCount: Int
            do {
                stagedCount = try uniqueObservationCount(for: generationID)
            } catch {
                throw LibraryCatalogStoreError.persistenceFailed
            }
            guard stagedCount == seenIDs.count else {
                throw LibraryCatalogStoreError.incompleteGeneration
            }

            let finalAuthorization = await photoLibrary.authorizationStatus()
            guard !Task.isCancelled else { throw CancellationError() }
            let finalSnapshot = Self.snapshot(for: finalAuthorization)
            guard finalSnapshot == initialAuthorization else {
                if !Self.isAccessible(finalAuthorization) {
                    throw LibraryCatalogStoreError.accessRequired
                }
                throw LibraryCatalogStoreError.authorizationChanged
            }
            guard Self.isAccessible(finalAuthorization) else {
                throw LibraryCatalogStoreError.accessRequired
            }

            let changedAssetIDs: [AssetID]
            do {
                changedAssetIDs = try commit(
                    generationID: generationID,
                    assets: assets,
                    assetIDs: seenIDs,
                    authorization: finalSnapshot
                )
            } catch let error as LibraryCatalogStoreError {
                throw error
            } catch {
                throw LibraryCatalogStoreError.persistenceFailed
            }
            return CatalogReconciliationResult(
                generationID: generationID,
                assetCount: stagedCount,
                changedAssetIDs: changedAssetIDs.sorted { $0.rawValue < $1.rawValue }
            )
        } catch is CancellationError {
            try? abandon(generationID: generationID, category: .cancelled)
            throw CancellationError()
        } catch let error as LibraryCatalogStoreError {
            try? abandon(
                generationID: generationID,
                category: Self.failureCategory(for: error)
            )
            throw error
        } catch {
            try? abandon(
                generationID: generationID,
                category: .persistenceFailed
            )
            throw LibraryCatalogStoreError.persistenceFailed
        }
    }

    /// Bounds lifecycle-triggered work without creating a second writer. The
    /// reconciliation task observes cancellation and abandons its building
    /// generation before the task group returns.
    func reconcileBounded(
        using photoLibrary: any PhotoLibraryService,
        timeoutNanoseconds: UInt64 = LibraryCatalogStore.startupTimeoutNanoseconds
    ) async throws -> CatalogReconciliationResult {
        try await withThrowingTaskGroup(of: CatalogReconciliationResult.self) { group in
            group.addTask { try await self.reconcile(using: photoLibrary) }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw LibraryCatalogStoreError.reconciliationTimedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw LibraryCatalogStoreError.unavailable
            }
            return result
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
        guard let generationID = try fetchState()?.currentGenerationID else { return nil }
        guard let generation = try fetchGeneration(id: generationID) else { return nil }
        return Self.snapshot(generation)
    }

    /// Reads only the generation published by CatalogState. Building and
    /// abandoned rows are never browseable through this API.
    func currentObservations() throws -> [CatalogAssetObservationSnapshot] {
        guard let generationID = try fetchState()?.currentGenerationID else { return [] }
        return try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.generationID == generationID }
        ))
            .sorted { $0.assetID < $1.assetID }
            .map { CatalogAssetObservationSnapshot(generationID: generationID, asset: $0.photoAsset) }
    }
}

private extension LibraryCatalogStore {
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
            let existing = Set(
                try context.fetch(FetchDescriptor<CatalogAssetObservation>(
                    predicate: #Predicate { $0.generationID == generationID }
                ))
                    .map(\.identity)
            )
            var insertedCount = 0
            for asset in assets {
                let identity = CatalogAssetObservation.identity(
                    generationID: generationID,
                    assetID: asset.id.rawValue
                )
                guard !existing.contains(identity) else { continue }
                context.insert(CatalogAssetObservation(generationID: generationID, asset: asset))
                insertedCount += 1
            }
            if let generation = try fetchGeneration(id: generationID) {
                generation.assetCount += insertedCount
            }
            try context.save()
        }
    }

    func uniqueObservationCount(for generationID: UUID) throws -> Int {
        Set(
            try context.fetch(FetchDescriptor<CatalogAssetObservation>(
                predicate: #Predicate { $0.generationID == generationID }
            ))
                .map(\.assetID)
        ).count
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
            let stagedCount = try uniqueObservationCount(for: generationID)
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
        return Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<CatalogAssetObservation>(
                predicate: #Predicate { $0.generationID == generationID }
            ))
                .map { ($0.assetID, $0.modificationFingerprint) }
        )
    }

    func fetchState() throws -> CatalogState? {
        let singletonKey = CatalogState.singletonID
        try context.fetch(FetchDescriptor<CatalogState>(
            predicate: #Predicate { $0.singletonKey == singletonKey }
        )).first
    }

    func stateOrCreate(availability: CatalogAvailability) throws -> CatalogState {
        if let state = try fetchState() { return state }
        let state = CatalogState(availability: availability)
        context.insert(state)
        return state
    }

    func fetchGeneration(id: UUID) throws -> CatalogGeneration? {
        try context.fetch(FetchDescriptor<CatalogGeneration>(
            predicate: #Predicate { $0.id == id }
        )).first
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
        case .persistenceFailed, .unavailable: .persistenceFailed
        case .reconciliationInProgress: .incomplete
        case .reconciliationTimedOut: .cancelled
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
             .persistenceFailed:
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: min(size, distance(from: start, to: endIndex)))
            result.append(Array(self[start..<end]))
            start = end
        }
        return result
    }
}
