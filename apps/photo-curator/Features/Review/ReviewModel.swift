import Foundation
import Observation

/// One near-duplicate set for S12. `engineWinner` is the automatic pick
/// (`Recommended best pick`); selection state stays in `ReviewModel`.
struct SimilarGroup: Hashable, Sendable {
    let id: ClusterID
    let memberIDs: [AssetID]
    let engineWinner: AssetID

    func selectedCount(in selected: Set<AssetID>) -> Int {
        memberIDs.filter(selected.contains).count
    }
}

/// Session-local review state over the persisted chronological result.
///
/// Single source of truth shared by S09–S14. `displayIDs` covers every live
/// result ID in engine chronology (selected union rejected); S10 keeps its
/// dim-don't-shift layout via `curatedDisplayIDs` (engine-selected plus
/// currently selected). Edits mutate only this model plus a `SelectionFeedback`
/// snapshot persisted by the owner; the engine never reruns.
@MainActor @Observable
final class ReviewModel {
    let sessionID: SessionID
    let result: SelectionResult
    let sourceByID: [AssetID: PhotoAsset]
    /// Durable workspace scope bound at review entry (feat-034). Nil on the
    /// legacy file-backed path when workspace storage is unavailable.
    let scopeID: UUID?
    var selectedIDs: Set<AssetID>
    let displayIDs: [AssetID]
    var lastRemovedID: AssetID?
    var albumName = "Curated Photos"
    /// Persisted unavailable bucket (survives relaunch where the in-memory
    /// progress counter resets). Assigned by the owner at review entry from
    /// `unavailableCount(result:frozenSourceCount:)`; defaults to hidden.
    var persistedUnavailableCount = 0
    /// Last durable write failure for a choice action. Views render retry
    /// from this without claiming saved state.
    private(set) var saveError: ReviewChoiceSaveError?
    /// Needs Review queue (feat-026): one `UncertaintyReviewState` owns queue
    /// derivation, resolution, and snapshot (derived once at review entry;
    /// resolution recomputes from live edits per read).
    @ObservationIgnored private let reviewState: UncertaintyReviewState
    var needsReviewItems: [NeedsReviewItem] {
        reviewState.items
    }

    private let engineSelected: Set<AssetID>
    @ObservationIgnored private let analysisCache: any AnalysisCache
    @ObservationIgnored private let decisionByID: [AssetID: Decision]
    @ObservationIgnored private var analysisByID: [AssetID: PhotoAnalysis] = [:]
    @ObservationIgnored private var unavailableAnalysisIDs: Set<AssetID> = []
    @ObservationIgnored private var analysisFlights: [AssetID: Task<PhotoAnalysis?, Never>] = [:]
    var removedEditIDs: Set<AssetID>
    var restoredEditIDs: Set<AssetID>
    var favoriteEditIDs: Set<AssetID>
    var swapWinnerByGroup: [ClusterID: AssetID]
    @ObservationIgnored private var onFeedbackChanged: ((SelectionFeedback) -> Void)?
    /// Durable write hook installed by the owner alongside `onFeedbackChanged`.
    /// Receives one applied choice (dimension-scoped) per user action so the
    /// owner can persist through `WorkspaceStore` without the model touching
    /// PhotoKit or SwiftData directly.
    @ObservationIgnored private var onWorkspaceChoice: ((ReviewWorkspaceChoice) -> Void)?

