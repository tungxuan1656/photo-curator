import Foundation

// MARK: - feat-034 review action transitions

extension ReviewModel {
    /// Preserves the workspace's tri-state album membership for review entry.
    static func workspaceAlbumMembership(
        workspaceItems: [AssetID: WorkspaceItemSnapshot], live: Set<AssetID>
    ) -> [AssetID: AlbumMembership] {
        Dictionary(uniqueKeysWithValues: workspaceItems.values
            .filter { live.contains($0.assetID) }
            .map { ($0.assetID, $0.albumMembership) })
    }

    /// Returns workspace membership without collapsing `.unset` into a
    /// selection boolean. Legacy sessions retain their binary behavior.
    func albumMembership(for id: AssetID) -> AlbumMembership {
        if let membership = albumMembershipByID[id] {
            return membership
        }
        if scopeID != nil {
            return .unset
        }
        return selectedIDs.contains(id) ? .included : .excluded
    }

    /// review-rules: explicit album-membership write; leaves cleanup, progress, facts unchanged.
    func addToAlbum(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) && !selectedIDs.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, albumMembership(for: $0)) })
        setSelected(selectedIDs.union(targets))
        for id in targets {
            trackInsertion(id)
        }
        persist()
        notifyAlbumChanges(
            Dictionary(uniqueKeysWithValues: targets.map { ($0, AlbumMembership.included) }),
            previous: previous
        )
    }

    /// review-rules: explicit album-membership write; leaves cleanup, progress, facts unchanged.
    func removeFromAlbum(_ ids: [AssetID]) {
        let targets = ids.filter { selectedIDs.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, albumMembership(for: $0)) })
        setSelected(selectedIDs.subtracting(targets))
        for id in targets {
            trackRemoval(id)
        }
        if let lastRemovedID, targets.contains(lastRemovedID) {
            setLastRemovedID(nil)
        }
        persist()
        notifyAlbumChanges(
            Dictionary(uniqueKeysWithValues: targets.map { ($0, AlbumMembership.excluded) }),
            previous: previous
        )
    }

    /// review-rules: explicit progress write; leaves album, cleanup, facts unchanged.
    func markReviewed(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, progress(for: $0)) })
        setProgress(.reviewed, for: targets)
        persist()
        notifyWorkspaceChoice(
            assetIDs: targets, reviewProgress: .reviewed, previousReviewProgresses: previous
        )
    }

    /// review-rules: grid visibility never marks progress; only explicit open does.
    /// `unseen` → `inProgress` only; existing `inProgress`/`reviewed` stay.
    func markOpened(_ ids: [AssetID]) {
        let targets = ids.filter { progress(for: $0) == .unseen }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, progress(for: $0)) })
        setProgress(.inProgress, for: targets)
        persist()
        notifyWorkspaceChoice(
            assetIDs: targets, reviewProgress: .inProgress, previousReviewProgresses: previous
        )
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func stageForDeletion(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, cleanupDisposition(for: $0)) })
        setCleanup(.stagedForDeletion, for: targets)
        persist()
        notifyWorkspaceChoice(
            assetIDs: targets, cleanupDisposition: .stagedForDeletion,
            previousCleanupDispositions: previous
        )
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func unstageDeletion(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, cleanupDisposition(for: $0)) })
        setCleanup(.undecided, for: targets)
        persist()
        notifyWorkspaceChoice(
            assetIDs: targets, cleanupDisposition: .undecided,
            previousCleanupDispositions: previous
        )
    }

    /// review-rules: explicit cleanup write; leaves album, progress, facts unchanged.
    func keepPhoto(_ ids: [AssetID]) {
        let display = Set(displayIDs)
        let targets = ids.filter { display.contains($0) }
        guard !targets.isEmpty else { return }
        let previous = Dictionary(uniqueKeysWithValues: targets.map { ($0, cleanupDisposition(for: $0)) })
        setCleanup(.keep, for: targets)
        persist()
        notifyWorkspaceChoice(
            assetIDs: targets, cleanupDisposition: .keep,
            previousCleanupDispositions: previous
        )
    }

    /// review-rules: explicit retry re-issues the exact failed dimension
    /// values for the full failed set; Done dismisses without claiming
    /// saved state. Never a silent no-op: retry returns false when the
    /// scope/session no longer owns the failed choice.
    var canRetrySaveError: Bool {
        guard let saveError, saveError.scopeID == scopeID else { return false }
        return !saveError.assetIDs.isEmpty
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
            let changedIncluded = included.filter { albumMembership(for: $0) != .included }
            let changedExcluded = excluded.filter { albumMembership(for: $0) != .excluded }
            guard !changedIncluded.isEmpty || !changedExcluded.isEmpty else { return false }
            if !changedIncluded.isEmpty {
                guard !isSuggestionStale(suggestion) else { return false }
                addToAlbum(changedIncluded)
            }
            if !changedExcluded.isEmpty {
                guard !isSuggestionStale(suggestion) else { return false }
                let selected = changedExcluded.filter { selectedIDs.contains($0) }
                let alreadyUnselected = changedExcluded.filter { !selectedIDs.contains($0) }
                if !selected.isEmpty {
                    removeFromAlbum(selected)
                }
                if !alreadyUnselected.isEmpty {
                    persist()
                    notifyAlbumChanges(
                        Dictionary(uniqueKeysWithValues: alreadyUnselected.map { ($0, .excluded) })
                    )
                }
            }
            return true
        case let .cleanupKeep(ids):
            let display = Set(displayIDs)
            let targets = ids.filter { display.contains($0) }
            let changed = targets.filter { cleanupDisposition(for: $0) != .keep }
            guard !changed.isEmpty else { return false }
            guard !isSuggestionStale(suggestion) else { return false }
            keepPhoto(Array(changed))
            return true
        case .none:
            return false
        }
    }
}
