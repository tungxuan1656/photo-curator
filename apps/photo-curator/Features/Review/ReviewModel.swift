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
    private(set) var selectedIDs: Set<AssetID>
    let displayIDs: [AssetID]
    private(set) var lastRemovedID: AssetID?
    var albumName = "Curated Photos"
    /// Persisted unavailable bucket (survives relaunch where the in-memory
    /// progress counter resets). Assigned by the owner at review entry from
    /// `unavailableCount(result:frozenSourceCount:)`; defaults to hidden.
    var persistedUnavailableCount = 0

    private let engineSelected: Set<AssetID>
    @ObservationIgnored private let analysisCache: any AnalysisCache
    @ObservationIgnored private let decisionByID: [AssetID: Decision]
    @ObservationIgnored private var analysisByID: [AssetID: PhotoAnalysis] = [:]
    @ObservationIgnored private var unavailableAnalysisIDs: Set<AssetID> = []
    @ObservationIgnored private var analysisFlights: [AssetID: Task<PhotoAnalysis?, Never>] = [:]
    private var removedEditIDs: Set<AssetID>
    private var restoredEditIDs: Set<AssetID>
    private var favoriteEditIDs: Set<AssetID>
    private var swapWinnerByGroup: [ClusterID: AssetID]
    @ObservationIgnored private var onFeedbackChanged: ((SelectionFeedback) -> Void)?

    init(
        sessionID: SessionID,
        result: SelectionResult,
        sourceByID: [AssetID: PhotoAsset],
        analysisCache: any AnalysisCache,
        feedback: SelectionFeedback? = nil,
        onFeedbackChanged: ((SelectionFeedback) -> Void)? = nil
    ) {
        self.sessionID = sessionID
        self.result = result
        self.sourceByID = sourceByID
        self.analysisCache = analysisCache
        decisionByID = Dictionary(uniqueKeysWithValues: result.decisions.map { ($0.assetID, $0) })
        self.onFeedbackChanged = onFeedbackChanged
        let live = Set(sourceByID.keys)
        let allResultIDs = Set(result.selectedAssetIDs + result.rejectedAssetIDs)
        let chrono = Self.chronoOrder(ids: allResultIDs, sourceByID: sourceByID)
        displayIDs = chrono.filter(live.contains)
        let liveSet = Set(displayIDs)
        let engineSelectedIDs = Set(result.selectedAssetIDs).intersection(liveSet)
        engineSelected = engineSelectedIDs
        let removed: Set<AssetID>
        let restored: Set<AssetID>
        if let feedback {
            removed = feedback.removedIDs.intersection(liveSet)
            restored = feedback.restoredIDs.intersection(liveSet)
            favoriteEditIDs = feedback.favoriteIDs.intersection(liveSet)
            swapWinnerByGroup = feedback.swapWinner.filter { liveSet.contains($0.value) }
        } else {
            removed = []
            restored = []
            favoriteEditIDs = []
            swapWinnerByGroup = [:]
        }
        removedEditIDs = removed
        restoredEditIDs = restored
        selectedIDs = engineSelectedIDs.subtracting(removed).union(restored).intersection(liveSet)
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
    }

    func feedbackSnapshot() -> SelectionFeedback {
        SelectionFeedback(
            removedIDs: removedEditIDs,
            restoredIDs: restoredEditIDs,
            favoriteIDs: favoriteEditIDs,
            swapWinner: swapWinnerByGroup
        )
    }

    private func trackRemoval(_ id: AssetID) {
        restoredEditIDs.remove(id)
        if engineSelected.contains(id) {
            removedEditIDs.insert(id)
        }
    }

    private func trackInsertion(_ id: AssetID) {
        if engineSelected.contains(id) {
            removedEditIDs.remove(id)
        } else {
            restoredEditIDs.insert(id)
        }
    }

    private func persist() {
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
