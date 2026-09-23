import Foundation
import OSLog

// MARK: - feat-010 review entry

extension AppModel {
    /// S09 entry: builds the session-owned ReviewModel from the persisted
    /// result plus frozen source metadata, then routes. Returns true on success.
    /// Reuses the existing model (preserving remove/restore edits) and never
    /// pushes a duplicate overview when one is already on top. Durable
    /// workspace rows own review choices when available; the legacy
    /// `SelectionFeedback` handoff remains only for the unavailable-workspace
    /// fallback. The engine never reruns. Returns false when the result is
    /// missing, mismatched, or empty; the review entry caller surfaces inline
    /// retry feedback while the failed-route Try Again caller already shows
    /// the recoverable state.
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
        let workspaceBinding = await ensureReviewScope(
            for: sessionID, confirmedSource: confirmedSourceIDs
        )
        let model = await makeReviewModel(
            sessionID: sessionID,
            result: result,
            sourceByID: live,
            workspaceBinding: workspaceBinding
        )
        // Legacy feedback persistence is retained only for the file-backed
        // fallback. Available durable-workspace sessions do not reopen a
        // legacy generation or install a SelectionFeedback hook.
        if workspaceBinding == nil {
            await installLegacyFeedbackPersistence(for: sessionID, model: model)
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

    private func makeReviewModel(
        sessionID: SessionID,
        result: SelectionResult,
        sourceByID: [AssetID: PhotoAsset],
        workspaceBinding: (scopeID: UUID, items: [AssetID: WorkspaceItemSnapshot])?
    ) async -> ReviewModel {
        let feedback: SelectionFeedback?
        if workspaceBinding == nil {
            feedback = await container.checkpointStore.loadFeedback(sessionID: sessionID)
        } else {
            feedback = nil
        }
        let model = ReviewModel(
            sessionID: sessionID,
            result: result,
            sourceByID: sourceByID,
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
        return model
    }

    /// Installs the compatibility writer only when durable workspace entry
    /// failed or is unavailable. Durable sessions never reopen a legacy
    /// generation or persist `SelectionFeedback`.
    private func installLegacyFeedbackPersistence(for sessionID: SessionID, model: ReviewModel) async {
        // Ordered writes: the latest snapshots always persist last, so rapid
        // toggles cannot land out of order on disk. The bounded aggregate
        // snapshot follows the full feedback write in one actor call.
        let generation = await container.checkpointStore.reopenSession(sessionID)
        let persist = PersistLatest(
            store: container.checkpointStore, sessionID: sessionID, generation: generation
        )
        model.setFeedbackHook { [weak model, persist] snapshot in
            guard let model else { return }
            let uncertainty = model.uncertaintySnapshot()
            Task { [persist] in
                await persist.save(snapshot, uncertainty: uncertainty)
            }
        }
    }

    /// feat-034 review entry helper: ensures one durable scope per session and
    /// returns the workspace-owned item rows. Existing workspace rows are the
    /// source of truth for review choices. New rows start `.unset`; engine
    /// output and legacy feedback remain review facts/compatibility data, not
    /// durable membership. Nil when workspace storage is unavailable,
    /// preserving the legacy file-backed flow.
    private func ensureReviewScope(
        for sessionID: SessionID,
        confirmedSource: [AssetID]
    ) async -> (scopeID: UUID, items: [AssetID: WorkspaceItemSnapshot])? {
        guard let workspaceStore = container.workspaceStore else { return nil }
        let scopeID = sessionID.rawValue
        do {
            // A migrated or previously-entered scope owns its historical
            // source set. A new scope uses only the frozen source handoff;
            // SelectionResult is intentionally not a membership seed.
            let existingScope = try await workspaceStore.loadScope(id: scopeID)
            let sourceIDs = existingScope?.sourceAssetIDs ?? confirmedSource
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
            for assetID in sourceIDs where byID[assetID] == nil {
                let created = try await workspaceStore.createItem(
                    scopeID: scopeID,
                    assetID: assetID,
                    albumMembership: .unset
                )
                byID[assetID] = created
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
}
