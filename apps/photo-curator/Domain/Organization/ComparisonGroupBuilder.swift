import Foundation

enum ComparisonEvidenceKind: String, Codable, Sendable {
    case validatedVisualSimilarity
}

/// A visual edge has already passed image-sensitive validation. The builder
/// never treats dates, labels, or candidate membership as visual evidence.
struct ComparisonValidatedVisualEdge: Codable, Sendable {
    let first: AssetID
    let second: AssetID
    let relation: ComparisonGroupRelation
    let path: ComparisonCandidatePath
    let visualDistance: Double
    let evidenceReference: String?

    init(
        first: AssetID,
        second: AssetID,
        relation: ComparisonGroupRelation,
        path: ComparisonCandidatePath,
        visualDistance: Double,
        evidenceReference: String? = nil
    ) {
        if first.rawValue < second.rawValue {
            self.first = first
            self.second = second
        } else {
            self.first = second
            self.second = first
        }
        self.relation = relation
        self.path = path
        self.visualDistance = visualDistance
        self.evidenceReference = evidenceReference
    }

    var isUsable: Bool {
        first != second
            && visualDistance.isFinite
            && visualDistance >= 0
            && ((relation == .retake && path == .chronologicalNeighbors)
                || (relation == .nearCopy && path == .inputHashBucket))
    }
}

struct ComparisonGroupEvidenceReason: Codable, Sendable {
    let evidence: ComparisonEvidenceKind
    let relation: ComparisonGroupRelation
    let path: ComparisonCandidatePath
    let validatedEdgeCount: Int
    let maximumVisualDistance: Double
    let evidenceReferences: [String]

    var title: String {
        switch relation {
        case .retake:
            return "Visually similar retake"
        case .nearCopy:
            return "Visually similar near-copy"
        }
    }
}

struct ComparisonGroupID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}

struct ComparisonGroup: Identifiable, Codable, Sendable {
    let id: ComparisonGroupID
    let assetIDs: [AssetID]
    let relation: ComparisonGroupRelation
    let reason: ComparisonGroupEvidenceReason
    let representativeAssetID: AssetID?
    let groupingRevision: String
}

struct ComparisonGroupBuildResult: Sendable {
    let groups: [ComparisonGroup]
    let standaloneAssetIDs: [AssetID]
}

/// Builds only coherent groups from validated edges. It uses complete-link
/// merging: every pair across two proposed clusters must have a validated edge
/// of the same relation before the clusters can merge.
struct ComparisonGroupBuilder: Sendable {
    let groupingRevision: String

    init(groupingRevision: String = "comparison-groups-v1") {
        self.groupingRevision = groupingRevision
    }

    func build(
        assetIDs: [AssetID],
        validatedEdges: [ComparisonValidatedVisualEdge]
    ) -> ComparisonGroupBuildResult {
        let orderedAssetIDs = Array(Set(assetIDs)).sorted { $0.rawValue < $1.rawValue }
        var groups: [ComparisonGroup] = []
        var groupedAssetIDs: Set<AssetID> = []

        for relation in [ComparisonGroupRelation.retake, .nearCopy] {
            let edges = normalizedEdges(
                validatedEdges,
                relation: relation,
                allowedAssetIDs: Set(orderedAssetIDs)
            )
            guard !edges.isEmpty else { continue }
            let relationGroups = buildGroups(for: relation, edges: edges)
            groups.append(contentsOf: relationGroups)
            for group in relationGroups {
                groupedAssetIDs.formUnion(group.assetIDs)
            }
        }

        groups.sort(by: groupOrder)
        let standaloneAssetIDs = orderedAssetIDs.filter { !groupedAssetIDs.contains($0) }
        return ComparisonGroupBuildResult(groups: groups, standaloneAssetIDs: standaloneAssetIDs)
    }

    private func normalizedEdges(
        _ edges: [ComparisonValidatedVisualEdge],
        relation: ComparisonGroupRelation,
        allowedAssetIDs: Set<AssetID>
    ) -> [ComparisonValidatedVisualEdge] {
        var bestByPair: [ComparisonAssetPair: ComparisonValidatedVisualEdge] = [:]
        for edge in edges {
            guard edge.relation == relation,
                  edge.isUsable,
                  allowedAssetIDs.contains(edge.first),
                  allowedAssetIDs.contains(edge.second) else { continue }
            let pair = ComparisonAssetPair(first: edge.first, second: edge.second)
            guard let existing = bestByPair[pair] else {
                bestByPair[pair] = edge
                continue
            }
            if edgeOrder(edge, isBefore: existing) {
                bestByPair[pair] = edge
            }
        }
        return bestByPair.values.sorted(by: edgeOrder)
    }

