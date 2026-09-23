import Foundation

/// Tier-C visual-embedding capability (feat-024).
///
/// Pure synchronous Domain: no PhotoKit, Vision, Core ML, file I/O, or async.
/// The engine depends on this abstraction, never a model-specific type, per
/// the runtime-stack §6 contract.
///
/// The production-selected representation is the native derived embedding: a
/// transient fixed-length vector built from already-persisted `PhotoAnalysis`
/// scalars (no pixels, no boxes, no new request, no weights). Vectors are
/// never persisted and never leave the run; only pairwise distances cross as
/// transient `SimilarityEdge` values. The FastViT headless family stays
/// benchmark-only (not vendored — see `docs/plans/feat-024.md`); no Core ML
/// model ships with this feature.
///
/// Tier-C never runs on every photo: the router accepts shortlist-scale input
/// only (≤ `maxShortlistForTierC` assets, pairs capped at `maxTierCPairs`) and
/// the engine consumes only explicitly supplied `tierCEdges`. Scalar Tier-C
/// novelty is disabled until calibration; FeaturePrint remains the only
/// measured visual signal. Tier-C never affects cluster membership (feat-021
/// frozen) or moment boundaries (feat-022 frozen).
enum TierCRoutingPolicy {
    /// Scalar Tier-C has no calibrated novelty semantics yet. Keep routing and
    /// evidence contracts available, but do not let it change ranking.
    static let scalarNoveltyInfluenceEnabled = false
    /// Shortlist-scale ceiling: larger inputs refuse Tier-C (fallback).
    /// Matches the feat-023 150–250 candidate-graph operating range.
    static let maxShortlistForTierC = 250
    /// Hard cap on Tier-C pairs per run. For 250 candidates all-pairs is
    /// 31,125; only the first `maxTierCPairs` canonical pairs route.
    static let maxTierCPairs = 4000
}

/// Bounded Tier-C pair router (feat-024).
///
/// Selects which shortlist-scale pairs deserve embedding work. The caller MUST
/// pass shortlist members, never the full library; larger inputs return `[]`
/// so model work can never silently cover every photo. Output is canonical,
/// balanced across members, and capped, so the same shortlist always routes
/// the same bounded pairs.
enum VisualEmbeddingRouter {
    struct CandidateSelection: Sendable {
        let pairs: [SimilarityCandidate]
        let candidateCount: Int
        let pairLimit: Int
        let truncatedPairCount: Int
        let coveredAssetCount: Int
    }

    static func tierCCandidates(
        for assets: [PhotoAsset], cap: Int = TierCRoutingPolicy.maxTierCPairs
    ) -> [SimilarityCandidate] {
        tierCCandidateSelection(for: assets, cap: cap).pairs
    }

    static func tierCCandidateSelection(
        for assets: [PhotoAsset], cap: Int = TierCRoutingPolicy.maxTierCPairs
    ) -> CandidateSelection {
        let ordered = assets.map(\.id).sorted { $0.rawValue < $1.rawValue }
        guard ordered.count >= 2, ordered.count <= TierCRoutingPolicy.maxShortlistForTierC else {
            let totalPairs = ordered.count * max(0, ordered.count - 1) / 2
            return CandidateSelection(
                pairs: [], candidateCount: ordered.count,
                pairLimit: 0, truncatedPairCount: totalPairs, coveredAssetCount: 0
            )
        }
        let limit = max(0, min(cap, TierCRoutingPolicy.maxTierCPairs))
        var out: [SimilarityCandidate] = []
        out.reserveCapacity(min(limit, ordered.count * (ordered.count - 1) / 2))
        var seen = Set<TierCPairKey>()
        var offset = 1
        while out.count < limit && offset < ordered.count {
            for index in ordered.indices.dropLast(offset) {
                guard out.count < limit else { break }
                let key = TierCPairKey(ordered[index], ordered[index + offset])
                guard seen.insert(key).inserted else { continue }
                out.append(SimilarityCandidate(first: key.first, second: key.second))
            }
            offset += 1
        }
        let covered = out.reduce(into: Set<AssetID>()) { result, pair in
            result.insert(pair.first)
            result.insert(pair.second)
        }
        let totalPairs = ordered.count * (ordered.count - 1) / 2
        return CandidateSelection(
            pairs: out,
            candidateCount: ordered.count,
            pairLimit: limit,
            truncatedPairCount: max(0, totalPairs - out.count),
            coveredAssetCount: covered.count
        )
    }
}

/// Tier-C embedding capability. Same pairs + analyses always give the same
/// edges; missing analysis on either side skips that pair (fallback covers it).
protocol VisualEmbeddingProvider: Sendable {
    func tierCDistances(
        for pairs: [SimilarityCandidate], analyses: [AssetID: PhotoAnalysis]
    ) -> [SimilarityEdge]
}

