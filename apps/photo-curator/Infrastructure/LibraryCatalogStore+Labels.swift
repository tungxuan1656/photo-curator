import Foundation
import SwiftData

// swiftlint:disable file_length

/// V7 label records are owned by the catalog actor. Automatic evidence and
/// user state are separate rows; only the effective projection is rebuilt.
extension LibraryCatalogStore {
    func labelAnalysisState(for assetID: AssetID) throws -> CatalogLabelAnalysisSnapshot? {
        try fetchLabelAnalysisState(assetID: assetID.rawValue)?.snapshot()
    }

    func labelAnalysisStates() throws -> [CatalogLabelAnalysisSnapshot] {
        try context.fetch(FetchDescriptor<CatalogLabelAnalysisState>())
            .sorted { $0.assetID < $1.assetID }
            .map { $0.snapshot() }
    }

    func automaticLabelAssignments(for assetID: AssetID) throws -> [PhotoLabelAutomaticAssignment] {
        try context.fetch(FetchDescriptor<CatalogAutomaticLabelAssignment>())
            .filter { $0.assetID == assetID.rawValue }
            .compactMap { assignment in
                guard let labelID = assignment.labelID,
                      assignment.outcome == .completed
                else { return nil }
                return PhotoLabelAutomaticAssignment(
                    assetID: assetID,
                    assetRevision: assignment.assetRevision,
                    labelID: labelID,
                    facet: PhotoLabelFacet(rawValue: assignment.facetRawValue) ?? .content,
                    sourceRevision: assignment.sourceRevision,
                    providerRevision: assignment.providerRevision,
                    runtimeRevision: assignment.runtimeRevision,
                    mappingRevision: assignment.mappingRevision,
                    taxonomyRevision: assignment.taxonomyRevision,
                    evidenceSource: PhotoLabelEvidenceSource(rawValue: assignment.evidenceSourceRawValue)
                        ?? .visionClassification,
                    outcome: assignment.outcome,
                    rawScore: assignment.rawScore,
                    evidenceReferenceID: assignment.evidenceReferenceID,
                    generationID: assignment.generationID,
                    analysisRevision: assignment.analysisRevision,
                    confidenceFloor: assignment.confidenceFloor ?? PhotoLabelTaxonomy.confidenceFloor,
                    ambiguityMargin: assignment.ambiguityMargin ?? PhotoLabelTaxonomy.ambiguityMargin
                )
            }
            .sorted { $0.labelID.rawValue < $1.labelID.rawValue }
    }

    func effectiveLabels(for assetID: AssetID) throws -> [CatalogEffectiveLabelSnapshot] {
        try context.fetch(FetchDescriptor<CatalogEffectiveLabelProjection>())
            .filter { $0.assetID == assetID.rawValue }
            .compactMap(\.snapshot)
            .sorted(by: Self.effectiveLabelOrder)
    }

    func effectiveLabels(for assetIDs: [AssetID]) throws -> [CatalogEffectiveLabelSnapshot] {
        let allowed = Set(assetIDs.map(\.rawValue))
        return try context.fetch(FetchDescriptor<CatalogEffectiveLabelProjection>())
            .filter { allowed.contains($0.assetID) }
            .compactMap(\.snapshot)
            .sorted { left, right in
                if left.assetID != right.assetID {
                    return left.assetID.rawValue < right.assetID.rawValue
                }
                return Self.effectiveLabelOrder(left, right)
            }
    }

    /// Returns the catalog-wide monotonic revision even when the requested
    /// asset has no effective rows.
    func currentLabelProjectionRevision() throws -> Int64 {
        try fetchState()?.labelProjectionRevision ?? 0
    }

    /// Publishes one mapper result only after the matching native evidence has
    /// been committed. The generation, asset fingerprint, analysis revision,
    /// and evidence reference are checked inside the actor before one save.
    func publishLabels(
        _ result: PhotoLabelMappingResult,
        generationID: UUID
    ) throws {
        guard try isCurrentGeneration(generationID),
              let observation = try fetchObservation(
                  assetID: result.assetID.rawValue,
                  generationID: generationID
              ),
              observation.modificationFingerprint == result.assetRevision
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }

