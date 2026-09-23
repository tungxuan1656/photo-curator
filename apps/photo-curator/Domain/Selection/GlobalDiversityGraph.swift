import Foundation

/// Bounded global novelty/saturation graph over the shortlist (feat-023).
///
/// Pure synchronous Domain: no PhotoKit, Vision, Core ML, file I/O, or async.
/// Members are the exact shortlist the selector consumes, in canonical engine
/// order (chrono + ID — never re-sorted by score). Edges are merged
/// FeaturePrint + Tier-C distances restricted to member pairs only, capped at
/// the router-scale pair bound, in canonical balanced order. Missing or empty
/// merged edges mark `isFallback = true`; bounded unknown pairs are retained
/// with no novelty reward so absent evidence cannot become maximum novelty.
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
    /// True when no measured merged edge survived; unknown-pair sentinels may
    /// still be present for bounded selection.
    let isFallback: Bool
    /// Accounting for bounded graph work. Unknown pairs are intentionally
    /// represented conservatively by a zero-distance edge so the selector
    /// cannot turn absent evidence into maximum novelty; the counters retain
    /// their unknown status for review evidence.
    let truncatedMemberCount: Int
    let knownEdgeCount: Int
    let unknownPairCount: Int
    let truncatedPairCount: Int
    let coveredMemberCount: Int

    init(
        members: [ScoredCandidate], edges: [SimilarityEdge], isFallback: Bool,
        truncatedMemberCount: Int = 0, knownEdgeCount: Int = 0,
        unknownPairCount: Int = 0, truncatedPairCount: Int = 0,
        coveredMemberCount: Int = 0
    ) {
        self.members = members
        self.edges = edges
        self.isFallback = isFallback
        self.truncatedMemberCount = truncatedMemberCount
        self.knownEdgeCount = knownEdgeCount
        self.unknownPairCount = unknownPairCount
        self.truncatedPairCount = truncatedPairCount
        self.coveredMemberCount = coveredMemberCount
    }

    /// Canonical member IDs, in graph order.
    var memberIDs: [AssetID] {
        members.map(\.asset.id)
    }
}

/// Graph construction policy (feat-023): non-overlapping member scope, bounded
/// pairs, deterministic fallback. Same shortlist + merged edges always give the
/// same graph; member order is never re-sorted and pair coverage is balanced
/// before the cap is applied.
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
        let members = Array(shortlist.prefix(maxGraphMembers))
        let truncatedMemberCount = max(0, shortlist.count - members.count)
        guard members.count >= 2, !mergedEdges.isEmpty else {
            let pairCount = members.count * max(0, members.count - 1) / 2
            let selectedKeys = balancedPairKeys(
                memberIDs: members.map(\.asset.id), limit: min(maxGraphPairs, pairCount)
            )
            let unknownEdges = selectedKeys.map {
                SimilarityEdge(first: $0.first, second: $0.second, distance: 0)
            }
            return GlobalDiversityGraph(
                members: members,
                edges: unknownEdges,
                isFallback: true,
                truncatedMemberCount: truncatedMemberCount,
                knownEdgeCount: 0,
                unknownPairCount: unknownEdges.count,
                truncatedPairCount: max(0, pairCount - unknownEdges.count),
                coveredMemberCount: coveredMemberCount(memberIDs: members.map(\.asset.id), keys: selectedKeys)
            )
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
        let pairCount = members.count * max(0, members.count - 1) / 2
        let selectedKeys = balancedPairKeys(
            memberIDs: members.map(\.asset.id), limit: min(maxGraphPairs, pairCount)
        )
        let selectedKnownCount = selectedKeys.reduce(into: 0) { count, key in
            if best[key] != nil {
                count += 1
            }
        }
        let edges: [SimilarityEdge] = selectedKeys.map { key in
            // The zero sentinel is deliberately conservative: unknown visual
            // evidence grants no novelty reward. It is accounted separately
            // and is never presented as a measured FeaturePrint distance.
            let distance = best[key] ?? 0.0
            return SimilarityEdge(first: key.first, second: key.second, distance: distance)
        }
        return GlobalDiversityGraph(
            members: members,
            edges: edges,
            isFallback: selectedKnownCount == 0,
            truncatedMemberCount: truncatedMemberCount,
            knownEdgeCount: selectedKnownCount,
            unknownPairCount: edges.count - selectedKnownCount,
            truncatedPairCount: max(0, pairCount - edges.count),
            coveredMemberCount: coveredMemberCount(memberIDs: members.map(\.asset.id), keys: selectedKeys)
        )
    }

    private static func balancedPairKeys(memberIDs: [AssetID], limit: Int) -> [GraphPairKey] {
        let ids = memberIDs.sorted { $0.rawValue < $1.rawValue }
        guard ids.count >= 2, limit > 0 else { return [] }
        var output: [GraphPairKey] = []
        output.reserveCapacity(limit)
        var seen = Set<GraphPairKey>()
        var offset = 1
        while output.count < limit, offset < ids.count {
            for index in ids.indices.dropLast(offset) {
                guard output.count < limit else { break }
                let key = GraphPairKey(ids[index], ids[index + offset])
                if seen.insert(key).inserted {
                    output.append(key)
                }
            }
            offset += 1
        }
        return output
    }

    private static func coveredMemberCount(memberIDs: [AssetID], keys: [GraphPairKey]) -> Int {
        let covered = keys.reduce(into: Set<AssetID>()) { result, key in
            result.insert(key.first)
            result.insert(key.second)
        }
        return memberIDs.filter(covered.contains).count
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
