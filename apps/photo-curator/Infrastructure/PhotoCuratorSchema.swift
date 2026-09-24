// swiftlint:disable trailing_comma
import SwiftData

/// The workspace schema before durable original-deletion operations were added.
enum PhotoCuratorSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ReviewScope.self,
            WorkspaceItem.self,
            WorkspaceMigrationMarker.self,
            AlbumSaveOperation.self,
        ]
    }
}

/// The current workspace schema. Deletion operations are additive and do not
/// alter any existing workspace or staged-choice fields.
enum PhotoCuratorSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        PhotoCuratorSchemaV1.models + [PhotoDeletionOperation.self]
    }
}

/// Additive catalog schema. Existing workspace and operation declarations stay
/// in V1/V2 so their migration history remains unchanged.
enum PhotoCuratorSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        PhotoCuratorSchemaV2.models + [
            LibraryAsset.self,
            CatalogAssetObservation.self,
            CatalogGeneration.self,
            CatalogState.self,
        ]
    }
}

/// Additive analysis work state. Evidence remains outside SwiftData; this
/// schema stores only the current per-asset/capability projection.
enum PhotoCuratorSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        PhotoCuratorSchemaV3.models + [AnalysisWorkState.self]
    }
}

/// Additive comparison projections. Visual hashes, feature prints, vectors,
/// decoded images, and candidate buckets remain transient and are not models.
enum PhotoCuratorSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        PhotoCuratorSchemaV4.models + [
            CatalogComparisonState.self,
            CatalogComparisonSnapshotProjection.self,
            CatalogComparisonGroupProjection.self,
            CatalogComparisonMemberProjection.self,
        ]
    }
}

/// Additive comparison coverage and revision-bound evidence rows.
enum PhotoCuratorSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        PhotoCuratorSchemaV5.models + [CatalogComparisonEvidenceProjection.self]
    }
}

enum PhotoCuratorMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            PhotoCuratorSchemaV1.self,
            PhotoCuratorSchemaV2.self,
            PhotoCuratorSchemaV3.self,
            PhotoCuratorSchemaV4.self,
            PhotoCuratorSchemaV5.self,
            PhotoCuratorSchemaV6.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: PhotoCuratorSchemaV1.self,
                toVersion: PhotoCuratorSchemaV2.self
            ),
            .lightweight(
                fromVersion: PhotoCuratorSchemaV2.self,
                toVersion: PhotoCuratorSchemaV3.self
            ),
            .lightweight(
                fromVersion: PhotoCuratorSchemaV3.self,
                toVersion: PhotoCuratorSchemaV4.self
            ),
            .lightweight(
                fromVersion: PhotoCuratorSchemaV4.self,
                toVersion: PhotoCuratorSchemaV5.self
            ),
            .lightweight(
                fromVersion: PhotoCuratorSchemaV5.self,
                toVersion: PhotoCuratorSchemaV6.self
            ),
        ]
    }
}

// swiftlint:enable trailing_comma
