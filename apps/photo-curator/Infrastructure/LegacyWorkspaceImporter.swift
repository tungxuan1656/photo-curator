import Foundation
import OSLog

enum LegacyMigrationFailure: Sendable {
    case unreadableArtifacts(count: Int)
    case persistenceFailure
}

enum LegacyMigrationResult: Sendable {
    case alreadyCommitted
    case committed(sessionCount: Int)
    case blocked(LegacyMigrationFailure)
    case failed(LegacyMigrationFailure)
}

/// Imports the old file-backed selection state into the durable workspace.
/// The source files are intentionally retained; the SwiftData marker is the
/// only completion signal and is written after every discovered session lands.
actor LegacyWorkspaceImporter {
    private let checkpointStore: SessionCheckpointStore
    private let workspaceStore: WorkspaceStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "workspace-migration"
    )

    init(checkpointStore: SessionCheckpointStore, workspaceStore: WorkspaceStore) {
        self.checkpointStore = checkpointStore
        self.workspaceStore = workspaceStore
    }

    func importIfNeeded() async -> LegacyMigrationResult {
        guard !(await workspaceStore.hasCompletedMigration()) else { return .alreadyCommitted }

        let artifacts = await checkpointStore.legacySessionArtifacts()
        let unreadableCount = artifacts.reduce(0) { $0 + $1.unreadableArtifactCount }
        guard unreadableCount == 0 else {
            logger.error(
                "Legacy workspace migration blocked: \(unreadableCount, privacy: .public) present artifacts are unreadable; legacy files retained for repair and retry."
            )
            return .blocked(.unreadableArtifacts(count: unreadableCount))
        }

        do {
            for artifact in artifacts {
                let sourceIDs = sourceAssetIDs(from: artifact)
                let memberships = albumMemberships(from: artifact)
                try await workspaceStore.importLegacyScope(
                    scopeID: artifact.sessionID.rawValue,
                    sourceAssetIDs: sourceIDs,
                    albumMemberships: memberships
                )
            }
            try await workspaceStore.markMigrationCommitted()
            return .committed(sessionCount: artifacts.count)
        } catch {
            // Startup remains usable. A later launch retries from the retained
            // legacy files because no completion marker was committed.
            logger.error(
                """
                Legacy workspace migration did not commit; legacy files retained for retry.
                Failure category: migration_persistence_failure.
                """
            )
            return .failed(.persistenceFailure)
        }
    }

    private func sourceAssetIDs(
        from artifacts: SessionCheckpointStore.LegacySessionArtifacts
    ) -> [AssetID] {
        let checkpointIDs = artifacts.decodedCheckpoint?.sourceAssetIDs ?? []
        var assetIDs = checkpointIDs
        var seenIDs = Set(checkpointIDs)
        var additionalIDs = Set<AssetID>()
        if let result = artifacts.decodedResult {
            additionalIDs.formUnion(result.selectedAssetIDs)
            additionalIDs.formUnion(result.rejectedAssetIDs)
            additionalIDs.formUnion(result.decisions.map(\.assetID))
        }
        if let feedback = artifacts.decodedFeedback {
            additionalIDs.formUnion(feedback.removedIDs)
            additionalIDs.formUnion(feedback.restoredIDs)
        }
        for assetID in additionalIDs.sorted(by: { $0.rawValue < $1.rawValue }) where seenIDs.insert(assetID).inserted {
            assetIDs.append(assetID)
        }
        return assetIDs
    }

    private func albumMemberships(
        from artifacts: SessionCheckpointStore.LegacySessionArtifacts
    ) -> [AssetID: AlbumMembership] {
        var memberships: [AssetID: AlbumMembership] = [:]
        if let result = artifacts.decodedResult {
            for assetID in result.rejectedAssetIDs {
                memberships[assetID] = .excluded
            }
            for assetID in result.selectedAssetIDs {
                memberships[assetID] = .included
            }
        }
        if let feedback = artifacts.decodedFeedback {
            for assetID in feedback.removedIDs {
                memberships[assetID] = .excluded
            }
            for assetID in feedback.restoredIDs {
                memberships[assetID] = .included
            }
        }
        return memberships
    }
}
