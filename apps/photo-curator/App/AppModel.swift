import Foundation
import Observation
import UIKit

/// Task-2 coordinator-backed run state. Defined in AppModel.swift so the feat-006
/// Task-2 commit list stays exact; Task 3 views read state/progress via
/// `AppModel.processing`. Navigation stays in AppModel (no path access here);
/// automatic result-present routing is feat-012, so completion does NOT navigate.
@MainActor
@Observable
final class ProcessingModel {
    var state: ProcessingState = .idle
    var progress: ProcessingProgress = .zero

    private let coordinator: SelectionSessionCoordinator
    private let checkpointStore: SessionCheckpointStore
    private var request: SelectionRequest?
    private var sourceAssets: [PhotoAsset] = []
    private var runTask: Task<Void, Never>?

    init(coordinator: SelectionSessionCoordinator, checkpointStore: SessionCheckpointStore) {
        self.coordinator = coordinator
        self.checkpointStore = checkpointStore
    }

    var sessionID: SessionID? {
        request?.sessionID
    }

    func start(request: SelectionRequest, sourceAssets: [PhotoAsset]) {
        runTask?.cancel()
        self.request = request
        self.sourceAssets = sourceAssets
        progress = .zero
        state = .preparing
        runTask = Task { await execute() }
    }

    func cancel() {
        runTask?.cancel()
    }

    func retry() {
        guard let request else { return }
        switch state {
        case .paused, .cancelled, .failed:
            start(request: request, sourceAssets: sourceAssets)
        case .idle, .preparing, .running, .cancelling, .completed:
            return
        }
    }

    /// Foreground resume: retries ONLY when paused/cancelled with a saved checkpoint.
    /// Never restarts completed jobs.
    func resumeIfPaused() async {
        guard let request else { return }
        switch state {
        case .paused, .cancelled:
            break
        case .idle, .preparing, .running, .cancelling, .completed, .failed:
            return
        }
        guard (try? await checkpointStore.load(sessionID: request.sessionID)) != nil else { return }
        retry()
    }

    /// Background path: writes a safe checkpoint now (preserving already-completed
    /// IDs), then cancels the run so no new work starts while backgrounded.
    /// The pipeline's cancel path checkpoints again before throwing, so resume
    /// never drops completed work.
    func pauseForBackground() async {
        switch state {
        case .preparing, .running:
            break
        case .idle, .cancelling, .paused, .completed, .cancelled, .failed:
            return
        }
        guard let request else { return }
        let completed = (try? await checkpointStore.load(sessionID: request.sessionID))?.completedAssetIDs ?? []
        let stage: ProcessingStage
        if case let .running(live) = state {
            stage = live.stage
        } else {
            stage = .loading
        }
        await coordinator.checkpointNow(sessionID: request.sessionID, completed: completed, stage: stage)
        runTask?.cancel()
    }

    private func execute() async {
        guard let request else { return }
        let assets = sourceAssets
        do {
            let result = try await coordinator.run(request: request, sourceAssets: assets) { [weak self] update in
                await self?.apply(update)
            }
            let total = result.selectedAssetIDs.count + result.rejectedAssetIDs.count
            state = .completed(
                sessionID: request.sessionID,
                analyzed: total,
                unavailable: max(assets.count - total, 0)
            )
        } catch {
            if error is CancellationError {
                state = .paused(reason: "Curation paused. Progress is saved.")
            } else if case SelectionError.cancelled = error {
                state = .paused(reason: "Curation paused. Progress is saved.")
            } else {
                state = .failed(SelectionSessionCoordinator.userError(for: error, unavailable: 0))
            }
        }
    }

    private func apply(_ update: ProcessingProgress) {
        progress = update
        state = .running(update)
    }
}

/// G1 skeleton session state. Runs on the `PhotoLibraryService` protocol (Noop in G1);
/// real permission wiring landed in feat-002.
@MainActor
@Observable
final class AppModel {
    private static let seenWelcomeKey = "hasSeenWelcome"

