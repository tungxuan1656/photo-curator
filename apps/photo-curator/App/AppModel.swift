import Foundation
import Observation
import OSLog
import UIKit

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
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "session"
    )

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
        processing = ProcessingModel(
            coordinator: coordinator,
            checkpointStore: container.checkpointStore,
            authorization: { [photoLibrary = container.photoLibrary] in
                await photoLibrary.authorizationStatus()
            }
        )
        // Ownership rule (leave-safe): Home retains the session so owned work
        // may continue; ownership clears only on discard/completion.
        processing.onCompleted = { [weak self] _ in self?.activeSessionID = nil }
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
        // Double-tap guard: a session task is already starting/running, so a
        // second Start would mint a new session + route the old task rejects —
        // desync. Ignore while the run task exists.
        guard !processing.isRunning else { return }
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
        // Ownership guard: foreground resumes only owned work. Home retains
        // ownership (leave-safe); a nil/mismatched session means ownerless
        // work that must never resume on its own.
        guard let active = activeSessionID, active == processing.sessionID else { return }
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

    /// Partial-result finalizer for Continue Without Them: builds a persisted
    /// SelectionResult from the available cached analyses so ReviewReady has
    /// data, then routes. No-op when nothing analyzable exists (the attention
    /// screen stays put).
    func continueWithoutUnavailable() async {
        guard let sessionID = activeSessionID else { return }
        do {
            let checkpoint = try? await container.checkpointStore.load(sessionID: sessionID)
            let completedIDs = Set(checkpoint?.completedAssetIDs ?? [])
            let assets = confirmedSourceAssets()
            var analyses: [AssetID: PhotoAnalysis] = [:]
            for asset in assets where completedIDs.contains(asset.id) {
                if let hit = await container.analysisCache.analysis(for: asset.id) {
                    analyses[asset.id] = hit
                }
            }
            // Minimum-analyzable rule: no partial result without at least one analysis.
            guard !analyses.isEmpty else { return }
            let available = assets.filter { analyses[$0.id] != nil }
            let engineOut = try container.selectionEngine.select(
                assets: available,
                analyses: analyses,
                configuration: AppConfiguration.default.selection,
                feedback: nil
            )
            let partial = SelectionResult(
                sessionID: sessionID,
                selectedAssetIDs: engineOut.selectedAssetIDs,
                rejectedAssetIDs: engineOut.rejectedAssetIDs,
                decisions: engineOut.decisions,
                generatedAt: engineOut.generatedAt,
                engineVersion: engineOut.engineVersion
            )
            try await container.checkpointStore.saveResult(partial)
            let done = SessionCheckpoint(
                sessionID: sessionID,
                stage: ProcessingStage.finalSelection.rawValue,
                completedAssetIDs: Array(analyses.keys),
                sourceAssetIDs: confirmedSourceIDs,
                configVersion: AppConfiguration.default.configVersion,
                analysisVersion: PhotoAnalysis.currentVersion,
                updatedAt: Date()
            )
            try await container.checkpointStore.save(done)
            showReview(for: sessionID)
        } catch {
            logger
                .error("Continuing without unavailable photos failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func goHome() {
        // Leave-safe: ownership is retained so the run may continue after Home;
        // activeSessionID clears only on discard/completion.
        path.removeAll()
    }

    /// Discard: cancel the run, await its termination, delete the checkpoint +
    /// persisted result, go home. Termination is awaited BEFORE deletion: the
    /// pipeline's cancel path writes a final checkpoint that would otherwise
    /// recreate data after deletion. Cleanup failures are logged, never silent.
    /// The §4.3 confirmation lives in the view.
    func discardCuration() {
        processing.cancel()
        let sessionID = activeSessionID
        activeSessionID = nil
        path.removeAll()
        guard let sessionID else { return }
        let store = container.checkpointStore
        Task {
            await processing.awaitTermination()
            do {
                try await store.delete(sessionID: sessionID)
                try await store.deleteResult(sessionID: sessionID)
            } catch {
                logger.error("Discarding curation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func markSeen() {
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.seenWelcomeKey)
    }
}