    private func buildGroups(
        for relation: ComparisonGroupRelation,
        edges: [ComparisonValidatedVisualEdge]
    ) -> [ComparisonGroup] {
        var clusters: [[AssetID]] = []
        var edgeByPair: [ComparisonAssetPair: ComparisonValidatedVisualEdge] = [:]
        for edge in edges {
            edgeByPair[ComparisonAssetPair(first: edge.first, second: edge.second)] = edge
            if !clusters.contains(where: { $0.contains(edge.first) }) {
                clusters.append([edge.first])
            }
            if !clusters.contains(where: { $0.contains(edge.second) }) {
                clusters.append([edge.second])
            }
        }
        clusters.sort(by: memberOrder)

        for edge in edges {
            guard let leftIndex = clusters.firstIndex(where: { $0.contains(edge.first) }),
                  let rightIndex = clusters.firstIndex(where: { $0.contains(edge.second) }),
                  leftIndex != rightIndex else { continue }

            let lowerIndex = min(leftIndex, rightIndex)
            let upperIndex = max(leftIndex, rightIndex)
            let left = clusters[lowerIndex]
            let right = clusters[upperIndex]
            guard completeLinkExists(between: left, and: right, edgeByPair: edgeByPair) else { continue }

            clusters[lowerIndex] = (left + right).sorted(by: assetOrder)
            clusters.remove(at: upperIndex)
        }

        return clusters.filter { $0.count > 1 }.map { members in
            let memberEdges = edges.filter { edge in
                members.contains(edge.first) && members.contains(edge.second)
            }
            let references = Set(memberEdges.compactMap(\.evidenceReference)).sorted()
            let reason = ComparisonGroupEvidenceReason(
                evidence: .validatedVisualSimilarity,
                relation: relation,
                path: relation == .retake ? .chronologicalNeighbors : .inputHashBucket,
                validatedEdgeCount: memberEdges.count,
                maximumVisualDistance: memberEdges.map(\.visualDistance).max() ?? 0,
                evidenceReferences: references
            )
            return ComparisonGroup(
                id: ComparisonGroupID(rawValue: stableID(relation: relation, members: members)),
                assetIDs: members,
                relation: relation,
                reason: reason,
                representativeAssetID: members.first,
                groupingRevision: groupingRevision
            )
        }
    }

    private func completeLinkExists(
        between left: [AssetID],
        and right: [AssetID],
        edgeByPair: [ComparisonAssetPair: ComparisonValidatedVisualEdge]
    ) -> Bool {
        for first in left {
            for second in right {
                guard edgeByPair[ComparisonAssetPair(first: first, second: second)] != nil else {
                    return false
                }
            }
        }
        return true
    }

    private func stableID(relation: ComparisonGroupRelation, members: [AssetID]) -> String {
        let encodedMembers = members.map { "\($0.rawValue.count):\($0.rawValue)" }.joined()
        return "comparison.\(groupingRevision).\(relation.rawValue).\(encodedMembers)"
    }

    private func edgeOrder(
        _ left: ComparisonValidatedVisualEdge,
        isBefore right: ComparisonValidatedVisualEdge
    ) -> Bool {
        if left.first.rawValue != right.first.rawValue {
            return left.first.rawValue < right.first.rawValue
        }
        if left.second.rawValue != right.second.rawValue {
            return left.second.rawValue < right.second.rawValue
        }
        if left.visualDistance != right.visualDistance {
            return left.visualDistance < right.visualDistance
        }
        return (left.evidenceReference ?? "") < (right.evidenceReference ?? "")
    }

    private func groupOrder(_ left: ComparisonGroup, _ right: ComparisonGroup) -> Bool {
        if left.relation.rawValue != right.relation.rawValue {
            return left.relation.rawValue < right.relation.rawValue
        }
        return memberOrder(left.assetIDs, right.assetIDs)
    }

    private func memberOrder(_ left: [AssetID], _ right: [AssetID]) -> Bool {
        for (leftID, rightID) in zip(left, right) where leftID != rightID {
            return leftID.rawValue < rightID.rawValue
        }
        return left.count < right.count
    }

    private func assetOrder(_ left: AssetID, _ right: AssetID) -> Bool {
        left.rawValue < right.rawValue
    }
}

private struct ComparisonAssetPair: Hashable {
    let first: AssetID
    let second: AssetID

    init(first: AssetID, second: AssetID) {
        if first.rawValue < second.rawValue {
            self.first = first
            self.second = second
        } else {
            self.first = second
            self.second = first
        }
    }
}
