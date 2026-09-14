import Foundation

/// One persisted decision per source asset plus chronological ordering.
///
/// Selected IDs receive `bestInMoment` or `secondaryMomentRepresentative`,
/// plus `nearDuplicateRepresentative` when the pick speaks for a cluster.
/// Rejected duplicate losers receive `nearDuplicate` with the winner in
/// `competingIDs`; quality-floor exclusions receive `lowQuality`; usable
/// assets cut by shortlist/diversity receive a truthful diversity reason
/// (never a false quality claim). Verifies one-decision-per-source,
/// every pick has a reason and an analysis, one pick per cluster, and
/// chronological output before returning `engineVersion 2`.
struct FinalAlbumBuilder: Sendable {
    // swiftlint:disable:next function_parameter_count
    func build(
        sourceAssets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        clusters: [PhotoCluster],
        moments: [PhotoMoment],
        scored: [ScoredCandidate],
        selectedIDs: Set<AssetID>,
        configuration _: SelectionConfiguration
    ) throws -> SelectionResult {
        let context = BuilderContext(sourceAssets: sourceAssets, clusters: clusters, moments: moments, scored: scored)
        var decisions: [Decision] = []
        for asset in sourceAssets {
            decisions.append(context.decision(for: asset, analyses: analyses, selectedIDs: selectedIDs))
        }
        let byID = Dictionary(uniqueKeysWithValues: sourceAssets.map { ($0.id, $0) })
        let selected = decisions.filter { $0.status == .selected }.map(\.assetID).sorted {
            context.chronological($0, $1, byID: byID)
        }
        try context.verify(decisions: decisions, sourceCount: sourceAssets.count, selected: selected, byID: byID)
        return SelectionResult(
            sessionID: SessionID(rawValue: UUID()),
            selectedAssetIDs: selected,
            rejectedAssetIDs: sourceAssets.map(\.id).filter { !selected.contains($0) },
            decisions: decisions,
            generatedAt: Date(),
            engineVersion: 2
        )
    }
}

/// Decision assembly plus invariant checks over frozen source order.
private struct BuilderContext {
    let order: [AssetID: Int]
    let winnerByCluster: [AssetID: AssetID]
    let moments: [PhotoMoment]
    let scoreByID: [AssetID: ScoredCandidate]
    let scored: [ScoredCandidate]

    init(sourceAssets: [PhotoAsset], clusters: [PhotoCluster], moments: [PhotoMoment], scored: [ScoredCandidate]) {
        order = Dictionary(uniqueKeysWithValues: sourceAssets.enumerated().map { ($1.id, $0) })
        winnerByCluster = Dictionary(uniqueKeysWithValues: clusters.flatMap { cluster in
            guard let winner = cluster.representativeAssetID else { return [] as [(AssetID, AssetID)] }
            return cluster.assetIDs.map { ($0, winner) }
        })
        self.moments = moments
        scoreByID = Dictionary(uniqueKeysWithValues: scored.map { ($0.asset.id, $0) })
        self.scored = scored
    }

    func decision(
        for asset: PhotoAsset, analyses: [AssetID: PhotoAnalysis], selectedIDs: Set<AssetID>
    ) -> Decision {
        guard analyses[asset.id] != nil else {
            return Decision(
                assetID: asset.id, status: .rejected, score: nil,
                qualityBreakdown: nil, reasons: ["assetUnavailable"], competingIDs: []
            )
        }
        if selectedIDs.contains(asset.id) {
            var reasons: [String] = moments.contains(where: { $0.representativeAssetID == asset.id })
                ? ["bestInMoment"]
                : ["secondaryMomentRepresentative"]
            if winnerByCluster[asset.id] != nil {
                reasons.append("nearDuplicateRepresentative")
            }
            return Decision(
                assetID: asset.id, status: .selected, score: scoreByID[asset.id]?.score,
                qualityBreakdown: analyses[asset.id]?.qualityBreakdown, reasons: reasons, competingIDs: []
            )
        }
        // Decision priority follows selection-rules §1: eligibility, then hard
        // quality rejection, then duplicate suppression, then diversity cuts.
        // Only an actually scored non-usable candidate reports lowQuality; an
        // unscored duplicate loser (never a representative) keeps nearDuplicate.
        // A low-quality duplicate reports lowQuality first; the cluster winner
        // stays as secondary competingIDs data for QA/swap use.
        if let candidate = scoreByID[asset.id], candidate.disposition != .usable {
            var competing: [AssetID] = []
            if let winner = winnerByCluster[asset.id], winner != asset.id {
                competing = [winner]
            }
            return Decision(
                assetID: asset.id, status: .rejected, score: nil,
                qualityBreakdown: nil, reasons: ["lowQuality"], competingIDs: competing
            )
        }
        if let winner = winnerByCluster[asset.id], winner != asset.id {
            return Decision(
                assetID: asset.id, status: .rejected, score: nil,
                qualityBreakdown: nil, reasons: ["nearDuplicate"], competingIDs: [winner]
            )
        }
        let candidate = scoreByID[asset.id]
        return Decision(
            assetID: asset.id, status: .rejected, score: candidate?.score,
            qualityBreakdown: analyses[asset.id]?.qualityBreakdown,
            reasons: [diversityCutReason(for: asset.id, selectedIDs: selectedIDs)],
            competingIDs: []
        )
    }

    func chronological(_ left: AssetID, _ right: AssetID, byID: [AssetID: PhotoAsset]) -> Bool {
        let leftAsset = byID[left]!
        let rightAsset = byID[right]!
        if (leftAsset.creationDate ?? .distantPast) != (rightAsset.creationDate ?? .distantPast) {
            return (leftAsset.creationDate ?? .distantPast) < (rightAsset.creationDate ?? .distantPast)
        }
        if order[left] != order[right] {
            return order[left]! < order[right]!
        }
        return left.rawValue < right.rawValue
    }

    func verify(
        decisions: [Decision], sourceCount: Int, selected: [AssetID], byID: [AssetID: PhotoAsset]
    ) throws {
        guard decisions.count == sourceCount, Set(decisions.map(\.assetID)).count == sourceCount else {
            throw SelectionError.internal
        }
        guard decisions.filter({ $0.status == .selected }).allSatisfy({ !$0.reasons.isEmpty }) else {
            throw SelectionError.internal
        }
        let pickedClusters = decisions.filter { $0.status == .selected }.compactMap { winnerByCluster[$0.assetID] }
        guard Set(pickedClusters).count == pickedClusters.count else {
            throw SelectionError.internal
        }
        let pairs = zip(selected, selected.dropFirst())
        guard pairs.allSatisfy({ chronological($0, $1, byID: byID) }) else {
            throw SelectionError.internal
        }
    }

    private func diversityCutReason(for id: AssetID, selectedIDs: Set<AssetID>) -> String {
        guard let candidate = scoreByID[id] else { return "compositionDiversity" }
        let picked = scored.filter { selectedIDs.contains($0.asset.id) }
        if picked.contains(where: { $0.momentID == candidate.momentID }) {
            return "temporalCoverage"
        }
        if picked.contains(where: { $0.sceneType == candidate.sceneType }) {
            return "sceneDiversity"
        }
        if picked.contains(where: { $0.containsPeople == candidate.containsPeople }) {
            return "peopleDiversity"
        }
        return "compositionDiversity"
    }
}
