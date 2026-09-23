import Foundation

/// One persisted decision per source asset plus chronological ordering.
///
/// Selected IDs receive `bestInMoment` or `secondaryMomentRepresentative`,
/// plus `nearDuplicateRepresentative` when the pick speaks for a cluster,
/// plus feat-020 people reasons (`bestGroupPhoto` + `betterFaceQuality` for
/// group picks, `bestPortrait` for single-face picks; frozen codes only).
/// Rejected duplicate losers receive `nearDuplicate` with the winner in
/// `competingIDs`; quality-floor exclusions receive `lowQuality`; usable
struct FinalAlbumBuildInput: Sendable {
    let sourceAssets: [PhotoAsset]
    let analyses: [AssetID: PhotoAnalysis]
    let clusters: [PhotoCluster]
    let moments: [PhotoMoment]
    let scored: [ScoredCandidate]
    let selectedIDs: Set<AssetID>
}

struct FinalAlbumBuilder: Sendable {
    func build(_ input: FinalAlbumBuildInput) throws -> SelectionResult {
        let context = BuilderContext(
            sourceAssets: input.sourceAssets,
            clusters: input.clusters,
            moments: input.moments,
            scored: input.scored
        )
        var decisions: [Decision] = []
        for asset in input.sourceAssets {
            decisions.append(context.decision(for: asset, analyses: input.analyses, selectedIDs: input.selectedIDs))
        }
        let byID = Dictionary(uniqueKeysWithValues: input.sourceAssets.map { ($0.id, $0) })
        let selected = decisions.filter { $0.status == .selected }.map(\.assetID).sorted {
            context.chronological($0, $1, byID: byID)
        }
        try context.verify(decisions: decisions, sourceCount: input.sourceAssets.count, selected: selected, byID: byID)
        let provenance = context.provenance(
            ProvenanceInput(
                sourceAssets: input.sourceAssets,
                analyses: input.analyses,
                clusters: input.clusters,
                moments: input.moments,
                scored: input.scored
            ),
            selectedCount: selected.count
        )
        return SelectionResult(
            sessionID: SessionID(rawValue: UUID()),
            selectedAssetIDs: selected,
            rejectedAssetIDs: input.sourceAssets.map(\.id).filter { !selected.contains($0) },
            decisions: decisions,
            generatedAt: Date(),
            engineVersion: 3,
            provenance: provenance
        )
    }
}

/// Decision assembly plus invariant checks over frozen source order.
private struct ProvenanceInput {
    let sourceAssets: [PhotoAsset]
    let analyses: [AssetID: PhotoAnalysis]
    let clusters: [PhotoCluster]
    let moments: [PhotoMoment]
    let scored: [ScoredCandidate]
}

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
            // feat-020 people reasons (selection-rules §16, frozen codes only):
            // a group pick (2+ faces) carries bestGroupPhoto with
            // betterFaceQuality when the weakest-face signal is present; a
            // single-face pick carries bestPortrait. No new code invented.
            if let candidate = scoreByID[asset.id], candidate.containsPeople {
                let faces = analyses[asset.id]?.people.faceCount ?? 0
                if faces >= 2 {
                    reasons.append("bestGroupPhoto")
                    if analyses[asset.id]?.people.minFaceQuality != nil {
                        reasons.append("betterFaceQuality")
                    }
                } else {
                    reasons.append("bestPortrait")
                }
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

    func provenance(_ input: ProvenanceInput, selectedCount: Int) -> SelectionResultProvenance {
        let sourceIDs = input.sourceAssets.map(\.id)
        let sourceSet = Set(sourceIDs)
        let groupedIDs = Set(
            input.clusters.flatMap(\.assetIDs) + input.moments.flatMap(\.assetIDs)
        ).intersection(sourceSet)
        let analyzedIDs = Set(input.analyses.keys).intersection(sourceSet)
        let scoredIDs = Set(input.scored.map { $0.asset.id }).intersection(sourceSet)
        let analysisRevisions = Set(input.analyses.values.map(\.analysisVersion))
        let analysisRevision = analysisRevisions.count == 1 ? analysisRevisions.first : nil
        return SelectionResultProvenance(
            schemaVersion: SelectionResultProvenance.schemaVersion,
            sourceAssetIDs: sourceIDs,
            analysisRevision: analysisRevision,
            groupingRevision: 1,
            clusters: input.clusters.map {
                SelectionClusterRecord(
                    id: $0.id,
                    type: $0.type,
                    memberIDs: $0.assetIDs,
                    representativeAssetID: $0.representativeAssetID
                )
            },
            moments: input.moments.map {
                SelectionMomentRecord(
                    id: $0.id,
                    memberIDs: $0.assetIDs,
                    representativeAssetID: $0.representativeAssetID
                )
            },
            evidence: SelectionEvidenceAvailability(
                analyzedAssetCount: analyzedIDs.count,
                unavailableAssetCount: sourceSet.subtracting(analyzedIDs).count,
                scoredAssetCount: scoredIDs.count,
                unscoredAssetCount: analyzedIDs.subtracting(scoredIDs).count,
                scoreContributionAssetCount: scoredIDs.count,
                qualityEvidenceAvailable: false,
                coverageEvidenceAvailable: false
            ),
            coverage: SelectionCoverageCounters(
                sourceAssetCount: sourceIDs.count,
                groupedAssetCount: groupedIDs.count,
                ungroupedAssetCount: sourceSet.subtracting(groupedIDs).count,
                clusterCount: input.clusters.count,
                momentCount: input.moments.count,
                selectedAssetCount: selectedCount,
                uncoveredMomentCount: nil,
                candidateCount: nil,
                candidateLimit: nil,
                truncatedCandidateCount: nil,
                pairCount: nil,
                pairLimit: nil,
                truncatedPairCount: nil,
                coveredMemberCount: nil,
                unknownPairCount: nil
            )
        )
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
