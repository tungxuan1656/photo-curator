import Foundation

// MARK: - feat-010 review entry + feat-011 save intents

extension AppModel {
    /// S09 entry: builds the session-owned ReviewModel from the persisted
    /// result plus frozen source metadata, then routes. Returns true on success.
    /// Reuses the existing model (preserving remove/restore edits) and never
    /// pushes a duplicate overview when one is already on top. Reloads the
    /// persisted `SelectionFeedback` so review edits survive relaunch; the
    /// engine never reruns. Returns false when the result is missing,
    /// mismatched, or empty; the ReviewReady caller surfaces inline retry
    /// feedback while the failed-route Try Again caller already shows the
    /// recoverable state.
    func beginReview(for sessionID: SessionID) async -> Bool {
        if let existing = reviewModel, existing.sessionID == sessionID {
            // Interrupted-save reconciliation applies to the reuse path too:
            // a persisted state with remaining IDs routes to S15 against the
            // same album instead of the overview.
            if await hasInterruptedSave(for: sessionID) {
                if path.last != .saving(sessionID: sessionID) {
                    path.append(.saving(sessionID: sessionID))
                }
                return true
            }
            if path.last != .reviewOverview(sessionID: sessionID) {
                path.append(.reviewOverview(sessionID: sessionID))
            }
            return true
        }
        guard let result = await loadResult(for: sessionID),
              result.sessionID == sessionID,
              !result.selectedAssetIDs.isEmpty
        else { return false }
        let live = Dictionary(uniqueKeysWithValues: confirmedSourceAssets().map { ($0.id, $0) })
        let feedback = await container.checkpointStore.loadFeedback(sessionID: sessionID)
        let model = ReviewModel(sessionID: sessionID, result: result, sourceByID: live, feedback: feedback)
        // Ordered writes: the latest snapshot always persists last, so rapid
        // toggles cannot land out of order on disk.
        let persist = PersistLatest(store: container.checkpointStore, sessionID: sessionID)
        model.setFeedbackHook { snapshot in
            Task { await persist.save(snapshot) }
        }
        reviewModel = model
        // Interrupted-save reconciliation: never a duplicate album. A
        // persisted state with remaining IDs routes to S15 retry-remaining
        // against the same album instead of the normal overview.
        if await hasInterruptedSave(for: sessionID) {
            if path.last != .saving(sessionID: sessionID) {
                path.append(.saving(sessionID: sessionID))
            }
            return true
        }
        if path.last != .reviewOverview(sessionID: sessionID) {
            path.append(.reviewOverview(sessionID: sessionID))
        }
        return true
    }

    /// S14 Save entry: atomically claims one save per session before touching
    /// PhotoKit. First tap owns the flight; repeat taps join it. Returns the
    /// terminal outcome.
    func saveAlbum(for sessionID: SessionID) async -> SaveOutcome {
        if let flight = saveFlight, flight.session == sessionID {
            return await flight.task.value
        }
        guard let model = reviewModel, model.sessionID == sessionID else {
            return .failed(.creationFailed)
        }
        let ids = model.selectedAssetIDs
        let name = model.albumName
        guard !ids.isEmpty else {
            return .failed(.assetsUnavailable)
        }
        let flight = Task { [container] in
            await Self.runSave(
                sessionID: sessionID,
                name: name,
                requestedIDs: ids,
                exporter: container.exporter,
                store: container.checkpointStore
            )
        }
        saveFlight = (session: sessionID, task: flight)
        let outcome = await flight.value
        if saveFlight?.session == sessionID {
            saveFlight = nil
        }
        return outcome
    }

    /// Retry-remaining entry: adds only IDs neither added nor missing to the
    /// persisted album, then re-runs the same terminal mapping as `saveAlbum`.
    func retryRemainingSave(for sessionID: SessionID) async -> SaveOutcome {
        guard let state = await container.checkpointStore.loadSaveState(sessionID: sessionID) else {
            return await saveAlbum(for: sessionID)
        }
        let remaining = state.remainingIDs
        guard !remaining.isEmpty else {
            return Self.outcome(for: state)
        }
        do {
            let result = try await container.exporter.addToAlbum(
                albumLocalIdentifier: state.albumLocalIdentifier, assetIDs: remaining
            )
            var updated = state
            updated.addedIDs += result.addedIDs.filter { !Set(updated.addedIDs).contains($0) }
            updated.missingIDs += result.missingIDs.filter { !Set(updated.missingIDs).contains($0) }
            try? await container.checkpointStore.saveSaveState(updated)
            return Self.outcome(for: updated)
        } catch let error as ExportError {
            return Self.mapped(error)
        } catch {
            return .failed(.creationFailed)
        }
    }

    /// S14 guard: Save disables while this session's save is in flight.
    func isSaving(sessionID: SessionID) -> Bool {
        saveFlight?.session == sessionID
    }

