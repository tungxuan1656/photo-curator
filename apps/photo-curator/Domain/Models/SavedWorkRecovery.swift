import Foundation

/// The durable records that can appear in Saved Work. These identities are
/// deliberately typed: a workspace, its legacy handoff, and an operation for
/// the same UUID are different records and must not have their choices merged.
enum SavedWorkItemKind: String, Sendable, Hashable {
    case catalogAction
    case workspaceScope
    case albumSave
    case deletion
    case legacyCheckpoint
    case legacyResult
    case legacyFeedback
}

struct SavedWorkIdentity: Sendable, Hashable {
    let kind: SavedWorkItemKind
    let rawValue: String

    var stableID: String {
        "\(kind.rawValue):\(rawValue)"
    }
}

enum SavedWorkUnavailableReason: String, Sendable, Hashable {
    case storageUnavailable
    case unreadableLegacyArtifact
}

enum SavedWorkAvailability: Sendable, Hashable {
    case available
    case recoveryUnavailable(SavedWorkUnavailableReason)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
}

enum SavedWorkStorage: String, CaseIterable, Sendable, Hashable {
    case catalogActions
    case workspaceScopes
    case albumSaves
    case deletions
    case legacyCheckpoints
}

struct SavedWorkStorageStatus: Sendable, Hashable {
    let storage: SavedWorkStorage
    let isAvailable: Bool
}

/// A legacy file is retained as its own item. Decoded payloads are exposed
/// only as their original type; no legacy selection is converted to a catalog
/// action or a deletion.
struct SavedWorkLegacyArtifact: Sendable {
    let sessionID: SessionID
    let kind: SessionCheckpointStore.LegacyArtifactKind
    let state: SessionCheckpointStore.LegacyArtifactState
    let checkpoint: SessionCheckpoint?
    let result: SelectionResult?
    let feedback: SelectionFeedback?
    let availabilityOverride: SavedWorkUnavailableReason?

    init(
        sessionID: SessionID,
        kind: SessionCheckpointStore.LegacyArtifactKind,
        state: SessionCheckpointStore.LegacyArtifactState,
        checkpoint: SessionCheckpoint?,
        result: SelectionResult?,
        feedback: SelectionFeedback?,
        availabilityOverride: SavedWorkUnavailableReason? = nil
    ) {
        self.sessionID = sessionID
        self.kind = kind
        self.state = state
        self.checkpoint = checkpoint
        self.result = result
        self.feedback = feedback
        self.availabilityOverride = availabilityOverride
    }

    var availability: SavedWorkAvailability {
        if let availabilityOverride {
            return .recoveryUnavailable(availabilityOverride)
        }
        return state.isUnreadable
            ? SavedWorkAvailability.recoveryUnavailable(.unreadableLegacyArtifact)
            : .available
    }

    var updatedAt: Date {
        checkpoint?.updatedAt ?? result?.generatedAt ?? .distantPast
    }
}

/// One typed, non-persistent Saved Work record.
enum SavedWorkRecoveryItem: Sendable, Identifiable {
    case catalogAction(LibraryActionContextSnapshot)
    case workspaceScope(ReviewScopeSnapshot)
    case albumSave(AlbumSaveOperationSnapshot)
    case deletion(PhotoDeletionOperationSnapshot)
    case legacy(SavedWorkLegacyArtifact)

    static func unavailableLegacyStorage(_ storage: SavedWorkStorage) -> Self {
        .legacy(SavedWorkLegacyArtifact(
            sessionID: SessionID(rawValue: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!),
            kind: .checkpoint,
            state: .unreadable,
            checkpoint: nil,
            result: nil,
            feedback: nil,
            availabilityOverride: .storageUnavailable
        ))
    }

    var kind: SavedWorkItemKind {
        switch self {
        case .catalogAction: .catalogAction
        case .workspaceScope: .workspaceScope
        case .albumSave: .albumSave
        case .deletion: .deletion
        case let .legacy(artifact):
            switch artifact.kind {
            case .checkpoint: .legacyCheckpoint
            case .result: .legacyResult
            case .feedback: .legacyFeedback
            }
        }
    }

    var identity: SavedWorkIdentity {
        switch self {
        case let .catalogAction(context):
            SavedWorkIdentity(kind: .catalogAction, rawValue: context.actionID.uuidString)
        case let .workspaceScope(scope):
            SavedWorkIdentity(kind: .workspaceScope, rawValue: scope.id.uuidString)
        case let .albumSave(operation):
            SavedWorkIdentity(kind: .albumSave, rawValue: operation.sessionID.uuidString)
        case let .deletion(operation):
            SavedWorkIdentity(kind: .deletion, rawValue: operation.operationID.uuidString)
        case let .legacy(artifact):
            SavedWorkIdentity(kind: kind, rawValue: artifact.sessionID.rawValue.uuidString)
        }
    }

    var stableID: String {
        identity.stableID
    }

    var id: String {
        stableID
    }

    var availability: SavedWorkAvailability {
        if case let .legacy(artifact) = self {
            return artifact.availability
        }
        return .available
    }

    var updatedAt: Date {
        switch self {
        case let .catalogAction(context): context.updatedAt
        case let .workspaceScope(scope): scope.updatedAt
        case let .albumSave(operation): operation.updatedAt
        case let .deletion(operation): operation.updatedAt
        case let .legacy(artifact): artifact.updatedAt
        }
    }
}

/// Aggregated in memory for the Saved Work surface. This is intentionally not
/// persisted and records unavailable stores instead of presenting an empty
/// list as if storage had been successfully read.
struct SavedWorkRecoverySnapshot: Sendable {
    let items: [SavedWorkRecoveryItem]
    let storage: [SavedWorkStorageStatus]

    init(items: [SavedWorkRecoveryItem], storage: [SavedWorkStorageStatus]) {
        var seen = Set<SavedWorkIdentity>()
        self.items = items
            .filter { seen.insert($0.identity).inserted }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.stableID < $1.stableID
            }
        self.storage = storage.sorted { $0.storage.rawValue < $1.storage.rawValue }
    }
}
