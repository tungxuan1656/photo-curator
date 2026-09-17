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
struct QualityScorer: Sendable {
    func score(
        asset: PhotoAsset,
        analysis: PhotoAnalysis,
        clusterID: ClusterID?,
        momentID: MomentID,
        configuration: SelectionConfiguration
    ) -> ScoredCandidate {
        var numerator = analysis.qualityScore * configuration.technicalQualityWeight
        var denominator = configuration.technicalQualityWeight
        // feat-020 weakest-face fold: the people term is the weaker of the
        // persisted count-proxy group score and the transient per-face minimum
        // (one failed face drags the group down, never up). Weights stay in
        // configuration; no threshold is invented here.
        if let group = analysis.people.groupPhotoScore {
            let peopleTerm = analysis.people.minFaceQuality.map { min(group, $0) } ?? group
            numerator += peopleTerm * configuration.humanImportanceWeight
            denominator += configuration.humanImportanceWeight
        }
        var compositionScores: [Double] = []
        compositionScores.append(contentsOf: analysis.composition.aestheticScore.map { [$0] } ?? [])
        compositionScores.append(contentsOf: analysis.composition.subjectPlacementScore.map { [$0] } ?? [])
        compositionScores.append(contentsOf: analysis.composition.horizonScore.map { [$0] } ?? [])
        compositionScores.append(contentsOf: analysis.composition.visualBalanceScore.map { [$0] } ?? [])
        let composition = compositionScores
        if !composition.isEmpty {
            let mean = composition.reduce(0, +) / Double(composition.count)
            numerator += mean * configuration.representativenessWeight
            denominator += configuration.representativenessWeight
        }
        var score = denominator > 0 ? numerator / denominator : analysis.qualityScore
        if asset.isFavorite {
            score += configuration.favoriteBonus
        }
        if asset.isEdited {
            score += configuration.editedBonus
        }
        score = min(1.0, max(0.0, score))
        let disposition: QualityDisposition
        if score < configuration.hardRejectThreshold {
            disposition = .hardRejected
        } else if score < configuration.lowQualityThreshold {
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
            disposition: disposition,
            reasons: disposition == .usable ? [] : ["lowQuality"]
        )
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
