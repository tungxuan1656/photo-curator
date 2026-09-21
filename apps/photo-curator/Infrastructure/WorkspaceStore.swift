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

    /// Imports one legacy session in one transaction. Repeating this call
    /// updates the same scope/items instead of creating duplicate rows.
    func importLegacyScope(
        scopeID: UUID,
        sourceAssetIDs: [AssetID],
        albumMemberships: [AssetID: AlbumMembership]
    ) throws {
        let now = Date()
        var seenIDs = Set<String>()
        var orderedIDs: [String] = []
        for assetID in sourceAssetIDs.map(\.rawValue) {
            guard seenIDs.insert(assetID).inserted else { continue }
            orderedIDs.append(assetID)
        }
        for assetID in albumMemberships.keys.map(\.rawValue).sorted() {
            guard seenIDs.insert(assetID).inserted else { continue }
            orderedIDs.append(assetID)
        }
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

    func scope(id: UUID) throws -> ReviewScopeSnapshot? {
        let scope = try context.fetch(FetchDescriptor<ReviewScope>()).first { $0.id == id }
        guard let scope else { return nil }
        return ReviewScopeSnapshot(
            id: scope.id,
            intent: scope.intent,
            sourceAssetIDs: scope.sourceAssetIDs.map(AssetID.init(rawValue:)),
            createdAt: scope.createdAt,
            updatedAt: scope.updatedAt
        )
    }

    func items(scopeID: UUID) throws -> [WorkspaceItemSnapshot] {
        try context.fetch(FetchDescriptor<WorkspaceItem>())
            .filter { $0.scopeID == scopeID }
            .map {
                WorkspaceItemSnapshot(
                    scopeID: $0.scopeID,
                    assetID: AssetID(rawValue: $0.assetID),
                    cleanupDisposition: $0.cleanupDisposition,
                    albumMembership: $0.albumMembership,
                    reviewProgress: $0.reviewProgress,
                    analysisRef: $0.analysisRef,
                    analysisAvailable: $0.analysisAvailable,
                    analysisVersion: $0.analysisVersion,
                    updatedAt: $0.updatedAt
                )
            }
            .sorted { $0.assetID.rawValue < $1.assetID.rawValue }
    }
}
