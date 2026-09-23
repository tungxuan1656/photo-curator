import Foundation
import OSLog

// MARK: - feat-011 save intents

extension AppModel {
    /// S14 Save entry: atomically claims one save per session before touching
    /// PhotoKit. First tap owns the flight; repeat taps join it. Returns the
    /// terminal outcome. The feat-035 `AlbumSaveService` owns the durable
    /// operation: the draft is the exact workspace membership read from the
    /// live model (`selectedAssetIDs`); inaccessible IDs surface as
    /// `missingIDs` (`.partial`), never silently dropped. Save never clears
    /// workspace, album draft, review progress, or cleanup state.
    func saveAlbum(for sessionID: SessionID) async -> SaveOutcome {
        if let flight = saveFlight, flight.session == sessionID {
            return await flight.task.value
        }
        guard let model = reviewModel, model.sessionID == sessionID else {
            return .failed(.creationFailed)
        }
        let ids = model.selectedAssetIDs
        let name = model.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ids.isEmpty, !name.isEmpty else {
            return .failed(.assetsUnavailable)
        }
        let scopeID = model.scopeID ?? sessionID.rawValue
        if let albumSave = container.albumSaveService {
            let flight = Task { [albumSave] in
                await albumSave.save(
                    sessionID: sessionID,
                    scopeID: scopeID,
                    intent: .fresh(draftIDs: ids, albumName: name)
                ).outcome
            }
            saveFlight = (session: sessionID, task: flight)
            let outcome = await flight.value
            if saveFlight?.session == sessionID {
                saveFlight = nil
            }
            // Legacy file handoff stays for reconciliation: mirror the latest
            // durable display state so an unreadable SwiftData row still
            // routes to recoverable review instead of a second album.
            await mirrorLegacySaveState(sessionID: sessionID)
            return outcome
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

    /// Retry-remaining entry: explicit retry only. With durable operations,
    /// adds only IDs neither added nor missing to the persisted operation
    /// album; without them, falls back to the file `SaveState` handoff.
    func retryRemainingSave(for sessionID: SessionID) async -> SaveOutcome {
        if let albumSave = container.albumSaveService {
            let scopeID = reviewModel?.scopeID ?? sessionID.rawValue
            let result = await albumSave.save(
                sessionID: sessionID, scopeID: scopeID, intent: .retryRemaining
            )
            await mirrorLegacySaveState(sessionID: sessionID)
            return result.outcome
        }
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

    /// Mirrors the durable operation display state into the file handoff so
    /// interruption between the SwiftData write and the next read still
    /// reconciles to the same album. Best-effort: a failed mirror never
    /// changes the returned outcome.
    private func mirrorLegacySaveState(sessionID: SessionID) async {
        guard let albumSave = container.albumSaveService else { return }
        let legacy = await container.checkpointStore.loadSaveState(sessionID: sessionID)
        let draft = reviewModel?.selectedAssetIDs ?? []
        let name = reviewModel?.albumName ?? "Curated Photos"
        let state = await albumSave.displayState(
            sessionID: sessionID,
            legacy: legacy,
            intent: .fresh(draftIDs: draft, albumName: name)
        )
        // No operation, no legacy, no live model: nothing worth persisting.
        // Writing the empty fallback would create a file that didn't exist.
        guard !state.requestedIDs.isEmpty || legacy != nil else { return }
        try? await container.checkpointStore.saveSaveState(state)
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
        _ = await flight?.value
    }

    /// S16 Done: clears the save claim, drops the session review state, and
    /// returns Home with no unfinished session card. Deletes the persisted
    /// session data (mirroring `discardCuration` ordering: clear claim, await
    /// in-flight save termination via `cancelSave`, then `deleteSessionData`)
    /// so `refreshResumeSnapshot` never resurrects the completed session.
    /// The loaded `Completion` view already holds its display `SaveState` in
    /// memory (`Completion.swift:11-27`), so deleting underneath it is safe.
    func finishSave(for sessionID: SessionID) {
        // The save claim clears inside cancelSave below (mirroring
        // discardCuration), so the flight's termination is awaited before
        // any file is deleted.
        if reviewModel?.sessionID == sessionID {
            reviewModel = nil
        }
        activeSessionID = nil
        resumeSnapshot = nil
        path.removeAll()
        Task {
            await cancelSave(for: sessionID)
            let cleaned = await deleteSessionData(sessionID, context: "Completed curation")
            if cleaned, lastSessionID == sessionID {
                lastSessionID = nil
            }
        }
    }

    /// S16 data: latest durable operation display state for the session, if
    /// any. Prefers the feat-035 operation; falls back to the file handoff
    /// when workspace storage is unavailable. Never clears workspace state.
    func savedAlbum(for sessionID: SessionID) async -> SaveState? {
        if let albumSave = container.albumSaveService {
            let legacy = await container.checkpointStore.loadSaveState(sessionID: sessionID)
            let draft = reviewModel?.selectedAssetIDs ?? legacy?.requestedIDs ?? []
            let name = reviewModel?.albumName ?? legacy?.albumTitle ?? "Curated Photos"
            let state = await albumSave.displayState(
                sessionID: sessionID,
                legacy: legacy,
                intent: .fresh(draftIDs: draft, albumName: name)
            )
            guard state.sessionID == sessionID, !state.requestedIDs.isEmpty else { return legacy }
            return state
        }
        return await container.checkpointStore.loadSaveState(sessionID: sessionID)
    }

    /// Interrupted-save reconciliation: a durable operation (or legacy file
    /// state) with remaining IDs routes to S15 (retry-remaining against the
    /// same album), never a duplicate album. Returns true when such a state
    /// exists.
    func hasInterruptedSave(for sessionID: SessionID) async -> Bool {
        if let albumSave = container.albumSaveService {
            if await albumSave.pendingOperation(sessionID: sessionID) != nil {
                return true
            }
        }
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
        if let existing, Set(existing.requestedIDs) == Set(requestedIDs) {
            return await LegacySaveFlow.resume(
                existing: existing,
                exporter: exporter,
                store: store,
                outcome: Self.outcome,
                mapped: Self.mapped
            )
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

    private static func outcome(for state: SaveState) -> SaveOutcome {
        LegacySaveFlow.outcome(for: state)
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
