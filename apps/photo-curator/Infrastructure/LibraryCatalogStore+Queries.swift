import Foundation
import SwiftData

extension LibraryCatalogStore {
    /// Reads one atomic query view from the current generation and current
    /// label projection. No query operation mutates catalog or user state.
    func query(_ query: LibraryQuery) throws -> LibraryQueryResultSnapshot {
        guard let catalogState = try fetchState(),
              let generationID = catalogState.currentGenerationID,
              catalogState.availability == .available || catalogState.availability == .stale,
              let generation = try fetchGeneration(id: generationID),
              generation.status == .committed
        else {
            throw LibraryCatalogStoreError.unavailable
        }
        try validate(query)

        let observations = try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.generationID == generationID }
        )).sorted { $0.assetID < $1.assetID }
        let allAssetIDs = observations.map { AssetID(rawValue: $0.assetID) }
        let allAssetIDSet = Set(allAssetIDs)
        let labelsByAsset = try currentLabelsByAsset()
        let completeAssetIDs = allAssetIDs.filter { matches($0, filters: query.filters, labelsByAsset: labelsByAsset) }
        let personalLabels = try context.fetch(FetchDescriptor<CatalogPersonalLabelDefinition>())
            .map(\.snapshot)
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        let facetCounts = contextualFacetCounts(
            allAssetIDs: allAssetIDs,
            filters: query.filters,
            labelsByAsset: labelsByAsset,
            personalLabels: personalLabels
        )
        let coverage = try queryCoverage(assetIDs: allAssetIDs)
        let groups = try queryGroups(
            generationID: generationID,
            matchingAssetIDs: Set(completeAssetIDs),
            accessibleAssetIDs: allAssetIDSet
        )
        let pageAssetIDs = Array(
            completeAssetIDs.dropFirst(query.page.offset).prefix(query.page.limit)
        )
        let selection = LibraryQuerySelectionSnapshot(
            selectionID: UUID(),
            queryIdentity: query.identity,
            catalogGenerationID: generationID,
            labelProjectionRevision: catalogState.labelProjectionRevision,
            selectedAssetIDs: []
        )
        return LibraryQueryResultSnapshot(
            snapshotID: UUID(),
            query: query,
            catalogGenerationID: generationID,
            labelProjectionRevision: catalogState.labelProjectionRevision,
            completeAssetIDs: completeAssetIDs,
            pageAssetIDs: pageAssetIDs,
            facetCounts: facetCounts,
            coverage: coverage,
            groups: groups,
            selection: selection
        )
    }

    func execute(_ query: LibraryQuery) throws -> LibraryQueryResultSnapshot {
        try self.query(query)
    }

    /// Assembles the query result and its presentation inputs while the actor
    /// owns one model context. Callers publish this value as one revisioned
    /// presentation snapshot rather than stitching together separate reads.
    func queryPresentation(_ query: LibraryQuery) throws -> LibraryQueryPresentationSnapshot {
        let result = try self.query(query)
        let observations = try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.generationID == result.catalogGenerationID }
        )).sorted { $0.assetID < $1.assetID }
            .map {
                CatalogAssetObservationSnapshot(
                    generationID: result.catalogGenerationID,
                    asset: $0.photoAsset
                )
            }
        let personalLabels = try context.fetch(FetchDescriptor<CatalogPersonalLabelDefinition>())
            .map(\.snapshot)
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        return LibraryQueryPresentationSnapshot(
            result: result,
            observations: observations,
            personalLabels: personalLabels
        )
    }

    private func validate(_ query: LibraryQuery) throws {
        let admitted = Dictionary(uniqueKeysWithValues: PhotoLabelTaxonomy.supportedLabels.map { ($0.id, $0) })
        let personalIDs = try Set(context.fetch(FetchDescriptor<CatalogPersonalLabelDefinition>()).map(\.id))
        for filter in query.filters {
            if filter.facet == .personal {
                guard filter.labelIDs.isEmpty,
                      !filter.personalLabelIDs.isEmpty,
                      Set(filter.personalLabelIDs).isSubset(of: personalIDs)
                else {
                    throw LibraryCatalogStoreError.invalidQuery
                }
                continue
            }
            guard !filter.labelIDs.isEmpty, filter.personalLabelIDs.isEmpty else {
                throw LibraryCatalogStoreError.invalidQuery
            }
            for labelID in filter.labelIDs {
                guard let definition = admitted[labelID], definition.facet == filter.facet else {
                    throw LibraryCatalogStoreError.invalidQuery
                }
            }
        }
    }

    private struct QueryAssetLabels {
        var semantic: Set<PhotoLabelID> = []
        var personal: Set<UUID> = []
    }

    private func currentLabelsByAsset() throws -> [AssetID: QueryAssetLabels] {
        let projections = try context.fetch(FetchDescriptor<CatalogEffectiveLabelProjection>())
        var result: [AssetID: QueryAssetLabels] = [:]
        for projection in projections {
            let assetID = AssetID(rawValue: projection.assetID)
            if let labelID = projection.labelIDRawValue.flatMap(PhotoLabelID.init(rawValue:)) {
                let isAdmitted = projection.taxonomyRevision == PhotoLabelTaxonomy.revision
                    && PhotoLabelTaxonomy.supportedLabels.contains { $0.id == labelID }
                if isAdmitted {
                    result[assetID, default: QueryAssetLabels()].semantic.insert(labelID)
                }
            } else if let personalLabelID = projection.personalLabelID {
                if projection.facetRawValue == PhotoLabelFacet.personal.rawValue {
                    result[assetID, default: QueryAssetLabels()].personal.insert(personalLabelID)
                }
            }
        }
        return result
    }

    private func matches(
        _ assetID: AssetID,
        filters: [LibraryQueryFacetFilter],
        labelsByAsset: [AssetID: QueryAssetLabels]
    ) -> Bool {
        let labels = labelsByAsset[assetID, default: QueryAssetLabels()]
        return filters.allSatisfy { filter in
            if filter.facet == .personal {
                return !labels.personal.isDisjoint(with: filter.personalLabelIDs)
            }
            return !labels.semantic.isDisjoint(with: filter.labelIDs)
        }
    }

    private func contextualFacetCounts(
        allAssetIDs: [AssetID],
        filters: [LibraryQueryFacetFilter],
        labelsByAsset: [AssetID: QueryAssetLabels],
        personalLabels: [CatalogPersonalLabelSnapshot]
    ) -> [LibraryQueryFacetCount] {
        let semanticCounts = PhotoLabelTaxonomy.supportedLabels.map { definition in
            let otherFilters = filters.filter { $0.facet != definition.facet }
            let proposed = otherFilters + [LibraryQueryFacetFilter(
                facet: definition.facet,
                labelIDs: [definition.id]
            )]
            let count = allAssetIDs.reduce(into: 0) { count, assetID in
                if matches(assetID, filters: proposed, labelsByAsset: labelsByAsset) {
                    count += 1
                }
            }
            return LibraryQueryFacetCount(
                facet: definition.facet,
                labelID: definition.id,
                contextualMatchCount: count
            )
        }
        let personalCounts = personalLabels.map { label in
            let otherFilters = filters.filter { $0.facet != .personal }
            let proposed = otherFilters + [LibraryQueryFacetFilter(
                facet: .personal,
                personalLabelIDs: [label.id]
            )]
            let count = allAssetIDs.reduce(into: 0) { count, assetID in
                if matches(assetID, filters: proposed, labelsByAsset: labelsByAsset) {
                    count += 1
                }
            }
            return LibraryQueryFacetCount(
                facet: .personal,
                personalLabelID: label.id,
                contextualMatchCount: count
            )
        }
        return semanticCounts + personalCounts
    }

    private func queryCoverage(assetIDs: [AssetID]) throws -> LibraryQueryCoverage {
        let states = try context.fetch(FetchDescriptor<CatalogLabelAnalysisState>())
        let byAsset = Dictionary(uniqueKeysWithValues: states.map { ($0.assetID, $0) })
        var analyzed = 0
        var pending = 0
        var unavailable = 0
        var stale = 0
        for assetID in assetIDs {
            guard let state = byAsset[assetID.rawValue], !state.publicationPending else {
                pending += 1
                continue
            }
            switch state.outcome {
            case .completed, .completedEmpty:
                analyzed += 1
            case .pending:
                pending += 1
            case .unavailable, .unsupported:
                unavailable += 1
            case .stale:
                stale += 1
            }
        }
        let known = analyzed + pending + unavailable + stale
        return LibraryQueryCoverage(
            state: pending == 0 && unavailable == 0 && stale == 0 && known == assetIDs.count
                ? .complete
                : .incomplete,
            totalAssetCount: assetIDs.count,
            analyzedAssetCount: analyzed,
            pendingAssetCount: pending,
            unavailableAssetCount: unavailable,
            staleAssetCount: stale,
            unknownAssetCount: max(0, assetIDs.count - known)
        )
    }

    private func queryGroups(
        generationID: UUID,
        matchingAssetIDs: Set<AssetID>,
        accessibleAssetIDs: Set<AssetID>
    ) throws -> [LibraryQueryGroupContext] {
        let singletonKey = CatalogComparisonState.singletonID
        let comparisonState = try context.fetch(FetchDescriptor<CatalogComparisonState>(
            predicate: #Predicate { $0.singletonKey == singletonKey }
        )).first
        guard let comparisonState,
              let snapshotID = comparisonState.currentSnapshotID,
              let snapshot = try context.fetch(FetchDescriptor<CatalogComparisonSnapshotProjection>(
                  predicate: #Predicate { $0.id == snapshotID }
              )).first,
              snapshot.catalogGenerationID == generationID
        else { return [] }
        let groups = try context.fetch(FetchDescriptor<CatalogComparisonGroupProjection>(
            predicate: #Predicate { $0.snapshotID == snapshotID }
        )).sorted {
            if $0.ordinal != $1.ordinal {
                return $0.ordinal < $1.ordinal
            }
            return $0.groupID.uuidString < $1.groupID.uuidString
        }
        let members = try context.fetch(FetchDescriptor<CatalogComparisonMemberProjection>(
            predicate: #Predicate { $0.snapshotID == snapshotID }
        ))
        return groups.compactMap { group in
            var groupMembers = members.filter { member in
                member.groupID == group.groupID
                    && accessibleAssetIDs.contains(AssetID(rawValue: member.assetID))
            }
            groupMembers.sort { $0.ordinal < $1.ordinal }
            let groupAssetIDs = groupMembers.map { AssetID(rawValue: $0.assetID) }
            let matched = groupAssetIDs.filter { matchingAssetIDs.contains($0) }
            guard !matched.isEmpty else { return nil }
            let outside = groupAssetIDs.filter { !matchingAssetIDs.contains($0) }
            guard let relation = ComparisonGroupRelation(rawValue: group.relationRawValue),
                  let reason = ComparisonGroupReason(rawValue: group.reasonRawValue)
            else { return nil }
            return LibraryQueryGroupContext(
                groupID: group.groupID,
                relation: relation,
                reason: reason,
                representativeAssetID: group.representativeAssetID.map(AssetID.init(rawValue:)),
                matchedAssetIDs: matched,
                outsideFilterAssetIDs: outside,
                totalMemberCount: groupAssetIDs.count
            )
        }
    }
}
