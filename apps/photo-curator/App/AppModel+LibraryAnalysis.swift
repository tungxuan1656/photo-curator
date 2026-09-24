import Foundation
import OSLog

// MARK: - Library analysis lifecycle

extension AppModel {
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
