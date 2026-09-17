import Foundation

/// Windowed variant-aware near-duplicate clustering over transient Vision distances.
///
/// Pure synchronous Domain: no PhotoKit, Vision types, file I/O, or async.
/// Candidate pairs come from `candidates(for:configuration:)`; raw edges
/// below `nearDuplicateSimilarityThreshold` propose merges closest-first, and
/// each proposal joins only when every already-grouped member stays pairwise
/// compatible — semantic variation resists transitive chain collapse
/// (feat-021). Each component of two or more assets becomes one
/// `.nearDuplicate` cluster with a context-aware winner and up to two
/// alternatives. Assets without analysis or without edges pass through as
/// singletons, never rejections. Missing evidence degrades to the legacy
/// union-find plus legacy rank exactly.
struct DuplicateResolution: Sendable {
    let clusters: [PhotoCluster]
    let representativeIDs: [AssetID]
    let alternativesByCluster: [ClusterID: [AssetID]]
}

struct DuplicateResolver: Sendable {
    func candidates(for assets: [PhotoAsset], configuration: SelectionConfiguration) -> [SimilarityCandidate] {
        let indexed = Dictionary(uniqueKeysWithValues: assets.enumerated().map { ($1.id, $0) })
        let ordered = canonicalOrder(assets)
        var out: [SimilarityCandidate] = []
        for indexI in ordered.indices {
            for indexJ in ordered.indices.dropFirst(indexI + 1) {
                let left = ordered[indexI]
                let right = ordered[indexJ]
                let window = configuration.duplicateTimeWindow
                // Dated-dated pairs are monotonic in canonical order: an
                // out-of-window gap only grows for later J, so break. Missing
                // dates use frozen-index adjacency, which is non-monotonic in
                // loop order, so a miss must continue to later genuinely
                // adjacent pairs instead of hiding them.
                if left.creationDate != nil, right.creationDate != nil {
                    guard withinWindow(left, right, indexByID: indexed, window: window) else { break }
                    out.append(SimilarityCandidate(first: left.id, second: right.id))
                } else {
                    if withinWindow(left, right, indexByID: indexed, window: window) {
                        out.append(SimilarityCandidate(first: left.id, second: right.id))
                    }
                    continue
                }
            }
        }
        return out
    }

