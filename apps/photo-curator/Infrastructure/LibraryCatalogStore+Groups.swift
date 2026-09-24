// swiftlint:disable function_body_length
import Foundation
import SwiftData

/// Durable comparison-group operations are isolated to LibraryCatalogStore so
/// no caller can observe a partially written snapshot. The input is entirely
/// value typed; no SwiftData model crosses the actor boundary.
extension LibraryCatalogStore {
    /// Publishes all snapshot, group, and member rows in one transaction. The
    /// catalog pointer changes only after every row has been inserted and
    /// saved, so a failed rebuild leaves the prior current snapshot intact.
    @discardableResult
    func publishComparisonSnapshot(_ input: ComparisonSnapshotInput) throws -> ComparisonSnapshot {
        guard let state = try fetchState(),
              let currentGenerationID = state.currentGenerationID,
              currentGenerationID == input.catalogGenerationID,
              state.availability == .available || state.availability == .stale,
              let generation = try fetchGeneration(id: currentGenerationID),
              generation.status == .committed
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }

        try validate(input, against: generation)
        guard try fetchComparisonSnapshot(id: input.id) == nil else {
            throw LibraryCatalogStoreError.persistenceFailed
        }

        let createdAt = Date()
        var published: ComparisonSnapshot?
        try context.transaction {
            // Re-check the generation while the actor still owns the context;
            // this protects the publish boundary from a stale queued rebuild.
            guard let currentState = try fetchState(),
                  currentState.currentGenerationID == input.catalogGenerationID,
                  currentState.availability == .available || currentState.availability == .stale,
                  let currentGeneration = try fetchGeneration(id: input.catalogGenerationID),
                  currentGeneration.status == .committed
            else {
                throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
            }

            let snapshot = CatalogComparisonSnapshotProjection(
                id: input.id,
                catalogGenerationID: input.catalogGenerationID,
                groupingRevision: input.groupingRevision,
                providerRevision: input.providerRevision,
                coverage: input.coverage,
                createdAt: createdAt
            )
            context.insert(snapshot)

            for (groupOrdinal, groupInput) in input.groups.enumerated() {
                context.insert(CatalogComparisonGroupProjection(
                    snapshotID: input.id,
                    groupID: groupInput.id,
                    ordinal: groupOrdinal,
                    relation: groupInput.relation,
                    reason: groupInput.reason,
                    representativeAssetID: groupInput.representativeAssetID,
                    groupingRevision: groupInput.groupingRevision,
                    providerRevision: groupInput.providerRevision,
                    evidenceReferenceIDs: groupInput.evidenceReferenceIDs,
                    memberCount: groupInput.members.count
                ))
                for reference in groupInput.evidenceReferences {
                    context.insert(CatalogComparisonEvidenceProjection(
                        snapshotID: input.id,
                        groupID: groupInput.id,
                        reference: reference
                    ))
                }
                for (memberOrdinal, member) in groupInput.members.enumerated() {
                    context.insert(CatalogComparisonMemberProjection(
                        snapshotID: input.id,
                        groupID: groupInput.id,
                        assetID: member.assetID,
                        ordinal: memberOrdinal,
                        evidenceReferenceID: member.evidenceReferenceID
                    ))
                }
            }

            // This is the first mutation of the current pointer. All derived
            // rows are already present in the same atomic save.
            let comparisonState = try comparisonStateOrCreate()
            comparisonState.currentSnapshotID = input.id
            comparisonState.updatedAt = createdAt
            try pruneComparisonProjections(currentSnapshotID: input.id)
            try context.save()
            published = try makeComparisonSnapshot(snapshot)
        }
        guard let published else { throw LibraryCatalogStoreError.persistenceFailed }
        return published
    }

    /// Reads the current comparison snapshot only when it belongs to the
    /// current committed catalog generation. A stale pointer is an explicit
    /// generation rejection rather than an invented current result.
    func currentComparisonSnapshot() throws -> ComparisonSnapshot? {
        guard let comparisonState = try fetchComparisonState(),
              let snapshotID = comparisonState.currentSnapshotID
        else { return nil }
        guard let catalogState = try fetchState(),
              let generationID = catalogState.currentGenerationID
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        return try readComparisonSnapshot(id: snapshotID, catalogGenerationID: generationID)
    }

    /// Reads a snapshot pinned to the current catalog generation. The optional
    /// argument is useful to make the generation pin explicit at call sites;
    /// it is never treated as permission to read a mismatched current row.
    func readComparisonSnapshot(
        id: UUID,
        catalogGenerationID expectedGenerationID: UUID? = nil
    ) throws -> ComparisonSnapshot? {
        guard let state = try fetchState(),
              let currentGenerationID = state.currentGenerationID,
              state.availability == .available || state.availability == .stale
        else { return nil }
        if let expectedGenerationID, expectedGenerationID != currentGenerationID {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let snapshot = try fetchComparisonSnapshot(id: id) else { return nil }
        guard snapshot.catalogGenerationID == currentGenerationID else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let generation = try fetchGeneration(id: currentGenerationID),
              generation.status == .committed
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        return try makeComparisonSnapshot(snapshot)
    }

    /// Removes the current comparison projection without touching catalog
    /// observations, analysis evidence, or user-owned state. An expected
    /// generation pin rejects reset requests queued across reconciliation.
    func resetComparisonSnapshot(catalogGenerationID expectedGenerationID: UUID? = nil) throws {
        guard let state = try fetchState(),
              let currentGenerationID = state.currentGenerationID
        else { return }
        if let expectedGenerationID, expectedGenerationID != currentGenerationID {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let comparisonState = try fetchComparisonState(),
              let snapshotID = comparisonState.currentSnapshotID
        else { return }
        guard let snapshot = try fetchComparisonSnapshot(id: snapshotID),
              snapshot.catalogGenerationID == currentGenerationID
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }

        try context.transaction {
            let groups = try fetchComparisonGroups(snapshotID: snapshotID)
            let members = try fetchComparisonMembers(snapshotID: snapshotID)
            let references = try fetchComparisonEvidenceReferences(snapshotID: snapshotID)
            for member in members {
                context.delete(member)
            }
            for group in groups {
                context.delete(group)
            }
            for reference in references {
                context.delete(reference)
            }
            context.delete(snapshot)
            comparisonState.currentSnapshotID = nil
            comparisonState.updatedAt = Date()
            try context.save()
        }
    }

    /// Compatibility spelling for callers that use the shorter reset label.
    func resetComparisonSnapshot(for catalogGenerationID: UUID? = nil) throws {
        try resetComparisonSnapshot(catalogGenerationID: catalogGenerationID)
    }
}

