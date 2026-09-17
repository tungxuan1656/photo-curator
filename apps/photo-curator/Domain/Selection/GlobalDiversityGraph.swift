import Foundation

/// Bounded global novelty/saturation graph over the shortlist (feat-023).
///
/// Pure synchronous Domain: no PhotoKit, Vision, Core ML, file I/O, or async.
/// Members are the exact shortlist the selector consumes, in canonical engine
/// order (chrono + ID — never re-sorted by score). Edges are merged
/// FeaturePrint + Tier-C distances restricted to member pairs only, capped at
/// the router-scale pair bound, in canonical lexicographic order. Missing or
/// empty merged edges mark `isFallback = true` and emit no distances, so the
/// selector runs the exact pre-feat-023 FeaturePrint path (byte-identical to
/// `engineVersion 2` on the same shortlist).
///
/// Operating window: 150-250 members (curation-intelligence Sec 11). The 250
/// ceiling is enforced upstream by `QualityScorer.shortlist`; the 150 floor is
/// informational only — this graph still builds over all members below 150 and
/// never pads with duplicates, low-quality, or out-of-shortlist assets
/// (selection-rules Sec 14 forbids inventing candidates). No per-category quota
/// exists here or anywhere in feat-023 (selection-rules Sec 13).
struct GlobalDiversityGraph: Sendable {
    /// Shortlist members in canonical engine order.
    let members: [ScoredCandidate]
    /// Capped merged distances, member pairs only, canonical order.
    let edges: [SimilarityEdge]
    /// True when no merged edges exist: selector runs the fallback path exactly.
    let isFallback: Bool

    /// Canonical member IDs, in graph order.
    var memberIDs: [AssetID] {
        members.map(\.asset.id)
    }
}

/// Graph construction policy (feat-023): non-overlapping member scope, bounded
/// pairs, deterministic fallback. Same shortlist + merged edges always give the
/// same graph; member order is never re-sorted here.
enum GlobalDiversityGraphBuilder {
    /// Graph operating window (policy constants, not config keys — the
    /// selection-rules Sec 17 small-knob rule). The ceiling matches
    /// `TierCRoutingPolicy.maxShortlistForTierC`; the floor is the
    /// curation-intelligence Sec 11 operating-range label.
    static let minGraphMembers = 150
    static let maxGraphMembers = TierCRoutingPolicy.maxShortlistForTierC
    static let maxGraphPairs = TierCRoutingPolicy.maxTierCPairs

    static func build(
        shortlist: [ScoredCandidate],
        mergedEdges: [SimilarityEdge]
    ) -> GlobalDiversityGraph {
        // Members pass through in engine order (already canonical chrono + ID
        // from SelectionEngine). Never re-sort: order stability is the
        // determinism contract with DiversitySelector.
        let members = shortlist
        guard members.count >= 2, !mergedEdges.isEmpty else {
            return GlobalDiversityGraph(members: members, edges: [], isFallback: true)
        }
        let memberSet = Set(members.map(\.asset.id))
        var best: [GraphPairKey: Double] = [:]
        for edge in mergedEdges {
            guard memberSet.contains(edge.first), memberSet.contains(edge.second) else {
                continue
            }
            let key = GraphPairKey(edge.first, edge.second)
            if let current = best[key] {
                if edge.distance < current {
                    best[key] = edge.distance
                }
            } else {
                best[key] = edge.distance
            }
        }
        let orderedKeys = best.keys.sorted {
            if $0.first.rawValue != $1.first.rawValue {
                return $0.first.rawValue < $1.first.rawValue
            }
            return $0.second.rawValue < $1.second.rawValue
        }
        var edges: [SimilarityEdge] = []
        edges.reserveCapacity(min(maxGraphPairs, orderedKeys.count))
        for key in orderedKeys.prefix(maxGraphPairs) {
            edges.append(SimilarityEdge(first: key.first, second: key.second, distance: best[key]!))
        }
        return GlobalDiversityGraph(
            members: members, edges: edges, isFallback: edges.isEmpty
        )
    }
}

/// Order-independent pair key for the graph edge table. Smaller raw value first.
private struct GraphPairKey: Hashable {
    let first: AssetID
    let second: AssetID

    init(_ left: AssetID, _ right: AssetID) {
        if left.rawValue <= right.rawValue {
            first = left
            second = right
        } else {
            first = right
            second = left
        }
    }
}
