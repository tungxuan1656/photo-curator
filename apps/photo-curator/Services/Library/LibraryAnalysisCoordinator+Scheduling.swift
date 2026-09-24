import Foundation

extension LibraryAnalysisCoordinator {
    func reconcileAndAnalyze(token: UInt64, schedule: ScheduleMode) async throws {
        var firstPass = true
        while true {
            try Task.checkCancellation()
            guard isCurrentRun(token) else { throw CancellationError() }

            let generation = try await catalogStore.currentGeneration()
            guard let generation else {
                if firstPass {
                    state = .waitingForCatalog
                    await publish(token: token, currentAssetID: nil, force: true)
                }
                return
            }
            firstPass = false

            if generationID != generation.id {
                beginGenerationBookkeeping(generationID: generation.id, total: generation.assetCount)
            }

            guard generation.assetCount > 0 else {
                state = .waitingForCatalog
                await publish(token: token, currentAssetID: nil, force: true)
                return
            }
            needsDurableReread = false

            let reread = try await analyzePages(
                generationID: generation.id,
                token: token,
                schedule: schedule
            )
            if reread {
                continue
            }
            return
        }
    }

    func analyzePages(
        generationID: UUID,
        token: UInt64,
        schedule: ScheduleMode
    ) async throws -> Bool {
        var cursor = await loadResumeCursor(for: generationID)
        var didWrap = cursor == nil
        while true {
            try Task.checkCancellation()
            guard isCurrentRun(token) else { throw CancellationError() }
            let page = try await catalogStore.analysisWorkPage(
                generationID: generationID,
                after: cursor,
                limit: Self.batchSize,
                capability: capability
            )
            let states = Dictionary(uniqueKeysWithValues: page.workStates.map { ($0.assetID, $0) })
            let pageWork = try await makePageWork(
                page.observations,
                states: states,
                generationID: generationID,
                schedule: schedule,
                token: token
            )
            if !pageWork.isEmpty {
                try await processBatch(pageWork, token: token)
            }
            if needsDurableReread {
                return true
            }
            guard page.hasMore else {
                if didWrap {
                    return false
                }
                didWrap = true
                cursor = nil
                continue
            }
            cursor = page.nextCursor
        }
    }

    func makePageWork(
        _ observations: [CatalogAssetObservationSnapshot],
        states: [AssetID: AnalysisWorkStateSnapshot],
        generationID: UUID,
        schedule: ScheduleMode,
        token: UInt64
    ) async throws -> [WorkItem] {
        var pageWork: [WorkItem] = []
        pageWork.reserveCapacity(observations.count)
        for observation in observations {
            try Task.checkCancellation()
            guard isCurrentRun(token) else { throw CancellationError() }
            if let item = try await prepare(
                observation: observation,
                existing: states[observation.asset.id],
                generationID: generationID,
                schedule: schedule
            ) {
                pageWork.append(item)
            }
        }
        return pageWork
    }

    func prepare(
        observation: CatalogAssetObservationSnapshot,
        existing: AnalysisWorkStateSnapshot?,
        generationID: UUID,
        schedule: ScheduleMode
    ) async throws -> WorkItem? {
        let asset = observation.asset

        if let reference = reusableEvidence(from: existing, for: asset) {
            do {
                if let analysis = try await evidenceStore.load(reference, revision: revision) {
                    guard analysis.assetID == asset.id else { return nil }
                    recordDurableCompletion(assetID: asset.id, analyzed: true)
                    return nil
                }
            } catch {
                // Cache loss or mismatch is a miss, not completion.
            }
        }

        if let existing, shouldSkip(existing, explicitRetry: schedule == .explicitRetry) {
            if existing.status == .unavailable {
                recordDurableCompletion(assetID: asset.id, analyzed: false)
            }
            return nil
        }

        do {
            let requested = try await catalogStore.requestAnalysis(
                for: asset,
                generationID: generationID,
                revision: revision
            )
            guard requested.requestedAssetFingerprint == asset.modificationFingerprint,
                  requested.requestedRevision == revision
            else { return nil }
            scheduledAssetCount += 1
            return WorkItem(asset: asset, generationID: generationID, revision: revision)
        } catch let error as LibraryCatalogStoreError {
            if case .analysisTransitionRejected = error {
                return nil
            }
            throw error
        }
    }

    func reusableEvidence(
        from state: AnalysisWorkStateSnapshot?,
        for asset: PhotoAsset
    ) -> AnalysisEvidenceReference? {
        guard let state,
              state.status == .available,
              state.requestedAssetFingerprint == asset.modificationFingerprint,
              state.requestedRevision == revision
        else { return nil }
        return state.evidence
    }

    func isEligibleForSchedule(
        _ state: AnalysisWorkStateSnapshot,
        explicitRetry: Bool
    ) -> Bool {
        if state.status == .stale || state.status == .running {
            return true
        }
        switch state.retryEligibility {
        case .automatic, .whenAvailable:
            return true
        case .explicit:
            return explicitRetry
        case .afterRevisionChange, .never:
            return false
        }
    }

    func shouldSkip(_ state: AnalysisWorkStateSnapshot, explicitRetry: Bool) -> Bool {
        state.status != .available && !isEligibleForSchedule(state, explicitRetry: explicitRetry)
    }
}
