import Foundation

/// Windowed near-duplicate clustering over transient Vision distances.
///
/// Pure synchronous Domain: no PhotoKit, Vision types, file I/O, or async.
/// Candidate pairs come from `candidates(for:configuration:)`; raw edges
/// below `nearDuplicateSimilarityThreshold` merge via union-find; each
/// component of two or more assets becomes one `.nearDuplicate` cluster
/// with a local winner and up to two alternatives. Assets without analysis
/// or without edges pass through as singletons, never rejections.
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
        let threshold = configuration.nearDuplicateSimilarityThreshold
        for edge in edges where edge.distance < threshold {
            disjoint.union(edge.first, edge.second)
        }
        var groupsByRoot: [AssetID: [PhotoAsset]] = [:]
        for asset in ordered {
            groupsByRoot[disjoint.root(of: asset.id), default: []].append(asset)
        }
        var clusters: [PhotoCluster] = []
        var representatives: [AssetID] = []
        var alternatives: [ClusterID: [AssetID]] = [:]
        let sortedGroups = groupsByRoot.values.sorted { ($0.first?.id.rawValue ?? "") < ($1.first?.id.rawValue ?? "") }
        for group in sortedGroups {
            guard group.count > 1 else {
                representatives.append(group[0].id)
                continue
            }
            let ranked = rank(group, analyses: analyses)
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

    /// Local winner order: quality first, then edited-twin preference, favorite,
    /// pixel area, stable ID.
    private func rank(_ group: [PhotoAsset], analyses: [AssetID: PhotoAnalysis]) -> [PhotoAsset] {
        group.sorted {
            let leftScore = analyses[$0.id]?.qualityScore ?? -1
            let rightScore = analyses[$1.id]?.qualityScore ?? -1
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            if $0.isEdited != $1.isEdited {
                return $0.isEdited
            }
            if $0.isFavorite != $1.isFavorite {
                return $0.isFavorite
            }
            let leftArea = $0.pixelWidth * $0.pixelHeight
            let rightArea = $1.pixelWidth * $1.pixelHeight
            if leftArea != rightArea {
                return leftArea > rightArea
            }
            return $0.id.rawValue < $1.id.rawValue
        }
    }

    /// Display-only mean of direct intra-component edges. Never feeds
    /// threshold decisions, which use raw edge distances.
    private func meanDistance(members: Set<AssetID>, edges: [SimilarityEdge]) -> Double {
        let distances = edges.filter { members.contains($0.first) && members.contains($0.second) }.map(\.distance)
        guard !distances.isEmpty else { return 0 }
        return distances.reduce(0, +) / Double(distances.count)
    }
}

/// Minimal union-find over asset IDs. Roots are deterministic: the smaller
/// raw value always wins, with path compression on lookup.
private struct DisjointGroups {
    private var parent: [AssetID: AssetID]

    init(members: [AssetID]) {
        parent = Dictionary(uniqueKeysWithValues: members.map { ($0, $0) })
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

    mutating func union(_ left: AssetID, _ right: AssetID) {
        let leftRoot = root(of: left)
        let rightRoot = root(of: right)
        guard leftRoot != rightRoot else { return }
        if leftRoot.rawValue < rightRoot.rawValue {
            parent[rightRoot] = leftRoot
        } else {
            parent[leftRoot] = rightRoot
        }
    }
}
