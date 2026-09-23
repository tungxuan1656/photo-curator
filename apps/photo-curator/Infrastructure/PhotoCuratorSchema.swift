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

enum PhotoCuratorMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PhotoCuratorSchemaV1.self, PhotoCuratorSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: PhotoCuratorSchemaV1.self,
                toVersion: PhotoCuratorSchemaV2.self
            ),
        ]
    }
}

// swiftlint:enable trailing_comma