    init(
        sessionID: SessionID,
        result: SelectionResult,
        sourceByID: [AssetID: PhotoAsset],
        analysisCache: any AnalysisCache,
        feedback: SelectionFeedback? = nil,
        onFeedbackChanged: ((SelectionFeedback) -> Void)? = nil,
        lowQualityThreshold: Double? = nil,
        scopeID: UUID? = nil,
        workspaceItems: [AssetID: WorkspaceItemSnapshot]? = nil,
        onWorkspaceChoice: ((ReviewWorkspaceChoice) -> Void)? = nil
    ) {
        self.sessionID = sessionID
        self.result = result
        self.sourceByID = sourceByID
        self.scopeID = scopeID
        self.onWorkspaceChoice = onWorkspaceChoice
        self.analysisCache = analysisCache
        decisionByID = Dictionary(uniqueKeysWithValues: result.decisions.map { ($0.assetID, $0) })
        self.onFeedbackChanged = onFeedbackChanged
        let threshold = lowQualityThreshold ?? AppConfiguration.default.selection.lowQualityThreshold
        let live = Set(sourceByID.keys)
        let allResultIDs = Set(result.selectedAssetIDs + result.rejectedAssetIDs)
        let chrono = Self.chronoOrder(ids: allResultIDs, sourceByID: sourceByID)
        displayIDs = chrono.filter(live.contains)
        let liveSet = Set(displayIDs)
        let engineSelectedIDs = Set(result.selectedAssetIDs).intersection(liveSet)
        if let workspaceItems {
            engineSelected = Self.workspaceAlbumSelected(workspaceItems: workspaceItems, live: liveSet)
            removedEditIDs = []
            restoredEditIDs = []
            favoriteEditIDs = []
            swapWinnerByGroup = [:]
            selectedIDs = engineSelected.intersection(liveSet)
        } else if let feedback {
            engineSelected = engineSelectedIDs
            removedEditIDs = feedback.removedIDs.intersection(liveSet)
            restoredEditIDs = feedback.restoredIDs.intersection(liveSet)
            favoriteEditIDs = feedback.favoriteIDs.intersection(liveSet)
            swapWinnerByGroup = feedback.swapWinner.filter { liveSet.contains($0.value) }
            selectedIDs = engineSelectedIDs
                .subtracting(feedback.removedIDs.intersection(liveSet))
                .union(feedback.restoredIDs.intersection(liveSet))
                .intersection(liveSet)
        } else {
            engineSelected = engineSelectedIDs
            removedEditIDs = []
            restoredEditIDs = []
            favoriteEditIDs = []
            swapWinnerByGroup = [:]
            selectedIDs = engineSelectedIDs.intersection(liveSet)
        }
        reviewState = UncertaintyReviewState(
            decisions: result.decisions.filter { liveSet.contains($0.assetID) },
            lowQualityThreshold: threshold
        )
        cachedSimilarGroups = Self.buildSimilarGroups(
            result: result, displayIDs: displayIDs, sourceByID: sourceByID
        )
    }

    /// Persisted unavailable derivation from already-persisted shapes (no new
    /// fields). `assetUnavailable` decisions cover analysis-missing assets in
    /// full results (FinalAlbumBuilder emits one decision per source asset);
    /// assets absent from a partial result (Continue Without Them builds from
    /// available only) are counted via the frozen checkpoint source count.
    /// Never filters by live resolution: the bucket is a historical run fact.
    static func unavailableCount(result: SelectionResult, frozenSourceCount: Int?) -> Int {
        let decided = result.selectedAssetIDs.count + result.rejectedAssetIDs.count
        let missing = max(0, (frozenSourceCount ?? decided) - decided)
        let flagged = result.decisions.filter { $0.reasons.contains("assetUnavailable") }.count
        return flagged + missing
    }

    func setFeedbackHook(_ hook: ((SelectionFeedback) -> Void)?) {
        onFeedbackChanged = hook
    }

    func reportSaveError(_ error: ReviewChoiceSaveError) {
        saveError = error
    }

    func clearSaveError() {
        saveError = nil
    }

    /// Reads compact saved analysis only when a visible review surface needs it.
    /// Concurrent cells for the same asset await one flight. Missing cache rows
    /// are remembered so scrolling does not repeatedly probe disk.
    func loadAnalysis(for id: AssetID) async -> PhotoAnalysis? {
        if let analysis = analysisByID[id] {
            return analysis
        }
        if unavailableAnalysisIDs.contains(id) {
            return nil
        }
        if let flight = analysisFlights[id] {
            return await flight.value
        }
        let cache = analysisCache
        let flight = Task { await cache.analysis(for: id) }
        analysisFlights[id] = flight
        let analysis = await flight.value
        analysisFlights[id] = nil
        if let analysis, analysis.assetID == id {
            analysisByID[id] = analysis
            return analysis
        }
        unavailableAnalysisIDs.insert(id)
        return nil
    }

    func decision(for id: AssetID) -> Decision? {
        decisionByID[id]
    }

    /// Cached S12 grouping: the derivation (incl. UUIDs) runs once in init,
    /// never per body evaluation (`SimilarGroups` and `ReviewOverview` both
    /// read it per render). `@ObservationIgnored`: derived, never observed.
    @ObservationIgnored private var cachedSimilarGroups: [SimilarGroup] = []

