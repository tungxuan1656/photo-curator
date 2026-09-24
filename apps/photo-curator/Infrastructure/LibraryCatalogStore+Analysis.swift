import Foundation
import SwiftData

extension LibraryCatalogStore {
    func analysisWorkPage(
        generationID: UUID,
        after cursor: AssetID? = nil,
        limit: Int = 32,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkPage {
        guard (1 ... 32).contains(limit) else {
            throw LibraryCatalogStoreError.analysisPageLimitExceeded
        }
        guard let catalogState = try fetchState(),
              catalogState.currentGenerationID == generationID,
              catalogState.availability == .available || catalogState.availability == .stale,
              let generation = try fetchGeneration(id: generationID),
              generation.status == .committed
        else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }

        let generationSnapshot = LibraryCatalogStore.snapshot(generation)
        let observations = try fetchObservationPage(
            generationID: generationID,
            after: cursor?.rawValue,
            limit: limit
        )
        let hasMore = observations.count > limit
        let pageObservations = Array(observations.prefix(limit))
        let assetIDs = pageObservations.map(\.assetID)
        let capabilityRawValue = capability.rawValue
        let states = try context.fetch(FetchDescriptor<AnalysisWorkState>(
            predicate: #Predicate {
                assetIDs.contains($0.assetID) && $0.capabilityRawValue == capabilityRawValue
            }
        )).filter { $0.generationID == generationID }
            .sorted { $0.assetID < $1.assetID }
            .map { $0.snapshot() }

