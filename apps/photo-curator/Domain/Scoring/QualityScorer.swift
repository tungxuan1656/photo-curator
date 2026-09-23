import Foundation

/// Quality tiers for final selection. Both rejection cases carry canonical
/// `lowQuality` in decisions: no configured defect-probability cutoff
/// identifies a truthful severe-defect reason.
enum QualityDisposition: Sendable {
    case usable, lowQuality, hardRejected
}

/// One ranked, selectable unit: a duplicate representative inside its moment,
/// with selection metadata copied out of `PhotoAnalysis`/`PhotoAsset`.
/// `sceneType`, `containsPeople`, and `isPortrait` are selection metadata
/// only; they never change the stored analysis.
struct ScoredCandidate: Sendable {
    let asset: PhotoAsset
    let analysis: PhotoAnalysis
    let clusterID: ClusterID?
    let momentID: MomentID
    let sceneType: SceneType
    let containsPeople: Bool
    let isPortrait: Bool
    let score: Double
    let scoreContributions: FinalScoreContributions
    let disposition: QualityDisposition
    let reasons: [String]
}

/// Pure quality scoring plus per-moment rank and coverage-first shortlist.
///
/// Scoring is a clamped weighted mean of available signals only: missing
/// face/composition data contributes no numerator and no denominator.
/// Shortlist ranks usable representatives per moment (score, favorite,
/// resolution, asset ID), caps each moment at `maxPhotosPerMoment`, then
/// round-robins rank 1 of every moment before rank 2 so coverage precedes
/// score concentration. Rank-1 candidates survive even past the soft cap.
/// Feat-023 graph window: the 150-250 operating range caps pools above 250 in
/// shortlist order (coverage-first, deterministic); pools below 150 pass
/// through unchanged — never padded (selection-rules Sec 14). Rank, cap, and
/// round-robin math are otherwise untouched.
struct QualityScorer: Sendable {
    /// One sizing contract for both native selection intents.
    /// `usableCount` is applied before the hard maximum, so a small source is
    /// never padded and a large source can never silently exceed the maximum.
    static func albumTargetCount(
        usableCount: Int, configuration: SelectionConfiguration
    ) -> Int {
        let usable = max(0, usableCount)
        let scaled = Int((Double(usable) * configuration.targetSelectionRatio).rounded(.up))
        let clamped = min(
            max(scaled, configuration.minimumFinalCount),
            configuration.maximumFinalCount
        )
        return min(usable, clamped)
    }

    func score(
        asset: PhotoAsset,
        analysis: PhotoAnalysis,
        clusterID: ClusterID?,
        momentID: MomentID,
        configuration: SelectionConfiguration
    ) -> ScoredCandidate {
        let technical = analysis.qualityScore
        var numerator = technical * configuration.technicalQualityWeight
        var denominator = configuration.technicalQualityWeight
        // A face count or the legacy count-derived group score is not a
        // quality claim. Only a measured per-face quality observation can
        // contribute to the final ranking.
        let peopleTerm = analysis.people.minFaceQuality
        if let peopleTerm {
            numerator += peopleTerm * configuration.humanImportanceWeight
            denominator += configuration.humanImportanceWeight
        }
        let composition = compositionScore(for: analysis)
        if let composition {
            numerator += composition * configuration.representativenessWeight
            denominator += configuration.representativenessWeight
        }
        let weightedBase = denominator > 0 ? numerator / denominator : technical
        let contributionDenominator = max(denominator, 1.0)
        let favoriteBonus = asset.isFavorite ? configuration.favoriteBonus : 0
        let editedBonus = asset.isEdited ? configuration.editedBonus : 0
        let unclampedTotal = weightedBase + favoriteBonus + editedBonus
        var score = unclampedTotal
        score = min(1.0, max(0.0, score))
        // Technical eligibility is a gate; the final score above is only the
        // relative ranking signal. People/composition evidence may improve or
        // lower rank, but it cannot turn a technically failed frame into an
        // eligible one (or reject an uncertain technical frame by itself).
        let disposition: QualityDisposition
        if technical < configuration.hardRejectThreshold {
            disposition = .hardRejected
        } else if technical < configuration.lowQualityThreshold {
            disposition = .lowQuality
        } else {
            disposition = .usable
        }
        return ScoredCandidate(
            asset: asset,
            analysis: analysis,
            clusterID: clusterID,
            momentID: momentID,
            sceneType: analysis.content.sceneType,
            containsPeople: analysis.people.containsPeople,
            isPortrait: asset.pixelHeight > asset.pixelWidth,
            score: score,
            scoreContributions: FinalScoreContributions(
                technical: technical,
                people: peopleTerm,
                composition: composition,
                technicalContribution: denominator > 0
                    ? technical * configuration.technicalQualityWeight / contributionDenominator
                    : technical,
                peopleContribution: peopleTerm.map {
                    $0 * configuration.humanImportanceWeight / contributionDenominator
                },
                compositionContribution: composition.map {
                    $0 * configuration.representativenessWeight / contributionDenominator
                },
                favoriteBonus: favoriteBonus,
                editedBonus: editedBonus,
                unclampedTotal: unclampedTotal,
                total: score
            ),
            disposition: disposition,
            reasons: disposition == .usable ? [] : ["lowQuality"]
        )
    }