/// Selected production representation (feat-024): native derived embedding.
///
/// Fixed 8-dim vector from persisted scalars only — sharpness, exposure,
/// resolution, aesthetic (nil → 0.5), horizon (nil → 0.5), visual balance
/// (nil → 0.5), people presence (faceCount capped at 6), text density
/// (textLineCount capped at 10). Distance is the normalized Euclidean distance
/// plus a 0.5 penalty when both scenes are known and differ. Deliberate
/// ceiling: this sees persisted facts only, never texture/detail pixels — a
/// pixel-level model (FastViT) would be needed to distinguish frames the facts
/// call identical (see plan ceilings).
struct NativeDerivedEmbeddingProvider: VisualEmbeddingProvider, Sendable {
    func tierCDistances(
        for pairs: [SimilarityCandidate], analyses: [AssetID: PhotoAnalysis]
    ) -> [SimilarityEdge] {
        guard TierCRoutingPolicy.scalarNoveltyInfluenceEnabled else { return [] }
        var edges: [SimilarityEdge] = []
        edges.reserveCapacity(pairs.count)
        for pair in pairs {
            guard let left = analyses[pair.first], let right = analyses[pair.second] else {
                continue
            }
            edges.append(SimilarityEdge(
                first: pair.first, second: pair.second,
                distance: Self.distance(between: left, and: right)
            ))
        }
        return edges
    }

    static func distance(between left: PhotoAnalysis, and right: PhotoAnalysis) -> Double {
        let leftVector = vector(for: left)
        let rightVector = vector(for: right)
        var sum = 0.0
        for index in leftVector.indices {
            let delta = leftVector[index] - rightVector[index]
            sum += delta * delta
        }
        let euclidean = (sum / Double(leftVector.count)).squareRoot()
        return euclidean + scenePenalty(between: left.content.sceneType, and: right.content.sceneType)
    }

    private static func vector(for analysis: PhotoAnalysis) -> [Double] {
        let people = min(Double(max(0, analysis.people.faceCount)), 6.0) / 6.0
        let text = Double(min(max(0, analysis.content.textLineCount ?? 0), 10)) / 10.0
        var vector = [Double]()
        vector += [analysis.technical.sharpnessScore, analysis.technical.exposureScore]
        vector += [analysis.technical.resolutionScore, analysis.composition.aestheticScore ?? 0.5]
        vector += [analysis.composition.horizonScore ?? 0.5, analysis.composition.visualBalanceScore ?? 0.5]
        vector += [people, text]
        return vector
    }

    private static func scenePenalty(between left: SceneType, and right: SceneType) -> Double {
        guard left != .unknown, right != .unknown, left != right else {
            return 0
        }
        return 0.5
    }
}

/// Fallback provider: produces no Tier-C edges. The graph records missing
/// visual evidence explicitly and applies no novelty reward for it.
struct NoopVisualEmbeddingProvider: VisualEmbeddingProvider, Sendable {
    func tierCDistances(
        for _: [SimilarityCandidate], analyses _: [AssetID: PhotoAnalysis]
    ) -> [SimilarityEdge] {
        []
    }
}

/// FeaturePrint edge normalization (feat-024).
///
/// Tier-C scalar edges are ignored until calibration. FeaturePrint remains a
/// single-provider signal; no cross-provider minimum can manufacture evidence.
/// Deterministic canonical order is retained.
enum VisualEmbeddingEdges {
    static func merged(
        featurePrintEdges: [SimilarityEdge], tierCEdges: [SimilarityEdge]
    ) -> [SimilarityEdge] {
        // Tier-C remains retained as an availability path, but scalar novelty
        // is disabled until calibration. Do not cross-provider-min merge it.
        _ = tierCEdges
        var best: [TierCPairKey: SimilarityEdge] = [:]
        for edge in featurePrintEdges {
            let key = TierCPairKey(edge.first, edge.second)
            if let current = best[key] {
                if edge.distance < current.distance {
                    best[key] = edge
                }
            } else {
                best[key] = edge
            }
        }
        return best.values.sorted {
            if $0.first.rawValue != $1.first.rawValue {
                return $0.first.rawValue < $1.first.rawValue
            }
            if $0.second.rawValue != $1.second.rawValue {
                return $0.second.rawValue < $1.second.rawValue
            }
            return $0.distance < $1.distance
        }
    }
}

/// Order-independent pair key for the Tier-C merge. Smaller raw value first.
private struct TierCPairKey: Hashable {
    let first: AssetID
    let second: AssetID

    init(_ left: AssetID, _ right: AssetID) {
        if left.rawValue < right.rawValue {
            first = left
            second = right
        } else {
            first = right
            second = left
        }
    }
}
