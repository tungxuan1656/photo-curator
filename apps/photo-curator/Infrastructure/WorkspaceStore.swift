import Foundation
import SwiftData

struct WorkspaceItemSnapshot: Equatable, Sendable {
    let scopeID: UUID
    let assetID: AssetID
    let cleanupDisposition: CleanupDisposition
    let albumMembership: AlbumMembership
    let reviewProgress: ReviewProgress
    let analysisRef: String?
    let analysisAvailable: Bool
    let analysisVersion: Int?
    let updatedAt: Date
}

struct ReviewScopeSnapshot: Equatable, Sendable {
    let id: UUID
    let intent: ReviewIntent
    let sourceAssetIDs: [AssetID]
    let createdAt: Date
    let updatedAt: Date
}

enum WorkspaceStoreError: Error, Sendable {
    case scopeNotFound
    case assetNotInScope
    case itemNotFound
    case invalidState
}

/// Concrete SwiftData owner for durable workspace state. It intentionally
/// exposes values, not PersistentModel instances, across the actor boundary.
actor WorkspaceStore {
    static let legacyMigrationKey = "legacy-selection-v1"

    let modelContainer: ModelContainer
    private let context: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        context = ModelContext(modelContainer)
    }

    func hasCompletedMigration(key: String = "legacy-selection-v1") -> Bool {
        let markers = (try? context.fetch(FetchDescriptor<WorkspaceMigrationMarker>())) ?? []
        return markers.contains { $0.key == key }
    }

    /// Creates a durable scope without materializing item rows.
    func createScope(
        id: UUID = UUID(),
        intent: ReviewIntent,
        sourceAssetIDs: [AssetID]
    ) throws -> ReviewScopeSnapshot {
        let now = Date()
        let orderedIDs = orderedAssetIDs(sourceAssetIDs.map(\.rawValue))
        let scopes = try context.fetch(FetchDescriptor<ReviewScope>())
        if let existing = scopes.first(where: { $0.id == id }) {
            existing.intentRawValue = intent.rawValue
            existing.updatedAt = now
            try context.save()
            return makeScopeSnapshot(existing)
        }
        let scope = ReviewScope(
            id: id,
            intent: intent,
            sourceAssetIDs: orderedIDs,
            createdAt: now,
            updatedAt: now
        )
        context.insert(scope)
        try context.save()
        return makeScopeSnapshot(scope)
    }

    func listScopes() throws -> [ReviewScopeSnapshot] {
        try context.fetch(FetchDescriptor<ReviewScope>())
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map(makeScopeSnapshot)
    }

    func loadScope(id: UUID) throws -> ReviewScopeSnapshot? {
        guard let scope = try context.fetch(FetchDescriptor<ReviewScope>()).first(where: { $0.id == id }) else {
            return nil
        }
        return makeScopeSnapshot(scope)
    }

    func createItem(
        scopeID: UUID,
        assetID: AssetID,
        cleanupDisposition: CleanupDisposition = .undecided,
        albumMembership: AlbumMembership = .unset,
        reviewProgress: ReviewProgress = .unseen,
        analysisRef: String? = nil,
        analysisAvailable: Bool = false,
        analysisVersion: Int? = nil
    ) throws -> WorkspaceItemSnapshot {
        var result: WorkspaceItemSnapshot?
        try context.transaction {
            let scope = try requireScope(scopeID)
            try requireAsset(assetID, sourceAssetIDs: scope.sourceAssetIDs)
            let items = try context.fetch(FetchDescriptor<WorkspaceItem>())
            if let existing = items.first(where: {
                $0.scopeID == scopeID && $0.assetID == assetID.rawValue
            }) {
                result = makeItemSnapshot(existing)
                return
            }
            let now = Date()
            let item = WorkspaceItem(
                scopeID: scopeID,
                assetID: assetID.rawValue,
                cleanupDisposition: cleanupDisposition,
                albumMembership: albumMembership,
                reviewProgress: reviewProgress,
                analysisRef: analysisRef,
                analysisAvailable: analysisAvailable,
                analysisVersion: analysisVersion,
                createdAt: now,
                updatedAt: now
            )
            scope.updatedAt = now
            context.insert(item)
            try context.save()
            result = makeItemSnapshot(item)
        }
        guard let result else { throw WorkspaceStoreError.invalidState }
        return result
    }

    func listItems(scopeID: UUID) throws -> [WorkspaceItemSnapshot] {
        guard try loadScope(id: scopeID) != nil else { throw WorkspaceStoreError.scopeNotFound }
        return try context.fetch(FetchDescriptor<WorkspaceItem>())
            .filter { $0.scopeID == scopeID }
            .map(makeItemSnapshot)
            .sorted { $0.assetID.rawValue < $1.assetID.rawValue }
    }

    func loadItem(scopeID: UUID, assetID: AssetID) throws -> WorkspaceItemSnapshot? {
        guard let scope = try loadScope(id: scopeID) else { throw WorkspaceStoreError.scopeNotFound }
        try requireAsset(assetID, sourceAssetIDs: scope.sourceAssetIDs.map(\.rawValue))
        guard let item = try context.fetch(FetchDescriptor<WorkspaceItem>()).first(where: {
            $0.scopeID == scopeID && $0.assetID == assetID.rawValue
        }) else {
            return nil
        }
        return makeItemSnapshot(item)
    }

    func updateCleanupDisposition(
        _ disposition: CleanupDisposition,
        scopeID: UUID,
        assetID: AssetID
    ) throws -> WorkspaceItemSnapshot {
        try updateItem(scopeID: scopeID, assetID: assetID) { item in
            item.cleanupDispositionRawValue = disposition.rawValue
        }
    }

    func updateAlbumMembership(
        _ membership: AlbumMembership,
        scopeID: UUID,
        assetID: AssetID
    ) throws -> WorkspaceItemSnapshot {
        try updateItem(scopeID: scopeID, assetID: assetID) { item in
            item.albumMembershipRawValue = membership.rawValue
        }
    }

    func updateReviewProgress(
        _ progress: ReviewProgress,
        scopeID: UUID,
        assetID: AssetID
    ) throws -> WorkspaceItemSnapshot {
        try updateItem(scopeID: scopeID, assetID: assetID) { item in
            item.reviewProgressRawValue = progress.rawValue
        }
    }

    /// Imports one legacy session in one transaction. Repeating this call
    /// updates the same scope/items instead of creating duplicate rows.
    func importLegacyScope(
        scopeID: UUID,
        sourceAssetIDs: [AssetID],
        albumMemberships: [AssetID: AlbumMembership]
    ) throws {
        let now = Date()
        let orderedIDs = orderedAssetIDs(
            sourceAssetIDs.map(\.rawValue) + albumMemberships.keys.map(\.rawValue).sorted()
        )
        guard !orderedIDs.isEmpty else { return }

        try context.transaction {
            let scopes = try context.fetch(FetchDescriptor<ReviewScope>())
            let scope = scopes.first { $0.id == scopeID }
                ?? ReviewScope(
                    id: scopeID,
                    intent: .album,
                    sourceAssetIDs: orderedIDs,
                    createdAt: now,
                    updatedAt: now
                )
            if scope.modelContext == nil {
                context.insert(scope)
            }
            scope.sourceAssetIDs = orderedIDs
            scope.updatedAt = now

            let items = try context.fetch(FetchDescriptor<WorkspaceItem>())
            for assetID in orderedIDs {
                let itemIdentity = WorkspaceItem.identity(scopeID: scopeID, assetID: assetID)
                let item = items.first { $0.identity == itemIdentity }
                    ?? WorkspaceItem(scopeID: scopeID, assetID: assetID, createdAt: now, updatedAt: now)
                if item.modelContext == nil {
                    context.insert(item)
                }
                if let membership = albumMemberships[AssetID(rawValue: assetID)] {
                    item.albumMembershipRawValue = membership.rawValue
                }
                item.updatedAt = now
            }
            try context.save()
        }
    }

    func markMigrationCommitted(
        key: String = "legacy-selection-v1",
        version: Int = 1
    ) throws {
        let now = Date()
        try context.transaction {
            let markers = try context.fetch(FetchDescriptor<WorkspaceMigrationMarker>())
            if markers.contains(where: { $0.key == key }) {
                return
            }
            context.insert(WorkspaceMigrationMarker(key: key, version: version, committedAt: now))
            try context.save()
        }
    }

    /// Deletes one durable scope and every item row bound to it.
    /// Absent scopes/items already count as success (idempotent) so
    /// discard/finish/reset never leave orphaned workspace rows.
    func deleteScope(id scopeID: UUID) throws {
        try context.transaction {
            let scopes = try context.fetch(FetchDescriptor<ReviewScope>())
            guard let scope = scopes.first(where: { $0.id == scopeID }) else { return }
            let items = try context.fetch(FetchDescriptor<WorkspaceItem>())
            for item in items where item.scopeID == scopeID {
                context.delete(item)
            }
            context.delete(scope)
            try context.save()
        }
    }

    /// Updates the persisted entry intent (home handoff → session resume).
    /// A recreated scope for an existing session keeps its item rows and
    /// only refreshes the intent label.
    func updateScopeIntent(_ intent: ReviewIntent, scopeID: UUID) throws -> ReviewScopeSnapshot {
        var result: ReviewScopeSnapshot?
        try context.transaction {
            let scope = try requireScope(scopeID)
            scope.intentRawValue = intent.rawValue
            scope.updatedAt = Date()
            try context.save()
            result = makeScopeSnapshot(scope)
        }
        guard let result else { throw WorkspaceStoreError.invalidState }
        return result
    }

    private func updateItem(
        scopeID: UUID,
        assetID: AssetID,
        mutation: (WorkspaceItem) -> Void
    ) throws -> WorkspaceItemSnapshot {
        var result: WorkspaceItemSnapshot?
        try context.transaction {
            let scope = try requireScope(scopeID)
            try requireAsset(assetID, sourceAssetIDs: scope.sourceAssetIDs)
            let items = try context.fetch(FetchDescriptor<WorkspaceItem>())
            guard let item = items.first(where: {
                $0.scopeID == scopeID && $0.assetID == assetID.rawValue
            }) else { throw WorkspaceStoreError.itemNotFound }
            let now = Date()
            mutation(item)
            item.updatedAt = now
            scope.updatedAt = now
            try context.save()
            result = makeItemSnapshot(item)
        }
        guard let result else { throw WorkspaceStoreError.invalidState }
        return result
    }

    private func requireScope(_ scopeID: UUID) throws -> ReviewScope {
        guard let scope = try context.fetch(FetchDescriptor<ReviewScope>()).first(where: { $0.id == scopeID }) else {
            throw WorkspaceStoreError.scopeNotFound
        }
        return scope
    }

    private func requireAsset(_ assetID: AssetID, sourceAssetIDs: [String]) throws {
        guard sourceAssetIDs.contains(assetID.rawValue) else { throw WorkspaceStoreError.assetNotInScope }
    }

    private func orderedAssetIDs(_ rawIDs: [String]) -> [String] {
        var seenIDs = Set<String>()
        return rawIDs.filter { seenIDs.insert($0).inserted }
    }

    private func makeScopeSnapshot(_ scope: ReviewScope) -> ReviewScopeSnapshot {
        ReviewScopeSnapshot(
            id: scope.id,
            intent: scope.intent,
            sourceAssetIDs: scope.sourceAssetIDs.map { AssetID(rawValue: $0) },
            createdAt: scope.createdAt,
            updatedAt: scope.updatedAt
        )
    }

    private func makeItemSnapshot(_ item: WorkspaceItem) -> WorkspaceItemSnapshot {
        WorkspaceItemSnapshot(
            scopeID: item.scopeID,
            assetID: AssetID(rawValue: item.assetID),
            cleanupDisposition: item.cleanupDisposition,
            albumMembership: item.albumMembership,
            reviewProgress: item.reviewProgress,
            analysisRef: item.analysisRef,
            analysisAvailable: item.analysisAvailable,
            analysisVersion: item.analysisVersion,
            updatedAt: item.updatedAt
        )
    }
}