    var selectedAssetIDs: [AssetID] {
        displayIDs.filter(selectedIDs.contains)
    }

    var removedAssetIDs: [AssetID] {
        displayIDs.filter { !selectedIDs.contains($0) }
    }

    /// S10 order: engine picks plus anything currently selected, chrono.
    var curatedDisplayIDs: [AssetID] {
        displayIDs.filter { engineSelected.contains($0) || selectedIDs.contains($0) }
    }

    /// S12 groups from near-duplicate decisions via the `competingIDs` winner
    /// relation. Engine-stable IDs via `StableSelectionID(kind: "cluster")`.
    /// Cached: `SimilarGroups` and `ReviewOverview` both read it per render.
    var similarGroups: [SimilarGroup] {
        cachedSimilarGroups
    }

    private static func buildSimilarGroups(
        result: SelectionResult, displayIDs: [AssetID], sourceByID: [AssetID: PhotoAsset]
    ) -> [SimilarGroup] {
        let live = Set(sourceByID.keys)
        var membersByWinner: [AssetID: Set<AssetID>] = [:]
        for decision in result.decisions {
            guard live.contains(decision.assetID) else { continue }
            if decision.reasons.contains("nearDuplicateRepresentative") {
                membersByWinner[decision.assetID, default: []].insert(decision.assetID)
            } else if decision.reasons.contains("nearDuplicate"), let winner = decision.competingIDs.first {
                guard live.contains(winner) else { continue }
                membersByWinner[winner, default: []].insert(decision.assetID)
                membersByWinner[winner, default: []].insert(winner)
            }
        }
        let order = Dictionary(uniqueKeysWithValues: displayIDs.enumerated().map { ($1, $0) })
        var groups: [SimilarGroup] = []
        for (winner, members) in membersByWinner {
            let liveMembers = members.intersection(live)
            guard liveMembers.count >= 2, live.contains(winner) else { continue }
            let sortedMembers = liveMembers.sorted {
                (order[$0] ?? Int.max, $0.rawValue) < (order[$1] ?? Int.max, $1.rawValue)
            }
            let id = ClusterID(rawValue: StableSelectionID.uuid(
                kind: "cluster",
                members: sortedMembers.sorted { $0.rawValue < $1.rawValue }
            ))
            groups.append(SimilarGroup(id: id, memberIDs: sortedMembers, engineWinner: winner))
        }
        return groups.sorted {
            (order[$0.engineWinner] ?? Int.max, $0.id.rawValue.uuidString)
                < (order[$1.engineWinner] ?? Int.max, $1.id.rawValue.uuidString)
        }
    }

    func currentWinner(of group: SimilarGroup) -> AssetID {
        swapWinnerByGroup[group.id] ?? group.engineWinner
    }

    func isSelected(_ id: AssetID) -> Bool {
        selectedIDs.contains(id)
    }

    func remove(_ id: AssetID) {
        guard selectedIDs.remove(id) != nil else { return }
        trackRemoval(id)
        lastRemovedID = id
        persist()
        notifyWorkspaceChoice(assetIDs: [id], albumMembership: .excluded)
    }

    func restore(_ id: AssetID) {
        guard Set(displayIDs).contains(id) else { return }
        guard !selectedIDs.contains(id) else { return }
        selectedIDs.insert(id)
        trackInsertion(id)
        if lastRemovedID == id {
            lastRemovedID = nil
        }
        persist()
        notifyWorkspaceChoice(assetIDs: [id], albumMembership: .included)
    }

    func toggle(_ id: AssetID) {
        if isSelected(id) {
            remove(id)
        } else {
            restore(id)
        }
    }

    func undoLastRemoval() {
        guard let id = lastRemovedID else { return }
        // A winner swap names `prior` as the removal; undoing it must also
        // drop the swap record, or the winner label and selection disagree.
        for (groupID, winner) in swapWinnerByGroup where winner == id {
            swapWinnerByGroup.removeValue(forKey: groupID)
        }
        restore(id)
        lastRemovedID = nil
    }

