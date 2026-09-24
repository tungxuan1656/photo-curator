import Foundation

/// One positive facet clause. Clauses with different facets are ANDed;
/// labels in one clause are ORed.
nonisolated struct LibraryQueryFacetFilter: Codable, Sendable, Equatable, Hashable {
    let facet: PhotoLabelFacet
    let labelIDs: [PhotoLabelID]
    let personalLabelIDs: [UUID]

    init(
        facet: PhotoLabelFacet,
        labelIDs: [PhotoLabelID] = [],
        personalLabelIDs: [UUID] = []
    ) {
        self.facet = facet
        self.labelIDs = Array(Set(labelIDs)).sorted { $0.rawValue < $1.rawValue }
        self.personalLabelIDs = Array(Set(personalLabelIDs)).sorted { $0.uuidString < $1.uuidString }
    }

    private enum CodingKeys: String, CodingKey {
        case facet
        case labelIDs
        case personalLabelIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            facet: container.decode(PhotoLabelFacet.self, forKey: .facet),
            labelIDs: container.decodeIfPresent([PhotoLabelID].self, forKey: .labelIDs) ?? [],
            personalLabelIDs: container.decodeIfPresent([UUID].self, forKey: .personalLabelIDs) ?? []
        )
    }
}

nonisolated struct LibraryQueryPage: Codable, Sendable, Equatable, Hashable {
    let offset: Int
    let limit: Int

    init(offset: Int = 0, limit: Int = 50) {
        self.offset = max(0, offset)
        self.limit = max(1, limit)
    }
}

/// The query is intentionally limited to admitted positive semantic labels.
/// Date/source scopes and technical scalar labels are not part of this core.
nonisolated struct LibraryQuery: Codable, Sendable, Equatable, Hashable {
    let filters: [LibraryQueryFacetFilter]
    let page: LibraryQueryPage

    init(filters: [LibraryQueryFacetFilter] = [], page: LibraryQueryPage = LibraryQueryPage()) {
        let grouped = Dictionary(grouping: filters, by: \.facet)
        self.filters = grouped.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { facet in
            let labels = grouped[facet, default: []].flatMap(\.labelIDs)
            let personalLabels = grouped[facet, default: []].flatMap(\.personalLabelIDs)
            guard !labels.isEmpty || !personalLabels.isEmpty else { return nil }
            return LibraryQueryFacetFilter(
                facet: facet,
                labelIDs: labels,
                personalLabelIDs: personalLabels
            )
        }
        self.page = page
    }

    var identity: String {
        let clauses = filters.map { filter in
            let semantic = filter.labelIDs.map(\.rawValue).joined(separator: ",")
            let personal = filter.personalLabelIDs.map(\.uuidString).joined(separator: ",")
            return "\(filter.facet.rawValue)=\(semantic)|\(personal)"
        }
        return clauses.joined(separator: "&")
    }

    func filter(for facet: PhotoLabelFacet) -> LibraryQueryFacetFilter? {
        filters.first { $0.facet == facet }
    }
}

nonisolated enum LibraryQueryCoverageState: String, Codable, Sendable, Equatable {
    case complete
    case incomplete
    case unavailable
}

/// Analysis coverage is independent from the number of matching labels.
nonisolated struct LibraryQueryCoverage: Codable, Sendable, Equatable {
    let state: LibraryQueryCoverageState
    let totalAssetCount: Int
    let analyzedAssetCount: Int
    let pendingAssetCount: Int
    let unavailableAssetCount: Int
    let staleAssetCount: Int
    let unknownAssetCount: Int
}

nonisolated struct LibraryQueryFacetCount: Codable, Sendable, Equatable {
    let facet: PhotoLabelFacet
    let labelID: PhotoLabelID?
    let personalLabelID: UUID?
    let contextualMatchCount: Int

    init(
        facet: PhotoLabelFacet,
        labelID: PhotoLabelID? = nil,
        personalLabelID: UUID? = nil,
        contextualMatchCount: Int
    ) {
        self.facet = facet
        self.labelID = labelID
        self.personalLabelID = personalLabelID
        self.contextualMatchCount = contextualMatchCount
    }
}

nonisolated struct LibraryQueryGroupContext: Codable, Sendable, Equatable {
    let groupID: UUID
    let relation: ComparisonGroupRelation
    let reason: ComparisonGroupReason
    let representativeAssetID: AssetID?
    let matchedAssetIDs: [AssetID]
    let outsideFilterAssetIDs: [AssetID]
    let totalMemberCount: Int

    var matchedMemberCount: Int {
        matchedAssetIDs.count
    }
}

/// A non-mutating action over a frozen selection. Actions cannot add assets
/// outside the complete result set supplied by the query snapshot.
nonisolated enum LibraryQuerySelectionAction: Sendable, Equatable {
    case select([AssetID])
    case deselect([AssetID])
    case selectAll
    case clear
}

nonisolated struct LibraryQuerySelectionSnapshot: Codable, Sendable, Equatable {
    let selectionID: UUID
    let queryIdentity: String
    let catalogGenerationID: UUID
    let labelProjectionRevision: Int64
    let selectedAssetIDs: [AssetID]

    func applying(
        _ action: LibraryQuerySelectionAction,
        completeAssetIDs: [AssetID]
    ) -> LibraryQuerySelectionSnapshot {
        let complete = Set(completeAssetIDs)
        var selected = Set(selectedAssetIDs).intersection(complete)
        switch action {
        case let .select(assetIDs):
            selected.formUnion(assetIDs.filter { complete.contains($0) })
        case let .deselect(assetIDs):
            selected.subtract(assetIDs)
        case .selectAll:
            selected = complete
        case .clear:
            selected.removeAll()
        }
        return LibraryQuerySelectionSnapshot(
            selectionID: selectionID,
            queryIdentity: queryIdentity,
            catalogGenerationID: catalogGenerationID,
            labelProjectionRevision: labelProjectionRevision,
            selectedAssetIDs: selected.sorted { $0.rawValue < $1.rawValue }
        )
    }
}

nonisolated struct LibraryQueryResultSnapshot: Codable, Sendable, Equatable {
    let snapshotID: UUID
    let query: LibraryQuery
    let catalogGenerationID: UUID
    let labelProjectionRevision: Int64
    let completeAssetIDs: [AssetID]
    let pageAssetIDs: [AssetID]
    let facetCounts: [LibraryQueryFacetCount]
    let coverage: LibraryQueryCoverage
    let groups: [LibraryQueryGroupContext]
    let selection: LibraryQuerySelectionSnapshot
}

nonisolated struct LibraryQueryPresentationSnapshot: Sendable, Equatable {
    let result: LibraryQueryResultSnapshot
    let observations: [CatalogAssetObservationSnapshot]
    let personalLabels: [CatalogPersonalLabelSnapshot]
}