private extension LibraryCatalogStore {
    func validate(_ input: ComparisonSnapshotInput, against generation: CatalogGeneration) throws {
        let coverage = input.coverage
        guard !input.groupingRevision.isEmpty,
              !input.providerRevision.isEmpty,
              coverage.assetCount == generation.assetCount,
              coverage.assetCount >= 0,
              coverage.eligibleAssetCount >= 0,
              coverage.eligibleAssetCount <= coverage.assetCount,
              coverage.candidateCount >= 0,
              coverage.attemptedComparisonCount >= 0,
              coverage.attemptedComparisonCount <= coverage.candidateCount,
              coverage.successfulComparisonCount >= 0,
              coverage.successfulComparisonCount <= coverage.attemptedComparisonCount,
              coverage.validatedCandidateCount >= 0,
              coverage.validatedCandidateCount == coverage.successfulComparisonCount,
              coverage.acceptedEdgeCount >= 0,
              coverage.acceptedEdgeCount <= coverage.successfulComparisonCount,
              coverage.groupedAssetCount >= 0,
              coverage.groupedAssetCount <= coverage.eligibleAssetCount,
              coverage.unavailableAssetCount >= 0,
              coverage.unavailableAssetCount <= coverage.assetCount,
              coverage.overflowedCandidateCount >= 0
        else { throw LibraryCatalogStoreError.incompleteGeneration }

        if coverage.status == .complete {
            guard coverage.attemptedComparisonCount == coverage.candidateCount,
                  coverage.successfulComparisonCount == coverage.attemptedComparisonCount,
                  coverage.unavailableAssetCount == 0,
                  coverage.overflowedCandidateCount == 0
            else { throw LibraryCatalogStoreError.incompleteGeneration }
        }

        var memberCount = 0
        var seenAssets = Set<String>()
        var seenGroups = Set<UUID>()
        let generationID = generation.id
        let observations = try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.generationID == generationID }
        ))
        let catalogAssetIDs = Set(observations.map(\.assetID))

        for group in input.groups {
            guard seenGroups.insert(group.id).inserted,
                  !group.groupingRevision.isEmpty,
                  !group.providerRevision.isEmpty,
                  group.groupingRevision == input.groupingRevision,
                  group.providerRevision == input.providerRevision,
                  !group.reason.rawValue.isEmpty,
                  !group.evidenceReferenceIDs.isEmpty,
                  Set(group.evidenceReferenceIDs).count == group.evidenceReferenceIDs.count,
                  !group.evidenceReferences.isEmpty,
                  Set(group.evidenceReferences.map(\.identifier)).count == group.evidenceReferences.count,
                  Set(group.evidenceReferences.map(\.identifier)) == Set(group.evidenceReferenceIDs),
                  group.members.count >= 2
            else { throw LibraryCatalogStoreError.incompleteGeneration }

            let groupAssetIDs = Set(group.members.map(\.assetID))
            for reference in group.evidenceReferences {
                guard reference.sourceGenerationID == generation.id,
                      reference.analysisRevision > 0,
                      reference.providerRevision == input.providerRevision,
                      !reference.identifier.isEmpty,
                      reference.firstAssetID != reference.secondAssetID,
                      groupAssetIDs.contains(reference.firstAssetID),
                      groupAssetIDs.contains(reference.secondAssetID),
                      catalogAssetIDs.contains(reference.firstAssetID.rawValue),
                      catalogAssetIDs.contains(reference.secondAssetID.rawValue)
                else { throw LibraryCatalogStoreError.incompleteGeneration }

                guard let firstObservation = observations.first(where: {
                    $0.assetID == reference.firstAssetID.rawValue
                }), let secondObservation = observations.first(where: {
                    $0.assetID == reference.secondAssetID.rawValue
                }) else { throw LibraryCatalogStoreError.incompleteGeneration }
                guard firstObservation.modificationFingerprint == reference.firstAssetFingerprint,
                      secondObservation.modificationFingerprint == reference.secondAssetFingerprint
                else {
                    throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged)
                }
            }

            if let representative = group.representativeAssetID {
                guard group.members.contains(where: { $0.assetID == representative }) else {
                    throw LibraryCatalogStoreError.incompleteGeneration
                }
            }

            var seenGroupAssets = Set<String>()
            for member in group.members {
                guard catalogAssetIDs.contains(member.assetID.rawValue),
                      seenGroupAssets.insert(member.assetID.rawValue).inserted,
                      seenAssets.insert(member.assetID.rawValue).inserted
                else { throw LibraryCatalogStoreError.incompleteGeneration }
                guard let evidenceReferenceID = member.evidenceReferenceID,
                      group.evidenceReferenceIDs.contains(evidenceReferenceID)
                else {
                    throw LibraryCatalogStoreError.incompleteGeneration
                }
                memberCount += 1
            }
        }

        guard memberCount == coverage.groupedAssetCount else {
            throw LibraryCatalogStoreError.incompleteGeneration
        }
    }

    func fetchComparisonSnapshot(id: UUID) throws -> CatalogComparisonSnapshotProjection? {
        try context.fetch(FetchDescriptor<CatalogComparisonSnapshotProjection>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    func fetchComparisonState() throws -> CatalogComparisonState? {
        let singletonKey = CatalogComparisonState.singletonID
        return try context.fetch(FetchDescriptor<CatalogComparisonState>(
            predicate: #Predicate { $0.singletonKey == singletonKey }
        )).first
    }

    func comparisonStateOrCreate() throws -> CatalogComparisonState {
        if let state = try fetchComparisonState() {
            return state
        }
        let state = CatalogComparisonState()
        context.insert(state)
        return state
    }

    func fetchComparisonGroups(snapshotID: UUID) throws -> [CatalogComparisonGroupProjection] {
        try context.fetch(FetchDescriptor<CatalogComparisonGroupProjection>(
            predicate: #Predicate { $0.snapshotID == snapshotID }
        )).sorted {
            if $0.ordinal != $1.ordinal {
                return $0.ordinal < $1.ordinal
            }
            return $0.groupID.uuidString < $1.groupID.uuidString
        }
    }

    func fetchComparisonMembers(snapshotID: UUID) throws -> [CatalogComparisonMemberProjection] {
        try context.fetch(FetchDescriptor<CatalogComparisonMemberProjection>(
            predicate: #Predicate { $0.snapshotID == snapshotID }
        )).sorted {
            if $0.groupID != $1.groupID {
                return $0.groupID.uuidString < $1.groupID.uuidString
            }
            return $0.ordinal < $1.ordinal
        }
    }

    func fetchComparisonEvidenceReferences(
        snapshotID: UUID,
        groupID: UUID? = nil
    ) throws -> [CatalogComparisonEvidenceProjection] {
        let references = try context.fetch(FetchDescriptor<CatalogComparisonEvidenceProjection>(
            predicate: #Predicate { $0.snapshotID == snapshotID }
        ))
        return references.filter { groupID == nil || $0.groupID == groupID }
            .sorted { $0.identifier < $1.identifier }
    }

    /// Comparison snapshots are immutable values at the read boundary, so the
    /// store can retain a small history while pruning orphaned child rows.
    /// The current pointer is always retained even when its creation date is
    /// outside the normal history window.
    func pruneComparisonProjections(currentSnapshotID: UUID) throws {
        let snapshots = try context.fetch(FetchDescriptor<CatalogComparisonSnapshotProjection>())
        let retainedIDs = Set(
            snapshots.sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
                .map(\.id)
        ).union([currentSnapshotID])
        let groups = try context.fetch(FetchDescriptor<CatalogComparisonGroupProjection>())
        let members = try context.fetch(FetchDescriptor<CatalogComparisonMemberProjection>())
        let references = try context.fetch(FetchDescriptor<CatalogComparisonEvidenceProjection>())
        let snapshotIDs = Set(snapshots.map(\.id))
        let membersToDelete = members.filter {
            $0.snapshotID != currentSnapshotID
                && (!snapshotIDs.contains($0.snapshotID) || !retainedIDs.contains($0.snapshotID))
        }
        let referencesToDelete = references.filter {
            $0.snapshotID != currentSnapshotID
                && (!snapshotIDs.contains($0.snapshotID) || !retainedIDs.contains($0.snapshotID))
        }
        let groupsToDelete = groups.filter {
            $0.snapshotID != currentSnapshotID
                && (!snapshotIDs.contains($0.snapshotID) || !retainedIDs.contains($0.snapshotID))
        }
        for member in membersToDelete {
            context.delete(member)
        }
        for reference in referencesToDelete {
            context.delete(reference)
        }
        for group in groupsToDelete {
            context.delete(group)
        }
        for snapshot in snapshots where !retainedIDs.contains(snapshot.id) {
            context.delete(snapshot)
        }
    }

    func makeComparisonSnapshot(_ projection: CatalogComparisonSnapshotProjection) throws -> ComparisonSnapshot {
        let groups = try fetchComparisonGroups(snapshotID: projection.id)
        let members = try fetchComparisonMembers(snapshotID: projection.id)
        let membersByGroup = Dictionary(grouping: members, by: \.groupID)
        var groupSnapshots: [ComparisonGroupSnapshot] = []
        groupSnapshots.reserveCapacity(groups.count)
        for group in groups {
            guard let relation = ComparisonGroupRelation(rawValue: group.relationRawValue),
                  let reason = ComparisonGroupReason(rawValue: group.reasonRawValue),
                  let groupMembers = membersByGroup[group.groupID],
                  group.memberCount == groupMembers.count
            else { throw LibraryCatalogStoreError.persistenceFailed }
            let references = try fetchComparisonEvidenceReferences(
                snapshotID: projection.id, groupID: group.groupID
            ).map(\.input)
            groupSnapshots.append(ComparisonGroupSnapshot(
                id: group.groupID,
                ordinal: group.ordinal,
                relation: relation,
                reason: reason,
                representativeAssetID: group.representativeAssetID.map(AssetID.init(rawValue:)),
                groupingRevision: group.groupingRevision,
                providerRevision: group.providerRevision,
                evidenceReferenceIDs: group.evidenceReferenceIDs,
                evidenceReferences: references,
                members: groupMembers.sorted { $0.ordinal < $1.ordinal }.map {
                    ComparisonMemberSnapshot(
                        assetID: AssetID(rawValue: $0.assetID),
                        ordinal: $0.ordinal,
                        evidenceReferenceID: $0.evidenceReferenceID
                    )
                }
            ))
        }
        return ComparisonSnapshot(
            id: projection.id,
            catalogGenerationID: projection.catalogGenerationID,
            groupingRevision: projection.groupingRevision,
            providerRevision: projection.providerRevision,
            coverage: projection.coverage,
            createdAt: projection.createdAt,
            groups: groupSnapshots
        )
    }
}

// swiftlint:enable function_body_length