    /// S12 winner swap: the new pick joins; the prior representative leaves
    /// only when it was the sole selected member (deliberate multi-selects
    /// survive). No-op beyond ensuring selection when re-tapping the winner.
    func selectWinner(_ id: AssetID, in group: SimilarGroup) {
        guard group.memberIDs.contains(id), Set(displayIDs).contains(id) else { return }
        let prior = currentWinner(of: group)
        let singlePrior = Set(group.memberIDs.filter(selectedIDs.contains)) == [prior]
        if !selectedIDs.contains(id) {
            selectedIDs.insert(id)
            trackInsertion(id)
        }
        if id != prior, singlePrior {
            selectedIDs.remove(prior)
            trackRemoval(prior)
            lastRemovedID = prior
        }
        if id != group.engineWinner {
            swapWinnerByGroup[group.id] = id
        } else if swapWinnerByGroup[group.id] != nil, !singlePrior {
            // Kept: re-selecting the engine winner after multi-select edits
            // still records the explicit choice.
            swapWinnerByGroup[group.id] = id
        } else {
            swapWinnerByGroup.removeValue(forKey: group.id)
        }
        persist()
        var albumChanges: [AssetID: AlbumMembership] = [id: .included]
        if id != prior, singlePrior {
            albumChanges[prior] = .excluded
        }
        notifyAlbumChanges(albumChanges)
    }

    func feedbackSnapshot() -> SelectionFeedback {
        SelectionFeedback(
            removedIDs: removedEditIDs,
            restoredIDs: restoredEditIDs,
            favoriteIDs: favoriteEditIDs,
            swapWinner: swapWinnerByGroup
        )
    }

    /// Resolution for one queue member: true once the user edits it (remove,
    /// restore, or swap-winner). Queue membership is fixed at review entry;
    /// only the edit sets grow. Delegates to the owned review state.
    func isUncertaintyResolved(_ id: AssetID) -> Bool {
        reviewState.isResolved(id, feedback: feedbackSnapshot())
    }

    func resolvedUncertaintyCount() -> Int {
        reviewState.resolvedCount(feedback: feedbackSnapshot())
    }

    /// Bounded snapshot for the on-disk row: aggregate counts only.
    /// Delegates to the owned review state.
    func uncertaintySnapshot() -> UncertaintyFeedbackSnapshot {
        reviewState.snapshot(
            sessionID: sessionID,
            engineVersion: result.engineVersion,
            feedback: feedbackSnapshot(),
            updatedAt: Date()
        )
    }

    func trackRemoval(_ id: AssetID) {
        restoredEditIDs.remove(id)
        if engineSelected.contains(id) {
            removedEditIDs.insert(id)
        }
    }

    func trackInsertion(_ id: AssetID) {
        if engineSelected.contains(id) {
            removedEditIDs.remove(id)
        } else {
            restoredEditIDs.insert(id)
        }
    }

    func persist() {
        onFeedbackChanged?(feedbackSnapshot())
    }

    private static func chronoOrder(ids: Set<AssetID>, sourceByID: [AssetID: PhotoAsset]) -> [AssetID] {
        ids.sorted {
            let left = sourceByID[$0]?.creationDate ?? .distantPast
            let right = sourceByID[$1]?.creationDate ?? .distantPast
            if left != right {
                return left < right
            }
            return $0.rawValue < $1.rawValue
        }
    }
}

// MARK: - feat-034 durable workspace dispatch

extension ReviewModel {
    func notifyWorkspaceChoice(
        assetIDs: [AssetID],
        albumMembership: AlbumMembership? = nil,
        cleanupDisposition: CleanupDisposition? = nil,
        reviewProgress: ReviewProgress? = nil
    ) {
        guard let scopeID else { return }
        onWorkspaceChoice?(ReviewWorkspaceChoice(
            scopeID: scopeID,
            assetIDs: assetIDs,
            albumMembership: albumMembership,
            cleanupDisposition: cleanupDisposition,
            reviewProgress: reviewProgress
        ))
    }

    func notifyAlbumChanges(_ changes: [AssetID: AlbumMembership]) {
        guard let scopeID else { return }
        for (assetID, membership) in changes {
            onWorkspaceChoice?(ReviewWorkspaceChoice(
                scopeID: scopeID,
                assetIDs: [assetID],
                albumMembership: membership,
                cleanupDisposition: nil,
                reviewProgress: nil
            ))
        }
    }

    static func workspaceAlbumSelected(
        workspaceItems: [AssetID: WorkspaceItemSnapshot], live: Set<AssetID>
    ) -> Set<AssetID> {
        Set(workspaceItems.values.filter { live.contains($0.assetID) && $0.albumMembership == .included }
            .map(\.assetID))
    }
}
