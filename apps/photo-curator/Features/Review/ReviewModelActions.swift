import Foundation

// MARK: - feat-034 review action transitions

extension ReviewModel {
    /// review-rules: explicit album-membership write; leaves cleanup, progress, facts unchanged.
    func addToAlbum(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) && !selectedIDs.contains($0) }
        guard !targets.isEmpty else { return }
        setSelected(selectedIDs.union(targets))
        for id in targets {
            trackInsertion(id)
        }
        persist()
        notifyAlbumChanges(Dictionary(uniqueKeysWithValues: targets.map { ($0, AlbumMembership.included) }))
    }

    /// review-rules: explicit album-membership write; leaves cleanup, progress, facts unchanged.
    func removeFromAlbum(_ ids: [AssetID]) {
        let targets = ids.filter { selectedIDs.contains($0) }
        guard !targets.isEmpty else { return }
        setSelected(selectedIDs.subtracting(targets))
        for id in targets {
            trackRemoval(id)
        }
        if let lastRemovedID, targets.contains(lastRemovedID) {
            setLastRemovedID(nil)
        }
        persist()
        notifyAlbumChanges(Dictionary(uniqueKeysWithValues: targets.map { ($0, AlbumMembership.excluded) }))
    }

    /// review-rules: explicit progress write; leaves album, cleanup, facts unchanged.
    func markReviewed(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        setProgress(.reviewed, for: targets)
        persist()
        notifyWorkspaceChoice(assetIDs: targets, reviewProgress: .reviewed)
    }

    /// review-rules: grid visibility never marks progress; only explicit open does.
    /// `unseen` → `inProgress` only; existing `inProgress`/`reviewed` stay.
    func markOpened(_ ids: [AssetID]) {
        let targets = ids.filter { progress(for: $0) == .unseen }
        guard !targets.isEmpty else { return }
        setProgress(.inProgress, for: targets)
        persist()
        notifyWorkspaceChoice(assetIDs: targets, reviewProgress: .inProgress)
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func stageForDeletion(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        setCleanup(.stagedForDeletion, for: targets)
        persist()
        notifyWorkspaceChoice(assetIDs: targets, cleanupDisposition: .stagedForDeletion)
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func unstageDeletion(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        setCleanup(.undecided, for: targets)
        persist()
        notifyWorkspaceChoice(assetIDs: targets, cleanupDisposition: .undecided)
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func keepPhoto(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        setCleanup(.keep, for: targets)
        persist()
        notifyWorkspaceChoice(assetIDs: targets, cleanupDisposition: .keep)
    }

    /// review-rules: explicit retry re-issues the exact failed dimension
    /// values for the full failed set; Done dismisses without claiming
    /// saved state. Never a silent no-op: retry returns false when the
    /// scope/session no longer owns the failed choice.
    var canRetrySaveError: Bool {
        guard let saveError, saveError.scopeID == scopeID else { return false }
        return !saveError.assetIDs.isEmpty
    }

    @discardableResult
    func retrySaveError() -> Bool {
        guard let saveError, saveError.scopeID == scopeID, !saveError.assetIDs.isEmpty else { return false }
        notifyWorkspaceChoice(
            assetIDs: saveError.assetIDs,
            albumMembership: saveError.albumMembership,
            cleanupDisposition: saveError.cleanupDisposition,
            reviewProgress: saveError.reviewProgress
        )
        return true
    }

    /// Applies one confirmed advisory proposal to its named dimension only.
    /// Suggestion acceptance can never stage deletion.
    func applySuggestion(_ suggestion: ReviewSuggestion) -> Bool {
        guard suggestion.canUse, suggestion.scopeID == scopeID else { return false }
        switch suggestion.proposal {
        case let .albumMembership(values):
            let display = Set(displayIDs)
            let targets = values.filter { display.contains($0.key) }
            guard !targets.isEmpty else { return false }
            let included = targets.filter { $0.value == .included }.map(\.key)
            let excluded = targets.filter { $0.value == .excluded }.map(\.key)
            let changedIncluded = included.filter { !selectedIDs.contains($0) }
            let changedExcluded = excluded.filter { selectedIDs.contains($0) }
            guard !changedIncluded.isEmpty || !changedExcluded.isEmpty else { return false }
            if !changedIncluded.isEmpty {
                addToAlbum(changedIncluded)
            }
            if !changedExcluded.isEmpty {
                removeFromAlbum(changedExcluded)
            }
            return true
        case let .cleanupKeep(ids):
            let display = Set(displayIDs)
            let targets = ids.filter { display.contains($0) }
            let changed = targets.filter { cleanupDisposition(for: $0) != .keep }
            guard !changed.isEmpty else { return false }
            keepPhoto(Array(changed))
            return true
        case .none:
            return false
        }
    }
}
