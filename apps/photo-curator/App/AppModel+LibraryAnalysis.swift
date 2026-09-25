import Foundation
import OSLog

// MARK: - Library analysis lifecycle

extension AppModel {
    func loadLibraryFacetedBrowsing() async {
        await loadLibrarySnapshot()
        await refreshLibraryQuery()
    }

    func applyLibraryQuery(_ query: LibraryQuery) {
        libraryQueryGeneration += 1
        let generation = libraryQueryGeneration
        librarySelection = nil
        Task { [weak self] in
            await self?.loadLibraryQuery(query, generation: generation)
        }
    }

    func updateLibrarySelection(_ selection: LibraryQuerySelectionSnapshot) {
        guard selection.catalogGenerationID == libraryQueryResult?.catalogGenerationID,
              selection.queryIdentity == libraryQueryResult?.query.identity,
              selection.labelProjectionRevision == libraryQueryResult?.labelProjectionRevision,
              let result = libraryQueryResult,
              Set(selection.selectedAssetIDs).isSubset(of: result.completeAssetIDs)
        else { return }
        librarySelection = selection
    }

    func refreshLibraryPersonalLabels() async {
        guard let catalogStore = container.catalogStore else { return }
        libraryPersonalLabels = (try? await catalogStore.personalLabels()) ?? libraryPersonalLabels
    }

    func loadLibraryLabelEditor(assetID: AssetID) async {
        libraryLabelEditorGeneration += 1
        let generation = libraryLabelEditorGeneration
        libraryLabelEditorLoadFailed = false
        guard let catalogStore = container.catalogStore else {
            libraryLabelEditorLoadFailed = true
            return
        }
        do {
            let automatic = try await catalogStore.automaticLabelAssignments(for: assetID)
            let editor = try LibraryLabelEditorSnapshot(
                assetID: assetID,
                automaticLabels: Array(Set(automatic.map(\.labelID))).sorted { $0.rawValue < $1.rawValue },
                effectiveLabels: await catalogStore.effectiveLabels(for: assetID),
                overrides: await catalogStore.labelOverrides(for: assetID),
                personalLabels: await catalogStore.personalLabels(),
                analysisState: await catalogStore.labelAnalysisState(for: assetID)
            )
            guard generation == libraryLabelEditorGeneration else { return }
            libraryLabelEditor = editor
            libraryPersonalLabels = editor.personalLabels
        } catch {
            guard generation == libraryLabelEditorGeneration else { return }
            libraryLabelEditorLoadFailed = true
            logger.error("Library label editor load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setLibraryLabelOverride(
        assetID: AssetID,
        labelID: PhotoLabelID,
        intent: CatalogLabelOverrideIntent
    ) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryCatalogStoreError.unavailable
        }
        try await catalogStore.setLabelOverride(for: assetID, labelID: labelID, intent: intent)
        await refreshLibraryAfterLabelMutation(assetID: assetID)
    }

