import Foundation

enum DecisionStatus: String, Codable, Sendable {
    case selected, rejected
}

/// One keep/reject choice. Rejected means "not in this album", never "safe to delete" (DEC-026).
struct Decision: Codable, Sendable {
    let assetID: AssetID
    let status: DecisionStatus
    let score: Double?
    let qualityBreakdown: QualityScoreBreakdown?
    /// The weighted terms that produced `score`. This is distinct from the
    /// analysis-time technical breakdown and is nil for unavailable or
    /// unscored duplicate members.
    let scoreContributions: FinalScoreContributions?
    let reasons: [String]
    let competingIDs: [AssetID]

    init(
        assetID: AssetID,
        status: DecisionStatus,
        score: Double?,
        qualityBreakdown: QualityScoreBreakdown?,
        scoreContributions: FinalScoreContributions? = nil,
        reasons: [String],
        competingIDs: [AssetID]
    ) {
        self.assetID = assetID
        self.status = status
        self.score = score
        self.qualityBreakdown = qualityBreakdown
        self.scoreContributions = scoreContributions
        self.reasons = reasons
        self.competingIDs = competingIDs
    }
}

/// Final selection score evidence. Optional terms are absent when the source
/// fact was not available; they are never replaced with a numeric default.
struct FinalScoreContributions: Codable, Sendable {
    let technical: Double
    let people: Double?
    let composition: Double?
    let technicalContribution: Double
    let peopleContribution: Double?
    let compositionContribution: Double?
    let favoriteBonus: Double
    let editedBonus: Double
    let unclampedTotal: Double
    let total: Double
}

/// Bounded selection accounting shared by the normal and quality routes.
/// It records hard-cap truncation and unknown graph coverage rather than
/// implying that omitted moments or pairs were low quality.
struct SelectionCoverageEvidence: Codable, Sendable {
    let usableCount: Int
    let targetCount: Int
    let selectedCount: Int
    let maximumCount: Int
    let uncoveredMomentIDs: [MomentID]
    let alternativeAssetIDs: [AssetID]
    let candidateCount: Int
    let candidateLimit: Int
    let truncatedCandidateCount: Int
    let pairCount: Int
    let pairLimit: Int
    let truncatedPairCount: Int
    let coveredMemberCount: Int
    let unknownPairCount: Int
}

/// Compact, run-owned grouping records persisted with a selection result.
/// These records keep review independent from transient analysis/cache state.
struct SelectionClusterRecord: Codable, Sendable {
    let id: ClusterID
    let type: ClusterType
    let memberIDs: [AssetID]
    let representativeAssetID: AssetID?
}

struct SelectionMomentRecord: Codable, Sendable {
    let id: MomentID
    let memberIDs: [AssetID]
    let representativeAssetID: AssetID?
}

struct SelectionEvidenceAvailability: Codable, Sendable {
    let analyzedAssetCount: Int
    let unavailableAssetCount: Int
    let scoredAssetCount: Int
    let unscoredAssetCount: Int
    let scoreContributionAssetCount: Int
    let qualityEvidenceAvailable: Bool
    let coverageEvidenceAvailable: Bool
}

/// Counters are optional only for route-specific graph work that was not
/// available to the result producer. Nil means unknown, never zero evidence.
struct SelectionCoverageCounters: Codable, Sendable {
    let sourceAssetCount: Int
    let groupedAssetCount: Int
    let ungroupedAssetCount: Int
    let clusterCount: Int
    let momentCount: Int
    let selectedAssetCount: Int
    let uncoveredMomentCount: Int?
    let candidateCount: Int?
    let candidateLimit: Int?
    let truncatedCandidateCount: Int?
    let pairCount: Int?
    let pairLimit: Int?
    let truncatedPairCount: Int?
    let coveredMemberCount: Int?
    let unknownPairCount: Int?
}

/// Versioned provenance for the analysis-to-review boundary. Older result
/// payloads decode with nil provenance and are handled by a legacy adapter.
struct SelectionResultProvenance: Codable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let sourceAssetIDs: [AssetID]
    let analysisRevision: Int?
    let groupingRevision: Int?
    let clusters: [SelectionClusterRecord]
    let moments: [SelectionMomentRecord]
    let evidence: SelectionEvidenceAvailability
    let coverage: SelectionCoverageCounters

    func updating(
        with coverageEvidence: SelectionCoverageEvidence,
        selectedAssetCount: Int,
        qualityEvidenceAvailable: Bool? = nil
    ) -> SelectionResultProvenance {
        SelectionResultProvenance(
            schemaVersion: schemaVersion,
            sourceAssetIDs: sourceAssetIDs,
            analysisRevision: analysisRevision,
            groupingRevision: groupingRevision,
            clusters: clusters,
            moments: moments,
            evidence: SelectionEvidenceAvailability(
                analyzedAssetCount: evidence.analyzedAssetCount,
                unavailableAssetCount: evidence.unavailableAssetCount,
                scoredAssetCount: evidence.scoredAssetCount,
                unscoredAssetCount: evidence.unscoredAssetCount,
                scoreContributionAssetCount: evidence.scoreContributionAssetCount,
                qualityEvidenceAvailable: qualityEvidenceAvailable ?? evidence.qualityEvidenceAvailable,
                coverageEvidenceAvailable: true
            ),
            coverage: SelectionCoverageCounters(
                sourceAssetCount: coverage.sourceAssetCount,
                groupedAssetCount: coverage.groupedAssetCount,
                ungroupedAssetCount: coverage.ungroupedAssetCount,
                clusterCount: coverage.clusterCount,
                momentCount: coverage.momentCount,
                selectedAssetCount: selectedAssetCount,
                uncoveredMomentCount: coverageEvidence.uncoveredMomentIDs.count,
                candidateCount: coverageEvidence.candidateCount,
                candidateLimit: coverageEvidence.candidateLimit,
                truncatedCandidateCount: coverageEvidence.truncatedCandidateCount,
                pairCount: coverageEvidence.pairCount,
                pairLimit: coverageEvidence.pairLimit,
                truncatedPairCount: coverageEvidence.truncatedPairCount,
                coveredMemberCount: coverageEvidence.coveredMemberCount,
                unknownPairCount: coverageEvidence.unknownPairCount
            )
        )
    }
}

