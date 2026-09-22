import Foundation
import OSLog

// MARK: - feat-010 review entry + feat-011 save intents

extension AppModel {
    /// S09 entry: builds the session-owned ReviewModel from the persisted
    /// result plus frozen source metadata, then routes. Returns true on success.
    /// Reuses the existing model (preserving remove/restore edits) and never
    /// pushes a duplicate overview when one is already on top. Reloads the
    /// persisted `SelectionFeedback` so review edits survive relaunch; the
    /// engine never reruns. Returns false when the result is missing,
    /// mismatched, or empty; the review entry caller surfaces inline retry
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
            // A Home intent switch before re-entry refreshes the per-session
            // label; the header reads this map, not the stale global.
            reviewIntentForSession[sessionID] = pendingReviewIntent
            if path.last != .reviewWorkspace(sessionID: sessionID) {
                path.append(.reviewWorkspace(sessionID: sessionID))
            }
            return true
        }
        guard let result = await loadResult(for: sessionID),
              result.sessionID == sessionID,
              !result.selectedAssetIDs.isEmpty
        else { return false }
        let live = Dictionary(uniqueKeysWithValues: confirmedSourceAssets().map { ($0.id, $0) })
        let feedback = await container.checkpointStore.loadFeedback(sessionID: sessionID)
        let workspaceBinding = await ensureReviewScope(
            for: sessionID, confirmedSource: confirmedSourceIDs, result: result, feedback: feedback
        )
        let model = ReviewModel(
            sessionID: sessionID,
            result: result,
            sourceByID: live,
            analysisCache: container.analysisCache,
            feedback: feedback,
            lowQualityThreshold: AppConfiguration.default.selection.lowQualityThreshold,
            scopeID: workspaceBinding?.scopeID,
            workspaceItems: workspaceBinding?.items,
            onWorkspaceChoice: { [weak self] choice in
                Task { await self?.persistWorkspaceChoice(choice) }
            }
        )
        // Persisted unavailable bucket: frozen checkpoint source count minus
        // decided IDs, plus `assetUnavailable` decisions (full-result path).
        // Survives relaunch where the in-memory progress counter is `.zero`.
        let frozenCount = try? await container.checkpointStore.load(sessionID: sessionID)
        model.persistedUnavailableCount = ReviewModel.unavailableCount(
            result: result, frozenSourceCount: frozenCount?.sourceAssetIDs.count
        )
        // Ordered writes: the latest snapshots always persist last, so rapid
        // toggles cannot land out of order on disk. The bounded aggregate
        // snapshot follows the full feedback write in one actor call.
        // Closed-session guard (DEC-043) + generation owner (DEC-046): a live
        // re-entry reopens the store tombstone AND mints a new generation,
        // captured here in the same statement; the installed hook owns its
        // PersistLatest actor strongly (closure owned by the model, model
        // owned by reviewModel), so feedback writes fire while review is
        // live. The model is captured weakly to avoid a retain cycle
        // (model -> hook -> model); cleanup releases reviewModel first,
        // then retire drops late writes AND stale old-session writers pinned
        // to the previous generation — no cycle, no resurrection.
        let generation = await container.checkpointStore.reopenSession(sessionID)
        let persist = PersistLatest(store: container.checkpointStore, sessionID: sessionID, generation: generation)
        model.setFeedbackHook { [weak model, persist] snapshot in
            guard let model else { return }
            let uncertainty = model.uncertaintySnapshot()
            Task { [persist] in
                await persist.save(snapshot, uncertainty: uncertainty)
            }
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
        if path.last != .reviewWorkspace(sessionID: sessionID) {
            path.append(.reviewWorkspace(sessionID: sessionID))
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
        let name = model.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ids.isEmpty, !name.isEmpty else {
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

    /// feat-034 review entry helper: ensures one durable scope per session and
    /// seeds item rows from the legacy selection feedback. Nil when workspace
    /// storage is unavailable, preserving the legacy file-backed flow.
    /// Legacy `SelectionFeedback` carries the durable remove/restore/favorite/
    /// swap record: it seeds both the in-memory model restore and any missing
    /// durable item membership so resume never drops pre-workspace edits.
    private func ensureReviewScope(
        for sessionID: SessionID,
        confirmedSource: [AssetID],
        result: SelectionResult,
        feedback: SelectionFeedback?
    ) async -> (scopeID: UUID, items: [AssetID: WorkspaceItemSnapshot])? {
        guard let workspaceStore = container.workspaceStore else { return nil }
        let scopeID = sessionID.rawValue
        let sourceIDs = confirmedSource.isEmpty
            ? (result.selectedAssetIDs + result.rejectedAssetIDs)
            : confirmedSource
        do {
            _ = try await workspaceStore.createScope(
                id: scopeID,
                intent: pendingReviewIntent,
                sourceAssetIDs: sourceIDs
            )
            // Capture the handoff per session so the header can read the
            // persisted intent instead of a stale global. A new source
            // selection always refreshes the label via `createScope`.
            reviewIntentForSession[sessionID] = pendingReviewIntent
            let items = try await workspaceStore.listItems(scopeID: scopeID)
            var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.assetID, $0) })
            let seededMembership = Dictionary(
                uniqueKeysWithValues: result.selectedAssetIDs.map { ($0, AlbumMembership.included) }
            ).merging(
                Dictionary(uniqueKeysWithValues: result.rejectedAssetIDs.map { ($0, AlbumMembership.excluded) }),
                uniquingKeysWith: { _, next in next }
            )
            let legacyRemoved = feedback?.removedIDs ?? []
            let legacyRestored = feedback?.restoredIDs ?? []
            for assetID in sourceIDs where byID[assetID] == nil {
                var membership = seededMembership[assetID] ?? .unset
                if legacyRemoved.contains(assetID) {
                    membership = .excluded
                } else if legacyRestored.contains(assetID) {
                    membership = .included
                }
                let created = try await workspaceStore.createItem(
                    scopeID: scopeID,
                    assetID: assetID,
                    albumMembership: membership
                )
                byID[assetID] = created
            }
            // Legacy feedback can also post-date existing durable rows (a
            // pre-workspace edit persisted after the scope was created).
            // Apply remove/restore deltas to existing rows so resume never
            // drops them; existing rows already carry the durable truth for
            // everything else. One-way migration rule: only removed/restored
            // map to excluded/included; nothing else is inferred.
            for assetID in legacyRemoved where sourceIDs.contains(assetID) {
                if byID[assetID]?.albumMembership == .included {
                    byID[assetID] = try await workspaceStore.updateAlbumMembership(
                        .excluded, scopeID: scopeID, assetID: assetID
                    )
                }
            }
            for assetID in legacyRestored where sourceIDs.contains(assetID) {
                if byID[assetID]?.albumMembership == .excluded {
                    byID[assetID] = try await workspaceStore.updateAlbumMembership(
                        .included, scopeID: scopeID, assetID: assetID
                    )
                }
            }
            return (scopeID, byID)
        } catch {
            logger.error("Review workspace unavailable; continuing with legacy review state.")
            return nil
        }
    }

    /// Persists one applied dimension-scoped choice. On failure the live
    /// review state stays and the model surfaces explicit retry with the
    /// exact failed dimension values. Success clears a pending save error
    /// only when this write replays that error's exact payload (same scope,
    /// IDs, and dimensions); a superseded session never clears the live
    /// model's error. Retry always re-issues the full failed set so the
    /// exact-match clear can fire.
    private func persistWorkspaceChoice(_ choice: ReviewWorkspaceChoice) async {
        guard let workspaceStore = container.workspaceStore else { return }
        do {
            for assetID in choice.assetIDs {
                if let membership = choice.albumMembership {
                    _ = try await workspaceStore.updateAlbumMembership(
                        membership, scopeID: choice.scopeID, assetID: assetID
                    )
                }
                if let disposition = choice.cleanupDisposition {
                    _ = try await workspaceStore.updateCleanupDisposition(
                        disposition, scopeID: choice.scopeID, assetID: assetID
                    )
                }
                if let progress = choice.reviewProgress {
                    _ = try await workspaceStore.updateReviewProgress(
                        progress, scopeID: choice.scopeID, assetID: assetID
                    )
                }
            }
            guard let model = reviewModel,
                  model.scopeID == choice.scopeID,
                  let pending = model.saveError,
                  pending.scopeID == choice.scopeID,
                  Set(choice.assetIDs).isSuperset(of: pending.assetIDs),
                  pending.albumMembership == choice.albumMembership,
                  pending.cleanupDisposition == choice.cleanupDisposition,
                  pending.reviewProgress == choice.reviewProgress
            else { return }
            model.clearSaveError()
        } catch {
            guard let model = reviewModel, model.scopeID == choice.scopeID else { return }
            model.reportSaveError(ReviewChoiceSaveError(
                scopeID: choice.scopeID,
                assetIDs: choice.assetIDs,
                albumMembership: choice.albumMembership,
                cleanupDisposition: choice.cleanupDisposition,
                reviewProgress: choice.reviewProgress
            ))
        }
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
/// the writes, so rapid toggles cannot persist out of order. Session-scoped
/// (DEC-043) + generation-pinned (DEC-046): the store drops writes for
/// tombstoned sessions AND for writers pinned to a retired generation, so a
/// late Task queued before discard/reset/finish deletes cannot recreate the
/// rows — even when a same-process reopen minted a newer generation first.
private actor PersistLatest {
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