    func restoreLibraryAutomaticLabel(assetID: AssetID, labelID: PhotoLabelID) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryCatalogStoreError.unavailable
        }
        try await catalogStore.restoreAutomaticLabel(for: assetID, labelID: labelID)
        await refreshLibraryAfterLabelMutation(assetID: assetID)
    }

    func assignLibraryPersonalLabel(_ labelID: UUID, to assetID: AssetID) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryCatalogStoreError.unavailable
        }
        try await catalogStore.assignPersonalLabel(labelID, to: [assetID])
        await refreshLibraryAfterLabelMutation(assetID: assetID)
    }

    func removeLibraryPersonalLabel(_ labelID: UUID, from assetID: AssetID) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryCatalogStoreError.unavailable
        }
        try await catalogStore.removePersonalLabel(labelID, from: [assetID])
        await refreshLibraryAfterLabelMutation(assetID: assetID)
    }

    func createLibraryPersonalLabel(_ name: String, for assetID: AssetID) async throws {
        guard let catalogStore = container.catalogStore else {
            throw LibraryCatalogStoreError.unavailable
        }
        try await catalogStore.createPersonalLabel(name: name, assigningTo: [assetID])
        await refreshLibraryAfterLabelMutation(assetID: assetID)
    }

    private func refreshLibraryAfterLabelMutation(assetID: AssetID) async {
        await loadLibraryLabelEditor(assetID: assetID)
        await refreshLibraryQuery()
    }

    private func refreshLibraryQuery() async {
        libraryQueryGeneration += 1
        let generation = libraryQueryGeneration
        await loadLibraryQuery(libraryQuery, generation: generation)
    }

    private func loadLibraryQuery(_ query: LibraryQuery, generation: Int) async {
        guard let catalogStore = container.catalogStore else {
            libraryQueryLoadFailed = true
            return
        }
        do {
            let presentation = try await catalogStore.queryPresentation(query)
            let result = presentation.result
            let state = await container.catalogState()
            let labelProjectionRevision = try await catalogStore.currentLabelProjectionRevision()
            guard generation == libraryQueryGeneration else { return }
            guard result.catalogGenerationID == state.currentGenerationID,
                  result.labelProjectionRevision == labelProjectionRevision,
                  presentation.observations.allSatisfy({
                      $0.generationID == result.catalogGenerationID
                  })
            else {
                librarySelection = nil
                return
            }
            libraryQuery = query
            libraryQueryResult = result
            libraryPersonalLabels = presentation.personalLabels
            librarySelection = result.selection
            libraryQueryLoadFailed = false
            publishLibrarySnapshot(
                LibrarySnapshotTuple(
                    catalogState: state,
                    observations: presentation.observations,
                    comparisonSnapshot: libraryComparisonSnapshot
                )
            )
        } catch {
            guard generation == libraryQueryGeneration else { return }
            librarySelection = nil
            libraryQueryLoadFailed = true
            logger.error("Library query failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Loads one coherent catalog/group read snapshot. The catalog actor pins
    /// both reads to its published generation; a failed refresh leaves the
    /// previously rendered snapshot untouched rather than reordering photos.
    func loadLibrarySnapshot() async {
        librarySnapshotGeneration += 1
        let generation = librarySnapshotGeneration
        librarySnapshotLoadFailed = false

        let state = await container.catalogState()
        guard generation == librarySnapshotGeneration else { return }

        guard state.availability != .unavailable else {
            librarySnapshotLoadFailed = true
            return
        }

        guard state.availability == .available || state.availability == .stale else {
            publishLibrarySnapshot(
                LibrarySnapshotTuple(catalogState: state, observations: [], comparisonSnapshot: nil)
            )
            return
        }
        guard let catalogStore = container.catalogStore else {
            librarySnapshotLoadFailed = true
            return
        }

        do {
            let observations = try await catalogStore.currentObservations()
            let snapshot = try await catalogStore.currentComparisonSnapshot()
            guard generation == librarySnapshotGeneration else { return }
            let finalState = await container.catalogState()
            guard finalState.currentGenerationID == state.currentGenerationID,
                  finalState.availability == .available || finalState.availability == .stale,
                  observations.allSatisfy({ $0.generationID == finalState.currentGenerationID }),
                  snapshot == nil || snapshot?.catalogGenerationID == finalState.currentGenerationID
            else { return }
            publishLibrarySnapshot(
                LibrarySnapshotTuple(
                    catalogState: finalState,
                    observations: observations,
                    comparisonSnapshot: snapshot
                )
            )
        } catch {
            guard generation == librarySnapshotGeneration else { return }
            librarySnapshotLoadFailed = true
            logger.error("Library snapshot load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshAuthorization() async {
        authorization = await container.photoLibrary.authorizationStatus()
        await container.catalogStore?.recordAuthorization(authorization)

        guard authorization == .authorized || authorization == .limited else {
            analysisLifecyclePermitted = false
            await pauseLibraryAnalysis()
            await container.libraryComparisonCoordinator?.pause()
            return
        }
        analysisLifecyclePermitted = true
    }

    func startup() async {
        switch container.workspaceAvailability {
        case .available:
            if let workspaceImporter = container.workspaceImporter {
                _ = await workspaceImporter.importIfNeeded()
            }
        case .unavailable:
            logger.error(
                "Durable workspace unavailable; legacy selection, analysis, review, and resume flow will continue."
            )
        }
        await refreshAuthorization()
        await refreshDeletionRecovery()
        await refreshResumeSnapshot()
        await refreshLibraryActionRecovery()
        await awaitCatalogReconciliation()
        await reconcileLibraryComparison()
        await startLibraryAnalysis(resume: false)
    }

    /// Reconciliation is awaitable before analysis starts. Photo-library
    /// notifications use the same single-flight task so a scan cannot race the
    /// analysis page reader.
    func reconcileCatalog() {
        Task { [weak self] in
            guard let self else { return }
            await self.awaitCatalogReconciliation()
            await self.reconcileLibraryComparison()
            await self.startLibraryAnalysis(resume: true)
        }
    }

    private func awaitCatalogReconciliation() async {
        guard let catalogStore = container.catalogStore else { return }
        if let task = catalogReconciliationTask {
            catalogReconciliationRequested = true
            await task.value
            return
        }

        let photoLibrary = container.photoLibrary
        let task = Task { [weak self, catalogStore] in
            while true {
                _ = try? await catalogStore.reconcile(using: photoLibrary)
                guard let self, self.catalogReconciliationRequested else { return }
                self.catalogReconciliationRequested = false
            }
        }
        catalogReconciliationTask = task
        await task.value
        catalogReconciliationTask = nil
    }

    /// Starts or resumes catalog enrichment without waiting for the scan or
    /// analysis worker itself.
    func startLibraryAnalysis(resume: Bool) async {
        guard analysisLifecyclePermitted, !analysisResetInFlight,
              authorization == .authorized || authorization == .limited,
              let coordinator = container.libraryAnalysisCoordinator
        else { return }

        if resume, libraryAnalysisHasStarted {
            let currentState = await coordinator.currentState()
            if currentState == .running {
                libraryAnalysisState = currentState
                return
            }
        }
        libraryAnalysisHasStarted = true

        let onProgress: @Sendable (LibraryAnalysisProgress) async -> Void = { [weak self] progress in
            await self?.applyLibraryAnalysisProgress(progress)
        }
        if resume {
            await coordinator.resume(onProgress: onProgress)
        } else {
            await coordinator.start(onProgress: onProgress)
        }
        libraryAnalysisState = await coordinator.currentState()
    }

    /// Scene foreground lifecycle: authorization and reconciliation complete
    /// before resumable enrichment and legacy session work continue.
    func applicationDidBecomeActive() async {
        await refreshAuthorization()
        if analysisLifecyclePermitted {
            await awaitCatalogReconciliation()
            await reconcileLibraryComparison()
            await startLibraryAnalysis(resume: true)
        }
        await resumeIfPaused()
    }

    /// Scene background lifecycle: prevent new catalog work, drain it, then use
    /// the existing session checkpoint path for legacy selection work.
    func applicationDidEnterBackground() async {
        analysisLifecyclePermitted = false
        await pauseLibraryAnalysis()
        await container.libraryComparisonCoordinator?.pause()
        await processing.pauseForBackground()
    }

    private func pauseLibraryAnalysis() async {
        guard let coordinator = container.libraryAnalysisCoordinator else { return }
        await coordinator.pause()
        libraryAnalysisState = await coordinator.currentState()
    }

    private func applyLibraryAnalysisProgress(_ progress: LibraryAnalysisProgress) {
        libraryAnalysisProgress = progress
        libraryAnalysisState = progress.state
    }

    func requestPermission() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        authorization = await container.photoLibrary.requestAuthorization()
        await container.catalogStore?.recordAuthorization(authorization)
        markSeen()
        path = []
        guard authorization == .authorized || authorization == .limited else {
            analysisLifecyclePermitted = false
            await pauseLibraryAnalysis()
            await container.libraryComparisonCoordinator?.pause()
            return
        }
        analysisLifecyclePermitted = true
        await awaitCatalogReconciliation()
        await reconcileLibraryComparison()
        await startLibraryAnalysis(resume: true)
    }

    private func reconcileLibraryComparison() async {
        guard analysisLifecyclePermitted else { return }
        await container.libraryComparisonCoordinator?.reconcile()
    }
}