        return AnalysisWorkPage(
            generation: generationSnapshot,
            observations: pageObservations.map {
                CatalogAssetObservationSnapshot(generationID: generationID, asset: $0.photoAsset)
            },
            workStates: states,
            nextCursor: hasMore ? pageObservations.last.map { AssetID(rawValue: $0.assetID) } : nil,
            hasMore: hasMore
        )
    }

    func analysisWorkPage(
        after cursor: AssetID? = nil,
        limit: Int = 32,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkPage? {
        guard let generationID = try fetchState()?.currentGenerationID else { return nil }
        return try analysisWorkPage(
            generationID: generationID,
            after: cursor,
            limit: limit,
            capability: capability
        )
    }

    func resetAnalysisWork(
        generationID: UUID? = nil,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws {
        if let generationID {
            guard try isCurrentGeneration(generationID) else {
                throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
            }
        }
        let capabilityRawValue = capability.rawValue
        let states = try context.fetch(FetchDescriptor<AnalysisWorkState>(
            predicate: #Predicate { $0.capabilityRawValue == capabilityRawValue }
        )).filter { generationID == nil || $0.generationID == generationID }

        try context.transaction {
            for state in states {
                state.status = .pending
                state.reason = .cancelled
                clearCompletedEvidence(from: state)
            }
            try resetLabelAnalysisStates()
            try context.save()
        }
    }

    static func recoverOrphanedAnalysisWork(in context: ModelContext) throws {
        let runningRawValue = AnalysisWorkStatus.running.rawValue
        let states = try context.fetch(FetchDescriptor<AnalysisWorkState>(
            predicate: #Predicate { $0.statusRawValue == runningRawValue }
        ))
        guard !states.isEmpty else { return }

        try context.transaction {
            for state in states {
                state.status = .pending
                state.reason = .cancelled
            }
            try context.save()
        }
    }

    private func fetchObservationPage(
        generationID: UUID,
        after cursor: String?,
        limit: Int
    ) throws -> [CatalogAssetObservation] {
        var descriptor: FetchDescriptor<CatalogAssetObservation>
        if let cursor {
            descriptor = FetchDescriptor(
                predicate: #Predicate {
                    $0.generationID == generationID && $0.assetID > cursor
                }
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.generationID == generationID }
            )
        }
        descriptor.sortBy = [SortDescriptor(\.assetID)]
        descriptor.fetchLimit = limit + 1
        return try context.fetch(descriptor)
    }

    func analysisWorkStates() throws -> [AnalysisWorkStateSnapshot] {
        try context.fetch(FetchDescriptor<AnalysisWorkState>())
            .sorted { $0.identity < $1.identity }
            .map { $0.snapshot() }
    }

    func analysisWorkState(
        for assetID: AssetID,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkStateSnapshot? {
        try fetchAnalysisWorkState(assetID: assetID.rawValue, capability: capability)?.snapshot()
    }

    func fetchAnalysisWorkState(
        assetID: String,
        capability: AnalysisCapability = .nativeImageFacts
    ) throws -> AnalysisWorkState? {
        let workIdentity = AnalysisWorkState.identity(assetID: assetID, capability: capability)
        return try context.fetch(FetchDescriptor<AnalysisWorkState>(
            predicate: #Predicate { $0.identity == workIdentity }
        )).first
    }

    func requestAnalysis(
        for asset: PhotoAsset,
        generationID: UUID,
        revision: AnalysisCapabilityRevision = .currentNativeImageFacts
    ) throws -> AnalysisWorkStateSnapshot {
        guard revision.capability == .nativeImageFacts else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard try isCurrentGeneration(generationID) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: asset.id.rawValue,
            generationID: generationID
        ), observation.modificationFingerprint == asset.modificationFingerprint else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged)
        }

        let state = try fetchAnalysisWorkState(assetID: asset.id.rawValue, capability: revision.capability)
            ?? AnalysisWorkState(
                assetID: asset.id.rawValue,
                generationID: generationID,
                fingerprint: asset.modificationFingerprint,
                revision: revision
            )
        try context.transaction {
            if state.modelContext == nil {
                context.insert(state)
            }
            state.generationID = generationID
            state.requestedModificationDate = asset.modificationFingerprint.modificationDate
            state.requestedFingerprintIsPresent = asset.modificationFingerprint.isPresent
            state.requestedAnalysisRevision = revision.analysisRevision.rawValue
            state.requestedProviderRuntimeRevision = revision.providerRuntimeRevision.rawValue
            state.status = .pending
            state.reason = nil
            clearCompletedEvidence(from: state)
            try context.save()
        }
        try recordLabelAnalysisState(
            for: asset.id,
            assetRevision: asset.modificationFingerprint,
            state: .pending,
            generationID: generationID
        )
        return state.snapshot()
    }

    func beginAnalysis(_ candidate: AnalysisCommitCandidate) throws -> AnalysisWorkStateSnapshot {
        let state = try guardedWorkState(for: candidate, allowStatuses: [.pending, .running])
        try context.transaction {
            state.status = .running
            state.reason = nil
            try context.save()
        }
        return state.snapshot()
    }

    func markAnalysisRunning(_ candidate: AnalysisCommitCandidate) throws -> AnalysisWorkStateSnapshot {
        try beginAnalysis(candidate)
    }

    func recordAnalysisUnavailable(
        for assetID: AssetID,
        generationID: UUID,
        fingerprint: AssetModificationFingerprint,
        revision: AnalysisCapabilityRevision,
        reason: AnalysisWorkReason
    ) throws -> AnalysisWorkStateSnapshot {
        guard reason != .completedEmpty else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workNotRequested)
        }
        let candidate = AnalysisCommitCandidate(
            generationID: generationID,
            assetID: assetID,
            assetFingerprint: fingerprint,
            revision: revision,
            evidence: AnalysisEvidenceReference(
                identifier: "unavailable",
                assetID: assetID,
                assetFingerprint: fingerprint,
                revision: revision
            )
        )
        let state = try guardedWorkState(for: candidate, allowStatuses: [.pending, .running, .stale])
        try context.transaction {
            state.status = .unavailable
            state.reason = reason
            clearCompletedEvidence(from: state)
            try context.save()
        }
        return state.snapshot()
    }

    // swiftlint:disable function_body_length
    /// Commits only the reference to evidence already durably written by the
    /// evidence boundary. Every guard is evaluated while actor-isolated and
    /// before the SwiftData transaction is saved.
    func commitAnalysis(_ candidate: AnalysisCommitCandidate) throws -> AnalysisCommitResult {
        guard candidate.revision.capability == .nativeImageFacts,
              candidate.evidence.assetID == candidate.assetID,
              candidate.evidence.capability == candidate.revision.capability,
              candidate.evidence.assetFingerprint == candidate.assetFingerprint,
              candidate.evidence.revision == candidate.revision
        else { return .rejected(.evidenceReferenceMismatch) }

        guard try isCurrentGeneration(candidate.generationID) else {
            return .rejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: candidate.assetID.rawValue,
            generationID: candidate.generationID
        ) else { return .rejected(.assetChanged) }
        guard observation.modificationFingerprint == candidate.assetFingerprint else {
            return .rejected(.assetChanged)
        }
        guard let state = try fetchAnalysisWorkState(
            assetID: candidate.assetID.rawValue,
            capability: candidate.revision.capability
        ) else { return .rejected(.workStateMissing) }
        guard state.generationID == candidate.generationID else {
            return .rejected(.generationChanged)
        }
        guard state.requestedAssetFingerprint == candidate.assetFingerprint else {
            return .rejected(.assetChanged)
        }
        guard state.requestedRevision == candidate.revision else {
            return .rejected(.capabilityRevisionChanged)
        }
        guard state.status == .pending || state.status == .running else {
            return state.status == .available
                ? .rejected(.workAlreadyCommitted)
                : .rejected(.workNotRequested)
        }

        try context.transaction {
            state.completedModificationDate = candidate.assetFingerprint.modificationDate
            state.completedFingerprintIsPresent = candidate.assetFingerprint.isPresent
            state.completedAnalysisRevision = candidate.revision.analysisRevision.rawValue
            state.completedProviderRuntimeRevision = candidate.revision.providerRuntimeRevision.rawValue
            state.evidenceIdentifier = candidate.evidence.identifier
            state.status = .available
            state.reason = candidate.outcome == .completedEmpty ? .completedEmpty : nil

            let labelState = try upsertLabelAnalysisState(
                assetID: candidate.assetID,
                assetRevision: candidate.assetFingerprint,
                outcome: .pending,
                generationID: candidate.generationID,
                evidenceReferenceID: candidate.evidence.identifier,
                analysisRevision: candidate.revision.analysisRevision.rawValue,
                confidenceFloor: PhotoLabelTaxonomy.confidenceFloor,
                ambiguityMargin: PhotoLabelTaxonomy.ambiguityMargin
            )
            labelState.publicationPending = true
            if labelState.modelContext == nil {
                context.insert(labelState)
            }
            try rebuildEffectiveLabelProjection(assetID: candidate.assetID)
            try context.save()
        }

        let snapshot = state.snapshot()
        return .committed(snapshot)
    }

    // swiftlint:enable function_body_length

    func commitEvidence(_ candidate: AnalysisCommitCandidate) throws -> AnalysisCommitResult {
        try commitAnalysis(candidate)
    }

    private func clearCompletedEvidence(from state: AnalysisWorkState) {
        state.completedModificationDate = nil
        state.completedFingerprintIsPresent = false
        state.completedAnalysisRevision = nil
        state.completedProviderRuntimeRevision = nil
        state.evidenceIdentifier = nil
    }

    func isCurrentGeneration(_ generationID: UUID) throws -> Bool {
        guard let state = try fetchState() else { return false }
        return state.currentGenerationID == generationID
            && (state.availability == .available || state.availability == .stale)
    }

    func fetchObservation(assetID: String, generationID: UUID) throws -> CatalogAssetObservation? {
        let identity = CatalogAssetObservation.identity(generationID: generationID, assetID: assetID)
        return try context.fetch(FetchDescriptor<CatalogAssetObservation>(
            predicate: #Predicate { $0.identity == identity }
        )).first
    }

    private func guardedWorkState(
        for candidate: AnalysisCommitCandidate,
        allowStatuses: Set<AnalysisWorkStatus>
    ) throws -> AnalysisWorkState {
        guard candidate.revision.capability == .nativeImageFacts else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard try isCurrentGeneration(candidate.generationID) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.generationChanged)
        }
        guard let observation = try fetchObservation(
            assetID: candidate.assetID.rawValue,
            generationID: candidate.generationID
        ), observation.modificationFingerprint == candidate.assetFingerprint else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged)
        }
        guard let state = try fetchAnalysisWorkState(
            assetID: candidate.assetID.rawValue,
            capability: candidate.revision.capability
        ) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workStateMissing)
        }
        guard state.generationID == candidate.generationID,
              state.requestedAssetFingerprint == candidate.assetFingerprint
        else { throw LibraryCatalogStoreError.analysisTransitionRejected(.assetChanged) }
        guard state.requestedRevision == candidate.revision else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.capabilityRevisionChanged)
        }
        guard allowStatuses.contains(state.status) else {
            throw LibraryCatalogStoreError.analysisTransitionRejected(.workNotRequested)
        }
        return state
    }

    // swiftlint:disable function_body_length
    /// Reconciliation changes the work projection only after a complete
    /// generation has been staged. Work for changed or removed assets is made
    /// stale, while matching completed work is retained for reuse.
    func reconcileAnalysisWorkStates(generationID: UUID, assets: [PhotoAsset]) throws {
        let capability = AnalysisCapability.nativeImageFacts
        let revision = AnalysisCapabilityRevision.currentNativeImageFacts
        let currentAssets = Dictionary(uniqueKeysWithValues: assets.map { ($0.id.rawValue, $0) })
        let states = try context.fetch(FetchDescriptor<AnalysisWorkState>()).filter {
            $0.capability == capability
        }
        var byIdentity = Dictionary(uniqueKeysWithValues: states.map { ($0.identity, $0) })

        for asset in assets {
            let identity = AnalysisWorkState.identity(assetID: asset.id.rawValue, capability: capability)
            let state: AnalysisWorkState
            if let existing = byIdentity[identity] {
                state = existing
            } else {
                state = AnalysisWorkState(
                    assetID: asset.id.rawValue,
                    generationID: generationID,
                    fingerprint: asset.modificationFingerprint,
                    revision: revision
                )
                context.insert(state)
                byIdentity[identity] = state
                continue
            }

            let fingerprintChanged = state.requestedAssetFingerprint != asset.modificationFingerprint
            let revisionChanged = state.requestedRevision != revision
            state.generationID = generationID
            if fingerprintChanged || revisionChanged {
                state.requestedModificationDate = asset.modificationFingerprint.modificationDate
                state.requestedFingerprintIsPresent = asset.modificationFingerprint.isPresent
                state.requestedAnalysisRevision = revision.analysisRevision.rawValue
                state.requestedProviderRuntimeRevision = revision.providerRuntimeRevision.rawValue
                state.status = .stale
                state.reason = .revisionStale
                clearCompletedEvidence(from: state)
                try transitionLabelAnalysisState(
                    assetID: asset.id,
                    assetRevision: asset.modificationFingerprint,
                    outcome: .stale,
                    generationID: generationID,
                    analysisRevision: revision.analysisRevision.rawValue
                )
            } else if state.status == .running {
                // A new generation invalidates the old in-flight token. The
                // same revision/fingerprint can be resumed from pending.
                state.status = .pending
                state.reason = .cancelled
                try transitionLabelAnalysisState(
                    assetID: asset.id,
                    assetRevision: asset.modificationFingerprint,
                    outcome: .pending,
                    generationID: generationID,
                    analysisRevision: revision.analysisRevision.rawValue
                )
            } else if state.status == .available, state.evidence == nil {
                // Evidence loss is a cache miss, never successful completion.
                state.status = .pending
                state.reason = nil
                try transitionLabelAnalysisState(
                    assetID: asset.id,
                    assetRevision: asset.modificationFingerprint,
                    outcome: .pending,
                    generationID: generationID,
                    analysisRevision: revision.analysisRevision.rawValue
                )
            }
        }

        for state in states where currentAssets[state.assetID] == nil {
            state.generationID = generationID
            state.status = .stale
            state.reason = .revisionStale
            try transitionLabelAnalysisState(
                assetID: AssetID(rawValue: state.assetID),
                assetRevision: .missing,
                outcome: .stale,
                generationID: generationID,
                analysisRevision: revision.analysisRevision.rawValue
            )
        }
    }
    // swiftlint:enable function_body_length
}