    func resolve(
        assets: [PhotoAsset],
        analyses: [AssetID: PhotoAnalysis],
        edges: [SimilarityEdge],
        configuration: SelectionConfiguration
    ) -> DuplicateResolution {
        let ordered = canonicalOrder(assets).filter { analyses[$0.id] != nil }
        var disjoint = DisjointGroups(members: ordered.map(\.id))
        var gate = VariantMergeGate(
            assets: Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) }),
            analyses: analyses
        )
        let threshold = configuration.nearDuplicateSimilarityThreshold
        for edge in qualifyingEdges(edges, threshold: threshold) {
            disjoint.union(edge.first, edge.second) { gate.compatible($0, $1) }
        }
        return assemble(
            ordered: ordered, disjoint: &disjoint, analyses: analyses,
            edges: edges, configuration: configuration
        )
    }

    /// Closest-first canonical edge order: the merge outcome never depends on
    /// caller edge order, and the strongest visual evidence groups first.
    private func qualifyingEdges(_ edges: [SimilarityEdge], threshold: Double) -> [SimilarityEdge] {
        edges.filter { $0.distance < threshold }.sorted {
            if $0.distance != $1.distance {
                return $0.distance < $1.distance
            }
            let left = MemberPair($0.first, $0.second)
            let right = MemberPair($1.first, $1.second)
            if left.first != right.first {
                return left.first.rawValue < right.first.rawValue
            }
            return left.second.rawValue < right.second.rawValue
        }
    }

    private func assemble(
        ordered: [PhotoAsset], disjoint: inout DisjointGroups, analyses: [AssetID: PhotoAnalysis],
        edges: [SimilarityEdge], configuration: SelectionConfiguration
    ) -> DuplicateResolution {
        var groupsByRoot: [AssetID: [PhotoAsset]] = [:]
        for asset in ordered {
            groupsByRoot[disjoint.root(of: asset.id), default: []].append(asset)
        }
        var clusters: [PhotoCluster] = []
        var representatives: [AssetID] = []
        var alternatives: [ClusterID: [AssetID]] = [:]
        let scorer = QualityScorer()
        let sortedGroups = groupsByRoot.values.sorted { ($0.first?.id.rawValue ?? "") < ($1.first?.id.rawValue ?? "") }
        for group in sortedGroups {
            guard group.count > 1 else {
                representatives.append(group[0].id)
                continue
            }
            let ranked = rank(group, analyses: analyses, scorer: scorer, configuration: configuration)
            let memberIDs = group.map(\.id).sorted { $0.rawValue < $1.rawValue }
            let id = ClusterID(rawValue: StableSelectionID.uuid(kind: "cluster", members: memberIDs))
            let mean = meanDistance(members: Set(memberIDs), edges: edges)
            clusters.append(PhotoCluster(
                id: id,
                type: .nearDuplicate,
                assetIDs: memberIDs,
                representativeAssetID: ranked[0].id,
                similarityScore: 1 / (1 + mean)
            ))
            representatives.append(ranked[0].id)
            alternatives[id] = Array(ranked.dropFirst().prefix(2).map(\.id))
        }
        return DuplicateResolution(
            clusters: clusters,
            representativeIDs: representatives,
            alternativesByCluster: alternatives
        )
    }

    /// Variant gate (feat-021): two members stay mergeable only when no
    /// persisted fact positively distinguishes them. Every veto needs evidence
    /// on BOTH sides — unknown scenes, nil facts, unknown media subtypes, and
    /// matching values stay compatible — so sparse facts never split legacy
    /// clusters. Categorical equality only: no threshold, no tuning knob.
    /// Orientation is deliberately not a veto (selection-rules §12:
    /// orientation change alone never justifies both).
    static func variantCompatible(
        leftAsset: PhotoAsset?, leftAnalysis: PhotoAnalysis?,
        rightAsset: PhotoAsset?, rightAnalysis: PhotoAnalysis?
    ) -> Bool {
        guard let leftAsset = leftAsset, let rightAsset = rightAsset,
              let leftAnalysis = leftAnalysis, let rightAnalysis = rightAnalysis
        else {
            // Unreachable in `resolve` (members always carry analyses); defer
            // to the legacy-compatible merge so missing facts never split.
            return true
        }
        // People presence: a portrait never merges with a faceless frame
        // (wide beach vs traveler portrait; person+landmark vs landmark-only).
        if (leftAnalysis.people.faceCount > 0) != (rightAnalysis.people.faceCount > 0) {
            return false
        }
        // Single vs group: different subject state, never a retake. Differing
        // group counts stay mergeable (detection-jitter safe).
        if (leftAnalysis.people.faceCount >= 2) != (rightAnalysis.people.faceCount >= 2) {
            return false
        }
        // Framing class: panorama and screenshot are categorical captures, but
        // only when BOTH sides are known. `.unknown` (unmodeled PhotoKit
        // flags) on either side defers to the legacy-compatible merge.
        if framingClassDiffers(leftAsset.mediaSubtype, rightAsset.mediaSubtype) {
            return false
        }
        // Document: an identified document never merges with a scene photo.
        // Either side nil defers to legacy, in both argument orders.
        if documentDiffers(leftAnalysis.content.isDocument, rightAnalysis.content.isDocument) {
            return false
        }
        let leftScene = leftAnalysis.content.sceneType
        let rightScene = rightAnalysis.content.sceneType
        if leftScene != .unknown, rightScene != .unknown, leftScene != rightScene {
            return false
        }
        return true
    }

    /// Bilateral framing-class veto: panorama or screenshot on one side splits
    /// only when the other side is a known different subtype. `.unknown` on
    /// either side defers to the legacy-compatible merge.
    private static func framingClassDiffers(_ left: PhotoMediaSubtype, _ right: PhotoMediaSubtype) -> Bool {
        guard left != right, left != .unknown, right != .unknown else { return false }
        return left == .panorama || right == .panorama || left == .screenshot || right == .screenshot
    }

    /// Bilateral document veto: true-vs-false splits only when Tier-B produced
    /// both facts. Either side nil defers to legacy, in both argument orders.
    private static func documentDiffers(_ left: Bool?, _ right: Bool?) -> Bool {
        guard let left, let right else { return false }
        return left != right
    }

    /// Deterministic chronological order: capture date ascending with missing
    /// dates first (matching SelectionEngine, FinalAlbumBuilder, and the frozen
    /// source snapshot); equal dates break by stable asset ID per
    /// selection-rules §15 so output never depends on caller input order.
    private func canonicalOrder(_ assets: [PhotoAsset]) -> [PhotoAsset] {
        assets.sorted {
            let leftDate = $0.creationDate ?? .distantPast
            let rightDate = $1.creationDate ?? .distantPast
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return $0.id.rawValue < $1.id.rawValue
        }
    }

    /// Time-adjacent pairs only. Missing dates never block grouping: fall back
    /// to frozen-index adjacency instead of guessing a time gap.
    private func withinWindow(
        _ left: PhotoAsset, _ right: PhotoAsset, indexByID: [AssetID: Int], window: TimeInterval
    ) -> Bool {
        switch (left.creationDate, right.creationDate) {
        case let (leftDate?, rightDate?):
            return abs(leftDate.timeIntervalSince(rightDate)) <= window
        default:
            guard let leftIndex = indexByID[left.id], let rightIndex = indexByID[right.id] else { return false }
            return abs(leftIndex - rightIndex) == 1
        }
    }

    /// Context-aware winner order: the shared quality rank over available
    /// signals through configured weights (technical + subject-specific +
    /// composition + user intent), never pairwise similarity. Missing
    /// evidence reduces to the legacy quality-then-edit-then-favorite order
    /// exactly: with no people/composition facts and no bonuses, the shared
    /// score equals `qualityScore` and every tie falls through identically.
    private func rank(
        _ group: [PhotoAsset], analyses: [AssetID: PhotoAnalysis],
        scorer: QualityScorer, configuration: SelectionConfiguration
    ) -> [PhotoAsset] {
        let scored = group.map { asset -> (PhotoAsset, Double) in
            let value = analyses[asset.id].map {
                representativeScore(asset: asset, analysis: $0, scorer: scorer, configuration: configuration)
            }
            return (asset, value ?? -1)
        }
        return scored.sorted {
            if $0.1 != $1.1 {
                return $0.1 > $1.1
            }
            let left = $0.0
            let right = $1.0
            if left.isEdited != right.isEdited {
                return left.isEdited
            }
            if left.isFavorite != right.isFavorite {
                return left.isFavorite
            }
            let leftArea = left.pixelWidth * left.pixelHeight
            let rightArea = right.pixelWidth * right.pixelHeight
            if leftArea != rightArea {
                return leftArea > rightArea
            }
            return left.id.rawValue < right.id.rawValue
        }.map { $0.0 }
    }

    /// Context-aware representative value: the shared `QualityScorer` rank
    /// for this member. `clusterID` stays nil and `momentID` is a fixed
    /// namespace constant — score math never reads the moment, and moments do
    /// not exist yet at dup time — so only configured quality weights decide.
    private func representativeScore(
        asset: PhotoAsset, analysis: PhotoAnalysis,
        scorer: QualityScorer, configuration: SelectionConfiguration
    ) -> Double {
        let scoringMoment = MomentID(rawValue: StableSelectionID.uuid(
            kind: "feat021-representative", members: [asset.id]
        ))
        return scorer.score(
            asset: asset, analysis: analysis, clusterID: nil,
            momentID: scoringMoment, configuration: configuration
        ).score
    }

    /// Display-only mean of direct intra-component edges. Never feeds
    /// threshold decisions, which use raw edge distances.
    private func meanDistance(members: Set<AssetID>, edges: [SimilarityEdge]) -> Double {
        let distances = edges.filter { members.contains($0.first) && members.contains($0.second) }.map(\.distance)
        guard !distances.isEmpty else { return 0 }
        return distances.reduce(0, +) / Double(distances.count)
    }
}