    var path: [AppRoute] = []
    var authorization: PhotoLibraryAuthorization = .notDetermined
    var hasSeenWelcome: Bool
    var sourceState: SourceLoadState = .idle
    var allAssets: [PhotoAsset] = []
    var selectedIDs = Set<AssetID>()
    var filter = SourceFilter()
    var unavailableCount = 0
    var confirmedSourceIDs: [AssetID] = []
    var activeSessionID: SessionID?
    let processing: ProcessingModel
    private var isRequesting = false
    private var sourceGeneration = 0

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        hasSeenWelcome = UserDefaults.standard.bool(forKey: Self.seenWelcomeKey)
        let coordinator = SelectionSessionCoordinator(
            imageLoader: container.imageLoader,
            analyzer: container.analyzer,
            analysisCache: container.analysisCache,
            checkpointStore: container.checkpointStore,
            engine: container.selectionEngine,
            config: .default
        )
        processing = ProcessingModel(coordinator: coordinator, checkpointStore: container.checkpointStore)
    }

    func showPermissionEducation() {
        if !path.contains(.permissionEducation) {
            path.append(.permissionEducation)
        }
    }

    func skipPermission() {
        markSeen()
        path = []
    }

    func refreshAuthorization() async {
        authorization = await container.photoLibrary.authorizationStatus()
    }

    func requestPermission() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        authorization = await container.photoLibrary.requestAuthorization()
        markSeen()
        path = []
    }

    func presentPicker() {
        container.photoLibrary.presentLimitedLibraryPicker()
    }

    var photoLibrary: any PhotoLibraryService {
        container.photoLibrary
    }

    var imageLoader: any PhotoImageLoader {
        container.imageLoader
    }

    var sourceByID: [AssetID: PhotoAsset] {
        Dictionary(uniqueKeysWithValues: allAssets.map { ($0.id, $0) })
    }

    var filteredAssets: [PhotoAsset] {
        filter.apply(to: allAssets)
    }

    var summary: SelectionSummary {
        SelectionSummary(
            selectedCount: selectedIDs.count,
            unavailableCount: unavailableCount
        )
    }

    /// Continue is valid only against fresh loaded source with a non-empty
    /// selection; mid-refresh/error states must not freeze a stale snapshot.
    var canContinueToSummary: Bool {
        sourceState == .loaded && !selectedIDs.isEmpty
    }

    func showSourceSelection() {
        guard path.last != .sourceSelection else { return }
        path.append(.sourceSelection)
    }

    func toggleSelection(_ id: AssetID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func loadSource() async {
        sourceGeneration += 1
        let generation = sourceGeneration
        sourceState = .loading
        do {
            let assets = try await container.photoLibrary.fetchAssets()
            guard generation == sourceGeneration else { return }
            allAssets = assets
            let live = Set(assets.map(\.id))
            let missing = selectedIDs.subtracting(live)
            unavailableCount = missing.count
            selectedIDs.subtract(missing)
            if assets.isEmpty {
                sourceState = .empty
            } else {
                sourceState = .loaded
            }
        } catch {
            guard generation == sourceGeneration else { return }
            let status = await container.photoLibrary.authorizationStatus()
            if status == .denied || status == .restricted {
                sourceState = .denied
            } else {
                sourceState = .failed
            }
        }
    }

    func refreshSourceAfterLibraryChange() async {
        await loadSource()
    }

    /// Freeze-only handoff for the feat-006 coordinator. No navigation here:
    /// S05 navigates via `continueToSummary()`; S06 Start calls this and stops
    /// (Processing transition is owned by feat-006).
    func freezeConfirmedSource() {
        let live = sourceByID
        let missing = selectedIDs.subtracting(Set(live.keys))
        selectedIDs.subtract(missing)
        unavailableCount += missing.count
        let liveAssets = selectedIDs.compactMap { live[$0] }
        confirmedSourceIDs = liveAssets.sorted {
            let left = $0.creationDate ?? .distantPast
            let right = $1.creationDate ?? .distantPast
            if left != right {
                return left < right
            }
            return $0.id.rawValue < $1.id.rawValue
        }.map(\.id)
    }

    /// S05 Continue: freeze the snapshot, then push S06.
    func continueToSummary() {
        freezeConfirmedSource()
        guard path.last != .summary else { return }
        path.append(.summary)
    }

    /// Snapshot in frozen order: maps the frozen IDs back to assets so the
    /// coordinator consumes the same stable chrono order that was confirmed.
    func confirmedSourceAssets() -> [PhotoAsset] {
        let live = sourceByID
        return confirmedSourceIDs.compactMap { live[$0] }
    }

    // MARK: - feat-006 curation intents

    /// S06 Start: takes NO asset args (reads the feat-004 frozen chrono snapshot),
    /// creates the request ID here, persists a loading shell BEFORE navigating so
    /// termination before the first batch still resumes, then always appends
    /// `.processing` with the session ID attached.
    func startCuration() {
        guard authorization == .authorized || authorization == .limited else {
            showPermissionEducation()
            return
        }
        freezeConfirmedSource()
        let assets = confirmedSourceAssets()
        guard !assets.isEmpty else { return }
        let request = SelectionRequest(
            sessionID: SessionID(rawValue: UUID()),
            sourceAssetIDs: confirmedSourceIDs,
            config: .default
        )
        activeSessionID = request.sessionID
        processing.start(request: request, sourceAssets: assets)
        let store = container.checkpointStore
        let shell = SessionCheckpoint(
            sessionID: request.sessionID,
            stage: ProcessingStage.loading.rawValue,
            completedAssetIDs: [],
            sourceAssetIDs: request.sourceAssetIDs,
            configVersion: request.config.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            updatedAt: Date()
        )
        Task {
            try? await store.save(shell)
            path.append(.processing(sessionID: request.sessionID))
        }
    }

    func cancelProcessing() {
        processing.cancel()
    }

    func retryProcessing() {
        processing.retry()
    }

    func resumeIfPaused() async {
        await processing.resumeIfPaused()
    }

    func checkpointForBackground() async {
        await processing.pauseForBackground()
    }

    func showReview(for sessionID: SessionID) {
        path.append(.reviewReady(sessionID: sessionID))
    }

    /// ReviewReadyView caller: persisted result when the run finished, nil otherwise.
    func loadResult(for sessionID: SessionID) async -> SelectionResult? {
        try? await container.checkpointStore.loadResult(sessionID: sessionID)
    }

    func openSettings() {
        path.append(.settings)
    }

    /// System Settings URL intent (Task 4 caller alongside the `openSettings()` route).
    func openSettingsURL() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func goHome() {
        activeSessionID = nil
        path.removeAll()
    }

    /// Discard: cancel the run, delete the checkpoint + persisted result, go home.
    /// The §4.3 confirmation lives in the view.
    func discardCuration() {
        processing.cancel()
        let sessionID = activeSessionID
        activeSessionID = nil
        path.removeAll()
        guard let sessionID else { return }
        let store = container.checkpointStore
        Task {
            try? await store.delete(sessionID: sessionID)
            try? await store.deleteResult(sessionID: sessionID)
        }
    }

    private func markSeen() {
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.seenWelcomeKey)
    }
}