        let workState = try fetchAnalysisWorkState(
            assetID: result.assetID.rawValue,
            capability: .nativeImageFacts
        )
        if result.outcome.isSuccessful {
            guard let workState,
                  workState.status == .available,
                  workState.completedAssetFingerprint == result.assetRevision,
                  let evidence = workState.evidence,
                  evidence.assetID == result.assetID,
                  evidence.assetFingerprint == result.assetRevision
            else {
                throw LibraryCatalogStoreError.analysisTransitionRejected(.evidenceReferenceMismatch)
            }

            let committedResult = result.committed(with: evidence, generationID: generationID)
            try context.transaction {
                try applyLabelPublication(committedResult)
                try context.save()
            }
            return
        }

        try context.transaction {
            try applyLabelPublication(result)
            try context.save()
        }
    }

    /// Records a non-image terminal/intermediate state without fabricating an
    /// assignment. This is used for pending, stale, unavailable, and
    /// unsupported lifecycle transitions.
    func recordLabelAnalysisState(
        for assetID: AssetID,
        assetRevision: AssetModificationFingerprint,
        state: PhotoLabelAnalysisInputState,
        generationID: UUID
    ) throws {
        let input = PhotoLabelMappingInput(
            assetID: assetID,
            assetRevision: assetRevision,
            state: state,
            observations: [],
            generationID: generationID,
            analysisRevision: PhotoAnalysis.currentVersion
        )
        try publishLabels(PhotoLabelMapper().map(input), generationID: generationID)
    }

    func setLabelOverride(
        for assetID: AssetID,
        labelID: PhotoLabelID,
        intent: CatalogLabelOverrideIntent
    ) throws {
        _ = PhotoLabelTaxonomy.definition(for: labelID)
        let identity = CatalogLabelOverride.identity(assetID: assetID, labelID: labelID)
        try context.transaction {
            let override = try context.fetch(FetchDescriptor<CatalogLabelOverride>(
                predicate: #Predicate { $0.identity == identity }
            )).first ?? CatalogLabelOverride(assetID: assetID, labelID: labelID, intent: intent)
            override.intentRawValue = intent.rawValue
            override.taxonomyRevision = PhotoLabelTaxonomy.revision
            override.updatedAt = Date()
            if override.modelContext == nil {
                context.insert(override)
            }
            try rebuildEffectiveLabelProjection(assetID: assetID)
            try context.save()
        }
    }

    func restoreAutomaticLabel(for assetID: AssetID, labelID: PhotoLabelID) throws {
        let identity = CatalogLabelOverride.identity(assetID: assetID, labelID: labelID)
        try context.transaction {
            if let override = try context.fetch(FetchDescriptor<CatalogLabelOverride>(
                predicate: #Predicate { $0.identity == identity }
            )).first {
                context.delete(override)
            }
            try rebuildEffectiveLabelProjection(assetID: assetID)
            try context.save()
        }
    }

    func labelOverrides(for assetID: AssetID) throws -> [CatalogLabelOverrideIntent: Set<PhotoLabelID>] {
        var result: [CatalogLabelOverrideIntent: Set<PhotoLabelID>] = [:]
        let overrides = try context.fetch(FetchDescriptor<CatalogLabelOverride>())
            .filter { $0.assetID == assetID.rawValue }
        for override in overrides {
            guard let labelID = override.labelID, let intent = override.intent else { continue }
            result[intent, default: []].insert(labelID)
        }
        return result
    }

    @discardableResult
    func createPersonalLabel(name: String) throws -> CatalogPersonalLabelSnapshot {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LibraryCatalogStoreError.persistenceFailed }
        let label = CatalogPersonalLabelDefinition(name: trimmed)
        try context.transaction {
            context.insert(label)
            try context.save()
        }
        return label.snapshot
    }

    func personalLabels() throws -> [CatalogPersonalLabelSnapshot] {
        try context.fetch(FetchDescriptor<CatalogPersonalLabelDefinition>())
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            .map(\.snapshot)
    }

    func renamePersonalLabel(_ id: UUID, name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let label = try fetchPersonalLabel(id: id)
        else { throw LibraryCatalogStoreError.persistenceFailed }
        try context.transaction {
            label.name = trimmed
            label.updatedAt = Date()
            try context.save()
        }
    }

    func removePersonalLabel(_ id: UUID) throws {
        try context.transaction {
            if let label = try fetchPersonalLabel(id: id) {
                context.delete(label)
            }
            let assignments = try context.fetch(FetchDescriptor<CatalogPersonalLabelAssignment>())
                .filter { $0.personalLabelID == id }
            for assignment in assignments {
                let assetID = AssetID(rawValue: assignment.assetID)
                context.delete(assignment)
                try rebuildEffectiveLabelProjection(assetID: assetID)
            }
            try context.save()
        }
    }

    func assignPersonalLabel(_ id: UUID, to assetIDs: [AssetID]) throws {
        guard try fetchPersonalLabel(id: id) != nil else {
            throw LibraryCatalogStoreError.persistenceFailed
        }
        try context.transaction {
            for assetID in Set(assetIDs) {
                let identity = CatalogPersonalLabelAssignment.identity(
                    assetID: assetID,
                    personalLabelID: id
                )
                let exists = try context.fetch(FetchDescriptor<CatalogPersonalLabelAssignment>(
                    predicate: #Predicate { $0.identity == identity }
                )).first != nil
                if !exists {
                    context.insert(CatalogPersonalLabelAssignment(
                        assetID: assetID,
                        personalLabelID: id
                    ))
                }
                try rebuildEffectiveLabelProjection(assetID: assetID)
            }
            try context.save()
        }
    }

    func removePersonalLabel(_ id: UUID, from assetIDs: [AssetID]) throws {
        try context.transaction {
            let allowed = Set(assetIDs.map(\.rawValue))
            let assignments = try context.fetch(FetchDescriptor<CatalogPersonalLabelAssignment>())
                .filter { $0.personalLabelID == id && allowed.contains($0.assetID) }
            let affected = Set(assignments.map { AssetID(rawValue: $0.assetID) })
            for assignment in assignments {
                context.delete(assignment)
            }
            for assetID in affected {
                try rebuildEffectiveLabelProjection(assetID: assetID)
            }
            try context.save()
        }
    }

    func resetLabelAnalysis() throws {
        try context.transaction {
            try resetLabelAnalysisStates()
            try context.save()
        }
    }

    func resetLabelAnalysisStates() throws {
        let states = try context.fetch(FetchDescriptor<CatalogLabelAnalysisState>())
        for state in states {
            state.outcome = .pending
            state.evidenceReferenceID = nil
            state.publicationPending = false
            state.updatedAt = Date()
            try rebuildEffectiveLabelProjection(assetID: AssetID(rawValue: state.assetID))
        }
    }

    /// Reconciles every interrupted label publication before a new analysis
    /// run begins. Pending rows remain pending until durable evidence is
    /// reread and `publishLabels` commits the replacement projection.
    @discardableResult
    func reconcilePendingLabelPublications() throws -> [AssetID] {
        let pending = try context.fetch(FetchDescriptor<CatalogLabelAnalysisState>())
            .filter { $0.publicationPending }
        let assetIDs = pending.map { AssetID(rawValue: $0.assetID) }
        try context.transaction {
            for assetID in assetIDs {
                try rebuildEffectiveLabelProjection(assetID: assetID)
            }
            try context.save()
        }
        return assetIDs
    }

    func transitionLabelAnalysisState(
        assetID: AssetID,
        assetRevision: AssetModificationFingerprint,
        outcome: PhotoLabelAnalysisOutcome,
        generationID: UUID,
        analysisRevision: Int
    ) throws {
        let state = try upsertLabelAnalysisState(
            assetID: assetID,
            assetRevision: assetRevision,
            outcome: outcome,
            generationID: generationID,
            evidenceReferenceID: nil,
            analysisRevision: analysisRevision,
            confidenceFloor: PhotoLabelTaxonomy.confidenceFloor,
            ambiguityMargin: PhotoLabelTaxonomy.ambiguityMargin
        )
        if state.modelContext == nil {
            context.insert(state)
        }
        try rebuildEffectiveLabelProjection(assetID: assetID)
    }

    // swiftlint:disable:next function_parameter_count
    func upsertLabelAnalysisState(
        assetID: AssetID,
        assetRevision: AssetModificationFingerprint,
        outcome: PhotoLabelAnalysisOutcome,
        generationID: UUID?,
        evidenceReferenceID: String?,
        analysisRevision: Int?,
        confidenceFloor: Double,
        ambiguityMargin: Double
    ) throws -> CatalogLabelAnalysisState {
        let state: CatalogLabelAnalysisState
        if let existing = try fetchLabelAnalysisState(assetID: assetID.rawValue) {
            state = existing
        } else {
            state = CatalogLabelAnalysisState(
                assetID: assetID,
                assetRevision: assetRevision,
                outcome: outcome,
                generationID: generationID,
                evidenceReferenceID: evidenceReferenceID,
                analysisRevision: analysisRevision,
                confidenceFloor: confidenceFloor,
                ambiguityMargin: ambiguityMargin
            )
        }
        state.modificationDate = assetRevision.modificationDate
        state.fingerprintIsPresent = assetRevision.isPresent
        state.generationID = generationID
        state.evidenceReferenceID = evidenceReferenceID
        state.analysisRevision = analysisRevision
        state.outcome = outcome
        state.sourceRevision = PhotoLabelTaxonomy.sourceRevision
        state.providerRevision = PhotoLabelTaxonomy.providerRevision
        state.runtimeRevision = PhotoLabelTaxonomy.runtimeRevision
        state.mappingRevision = PhotoLabelTaxonomy.mappingRevision
        state.taxonomyRevision = PhotoLabelTaxonomy.revision
        state.confidenceFloor = confidenceFloor
        state.ambiguityMargin = ambiguityMargin
        state.publicationPending = false
        state.updatedAt = Date()
        return state
    }

    func applyLabelPublication(_ result: PhotoLabelMappingResult) throws {
        let state = try upsertLabelAnalysisState(
            assetID: result.assetID,
            assetRevision: result.assetRevision,
            outcome: result.outcome,
            generationID: result.generationID,
            evidenceReferenceID: result.evidenceReferenceID,
            analysisRevision: result.analysisRevision,
            confidenceFloor: result.confidenceFloor,
            ambiguityMargin: result.ambiguityMargin
        )
        state.publicationPending = false
        if state.modelContext == nil {
            context.insert(state)
        }

        for assignment in result.assignments {
            guard assignment.assetID == result.assetID,
                  assignment.assetRevision == result.assetRevision,
                  assignment.outcome == .completed
            else { continue }
            let identity = CatalogAutomaticLabelAssignment.identity(for: assignment)
            let exists = try context.fetch(FetchDescriptor<CatalogAutomaticLabelAssignment>(
                predicate: #Predicate { $0.identity == identity }
            )).first != nil
            if !exists {
                context.insert(CatalogAutomaticLabelAssignment(assignment))
            }
        }

        try rebuildEffectiveLabelProjection(assetID: result.assetID)
    }

    // swiftlint:disable:next function_body_length
    func rebuildEffectiveLabelProjection(assetID: AssetID) throws {
        let catalogProjectionRevision = try nextLabelProjectionRevision()
        let projections = try context.fetch(FetchDescriptor<CatalogEffectiveLabelProjection>())
            .filter { $0.assetID == assetID.rawValue }
        for projection in projections {
            context.delete(projection)
        }

        let state = try fetchLabelAnalysisState(assetID: assetID.rawValue)
        let automaticAllowed = state?.outcome.isSuccessful == true
        let currentRevision = state?.assetRevision
        let projectionRevision = UUID()
        state?.projectionRevision = projectionRevision
        state?.catalogProjectionRevision = catalogProjectionRevision
        var effective: [CatalogEffectiveLabelProjection] = []
        let overrides = try context.fetch(FetchDescriptor<CatalogLabelOverride>())
            .filter { $0.assetID == assetID.rawValue }
        let overrideByLabel: [PhotoLabelID: CatalogLabelOverrideIntent] = Dictionary(
            uniqueKeysWithValues: overrides.compactMap { override in
                guard let labelID = override.labelID, let intent = override.intent else { return nil }
                return (labelID, intent)
            }
        )

        let automatic = try context.fetch(FetchDescriptor<CatalogAutomaticLabelAssignment>())
            .filter {
                $0.assetID == assetID.rawValue
                    && $0.outcome == .completed
                    && $0.taxonomyRevision == PhotoLabelTaxonomy.revision
                    && automaticAllowed
                    && $0.assetRevision == currentRevision
                    && $0.generationID == state?.generationID
                    && $0.evidenceReferenceID == state?.evidenceReferenceID
                    && $0.analysisRevision == state?.analysisRevision
                    && $0.sourceRevision == state?.sourceRevision
                    && $0.providerRevision == state?.providerRevision
                    && $0.runtimeRevision == state?.runtimeRevision
                    && $0.mappingRevision == state?.mappingRevision
                    && $0.confidenceFloor == state?.confidenceFloor
                    && $0.ambiguityMargin == state?.ambiguityMargin
            }
            .compactMap { assignment -> CatalogAutomaticLabelAssignment? in
                guard assignment.labelID != nil else { return nil }
                return assignment
            }

        for assignment in automatic {
            guard let labelID = assignment.labelID else { continue }
            if overrideByLabel[labelID] == .reject {
                continue
            }
            let source: CatalogEffectiveLabelSource
            if overrideByLabel[labelID] == .confirm {
                source = .confirmed
            } else {
                source = .automatic
            }
            effective.append(CatalogEffectiveLabelProjection(
                assetID: assetID,
                labelID: labelID,
                facet: PhotoLabelTaxonomy.definition(for: labelID).facet,
                source: source,
                taxonomyRevision: PhotoLabelTaxonomy.revision,
                rawScore: assignment.rawScore,
                projectionRevision: projectionRevision,
                catalogProjectionRevision: catalogProjectionRevision
            ))
        }

        for (labelID, intent) in overrideByLabel where intent == .confirm {
            guard !automatic.contains(where: { $0.labelID == labelID }) else { continue }
            effective.append(CatalogEffectiveLabelProjection(
                assetID: assetID,
                labelID: labelID,
                facet: PhotoLabelTaxonomy.definition(for: labelID).facet,
                source: .confirmed,
                taxonomyRevision: PhotoLabelTaxonomy.revision,
                rawScore: nil,
                projectionRevision: projectionRevision,
                catalogProjectionRevision: catalogProjectionRevision
            ))
        }

        let personal = try context.fetch(FetchDescriptor<CatalogPersonalLabelAssignment>())
            .filter { $0.assetID == assetID.rawValue }
        for assignment in personal {
            effective.append(CatalogEffectiveLabelProjection(
                assetID: assetID,
                personalLabelID: assignment.personalLabelID,
                projectionRevision: projectionRevision,
                catalogProjectionRevision: catalogProjectionRevision
            ))
        }
        for projection in effective {
            context.insert(projection)
        }
    }

    private func nextLabelProjectionRevision() throws -> Int64 {
        let state = try stateOrCreate(availability: .unavailable)
        guard state.labelProjectionRevision < Int64.max else {
            throw LibraryCatalogStoreError.persistenceFailed
        }
        state.labelProjectionRevision += 1
        return state.labelProjectionRevision
    }

    private func fetchLabelAnalysisState(assetID: String) throws -> CatalogLabelAnalysisState? {
        try context.fetch(FetchDescriptor<CatalogLabelAnalysisState>(
            predicate: #Predicate { $0.identity == assetID }
        )).first
    }

    private func fetchPersonalLabel(id: UUID) throws -> CatalogPersonalLabelDefinition? {
        try context.fetch(FetchDescriptor<CatalogPersonalLabelDefinition>(
            predicate: #Predicate { $0.id == id }
        )).first
    }

    private static func effectiveLabelOrder(
        _ left: CatalogEffectiveLabelSnapshot,
        _ right: CatalogEffectiveLabelSnapshot
    ) -> Bool {
        let leftKey = left.labelID?.rawValue ?? left.personalLabelID?.uuidString ?? ""
        let rightKey = right.labelID?.rawValue ?? right.personalLabelID?.uuidString ?? ""
        if left.facet.rawValue != right.facet.rawValue {
            return left.facet.rawValue < right.facet.rawValue
        }
        return leftKey < rightKey
    }
}

// swiftlint:enable file_length