    /// Supersede/discard hook: waits out the in-flight save claim for exactly
    /// this session before the caller deletes data, so the flight's final
    /// `SaveState` write cannot resurrect a deleted file. The PhotoKit add
    /// itself stays cooperative — an in-flight add may still land while a new
    /// album starts fresh on the changed selection.
    /// The persisted save state stays for reconciliation, never deleted here.
    func cancelSave(for sessionID: SessionID?) async {
        guard let sessionID, saveFlight?.session == sessionID else { return }
        let flight = saveFlight?.task
        flight?.cancel()
        saveFlight = nil
        await flight?.value
    }

    /// S16 Done: clears the save claim, drops the session review state, and
    /// returns Home with no unfinished session card.
    func finishSave(for sessionID: SessionID) {
        if saveFlight?.session == sessionID {
            saveFlight = nil
        }
        if reviewModel?.sessionID == sessionID {
            reviewModel = nil
        }
        activeSessionID = nil
        path.removeAll()
    }

    /// S16 data: latest persisted save state for the session, if any.
    func savedAlbum(for sessionID: SessionID) async -> SaveState? {
        await container.checkpointStore.loadSaveState(sessionID: sessionID)
    }

    /// Interrupted-save reconciliation: a persisted save state with remaining
    /// IDs routes to S15 (retry-remaining against the same album), never a
    /// duplicate album. Returns true when such a state exists.
    func hasInterruptedSave(for sessionID: SessionID) async -> Bool {
        guard let state = await container.checkpointStore.loadSaveState(sessionID: sessionID) else {
            return false
        }
        return state.sessionID == sessionID && !state.remainingIDs.isEmpty
    }

    private static func runSave(
        sessionID: SessionID,
        name: String,
        requestedIDs: [AssetID],
        exporter: any AlbumExportService,
        store: SessionCheckpointStore
    ) async -> SaveOutcome {
        // Resume rule: an existing state for the same requested set keeps its
        // album identity and skips already-added IDs; a changed selection
        // starts a fresh save (new album, matching the new S14 set).
        let existing = await store.loadSaveState(sessionID: sessionID)
        let resumable = if let existing {
            Self.shouldResume(existing: existing, requestedIDs: requestedIDs)
        } else {
            false
        }
        if let existing, resumable {
            return await Self.resumeSave(existing: existing, exporter: exporter, store: store)
        }
        do {
            let created = try await exporter.createAlbum(name: name)
            var state = SaveState(
                sessionID: sessionID,
                albumLocalIdentifier: created.localIdentifier,
                albumTitle: created.title,
                requestedIDs: requestedIDs,
                addedIDs: [],
                missingIDs: []
            )
            try? await store.saveSaveState(state)
            let result = try await exporter.addToAlbum(
                albumLocalIdentifier: created.localIdentifier, assetIDs: requestedIDs
            )
            state.addedIDs = result.addedIDs
            state.missingIDs = result.missingIDs
            try? await store.saveSaveState(state)
            return Self.outcome(for: state)
        } catch let error as ExportError {
            return Self.mapped(error)
        } catch {
            return .failed(.creationFailed)
        }
    }

    private static func resumeSave(
        existing: SaveState, exporter: any AlbumExportService, store: SessionCheckpointStore
    ) async -> SaveOutcome {
        var state = existing
        let remaining = state.remainingIDs
        guard !remaining.isEmpty else {
            return outcome(for: state)
        }
        do {
            let result = try await exporter.addToAlbum(
                albumLocalIdentifier: state.albumLocalIdentifier, assetIDs: remaining
            )
            state.addedIDs += result.addedIDs.filter { !Set(state.addedIDs).contains($0) }
            state.missingIDs += result.missingIDs.filter { !Set(state.missingIDs).contains($0) }
            try? await store.saveSaveState(state)
            return outcome(for: state)
        } catch let error as ExportError {
            return mapped(error)
        } catch {
            return .failed(.creationFailed)
        }
    }

    private static func shouldResume(existing: SaveState, requestedIDs: [AssetID]) -> Bool {
        // Same requested set keeps the persisted album even when nothing is
        // recorded as added/missing yet (interrupted between createAlbum and
        // the first add); resumeSave then adds the full remaining set.
        Set(existing.requestedIDs) == Set(requestedIDs)
    }

    private static func outcome(for state: SaveState) -> SaveOutcome {
        if state.addedIDs.isEmpty {
            return .failed(.assetsUnavailable)
        }
        if state.remainingIDs.isEmpty, state.missingIDs.isEmpty {
            return .saved(state: state)
        }
        return .partial(state: state)
    }

    private static func mapped(_ error: ExportError) -> SaveOutcome {
        switch error {
        case .permissionLost:
            .permissionLost
        case .creationFailed:
            .failed(.creationFailed)
        case .assetsUnavailable:
            .failed(.assetsUnavailable)
        }
    }
}

/// Orders feedback writes so the newest snapshot always lands last. Each
/// mutation captures a monotonically newer snapshot; the actor serializes
/// the writes, so rapid toggles cannot persist out of order.
private actor PersistLatest {
    private let store: SessionCheckpointStore
    private let sessionID: SessionID

    init(store: SessionCheckpointStore, sessionID: SessionID) {
        self.store = store
        self.sessionID = sessionID
    }

    func save(_ snapshot: SelectionFeedback) async {
        try? await store.saveFeedback(snapshot, for: sessionID)
    }
}
