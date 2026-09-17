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
/// the engine consumes only explicitly supplied `tierCEdges`. The default
/// (`[]`) is the complete native FeaturePrint fallback, identical to the
/// pre-feat-024 path. Tier-C edges feed diversity novelty only — never cluster
/// membership (feat-021 frozen) or moment boundaries (feat-022 frozen).
enum TierCRoutingPolicy {
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
/// so model work can never silently cover every photo. Output is canonical
/// (unordered pairs, lexicographic) and capped, so the same shortlist always
/// routes the same pairs.
enum VisualEmbeddingRouter {
    static func tierCCandidates(
        for assets: [PhotoAsset], cap: Int = TierCRoutingPolicy.maxTierCPairs
    ) -> [SimilarityCandidate] {
        let ordered = assets.map(\.id).sorted { $0.rawValue < $1.rawValue }
        guard ordered.count >= 2, ordered.count <= TierCRoutingPolicy.maxShortlistForTierC else {
            return []
        }
        let limit = max(0, min(cap, TierCRoutingPolicy.maxTierCPairs))
        var out: [SimilarityCandidate] = []
        out.reserveCapacity(min(limit, ordered.count * (ordered.count - 1) / 2))
        for indexI in ordered.indices {
            for indexJ in ordered.indices.dropFirst(indexI + 1) {
                guard out.count < limit else {
                    return out
                }
                out.append(SimilarityCandidate(first: ordered[indexI], second: ordered[indexJ]))
            }
        }
        return out
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

/// Fallback provider: produces no Tier-C edges, so the engine runs the
/// complete native FeaturePrint path exactly. Mirrors the default pipeline
/// (which supplies no `tierCEdges`) and anchors the fallback proof arm.
struct NoopVisualEmbeddingProvider: VisualEmbeddingProvider, Sendable {
    func tierCDistances(
        for _: [SimilarityCandidate], analyses _: [AssetID: PhotoAnalysis]
    ) -> [SimilarityEdge] {
        []
    }
}

/// Tier-C / FeaturePrint edge merge (feat-024).
///
/// Union by unordered pair keeping the smaller distance: either signal may
/// flag redundancy, so Tier-C can only add diversity pressure, never hide a
/// FeaturePrint-similar pair. Deterministic canonical order. The empty-Tier-C
/// fast path returns the FeaturePrint edges untouched, so the fallback is
/// exactly the pre-feat-024 path.
enum VisualEmbeddingEdges {
    static func merged(
        featurePrintEdges: [SimilarityEdge], tierCEdges: [SimilarityEdge]
    ) -> [SimilarityEdge] {
        guard !tierCEdges.isEmpty else {
            return featurePrintEdges
        }
        var best: [TierCPairKey: SimilarityEdge] = [:]
        for edge in featurePrintEdges + tierCEdges {
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