    private func compositionScore(for analysis: PhotoAnalysis) -> Double? {
        var scores: [Double] = []
        scores.append(contentsOf: analysis.composition.aestheticScore.map { [$0] } ?? [])
        scores.append(contentsOf: analysis.composition.subjectPlacementScore.map { [$0] } ?? [])
        scores.append(contentsOf: analysis.composition.horizonScore.map { [$0] } ?? [])
        scores.append(contentsOf: analysis.composition.visualBalanceScore.map { [$0] } ?? [])
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func shortlist(
        candidates: [ScoredCandidate],
        targetCount: Int,
        configuration: SelectionConfiguration
    ) -> [ScoredCandidate] {
        var byMoment: [MomentID: [ScoredCandidate]] = [:]
        for candidate in candidates where candidate.disposition == .usable {
            byMoment[candidate.momentID, default: []].append(candidate)
        }
        for momentID in byMoment.keys {
            byMoment[momentID] = Array(
                byMoment[momentID]!.sorted(by: QualityScorer.compareRank).prefix(configuration.maxPhotosPerMoment)
            )
        }
        let ranked = byMoment.values.sorted {
            $0.first!.momentID.rawValue.uuidString < $1.first!.momentID.rawValue.uuidString
        }
        var out: [ScoredCandidate] = []
        var rank = 0
        let cap = Int((Double(targetCount) * configuration.shortlistMultiplier).rounded(.up))
        while out.count < cap {
            var added = false
            for list in ranked where rank < list.count {
                out.append(list[rank])
                added = true
                if out.count >= cap {
                    break
                }
            }
            if !added {
                break
            }
            rank += 1
        }
        var seen = Set(out.map(\.asset.id))
        for list in ranked {
            guard let first = list.first, !seen.contains(first.asset.id) else { continue }
            out.append(first)
            seen.insert(first.asset.id)
        }
        // Feat-023: enforce the 250 graph ceiling in shortlist order. Pools at
        // or under the ceiling pass through untouched (fallback-identical).
        if out.count > GlobalDiversityGraphBuilder.maxGraphMembers {
            out = Array(out.prefix(GlobalDiversityGraphBuilder.maxGraphMembers))
        }
        return out
    }

    /// Canonical rank order: score desc, edited-twin preference, favorite desc,
    /// pixel area desc, asset ID asc. Shared with DiversitySelector utility ties.
    static func compareRank(_ left: ScoredCandidate, _ right: ScoredCandidate) -> Bool {
        if left.score != right.score {
            return left.score > right.score
        }
        if left.asset.isEdited != right.asset.isEdited {
            return left.asset.isEdited
        }
        if left.asset.isFavorite != right.asset.isFavorite {
            return left.asset.isFavorite
        }
        let leftArea = left.asset.pixelWidth * left.asset.pixelHeight
        let rightArea = right.asset.pixelWidth * right.asset.pixelHeight
        if leftArea != rightArea {
            return leftArea > rightArea
        }
        return left.asset.id.rawValue < right.asset.id.rawValue
    }
}
