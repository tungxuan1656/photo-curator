// MARK: - feat-035 legacy save handoff (unavailable-workspace path only)

import Foundation

/// Legacy file-backed save flow (pre-feat-035 handoff).
///
/// Kept only for the unavailable-workspace path where no durable
/// `AlbumSaveOperation` exists. Same resume/outcome contract as the durable
/// flow: same requested set resumes the persisted album, retry adds only
/// remaining IDs, and the terminal mapping stays truthful.
enum LegacySaveFlow {
    static func resume(
        existing: SaveState,
        exporter: any AlbumExportService,
        store: SessionCheckpointStore,
        outcome: (SaveState) -> SaveOutcome,
        mapped: (ExportError) -> SaveOutcome
    ) async -> SaveOutcome {
        var state = existing
        let remaining = state.remainingIDs
        guard !remaining.isEmpty else {
            return outcome(state)
        }
        do {
            let result = try await exporter.addToAlbum(
                albumLocalIdentifier: state.albumLocalIdentifier, assetIDs: remaining
            )
            let knownAdded = Set(state.addedIDs)
            let knownMissing = Set(state.missingIDs)
            state.addedIDs += result.addedIDs.filter { !knownAdded.contains($0) }
            state.missingIDs += result.missingIDs.filter { !knownMissing.contains($0) }
            try? await store.saveSaveState(state)
            return outcome(state)
        } catch let error as ExportError {
            return mapped(error)
        } catch {
            return mapped(.creationFailed)
        }
    }

    static func outcome(for state: SaveState) -> SaveOutcome {
        if state.addedIDs.isEmpty {
            return .failed(.assetsUnavailable)
        }
        if state.remainingIDs.isEmpty, state.missingIDs.isEmpty {
            return .saved(state: state)
        }
        return .partial(state: state)
    }
}

/// Orders feedback writes so the newest snapshot always lands last. Each
/// mutation captures a monotonically newer snapshot; the actor serializes
/// the writes, so rapid toggles cannot persist out of order. Session-scoped
/// (DEC-043) + generation-pinned (DEC-046): the store drops writes for
/// tombstoned sessions AND for writers pinned to a retired generation, so a
/// late Task queued before discard/reset/finish deletes cannot recreate the
/// rows — even when a same-process reopen minted a newer generation first.
actor PersistLatest {
    private let store: SessionCheckpointStore
    private let sessionID: SessionID
    private let generation: UInt64?

    init(store: SessionCheckpointStore, sessionID: SessionID, generation: UInt64?) {
        self.store = store
        self.sessionID = sessionID
        self.generation = generation
    }

    /// Ordered feedback pair: the full edit snapshot first, then the bounded
    /// aggregate snapshot derived from it (never throws — disk failure keeps
    /// in-memory review alive and the next mutation retries; a closed-session
    /// drop is also silent, by tombstone design).
    func save(_ snapshot: SelectionFeedback) async {
        try? await store.saveFeedback(snapshot, for: sessionID, generation: generation)
    }

    func save(_ feedback: SelectionFeedback, uncertainty: UncertaintyFeedbackSnapshot) async {
        try? await store.saveFeedback(feedback, for: sessionID, generation: generation)
        try? await store.saveUncertaintyFeedback(uncertainty, for: sessionID, generation: generation)
    }
}
