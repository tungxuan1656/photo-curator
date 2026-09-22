// swiftlint:disable file_length - feat-015 resume snapshot pushed AppModel past 500; split in a later task.
import Foundation
import Observation
import OSLog
import UIKit

/// Cold-start resume snapshot for the S17 Home card. In-memory only; it
/// mirrors the newest on-disk checkpoint and clears once its session is
/// owned, discarded, or completed.
struct ResumeSnapshot: Sendable, Equatable {
    let sessionID: SessionID
    let stage: String
    let sourceCount: Int
    let updatedAt: Date
    let hasResult: Bool
    let hasSaveState: Bool

    /// The persisted stage stays data-only; presentation resolves its copy in the View layer.
    var processingStage: ProcessingStage? {
        ProcessingStage(rawValue: stage)
    }
}

/// G1 skeleton session state. Runs on the `PhotoLibraryService` protocol (Noop in G1);
/// real permission wiring landed in feat-002.
@MainActor
@Observable
final class AppModel {
    private static let seenWelcomeKey = "hasSeenWelcome"
    private static let appLanguageKey = "appLanguage"

    var path: [AppRoute] = []
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageKey)
        }
    }

    var authorization: PhotoLibraryAuthorization = .notDetermined
    var hasSeenWelcome: Bool
    var sourceState: SourceLoadState = .idle
    var allAssets: [PhotoAsset] = []
    var selectedIDs = Set<AssetID>()
    var filter = SourceFilter()
    var unavailableCount = 0
    var confirmedSourceIDs: [AssetID] = []
    var activeSessionID: SessionID?
    /// feat-034: Home intent handoff. Selects the entry only; review actions
    /// keep the same meaning for both intents. The per-session map is the
    /// reader: `pendingReviewIntent` is the write-only handoff captured at
    /// review entry so a later session never inherits a stale label.
    var pendingReviewIntent: ReviewIntent = .album
    var reviewIntentForSession: [SessionID: ReviewIntent] = [:]

    func reviewIntent(for sessionID: SessionID) -> ReviewIntent {
        reviewIntentForSession[sessionID] ?? pendingReviewIntent
    }

    /// Most recent session, retained across completion so late cleanup (discard)
    /// still finds its data. Cleared only when that session's data is deleted.
    var lastSessionID: SessionID?
    var resumeSnapshot: ResumeSnapshot?
    var confirmingNewSession = false
    /// In-flight partial finalization (Continue Without Them), scoped per
    /// session: first tap owns it, repeat taps join it.
    private var finalizeFlight: (session: SessionID, task: Task<Void, Never>)?
    /// In-flight PhotoKit save, scoped per session: S14 Save claims it
    /// atomically; repeated taps join or stay disabled, never a second export.
    var saveFlight: (session: SessionID, task: Task<SaveOutcome, Never>)?
    let modelInstallation: ModelInstallationModel
    let processing: ProcessingModel
    private var isRequesting = false
    private var sourceGeneration = 0
    let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "session"
    )

    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        appLanguage = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: Self.appLanguageKey) ?? ""
        ) ?? .systemDefault
        hasSeenWelcome = UserDefaults.standard.bool(forKey: Self.seenWelcomeKey)
        container.memoryPressure.start()
        modelInstallation = ModelInstallationModel(service: container.modelInstallation)
        let coordinator = SelectionSessionCoordinator(
            imageLoader: container.imageLoader,
            analyzer: container.analyzer,
            analysisCache: container.analysisCache,
            checkpointStore: container.checkpointStore,
            engine: container.selectionEngine,
            config: .default,
            pressure: container.memoryPressure,
            tierCProvider: container.tierCProvider,
            semanticJuryProvider: container.semanticJuryProvider,
            qualityRunner: QualityCurationRunner(
                modelInstallation: container.modelInstallation,
                judge: container.qwenJudge,
                memoryPressure: container.memoryPressure,
                policy: .default
            )
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
        await modelInstallation.startupCheck()
        await refreshAuthorization()
        await refreshResumeSnapshot()
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

    var requestedQualityMode: QualityMode {
        AppConfiguration.default.quality.mode(
            for: .qualityQwen2B,
            sourceCount: summary.selectedCount
        )
    }

    var qualityModelNeededForCurrentSelection: Bool {
        requestedQualityMode.requiresModel
    }

    /// True when any confirmed source asset needs iCloud fetch (S06 copy condition).
    var summaryHasICloudAssets: Bool {
        let live = sourceByID
        return confirmedSourceIDs.compactMap { live[$0] }.contains { $0.source == .iCloud }
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

    /// feat-034: both Home intents route to one workspace. The intent selects
    /// the handoff only; review actions keep the same meaning either way.
    func startCleanupReview() {
        pendingReviewIntent = .cleanup
        reviewIntentForSession.removeAll()
        showSourceSelection()
    }

    /// feat-034: both Home intents route to one workspace. The intent selects
    /// the handoff only; review actions keep the same meaning either way.
    func startAlbumReview() {
        pendingReviewIntent = .album
        reviewIntentForSession.removeAll()
        showSourceSelection()
    }

    func toggleSelection(_ id: AssetID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAllFiltered() {
        selectedIDs = SourceSelectionMutation.selectAllFiltered(
            filteredIDs: filteredAssets.map(\.id),
            selectedIDs: selectedIDs
        )
    }

    func deselectAllFiltered() {
        selectedIDs = SourceSelectionMutation.deselectAllFiltered(
            filteredIDs: filteredAssets.map(\.id),
            selectedIDs: selectedIDs
        )
    }

    func updateDragSelection(
        initialSelected: Set<AssetID>,
        startIndex: Int,
        currentIndex: Int,
        isSelecting: Bool
    ) {
        guard let updatedSelection = SourceSelectionMutation.updateDragSelection(
            filteredIDs: filteredAssets.map(\.id),
            initialSelected: initialSelected,
            startIndex: startIndex,
            currentIndex: currentIndex,
            isSelecting: isSelecting
        )
        else { return }
        selectedIDs = updatedSelection
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

    /// Session-owned review state for S09–S11. Nil until beginReview succeeds.
    var reviewModel: ReviewModel?
    /// Inline retry note for a no-op review retry (already on the failed
    /// route); set by showReview, rendered by ReviewLoadFailedView.
    var reviewLoadRetryFailed = false
}

// MARK: - feat-006 curation intents

extension AppModel {
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
        let modelAvailable = modelInstallation.isInstalled
        let request = SelectionRequest(
            sessionID: SessionID(rawValue: UUID()),
            sourceAssetIDs: confirmedSourceIDs,
            config: .default,
            qualityMode: requestedQualityMode,
            qualityModelAvailableAtStart: modelAvailable
        )
        let supersededID = activeSessionID
        // Supersede rule: exactly one owned session, no multi-session support.
        // A new start replaces the retained session: cancel the old task if
        // running, clean its checkpoint + result (abandoned session, logged),
        // then run the new session. An in-flight save for the superseded
        // session is cancelled too: no orphan export may write into it.
        activeSessionID = request.sessionID
        lastSessionID = request.sessionID
        resumeSnapshot = nil
        finalizeFlight?.task.cancel()
        finalizeFlight = nil
        if processing.isRunning {
            processing.cancel()
            Task {
                // The save flight's final SaveState write must land before the
                // old files are deleted, or it resurrects a deleted file.
                await cancelSave(for: supersededID)
                await processing.awaitTermination()
                await deleteSessionData(supersededID, context: "Superseded curation")
                beginRun(request: request, assets: assets, modelAvailable: modelAvailable)
            }
        } else {
            if supersededID != nil {
                Task {
                    await cancelSave(for: supersededID)
                    await deleteSessionData(supersededID, context: "Superseded curation")
                }
            }
            beginRun(request: request, assets: assets, modelAvailable: modelAvailable)
        }
    }

    /// Shared run opener: starts the model, persists a loading shell BEFORE
    /// navigating so termination before the first batch still resumes, then
    /// appends `.processing` with the session ID attached — but only while
    /// still owned (a supersede/discard in flight must not append a stale route).
    private func beginRun(request: SelectionRequest, assets: [PhotoAsset], modelAvailable: Bool) {
        processing.start(request: request, sourceAssets: assets, modelAvailable: modelAvailable)
        let store = container.checkpointStore
        let shell = SessionCheckpoint(
            sessionID: request.sessionID,
            stage: ProcessingStage.loading.rawValue,
            completedAssetIDs: [],
            sourceAssetIDs: request.sourceAssetIDs,
            configVersion: request.config.configVersion,
            analysisVersion: PhotoAnalysis.currentVersion,
            qualityIdentity: QualityCheckpointIdentity.expected(
                for: request.qualityMode,
                modelAvailableAtStart: request.qualityModelAvailableAtStart
            ),
            updatedAt: Date()
        )
        Task {
            try? await store.save(shell)
            guard request.sessionID == activeSessionID else { return }
            path.append(.processing(sessionID: request.sessionID))
        }
    }

    /// Session cleanup: ALL deletes always attempted independently, each
    /// failure logged. Absent files already count as success (idempotent),
    /// so cleanup never short-circuits. Returns true when all succeeded.
    /// Shared with the Save extension (`finishSave` deletes the completed
    /// session's data with the same ordering as discard).
    /// Durable workspace rows join the same rule via `deleteScope`: absent
    /// scopes already count as success, so no orphaned scope survives.
    func deleteSessionData(_ sessionID: SessionID?, context: String) async -> Bool {
        guard let sessionID else { return true }
        var cleaned = true
        reviewIntentForSession.removeValue(forKey: sessionID)
        // feat-035: session-scoped album operations join the same
        // all-attempted/idempotent rule. Resolution order keeps album state
        // reconcilable: retire the operation only after the review scope it
        // references is gone. Absent rows already count as success.
        if let albumOperations = container.albumOperations {
            await albumOperations.delete(sessionID: sessionID.rawValue)
        }
        if let workspaceStore = container.workspaceStore {
            do {
                try await workspaceStore.deleteScope(id: sessionID.rawValue)
            } catch {
                cleaned = false
                logger
                    .error(
                        "\(context, privacy: .public) workspace cleanup failed: \(error.localizedDescription, privacy: .public)"
                    )
            }
        }
        cleaned = await deleteCheckpointFiles(sessionID: sessionID, context: context) && cleaned
        return cleaned
    }

    /// File-backed session artifacts. Each delete is attempted independently;
    /// absent files already count as success. Split from `deleteSessionData`
    /// so both stay under the function body budget.
    private func deleteCheckpointFiles(sessionID: SessionID, context: String) async -> Bool {
        var cleaned = true
        // Each entry is attempted independently; absent files count as
        // success. Written as sequential calls (not a collection literal) so
        // the formatter keeps the trailing-comma rule satisfied.
        let checkpointStore = container.checkpointStore
        cleaned = await deleteOne(label: "checkpoint", context: context) {
            try await checkpointStore.delete(sessionID: sessionID)
        } && cleaned
        cleaned = await deleteOne(label: "result", context: context) {
            try await checkpointStore.deleteResult(sessionID: sessionID)
        } && cleaned
        cleaned = await deleteOne(label: "feedback", context: context) {
            try await checkpointStore.deleteFeedback(sessionID: sessionID)
        } && cleaned
        // feat-026 uncertainty snapshot: same all-attempted/idempotent rule.
        cleaned = await deleteOne(label: "uncertainty-feedback", context: context) {
            try await checkpointStore.deleteUncertaintyFeedback(sessionID: sessionID)
        } && cleaned
        cleaned = await deleteOne(label: "save-state", context: context) {
            try await checkpointStore.deleteSaveState(sessionID: sessionID)
        } && cleaned
        return cleaned
    }

    private func deleteOne(
        label: String, context: String, delete: () async throws -> Void
    ) async -> Bool {
        do {
            try await delete()
            return true
        } catch {
            logger.error(
                "\(context, privacy: .public) \(label, privacy: .public) cleanup failed: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    func cancelProcessing() {
        processing.cancel()
    }

    func retryProcessing() {
        // A partial finalization racing a retry must not persist under it:
        // cancel the flight (its race gate aborts before any save/route).
        finalizeFlight?.task.cancel()
        finalizeFlight = nil
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

    /// Launch probe: remembers the newest unfinished session for the Home card.
    /// A session with a persisted non-empty result or save-state counts as
    /// unfinished even when the in-memory run already cleared ownership.
    func refreshResumeSnapshot() async {
        if activeSessionID != nil {
            resumeSnapshot = nil; return
        }
        guard let found = await container.checkpointStore.latestCheckpoint() else {
            resumeSnapshot = nil
            return
        }
        let result = try? await container.checkpointStore.loadResult(sessionID: found.checkpoint.sessionID)
        if let result, !result.selectedAssetIDs.isEmpty {
            resumeSnapshot = ResumeSnapshot(
                sessionID: found.checkpoint.sessionID,
                stage: found.checkpoint.stage,
                sourceCount: found.checkpoint.sourceAssetIDs.count,
                updatedAt: found.checkpoint.updatedAt,
                hasResult: true,
                hasSaveState: found.hasSaveState
            )
            return
        }
        if found.hasSaveState {
            resumeSnapshot = ResumeSnapshot(
                sessionID: found.checkpoint.sessionID,
                stage: found.checkpoint.stage,
                sourceCount: found.checkpoint.sourceAssetIDs.count,
                updatedAt: found.checkpoint.updatedAt,
                hasResult: false,
                hasSaveState: true
            )
            return
        }
        if found.checkpoint.stage == ProcessingStage.finalSelection.rawValue {
            resumeSnapshot = nil
            return
        }
        resumeSnapshot = ResumeSnapshot(
            sessionID: found.checkpoint.sessionID,
            stage: found.checkpoint.stage,
            sourceCount: found.checkpoint.sourceAssetIDs.count,
            updatedAt: found.checkpoint.updatedAt,
            hasResult: false,
            hasSaveState: false
        )
    }

    /// Home "Start New" when a resume snapshot exists: ask first (ux-flows §4.3),
    /// because starting supersedes and deletes the retained session's data.
    func requestNewSession() {
        if resumeSnapshot != nil || activeSessionID != nil {
            confirmingNewSession = true
            return
        }
        pendingReviewIntent = .album
        reviewIntentForSession.removeAll()
        showSourceSelection()
    }

    /// Confirmed Start New: supersedes the retained session exactly like
    /// discard (cancel run, clear ownership, async cancelSave → await
    /// termination → delete), then routes to source selection. Covers the
    /// snapshot-only case (no live run) and a mid-run supersede.
    func startNewSession(confirmed: Bool) {
        confirmingNewSession = false
        guard confirmed else { return }
        processing.cancel()
        finalizeFlight?.task.cancel()
        finalizeFlight = nil
        let sessionID = activeSessionID ?? lastSessionID ?? resumeSnapshot?.sessionID
        activeSessionID = nil
        resumeSnapshot = nil
        pendingReviewIntent = .album
        reviewIntentForSession.removeAll()
        if reviewModel?.sessionID == sessionID {
            reviewModel = nil
        }
        showSourceSelection()
        guard let sessionID else { return }
        Task {
            await cancelSave(for: sessionID)
            await processing.awaitTermination()
            let cleaned = await deleteSessionData(sessionID, context: "Superseded curation")
            if cleaned, lastSessionID == sessionID {
                lastSessionID = nil
            }
        }
    }

    /// Home "Continue" for the retained session: re-enter at the right surface.
    /// Processing/checkpointed work reopens Processing; a finished result (or an
    /// interrupted save) opens review/saving via showReview; otherwise the run
    /// resumes from its checkpoint.
    func continueResumedSession() {
        guard let snapshot = resumeSnapshot else { return }
        resumeSnapshot = nil
        activeSessionID = snapshot.sessionID
        lastSessionID = snapshot.sessionID
        if snapshot.hasSaveState || snapshot.hasResult {
            Task {
                do {
                    let checkpoint = try await container.checkpointStore.load(sessionID: snapshot.sessionID)
                    let assets = try await container.photoLibrary.fetchAssets()
                    allAssets = assets
                    confirmedSourceIDs = checkpoint.sourceAssetIDs
                    showReview(for: snapshot.sessionID)
                } catch {
                    await releaseUnrecoverable(snapshot: snapshot)
                }
            }
            return
        }
        if processing.sessionID == snapshot.sessionID {
            path.append(.processing(sessionID: snapshot.sessionID))
            Task { await resumeIfPaused() }
            return
        }
        Task {
            do {
                let checkpoint = try await container.checkpointStore.load(sessionID: snapshot.sessionID)
                let assets = try await container.photoLibrary.fetchAssets()
                allAssets = assets
                let live = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
                let ordered = checkpoint.sourceAssetIDs.compactMap { live[$0] }
                guard !ordered.isEmpty else {
                    await releaseUnrecoverable(snapshot: snapshot)
                    return
                }
                confirmedSourceIDs = checkpoint.sourceAssetIDs
                let modelAvailable = checkpoint.qualityIdentity?.modelAvailableAtStart ?? modelInstallation.isInstalled
                let requestedMode = checkpoint.qualityIdentity?.requestedMode ?? .native
                let request = SelectionRequest(
                    sessionID: snapshot.sessionID,
                    sourceAssetIDs: checkpoint.sourceAssetIDs,
                    config: .default,
                    qualityMode: requestedMode,
                    qualityModelAvailableAtStart: modelAvailable
                )
                processing.start(
                    request: request,
                    sourceAssets: ordered,
                    modelAvailable: modelAvailable
                )
                path.append(.processing(sessionID: snapshot.sessionID))
            } catch {
                await releaseUnrecoverable(snapshot: snapshot)
            }
        }
    }

    /// Empty/unrecoverable resume: release ownership, delete the dead session
    /// data, and land Home with no phantom card. No new alert copy.
    private func releaseUnrecoverable(snapshot: ResumeSnapshot) async {
        activeSessionID = nil
        if reviewModel?.sessionID == snapshot.sessionID {
            reviewModel = nil
        }
        goHome()
        await cancelSave(for: snapshot.sessionID)
        await processing.awaitTermination()
        let cleaned = await deleteSessionData(snapshot.sessionID, context: "Unrecoverable session")
        if cleaned, lastSessionID == snapshot.sessionID {
            lastSessionID = nil
        }
    }

    /// Review entry from Processing completed / Home Continue / load-failed retry:
    /// builds the ReviewModel (or reconciles an interrupted save), then routes
    /// directly to S09 (or S15). Never pushes a review interstitial.
    func showReview(for sessionID: SessionID) {
        reviewLoadRetryFailed = false
        Task {
            if await hasInterruptedSave(for: sessionID) {
                _ = await beginReview(for: sessionID)
                return
            }
            let ok = await beginReview(for: sessionID)
            if !ok {
                if path.last != .reviewOverview(sessionID: sessionID) {
                    path.append(.reviewOverview(sessionID: sessionID))
                } else {
                    // Already on the failed route: retrying would be a silent
                    // no-op, so surface an inline retry note instead.
                    reviewLoadRetryFailed = true
                }
            }
        }
    }

    /// Review entry caller: persisted result when the run finished, nil otherwise.
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
    /// SelectionResult from the available cached analyses so review entry has
    /// data, then routes. No-op when nothing analyzable exists (the attention
    /// screen stays put). Re-entrant safe: the first tap per session owns
    /// finalization; repeat taps for the SAME session join it (never duplicate
    /// saves/routes). Keep 5-action limit: no new actions.
    func continueWithoutUnavailable() async {
        guard let sessionID = activeSessionID else { return }
        if let flight = finalizeFlight {
            // Same session: join the owner. A different session mid-flight is
            // impossible from the UI; ignore defensively so it can never
            // interfere with the owned finalization.
            if flight.session == sessionID {
                await flight.task.value
            }
            return
        }
        let flight = Task {
            await finalizePartial(sessionID: sessionID)
        }
        finalizeFlight = (session: sessionID, task: flight)
        await flight.value
        if finalizeFlight?.session == sessionID {
            finalizeFlight = nil
        }
    }

    /// Owned finalization body. Aborts with no save and no route when
    /// cancelled by a superseding start/retry, or when the run is no longer
    /// sitting in `.failed` (a normal retry resumed it).
    private func finalizePartial(sessionID: SessionID) async {
        guard !Task.isCancelled else { return }
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
            let engineOut = try await processing.finalizeAvailable(
                assets: available, analyses: analyses, configuration: AppConfiguration.default.selection,
                laneCount: AppConfiguration.default.performance.maxConcurrentImageRequests,
                qualityMode: processing.requestedQualityMode,
                sessionID: sessionID
            )
            // Race gate: a retry resumed the run — never persist under it.
            guard !Task.isCancelled, case .failed = processing.state else { return }
            let partial = SelectionResult(
                sessionID: sessionID,
                selectedAssetIDs: engineOut.selectedAssetIDs,
                rejectedAssetIDs: engineOut.rejectedAssetIDs,
                decisions: engineOut.decisions,
                generatedAt: engineOut.generatedAt,
                engineVersion: engineOut.engineVersion,
                qualityEvidence: engineOut.qualityEvidence
            )
            try await container.checkpointStore.saveResult(partial)
            let done = SessionCheckpoint(
                sessionID: sessionID,
                stage: ProcessingStage.finalSelection.rawValue,
                completedAssetIDs: Array(analyses.keys),
                sourceAssetIDs: confirmedSourceIDs,
                configVersion: AppConfiguration.default.configVersion,
                analysisVersion: PhotoAnalysis.currentVersion,
                qualityIdentity: QualityCheckpointIdentity.expected(
                    for: processing.requestedQualityMode,
                    modelAvailableAtStart: processing.modelAvailableAtStart
                ),
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
    /// recreate data after deletion. BOTH deletes are always attempted
    /// independently (absent files count as success — idempotent), never gated
    /// on ownership and never short-circuited: completion clears ownership but
    func discardCuration() {
        processing.cancel()
        let sessionID = activeSessionID ?? lastSessionID
        activeSessionID = nil
        resumeSnapshot = nil
        if reviewModel?.sessionID == sessionID {
            reviewModel = nil
        }
        path.removeAll()
        guard let sessionID else { return }
        Task {
            await cancelSave(for: sessionID)
            await processing.awaitTermination()
            let cleaned = await deleteSessionData(sessionID, context: "Discarding curation")
            if cleaned, lastSessionID == sessionID {
                lastSessionID = nil
            }
        }
    }

    /// Reset Analysis (Settings → retention): clears the derived-analysis
    /// cache plus every persisted session artifact (checkpoints, results,
    /// feedback, save states) for the current session. Apple Photos
    /// originals are untouched. Cancels in-flight work first.
    func resetAnalysis() {
        processing.cancel()
        let sessionID = activeSessionID ?? lastSessionID
        activeSessionID = nil
        resumeSnapshot = nil
        reviewModel = nil
        path.removeAll()
        Task {
            await cancelSave(for: sessionID)
            await processing.awaitTermination()
            await container.analysisCache.reset()
            if sessionID != nil {
                _ = await deleteSessionData(sessionID, context: "Resetting analysis")
            }
            lastSessionID = nil
        }
    }

    private func markSeen() {
        hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: Self.seenWelcomeKey)
    }
}