struct SelectionResult: Codable, Sendable {
    let sessionID: SessionID
    let selectedAssetIDs: [AssetID]
    let rejectedAssetIDs: [AssetID]
    let decisions: [Decision]
    let generatedAt: Date
    let engineVersion: Int
    let qualityEvidence: QualityCurationEvidence?
    let coverageEvidence: SelectionCoverageEvidence?
    /// Nil identifies a legacy result whose producer did not persist grouping
    /// provenance. It must not be filled from current analysis constants.
    let provenance: SelectionResultProvenance?

    init(
        sessionID: SessionID,
        selectedAssetIDs: [AssetID],
        rejectedAssetIDs: [AssetID],
        decisions: [Decision],
        generatedAt: Date,
        engineVersion: Int,
        qualityEvidence: QualityCurationEvidence? = nil,
        coverageEvidence: SelectionCoverageEvidence? = nil,
        provenance: SelectionResultProvenance? = nil
    ) {
        self.sessionID = sessionID
        self.selectedAssetIDs = selectedAssetIDs
        self.rejectedAssetIDs = rejectedAssetIDs
        self.decisions = decisions
        self.generatedAt = generatedAt
        self.engineVersion = engineVersion
        self.qualityEvidence = qualityEvidence
        self.coverageEvidence = coverageEvidence
        self.provenance = provenance
    }

    /// The review contract is the complete source outcome, not the size of
    /// the album pick set. A run with zero picks is valid when every source
    /// asset has a rejected/unavailable outcome.
    var outcomeAssetIDs: [AssetID] {
        var seen = Set<AssetID>()
        return (selectedAssetIDs + rejectedAssetIDs + decisions.map(\.assetID)).filter {
            seen.insert($0).inserted
        }
    }

    func hasValidReviewOutcome(
        for sourceAssetIDs: [AssetID], unavailableAssetIDs: [AssetID] = []
    ) -> Bool {
        let source = Set(sourceAssetIDs)
        guard !source.isEmpty else { return !outcomeAssetIDs.isEmpty }
        let selected = Set(selectedAssetIDs)
        let rejected = Set(rejectedAssetIDs)
        let decisionIDs = decisions.map(\.assetID)
        guard selected.count == selectedAssetIDs.count,
              rejected.count == rejectedAssetIDs.count,
              selected.isDisjoint(with: rejected),
              Set(decisionIDs).count == decisionIDs.count else { return false }
        let outcomes = selected.union(rejected).union(decisionIDs)
        guard outcomes.isSubset(of: source) else { return false }
        // Complete outcomes are required when the frozen source set is known.
        // This permits a valid all-rejected/all-unavailable run without using
        // selected IDs as the validity test.
        return outcomes.union(Set(unavailableAssetIDs)) == source
    }
}

/// Review overrides collected by UI. Stored per session; learning from it is post-MVP (DEC-020).
///
/// Custom string-keyed coding: `swapWinner` uses `ClusterID` keys, which JSON
/// cannot encode directly, so it persists as UUID-string to asset-ID maps.
struct SelectionFeedback: Sendable {
    var removedIDs: Set<AssetID> = []
    var restoredIDs: Set<AssetID> = []
    var favoriteIDs: Set<AssetID> = []
    var swapWinner: [ClusterID: AssetID] = [:]
}

extension SelectionFeedback: Codable {
    enum CodingKeys: String, CodingKey {
        case removedIDs, restoredIDs, favoriteIDs, swapWinner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let removed = try container.decodeIfPresent([String].self, forKey: .removedIDs) ?? []
        let restored = try container.decodeIfPresent([String].self, forKey: .restoredIDs) ?? []
        let favorites = try container.decodeIfPresent([String].self, forKey: .favoriteIDs) ?? []
        removedIDs = Set(removed.map(AssetID.init(rawValue:)))
        restoredIDs = Set(restored.map(AssetID.init(rawValue:)))
        favoriteIDs = Set(favorites.map(AssetID.init(rawValue:)))
        let swaps = try container.decodeIfPresent([String: String].self, forKey: .swapWinner) ?? [:]
        var winners: [ClusterID: AssetID] = [:]
        for (key, value) in swaps {
            guard let uuid = UUID(uuidString: key) else { continue }
            winners[ClusterID(rawValue: uuid)] = AssetID(rawValue: value)
        }
        swapWinner = winners
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(removedIDs.map(\.rawValue).sorted(), forKey: .removedIDs)
        try container.encode(restoredIDs.map(\.rawValue).sorted(), forKey: .restoredIDs)
        try container.encode(favoriteIDs.map(\.rawValue).sorted(), forKey: .favoriteIDs)
        var swaps: [String: String] = [:]
        for (key, value) in swapWinner {
            swaps[key.rawValue.uuidString] = value.rawValue
        }
        try container.encode(swaps, forKey: .swapWinner)
    }
}