/// Lazy memoized variant gate: pair compatibility is checked only when a
/// merge proposes it, so fully distinct libraries pay nothing. Fully
/// deterministic: same pairs always give the same verdicts.
private struct VariantMergeGate {
    let assets: [AssetID: PhotoAsset]
    let analyses: [AssetID: PhotoAnalysis]
    var cache: [MemberPair: Bool] = [:]

    mutating func compatible(_ left: AssetID, _ right: AssetID) -> Bool {
        let pair = MemberPair(left, right)
        if let cached = cache[pair] {
            return cached
        }
        let result = DuplicateResolver.variantCompatible(
            leftAsset: assets[left], leftAnalysis: analyses[left],
            rightAsset: assets[right], rightAnalysis: analyses[right]
        )
        cache[pair] = result
        return result
    }
}

/// Order-independent member-pair key for the lazy compatibility cache and the
/// closest-first edge order. Smaller raw value always comes first.
private struct MemberPair: Hashable {
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

/// Minimal union-find over asset IDs. Roots are deterministic: the smaller
/// raw value always wins, with path compression on lookup. Union carries a
/// pairwise gate: every member across both components must satisfy
/// `compatible`, so incompatible endpoints never merge behind an intermediate
/// member (feat-021 coherence); a vetoed proposal leaves both components
/// untouched and later edges still process normally.
private struct DisjointGroups {
    private var parent: [AssetID: AssetID]
    private var members: [AssetID: [AssetID]]

    init(members ids: [AssetID]) {
        parent = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) })
        members = Dictionary(uniqueKeysWithValues: ids.map { ($0, [$0]) })
    }

    mutating func root(of id: AssetID) -> AssetID {
        var root = id
        while parent[root] != root {
            root = parent[root]!
        }
        var node = id
        while parent[node] != root {
            let next = parent[node]!
            parent[node] = root
            node = next
        }
        return root
    }

    mutating func union(_ left: AssetID, _ right: AssetID, whenCompatible compatible: (AssetID, AssetID) -> Bool) {
        let leftRoot = root(of: left)
        let rightRoot = root(of: right)
        guard leftRoot != rightRoot else { return }
        let leftMembers = members[leftRoot] ?? [leftRoot]
        let rightMembers = members[rightRoot] ?? [rightRoot]
        for leftMember in leftMembers {
            for rightMember in rightMembers {
                guard compatible(leftMember, rightMember) else { return }
            }
        }
        if leftRoot.rawValue < rightRoot.rawValue {
            parent[rightRoot] = leftRoot
            members[leftRoot] = leftMembers + rightMembers
            members[rightRoot] = nil
        } else {
            parent[leftRoot] = rightRoot
            members[rightRoot] = rightMembers + leftMembers
            members[leftRoot] = nil
        }
    }
}
