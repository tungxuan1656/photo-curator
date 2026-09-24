import Foundation

extension LibraryAnalysisCoordinator {
    func processBatch(_ batch: [WorkItem], token: UInt64) async throws {
        try await withThrowingTaskGroup(of: WorkOutcome.self) { group in
            var next = 0
            func submit() {
                guard next < batch.count else { return }
                let item = batch[next]
                next += 1
                group.addTask { [weak self] in
                    guard let self else { throw CancellationError() }
                    return try await self.processOne(item)
                }
            }

            for _ in 0 ..< min(Self.maxConcurrentImageWork, batch.count) {
                submit()
            }
            while let outcome = try await group.next() {
                try Task.checkCancellation()
                guard isCurrentRun(token) else {
                    group.cancelAll()
                    throw CancellationError()
                }
                try await finish(outcome, token: token)
                submit()
            }
        }
    }

    func processOne(_ item: WorkItem) async throws -> WorkOutcome {
        do {
            let inFlight = placeholderReference(for: item)
            do {
                _ = try await catalogStore.markAnalysisRunning(
                    AnalysisCommitCandidate(
                        generationID: item.generationID,
                        assetID: item.asset.id,
                        assetFingerprint: item.asset.modificationFingerprint,
                        revision: item.revision,
                        evidence: inFlight
                    )
                )
            } catch let error as LibraryCatalogStoreError {
                if case .analysisTransitionRejected = error {
                    return .obsolete(item)
                }
                return .failure(item, .transientFailure)
            }

            let output: ImageAnalysisOutput
            do {
                let imageLoader = self.imageLoader
                let analyzer = self.analyzer
                output = try await imageWorkArbiter.withPermit(priority: .enrichment) {
                    let image = try await imageLoader.analysisImage(for: item.asset.id)
                    try Task.checkCancellation()
                    return try await analyzer.analyze(AnalysisInput(
                        assetID: item.asset.id,
                        image: image,
                        isScreenshotSubtype: item.asset.mediaSubtype == .screenshot
                    ))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch SelectionError.cancelled {
                throw CancellationError()
            } catch let error as PhotoImageLoadError {
                if error == .cancelled {
                    throw CancellationError()
                }
                return .failure(item, .imageLoad(error))
            } catch let error as SelectionError {
                return .failure(item, Self.failure(for: error))
            } catch {
                if item.asset.source == .iCloud {
                    return .failure(item, .imageLoad(.classify(error)))
                }
                return .failure(item, .transientFailure)
            }

            try Task.checkCancellation()
            guard output.analysis.assetID == item.asset.id else {
                return .failure(item, .unsupported)
            }
            guard output.analysis.analysisVersion == item.revision.analysisRevision.rawValue else {
                return .failure(item, .revisionStale)
            }
            return .success(item, output.analysis)
        } catch is CancellationError {
            throw CancellationError()
        }
    }

    func finish(_ outcome: WorkOutcome, token: UInt64) async throws {
        switch outcome {
        case let .obsolete(item):
            needsDurableReread = true
            lastCheckpointCursor = item.asset.id

        case let .success(item, analysis):
            guard isCurrentRun(token) else { throw CancellationError() }
            let reference: AnalysisEvidenceReference
            do {
                reference = try await evidenceStore.store(
                    analysis,
                    assetFingerprint: item.asset.modificationFingerprint,
                    revision: item.revision
                )
            } catch let error as LibraryAnalysisEvidenceStoreError {
                try await finishFailure(item, failure: Self.failure(for: error), token: token)
                return
            } catch {
                try await finishFailure(item, failure: .transientFailure, token: token)
                return
            }

            guard isCurrentRun(token) else { throw CancellationError() }
            try Task.checkCancellation()
            let candidate = AnalysisCommitCandidate(
                generationID: item.generationID,
                assetID: item.asset.id,
                assetFingerprint: item.asset.modificationFingerprint,
                revision: item.revision,
                evidence: reference
            )
            let result = try await catalogStore.commitAnalysis(candidate)
            guard result.committed else {
                needsDurableReread = true
                return
            }
            do {
                try await publishLabels(for: item, analysis: analysis)
            } catch {
                needsDurableReread = true
                return
            }
            guard isCurrentRun(token) else { return }
            recordDurableCompletion(assetID: item.asset.id, analyzed: true)
            latestFailure = nil
            await publish(token: token, currentAssetID: item.asset.id)
            await saveCheckpointIfDue(token: token)

        case let .failure(item, failure):
            try await finishFailure(item, failure: failure, token: token)
        }
    }

    func finishFailure(
        _ item: WorkItem,
        failure: LibraryAnalysisFailure,
        token: UInt64
    ) async throws {
        guard isCurrentRun(token) else { throw CancellationError() }
        let reason = Self.catalogReason(for: failure)
        do {
            _ = try await catalogStore.recordAnalysisUnavailable(
                for: item.asset.id,
                generationID: item.generationID,
                fingerprint: item.asset.modificationFingerprint,
                revision: item.revision,
                reason: reason
            )
        } catch let error as LibraryCatalogStoreError {
            if case .analysisTransitionRejected = error {
                needsDurableReread = true
                return
            }
            throw error
        }
        do {
            try await catalogStore.recordLabelAnalysisState(
                for: item.asset.id,
                assetRevision: item.asset.modificationFingerprint,
                state: Self.labelInputState(for: failure),
                generationID: item.generationID
            )
        } catch let error as LibraryCatalogStoreError {
            if case .analysisTransitionRejected = error {
                needsDurableReread = true
                return
            }
            throw error
        }
        latestFailure = LibraryAnalysisFailureStatus(
            failure: failure,
            retryPolicy: Self.retryPolicy(for: failure)
        )
        recordDurableCompletion(assetID: item.asset.id, analyzed: false)
        await publish(token: token, currentAssetID: item.asset.id)
        await saveCheckpointIfDue(token: token)
        if case .imageLoad(.accessRequired) = failure {
            throw CancellationError()
        }
    }

    func saveCheckpointIfDue(token: UInt64) async {
        completedSinceCheckpoint += 1
        let dueByCount = completedSinceCheckpoint >= Self.checkpointAssetInterval
        let dueByTime = Date().timeIntervalSince(lastCheckpointDate) >= Self.checkpointTimeInterval
        guard dueByCount || dueByTime else { return }
        await saveCheckpoint(force: true, token: token)
    }

    func saveCheckpoint(force: Bool, token: UInt64) async {
        guard force, isCurrentRun(token), let generationID else { return }
        let checkpoint = LibraryAnalysisCheckpoint(
            catalogGenerationID: generationID,
            capability: capability,
            revision: revision,
            resumeCursor: lastCheckpointCursor,
            scheduledAssetCount: scheduledAssetCount,
            updatedAt: Date()
        )
        do {
            try await checkpointStore.save(checkpoint)
            completedSinceCheckpoint = 0
            lastCheckpointDate = Date()
        } catch {
            // Durable catalog state remains authoritative if the handoff fails.
        }
    }

    func loadResumeCursor(for generationID: UUID) async -> AssetID? {
        guard let checkpoint = try? await checkpointStore.load(
            catalogGenerationID: generationID,
            capability: capability,
            revision: revision
        ) else { return nil }
        return checkpoint.resumeCursor
    }

    func publish(token: UInt64, currentAssetID: AssetID?, force: Bool = false) async {
        guard isCurrentRun(token), let progressHandler else { return }
        if !force, Date().timeIntervalSince(lastProgressPublicationDate) < Self.progressInterval {
            return
        }
        lastProgressPublicationDate = Date()
        await progressHandler(LibraryAnalysisProgress(
            state: state,
            generationID: generationID,
            capability: capability,
            revision: revision,
            completed: completed,
            total: total,
            analyzed: analyzed,
            unavailable: unavailable,
            scheduledAssetCount: scheduledAssetCount,
            currentAssetID: currentAssetID,
            latestFailure: latestFailure
        ))
    }

    func recordDurableCompletion(assetID: AssetID, analyzed didAnalyze: Bool) {
        guard countedAssetIDs.insert(assetID).inserted else { return }
        completed += 1
        if didAnalyze {
            analyzed += 1
        } else if unavailableAssetIDs.insert(assetID).inserted {
            unavailable += 1
        }
        lastCheckpointCursor = assetID
    }

    func beginGenerationBookkeeping(generationID: UUID, total: Int) {
        self.generationID = generationID
        self.total = total
        completed = 0
        analyzed = 0
        unavailable = 0
        scheduledAssetCount = 0
        countedAssetIDs.removeAll()
        unavailableAssetIDs.removeAll()
        lastCheckpointCursor = nil
        completedSinceCheckpoint = 0
        lastCheckpointDate = Date()
        lastProgressPublicationDate = Date.distantPast
        latestFailure = nil
    }

    func clearRunBookkeeping() {
        generationID = nil
        total = 0
        completed = 0
        analyzed = 0
        unavailable = 0
        scheduledAssetCount = 0
        countedAssetIDs.removeAll()
        unavailableAssetIDs.removeAll()
        lastCheckpointCursor = nil
        completedSinceCheckpoint = 0
        lastCheckpointDate = Date()
        lastProgressPublicationDate = Date.distantPast
        needsDurableReread = false
        latestFailure = nil
    }
}
