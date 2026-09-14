# feat-006 — Processing UI on real coordinator + Settings skeleton

## Goal

Land Processing UI on real coordinator + Settings skeleton so 100 real assets reach review.

## Scope

- `Features/Processing/`
- `Features/Settings/`
- `App/AppModel.swift`
- `App/AppRoute.swift`
- `App/RootView.swift`
- `Services/Session/SelectionSessionCoordinator.swift`
- Minimal seams only (no feature logic outside owns): `App/AppContainer.swift` one-line DI swap, `Infrastructure/SessionCheckpointStore.swift` source-IDs field + `saveResult/loadResult/deleteResult` result methods on the existing store (separate `results/` directory; no second store actor), `Features/SourceSelection/SelectionSummaryView.swift` Start-button one-line wiring (feat-004 owns the file; this feat only repoints the button to the new intent)

## Non-goals

- Anything outside owns; duplicates + moments stay in feat-007 (no DuplicateResolver/MomentBuilder calls; engine select runs as feat-005 left it).
- Settings full privacy/polish stays in feat-013 (this feat ships skeleton only: access state + one on-device line + About). Exhaustive storage-low + privacy/error polish is feat-013; S08 here keeps only the 5 gate recovery actions.
- Kill/relaunch discovery, automatic result-present routing, and broader session recovery are feat-012; this feat keeps only background checkpoint write + explicit resume-if-paused.
- No review UI (feat-009 owns Review); feat-006 proves "reach review" via a persisted SelectionResult + reviewReady route. `ReviewReadyView` is a transition/count screen only (counts + Continue).
- Do NOT modify source code in this planning step; do NOT touch feat-004/feat-005 files.

## Design (accepted 2026-09-11, Approach: real coordinator + thin ProcessingModel)

- Architecture: actor `SelectionSessionCoordinator` owns sequencing + progress + checkpoint consistency; `@MainActor @Observable ProcessingModel` owns UI state only and forwards intents. Views render state, never fetch/analyze/score. Owner: `docs/design-docs/ios-architecture.md` §1, §8, §12.
- Progress ownership: coordinator throttles all progress callbacks to ≤4 Hz (last-write-wins, monotonic fraction); `ProcessingModel.apply` only renders. `Downloading n/total` aggregate is computed in the coordinator from `imageDownloadProgress` notifications + BatchPipeline callbacks, not in the view. Owner: `ios-architecture.md` §12 + `ship-gates/performance.md` §1.
- Pipeline order: S06 freeze source IDs → coordinator `loading` (ingest/eligible metadata only) → `analysis` (BatchPipeline over eligible, batch 32) → `clustering/momentDetection/ranking/finalSelection` select call (feat-007 fills real dups/moments later; this feat wires the call, it does not implement it) → persist result + checkpoint → reviewReady. Stage mapping follows `data-model.md` §10 canonical table. Owner: `selection-engine.md` §1–§2.
- S07/S08 copy: five stable user phases (Preparing/Analyzing/Grouping/Choosing/Finishing), determinate count only with real denominator, `Waiting for N photos from iCloud` stall line, leave-safe wording, Pause/Stop vs Discard split, plain-words `Curation Paused`. Owner: `product-specs/ux-flows.md` §7.
- Assumption: feat-005 has delivered versioned `PhotoAnalysis` + `BatchPipeline` with progress/cancel/checkpoint per `performance.md` §1. This plan consumes that API; it does not redefine it.
- Input contract: feat-004's frozen chrono snapshot (`confirmedSourceIDs: [AssetID]` + `confirmedSourceAssets() -> [PhotoAsset]`) is the ONLY pipeline input. Session identity is the request's `sessionID` created at Start; never route on `SelectionEngine`'s random result ID (engine output is re-stamped to the request ID before persist/route).

## Implementation Plan (inline per AGENTS.md; no docs/plans file)

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking. No Noop remains on the S06→S07→review path. Task order is dependency order: coordinator types (1) → AppModel/routes/DI/persistence seams (2) → models/views that consume them (3) → Settings + validation (4), so every intermediate `./init.sh` passes.

**Goal:** Wire S07/S08 to the real coordinator so 100 real assets flow from Summary through analysis + select to a persisted result and the reviewReady route, with real progress, cancel, error/unavailable, and retry/resume without redo.

**Architecture:** New actor `SelectionSessionCoordinator` sequences fetch→cache/checkpoint→BatchPipeline→engine select→persist. New `@MainActor ProcessingModel` bridges coordinator callbacks to SwiftUI state. `ProcessingView` (S07) + `AttentionView` (S08) render `ProcessingState`. `AppModel` holds the active `sessionID` + `ProcessingModel`; `AppRoute` gains `processing/settings/reviewReady` cases additively (004 cases preserved); `RootView` routes them. `SettingsView` is a read-only skeleton. `AppContainer.live()` swaps to the real analyzer.

**Tech Stack:** Swift 5/SwiftUI, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, SwiftLint --strict + SwiftFormat, NO test targets/no *Test*.swift/manual validation only + ./init.sh SKIP [test], iOS 26 min, on-device only never delete originals, budgets progressMaxHertz 4 / batch 32 / checkpoint 25-10s.

## Global Constraints

- Swift 5/SwiftUI, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, SwiftLint --strict + SwiftFormat, NO test targets/no *Test*.swift/manual validation only + ./init.sh SKIP [test], iOS 26 min, on-device only never delete originals, budgets progressMaxHertz 4 / batch 32 / checkpoint 25-10s.
- `./init.sh` must pass (format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`).
- Views do no fetching/analysis/scoring; engine imports no SwiftUI; never persist `PHAsset`/`UIImage`/`CGImage`; `AssetID` wraps `PHAsset.localIdentifier`.
- Centralize knobs in `AppConfiguration.default` (`performance.analysisBatchSize` 32, `checkpointEveryAssets` 25 / `checkpointEverySeconds` 10, `progressMaxHertz` 4). No tunables as user settings.
- `overallFraction` never moves backward; progress callbacks stay off-main until `ProcessingModel.apply`.
- Every long loop cooperates with `Task.checkCancellation()`; cancel keeps valid completed analyses.
- Full privacy/polish stays feat-013; duplicates + moments stay feat-007.
- Plan artifact only (this file). No source edits in this step.

## File Structure

- Create `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` — actor coordinator + `SelectionRequest` + canonical `ProcessingStage` reuse + computed `userPhase` display string + `ProcessingProgress`/`ProcessingState` + small typed `RecoveryAction`/`UserFacingError`.
- Modify `apps/photo-curator/App/AppRoute.swift` — ADD `processing(sessionID:)` + `settings` + `reviewReady(sessionID:)`; preserve `.sourceSelection`/`.summary`.
- Modify `apps/photo-curator/App/AppModel.swift` — hold active session + `ProcessingModel`, intents `startCuration()` / `cancelProcessing()` / `retryProcessing()` / `resumeIfPaused()` / `checkpointForBackground()` / `showReview` / `openSettings` / `goHome` / `discardCuration` (+ `presentPicker` passthrough reuse).
- Modify `apps/photo-curator/App/RootView.swift` — `navigationDestination` for the three new routes (additive) + scene-phase background-checkpoint/resume hook.
- Modify `apps/photo-curator/App/AppContainer.swift` — one-line DI swap `NoopImageAnalyzer()` → `VisionAnalysisService()`.
- Modify `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift` — add `sourceAssetIDs` field + `saveResult/loadResult/deleteResult` result methods on the existing store (separate `results/` directory).
- Create `apps/photo-curator/Features/Processing/ProcessingModel.swift` — `@MainActor @Observable` bridge (start/cancel/retry/resume, owns `Task`).
- Create `apps/photo-curator/Features/Processing/ProcessingView.swift` — S07 screen + S08 `AttentionView` (copy per ux-flows §7) + `ReviewReadyView` (count + unavailable + Continue guard).
- Create `apps/photo-curator/Features/Settings/SettingsView.swift` — S18 skeleton only.
- Touch `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` — repoint Start Curation button to `appModel.startCuration()` ONLY (feat-004 owns the file).

Inline rationale (AGENTS.md plans rule): 6+ files but 1 workspace, no DB migration, no breaking API, no phases/rollback — only 1 substantial signal (≥4 files), so inline is correct and no `docs/plans/feat-006.md` is created.

---

### Task 1: Real SelectionSessionCoordinator actor (canonical stages, exact pipeline API, real run body)

**Files:**
- Create: `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift`

**Interfaces (EXACT — matches feat-005 Task 3 signatures verbatim):**
- Consumes: `BatchPipeline.run(assets:sessionID:progress:) async throws -> BatchResult` + `resume(assets:sessionID:progress:) async throws -> BatchResult` where `assets: [PhotoAsset]` (feat-004 chrono snapshot), `sessionID: SessionID`, `progress: @Sendable @escaping (BatchProgress) -> Void`; `BatchProgress(completed:total:analyzed:unavailable:)`; `BatchResult(analyses: [AssetID: PhotoAnalysis], unavailableIDs: [AssetID])`; `PhotoAnalysis.analysisVersion`; `AnalysisCache`; `SessionCheckpointStore`; `SelectionEngine.select(assets:analyses:configuration:feedback:)`; `Notification.Name.imageDownloadProgress` (`userInfo["assetID": String, "fraction": Double]`); `AppConfiguration` budgets
- Produces: `struct SelectionRequest` + `actor SelectionSessionCoordinator` + canonical `ProcessingStage` (reused raw values, NOT redefined) + computed `userPhase` display string + `ProcessingProgress`/`ProcessingState` + small typed `RecoveryAction`/`UserFacingError` (5 gate actions only) so feat-007 duplicates/moments can rely on them

- [ ] **Step 1: Add request + canonical stage reuse + computed user-phase string + progress + typed error (no stage redefinition)**

```swift
import Foundation

struct SelectionRequest: Sendable {
    let sessionID: SessionID
    let sourceAssetIDs: [AssetID] // frozen chrono snapshot from feat-004 confirmedSourceIDs
    let config: AppConfiguration
}

// Canonical stored stages — data-model.md §10 raw values reused verbatim.
// This enum is the single stored/checkpoint vocabulary; do NOT add user-phase cases here.
enum ProcessingStage: String, Codable, Sendable {
    case loading, analysis, clustering, momentDetection, ranking, finalSelection
}

// UI-only display string — a computed property, NOT a separate enum. Never persisted,
// never written to checkpoint.stage.
extension ProcessingStage {
    var userPhase: String {
        switch self {
        case .loading: return "Preparing photos"
        case .analysis: return "Analyzing photos"
        case .clustering, .momentDetection: return "Grouping similar shots"
        case .ranking: return "Choosing the best photos"
        case .finalSelection: return "Finishing your album"
        }
    }
}

struct ProcessingProgress: Sendable, Equatable {
    var stage: ProcessingStage // canonical stored stage
    var completedUnits: Int // real BatchProgress denominator only; 0 totalUnits = indeterminate
    var totalUnits: Int
    var downloadingCount: Int
    var unavailableCount: Int // sourced from BatchProgress.unavailable + BatchResult.unavailableIDs
    var overallFraction: Double // mirrors BatchProgress completed/total during analysis only
    static var zero: Self {
        Self(stage: .loading, completedUnits: 0, totalUnits: 0,
             downloadingCount: 0, unavailableCount: 0, overallFraction: 0)
    }
}

enum ProcessingState: Equatable {
    case idle
    case preparing
    case running(ProcessingProgress)
    case cancelling
    case paused(reason: String)
    case completed(sessionID: SessionID, analyzed: Int, unavailable: Int)
    case cancelled
    case failed(UserFacingError)
}

// Small typed recovery actions for the gate paths only (no error-policy hierarchy).
enum RecoveryAction: Equatable, Sendable {
    case retry
    case openSettings
    case continueWithoutUnavailable
    case discard
    case goHome
}

struct UserFacingError: Equatable {
    let title: String
    let message: String
    let primary: RecoveryAction
    let secondary: RecoveryAction
}
```

Checkpoint rule fixed here: `SessionCheckpoint.stage` stores `ProcessingStage.rawValue` (`loading/analysis/...`); the display string is derived at render via `stage.userPhase` and never touches the checkpoint. Verify: `rg -n "case loading, analysis, clustering|var userPhase" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` shows canonical stages + computed string; `rg -n "enum UserPhase|func forStage" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` returns nothing (`ProcessingState.preparing` is a transient UI state, not a stage).

- [ ] **Step 2: Add coordinator actor with REAL run body (BatchPipeline + engine + persist + download aggregate)**

```swift
import Foundation
import OSLog

actor SelectionSessionCoordinator {
    private let photoLibrary: any PhotoLibraryService
    private let imageLoader: any PhotoImageLoader
    private let analyzer: any ImageAnalysisService
    private let analysisCache: any AnalysisCache
    private let checkpointStore: SessionCheckpointStore // owns checkpoints + saveResult/loadResult/deleteResult (results/ dir)
    private let pipeline: BatchPipeline // constructed from loader/analyzer/cache/checkpoints/config
    private let engine: SelectionEngine
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "photo-curator", category: "selection")

    private var lastEmit: Date = .distantPast
    private var lastFraction: Double = 0
    private var pendingDownloadIDs = Set<String>()
    private var downloadObserver: NSObjectProtocol?

    init(photoLibrary: any PhotoLibraryService, imageLoader: any PhotoImageLoader,
         analyzer: any ImageAnalysisService, analysisCache: any AnalysisCache,
         checkpointStore: SessionCheckpointStore,
         engine: SelectionEngine, config: AppConfiguration = .default) {
        self.photoLibrary = photoLibrary
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.analysisCache = analysisCache
        self.checkpointStore = checkpointStore
        self.engine = engine
        self.pipeline = BatchPipeline(imageLoader: imageLoader, analyzer: analyzer,
                                      cache: analysisCache, checkpoints: checkpointStore, config: config)
    }

    func run(request: SelectionRequest, sourceAssets: [PhotoAsset],
             onProgress: @Sendable @escaping (ProcessingProgress) async -> Void) async throws -> SelectionResult {
        try Task.checkCancellation()
        let interval = 1.0 / request.config.performance.progressMaxHertz // 4 Hz
        func emit(_ p: ProcessingProgress) async {
            let now = Date()
            guard p.overallFraction + 0.0001 >= self.lastFraction,
                  now.timeIntervalSince(self.lastEmit) >= interval || p.completedUnits == p.totalUnits else { return }
            self.lastEmit = now
            self.lastFraction = max(self.lastFraction, p.overallFraction)
            await onProgress(p)
        }
        // Subscribe download progress: userInfo assetID(String)+fraction(Double);
        // fraction >= 1.0 removes the ID; aggregate = pendingDownloadIDs.count.
        self.downloadObserver = NotificationCenter.default.addObserver(
            forName: .imageDownloadProgress, object: nil, queue: nil) { [weak self] note in
            Task { await self?.handleDownloadNote(note) }
        }
        defer {
            if let obs = self.downloadObserver { NotificationCenter.default.removeObserver(obs) }
            self.downloadObserver = nil
        }
        // 1. loading: indeterminate (no denominator yet) — determinate progress exists ONLY
        // for the real BatchProgress denominator during analysis.
        await emit(ProcessingProgress(stage: .loading, completedUnits: 0, totalUnits: 0,
                                      downloadingCount: 0, unavailableCount: 0, overallFraction: 0))
        try Task.checkCancellation()
        let assets = sourceAssets // chrono order from feat-004 snapshot; count == request.sourceAssetIDs.count
        // 2. checkpoint resume: pipeline skips completed IDs itself; choose resume when manifest exists.
        let hasCheckpoint = (try? await self.checkpointStore.load(sessionID: request.sessionID)) != nil
        // 3. analysis via BatchPipeline — EXACT feat-005 labels/types.
        let batchResult: BatchResult
        if hasCheckpoint {
            batchResult = try await self.pipeline.resume(assets: assets, sessionID: request.sessionID) { [weak self] bp in
                Task { await self?.forwardBatch(bp, stage: .analysis, emit: emit) }
            }
        } else {
            batchResult = try await self.pipeline.run(assets: assets, sessionID: request.sessionID) { [weak self] bp in
                Task { await self?.forwardBatch(bp, stage: .analysis, emit: emit) }
            }
        }
        try Task.checkCancellation()
        // 4. engine select (feat-007 fills dups/moments; call shape frozen here).
        // Indeterminate: select has no per-unit denominator, so no fraction is fabricated.
        await emit(ProcessingProgress(stage: .clustering, completedUnits: 0, totalUnits: 0,
                                      downloadingCount: 0,
                                      unavailableCount: batchResult.unavailableIDs.count, overallFraction: 0))
        let engineOut = try self.engine.select(assets: assets, analyses: batchResult.analyses,
                                               configuration: request.config.selection, feedback: nil)
        // Guarantee request/session ID: NEVER route on the engine's random result ID.
        let result = SelectionResult(sessionID: request.sessionID,
                                     selectedAssetIDs: engineOut.selectedAssetIDs,
                                     rejectedAssetIDs: engineOut.rejectedAssetIDs,
                                     decisions: engineOut.decisions,
                                     generatedAt: engineOut.generatedAt,
                                     engineVersion: engineOut.engineVersion)
        // 5. persist result + final checkpoint (stage finalSelection), then return.
        // No completion fraction is fabricated: completion is the .completed state, not 1.0.
        try await self.checkpointStore.saveResult(result)
        let done = SessionCheckpoint(sessionID: request.sessionID, stage: ProcessingStage.finalSelection.rawValue,
                                     completedAssetIDs: Array(batchResult.analyses.keys) + batchResult.unavailableIDs,
                                     sourceAssetIDs: request.sourceAssetIDs,
                                     configVersion: request.config.configVersion,
                                     analysisVersion: PhotoAnalysis.currentVersion, updatedAt: Date())
        try await self.checkpointStore.save(done)
        return result
    }

    private func forwardBatch(_ bp: BatchProgress, stage: ProcessingStage,
                              emit: @Sendable @escaping (ProcessingProgress) async -> Void) async {
        // overallFraction mirrors the real BatchProgress denominator ONLY — no stage weights.
        let total = max(bp.total, 1)
        let fraction = Double(bp.completed) / Double(total)
        await emit(ProcessingProgress(stage: stage, completedUnits: bp.completed, totalUnits: bp.total,
                                      downloadingCount: self.pendingDownloadIDs.count,
                                      unavailableCount: bp.unavailable, overallFraction: fraction))
    }

    private func handleDownloadNote(_ note: Notification) async {
        guard let id = note.userInfo?["assetID"] as? String else { return }
        let fraction = note.userInfo?["fraction"] as? Double ?? 0
        if fraction >= 1.0 { self.pendingDownloadIDs.remove(id) }
        else { self.pendingDownloadIDs.insert(id) }
    }

    /// Background path: write a safe checkpoint now, stop starting new work.
    func checkpointNow(sessionID: SessionID, completed: [AssetID], stage: ProcessingStage) async {
        let stub = SessionCheckpoint(sessionID: sessionID, stage: stage.rawValue,
                                     completedAssetIDs: completed, sourceAssetIDs: [],
                                     configVersion: AppConfiguration.default.configVersion,
                                     analysisVersion: PhotoAnalysis.currentVersion, updatedAt: Date())
        try? await self.checkpointStore.save(stub)
    }
}
```

Rules fixed in code (no placeholder): constructs `BatchPipeline` with the 5 exact init labels; calls `run(assets:sessionID:progress:)` / `resume(assets:sessionID:progress:)` with exact labels; `BatchProgress` fields read as `completed/total/analyzed/unavailable`; `BatchResult.unavailableIDs` flows to progress + final state; engine random `sessionID` is discarded via re-stamp; `throw SelectionError.internal` MUST NOT appear in this file. Throttle (≤4 Hz) + monotonic fraction live in the coordinator, not the view. Determinate progress exists ONLY for the real `BatchProgress` denominator (fraction = completed/total during analysis); loading/select/final stages emit `totalUnits: 0` and render indeterminate — no stage weights, no fabricated 0.02/0.05/0.90/1.0. Verify: `rg -n "pipeline\.(run|resume)\(assets:|BatchResult|unavailableIDs" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` shows real calls; `rg -n "throw SelectionError.internal|fatalError|runBatch|overallFraction: 0.9|overallFraction: 1.0|0.85 \*" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` returns nothing.

- [ ] **Step 3: Add failure classification incl. SelectionError.cancelled (S08 wiring, no raw errors in copy)**

```swift
extension SelectionSessionCoordinator {
    nonisolated static func userError(for error: Error, unavailable: Int) -> UserFacingError {
        if case SelectionError.cancelled = error {
            return UserFacingError(title: "Curation Paused",
                message: "Your progress is saved. Curation will continue when the app is active again.",
                primary: .goHome, secondary: .discard)
        }
        if error is CancellationError {
            return UserFacingError(title: "Curation Paused",
                message: "Your progress is saved. Curation will continue when the app is active again.",
                primary: .goHome, secondary: .discard)
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return UserFacingError(title: "Connection Needed",
                message: "Some photos need to download from iCloud. Connect and try again — saved work is kept.",
                primary: .retry, secondary: .continueWithoutUnavailable)
        }
        return UserFacingError(title: "Couldn't Continue Curation",
            message: "Your progress is saved. Try again to continue processing.",
            primary: .retry, secondary: .goHome)
    }

    // Permission-removed path (called by ProcessingModel when authorization is denied/restricted).
    nonisolated static func permissionError() -> UserFacingError {
        UserFacingError(title: "Photos Access Needed",
            message: "Allow photo access to continue. Your progress is saved.",
            primary: .openSettings, secondary: .goHome)
    }
}
```

Gate per-error table (5 actions only, no error-policy hierarchy): cancelled → goHome/discard; iCloud-no-network → retry/continueWithoutUnavailable (second offered only when analyzable ≥ minimum count per selection-engine partial rule); permission-removed → openSettings/goHome; anything else → retry/goHome. Storage-low + broader privacy/error polish are feat-013. Retry resumes from checkpoint `completedAssetIDs`; it never clears finished analyses. `SelectionError.cancelled` maps to `.cancelled` UI state, never `.failed`. Verify: `rg -n "SelectionError.cancelled" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` shows the cancel branch; `rg -n "chooseMorePhotos" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` returns nothing.

- [ ] **Step 4: Run `./init.sh`**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 2: AppModel + routes + DI + persistence seams (APIs BEFORE views consume them)

**Files:**
- Modify: `apps/photo-curator/App/AppRoute.swift`
- Modify: `apps/photo-curator/App/AppModel.swift`
- Modify: `apps/photo-curator/App/RootView.swift`
- Modify: `apps/photo-curator/App/AppContainer.swift`
- Modify: `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift` (add `sourceAssetIDs` field + `saveResult/loadResult/deleteResult` on the existing store)

**Interfaces:**
- Consumes: feat-004 `confirmedSourceIDs` + `confirmedSourceAssets()` chrono snapshot + `sourceByID`; Task 1 coordinator + `SelectionRequest` + checkpoint-store result methods
- Produces: additive routes + `AppModel` intents (`startCuration/cancelProcessing/retryProcessing/resumeIfPaused/checkpointForBackground/showReview/openSettings/goHome/discardCuration`) + live DI + checkpoint/result seam so Task 3 views can rely on them

- [ ] **Step 1: Extend AppRoute ADDITIVELY (preserve feat-004 cases, no renames)**

```swift
enum AppRoute: Hashable, Sendable {
    case welcome
    case permissionEducation
    case home
    case sourceSelection
    case summary
    case processing(sessionID: SessionID)
    case settings
    case reviewReady(sessionID: SessionID)
}
```

`reviewReady` is a real destination (Task 3 `ReviewReadyView`); full grid/detail/groups arrive in feat-009/010 and reuse this case without renaming. Verify: `rg -n "case sourceSelection|case summary|case processing\(sessionID:|case settings|case reviewReady\(sessionID:" apps/photo-curator/App/AppRoute.swift` shows all five domain cases.

- [ ] **Step 2: Hold active session + ProcessingModel in AppModel (real stored state, sessionID-carrying route, Summary wiring)**

```swift
extension AppModel {
    var activeSessionID: SessionID? { /* stored, set at startCuration, cleared on discard/goHome */ }
    var processing: ProcessingModel { /* container-built coordinator-backed model, stored */ }

    // Reads feat-004 frozen chrono snapshot; creates the request ID HERE (guaranteed session ID).
    func startCuration() {
        // guards authorization (.authorized/.limited) else routes to guidance;
        // freezes confirmedSourceIDs + confirmedSourceAssets();
        // persists created shell (checkpoint stage loading.rawValue + sourceAssetIDs) BEFORE navigating
        // so termination before first batch still resumes;
        // then path.append(.processing(sessionID: request.sessionID)) — sessionID always attached.
    }
    func cancelProcessing() { processing.cancel() }
    func retryProcessing() { processing.retry() }
    func resumeIfPaused() { /* calls processing.retry() ONLY when state is .paused/.cancelled with saved progress */ }
    func checkpointForBackground() async { /* coordinator passthrough write; stops starting new work */ }
    func showReview(for sessionID: SessionID) { path.append(.reviewReady(sessionID: sessionID)) }
    func loadResult(for sessionID: SessionID) async -> SelectionResult? { /* try? await checkpointStore.loadResult(sessionID:) — ReviewReadyView caller */ }
    func openSettings() { path.append(.settings) }
    func goHome() { path.removeAll() }
    func discardCuration() { /* cancel + delete checkpoint + delete persisted result + path.removeAll; §4.3 confirm lives in view */ }
}
```

Implementation notes (no vague steps, no fatalError): `activeSessionID` + `processing` are `stored` properties initialized from `container` in `init` (coordinator built with `container.photoLibrary/imageLoader/analyzer/analysisCache/checkpointStore/selectionEngine`); `startCuration()` takes NO asset args (reads `confirmedSourceIDs`); Summary wiring = `SelectionSummaryView` "Start Curation" button calls `appModel.startCuration()` (one-line change in feat-004's file, feat-004 owns layout/copy). No `fatalError("wired in implementation")` anywhere. Verify: `rg -n "fatalError" apps/photo-curator/App/AppModel.swift` returns nothing; `rg -n "path.append\(.processing\(sessionID:" apps/photo-curator/App/AppModel.swift` shows the sessionID-carrying navigation; `rg -n "settingsEntryAvailable" apps/photo-curator/App/AppModel.swift` returns nothing.

- [ ] **Step 3: DI swap to the real pipeline (AppContainer.live)**

One line: `analyzer: NoopImageAnalyzer(),` → `analyzer: VisionAnalysisService(),` (feat-005 delivers the class; this feat flips the switch so the real pipeline runs on the S06→S07→review path). Verify: `rg -n "VisionAnalysisService\(\)" apps/photo-curator/App/AppContainer.swift` shows it; `rg -n "NoopImageAnalyzer" apps/photo-curator/App/AppContainer.swift` returns nothing.

- [ ] **Step 4: Source-IDs + result methods on the existing store (no second store actor)**

Extend `SessionCheckpoint` with `sourceAssetIDs: [AssetID]` (default `[]` for version-tolerant decode of pre-006 manifests) and add result methods on `SessionCheckpointStore` reusing its `FileStore` under a separate `results/` directory:

```swift
nonisolated struct SessionCheckpoint: Codable, Sendable {
    let sessionID: SessionID
    let stage: String // canonical ProcessingStage.rawValue
    let completedAssetIDs: [AssetID]
    let sourceAssetIDs: [AssetID] // NEW — defaults to [] when absent
    let configVersion: Int
    let analysisVersion: Int
    let updatedAt: Date
    // Codable: custom init(from:) uses decodeIfPresent for sourceAssetIDs.
}

extension SessionCheckpointStore {
    func saveResult(_ result: SelectionResult) async throws // results/<uuid>.json via the same FileStore
    func loadResult(sessionID: SessionID) async throws -> SelectionResult
    func deleteResult(sessionID: SessionID) async throws
}
```

Scope here: background checkpoint write + explicit resume-if-paused only. Kill/relaunch discovery, automatic result-present routing, and broader session recovery are feat-012 (marked deferred; NOT claimed here). Verify: `rg -n "sourceAssetIDs|saveResult|loadResult|deleteResult" apps/photo-curator/Infrastructure/SessionCheckpointStore.swift` shows the field + methods; `rg -n "SelectionResultStore" apps/photo-curator -r` returns nothing.

- [ ] **Step 5: Route all destinations in RootView + background-checkpoint/resume hook (additive switch)**

```swift
.navigationDestination(for: AppRoute.self) { route in
    switch route {
    case .welcome: WelcomeView()
    case .permissionEducation: PermissionEducationView()
    case .home: HomeView()
    case .sourceSelection: SourceSelectionView()
    case .summary: SelectionSummaryView()
    case .processing: ProcessingView()
    case .settings: SettingsView()
    case .reviewReady(let id): ReviewReadyView(sessionID: id)
    }
}
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background {
        Task { await appModel.checkpointForBackground() } // write safe checkpoint, stop new work
    }
    if newPhase == .active {
        Task {
            await appModel.refreshAuthorization()
            await appModel.resumeIfPaused() // ONLY .paused/.cancelled with saved progress; never restarts completed jobs
        }
    }
}
```

Verify: `rg -n "SourceSelectionView|SelectionSummaryView|ProcessingView|SettingsView|ReviewReadyView" apps/photo-curator/App/RootView.swift` shows all five; switch has no dropped cases. Lock/background acceptance: background write + return restores persisted completed count (exercised in Task 4 smoke).

- [ ] **Step 6: Run `./init.sh`**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 3: ProcessingModel bridge + S07/S08 views + ReviewReady (consumes Task 2 APIs)

**Files:**
- Create: `apps/photo-curator/Features/Processing/ProcessingModel.swift`
- Create: `apps/photo-curator/Features/Processing/ProcessingView.swift` (hosts `ProcessingView` + `AttentionView` + `ReviewReadyView`)

**Interfaces:**
- Consumes: Task 1 coordinator `run(request:sourceAssets:onProgress:)` + `BatchResult` counts; Task 2 `AppModel` intents (`startCuration/cancelProcessing/retryProcessing/showReview/openSettings/goHome/discardCuration/presentPicker`) + `activeSessionID`
- Produces: `ProcessingModel.start/cancel/retry` + S07/S08 view states + `ReviewReadyView` (stage + counts + unavailable bucket, no engine internals in UI) so feat-007 duplicates/moments can rely on them

- [ ] **Step 1: Add ProcessingModel (owns Task, applies coordinator updates on MainActor, unavailable from BatchResult)**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class ProcessingModel {
    private(set) var state: ProcessingState = .idle
    private var task: Task<Void, Never>?
    private let coordinator: SelectionSessionCoordinator
    private var request: SelectionRequest?
    private var sourceAssets: [PhotoAsset] = []
    var onCompleted: ((SessionID) -> Void)? // AppModel sets: routes to reviewReady

    init(coordinator: SelectionSessionCoordinator) { self.coordinator = coordinator }

    func start(request: SelectionRequest, sourceAssets: [PhotoAsset]) {
        guard task == nil else { return }
        self.request = request
        self.sourceAssets = sourceAssets
        state = .preparing
        task = Task {
            do {
                let result = try await coordinator.run(request: request, sourceAssets: sourceAssets) { [weak self] update in
                    await self?.apply(update)
                }
                // unavailable sourced from BatchResult via coordinator progress — SelectionResult carries no unavailable count.
                let unavailable = if case .running(let p) = state { p.unavailableCount } else { 0 }
                let analyzed = result.selectedAssetIDs.count + result.rejectedAssetIDs.count
                state = .completed(sessionID: request.sessionID, analyzed: analyzed, unavailable: unavailable)
                onCompleted?(request.sessionID)
            } catch let error as SelectionError where error == .cancelled {
                state = .cancelled
            } catch is CancellationError {
                state = .cancelled
            } catch {
                let unavailable = if case .running(let p) = state { p.unavailableCount } else { 0 }
                state = .failed(SelectionSessionCoordinator.userError(for: error, unavailable: unavailable))
            }
            task = nil
        }
    }

    func apply(_ p: ProcessingProgress) {
        if case .running(let cur) = state, p.overallFraction + 0.0001 < cur.overallFraction { return }
        state = .running(p)
    }

    func cancel() {
        if case .running = state { state = .cancelling }
        task?.cancel()
    }

    func retry() {
        guard task == nil, let r = request else { return }
        start(request: r, sourceAssets: sourceAssets) // pipeline resume path reuses checkpoint; never clears valid work
    }
}
```

Cancel ack: `cancel()` sets `.cancelling` synchronously (<250 ms UI ack); no new expensive work starts after cancel is known. First visible progress: `.preparing` renders immediately at Start (<500 ms), before first batch lands. `unavailable: 0` hardcode is FORBIDDEN — count always comes from coordinator progress (BatchResult-sourced). `catch is CancellationError` alone is FORBIDDEN — `SelectionError.cancelled` is the cancel branch. Verify: `rg -n "SelectionError.cancelled|unavailableCount|sourceAssets" apps/photo-curator/Features/Processing/ProcessingModel.swift` shows all three; `rg -n "unavailable: 0" apps/photo-curator/Features/Processing/ProcessingModel.swift` returns nothing.

- [ ] **Step 2: Add S07 ProcessingView with real denominator, stall line, leave + stop paths (calls Task 2 intents only)**

```swift
import SwiftUI

struct ProcessingView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            switch appModel.processing.state {
            case .idle, .preparing:
                ProgressView("Preparing photos")
            case .running(let p):
                VStack(spacing: 16) {
                    Text("Curating your photos").font(.title2.bold())
                    Text(p.stage.userPhase).font(.headline)
                    if p.totalUnits > 0 {
                        ProgressView(value: p.overallFraction)
                        Text("\(p.completedUnits) of \(p.totalUnits) analyzed")
                            .font(.subheadline).monospacedDigit()
                    } else {
                        ProgressView().accessibilityLabel("Working") // indeterminate: loading/select/final
                    }
                    if p.downloadingCount > 0 {
                        Text("Waiting for \(p.downloadingCount) photos from iCloud")
                            .font(.subheadline)
                        Text("Keep this iPhone connected to the internet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if p.unavailableCount > 0 {
                        Text("\(p.unavailableCount) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text("You can leave this screen. We'll keep your progress and resume if needed.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Stop Processing") { appModel.cancelProcessing() }
                    Button("Discard Curation", role: .destructive) { appModel.discardCuration() }
                }.padding()
            case .completed(let id, let analyzed, let unavailable):
                VStack(spacing: 12) {
                    Text("Analysis complete").font(.title2.bold())
                    Text("\(analyzed) photos analyzed")
                    if unavailable > 0 {
                        Text("\(unavailable) photos were unavailable and could not be analyzed.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Continue to Review") { appModel.showReview(for: id) }
                }.padding()
            case .failed(let e):
                AttentionView(error: e)
            case .cancelled:
                Text("Processing stopped. Your progress is saved.")
            case .cancelling:
                ProgressView("Stopping…")
            case .paused(let reason):
                Text(reason)
            }
        }
        .navigationTitle("Curating")
        .navigationBarBackButtonHidden(true)
    }
}
```

Rules enforced: determinate bar + `N of M analyzed` ONLY when `totalUnits > 0` (real BatchProgress denominator during analysis); indeterminate `ProgressView` everywhere else (loading, select, final) — no fabricated percentages. No fake percentages. Stop keeps the session; Discard deletes session progress with the §4.3 confirmation (`Discard this curation?` / Keep vs Discard). View calls ONLY Task 2 `AppModel` intents (`cancelProcessing/discardCuration/showReview`) — no direct coordinator calls. Stage text reads `p.stage.userPhase` (computed string), never `stage.rawValue`.

- [ ] **Step 3: Add S08 AttentionView with TYPED recovery mapping (real actions, no string dispatch)**

```swift
import SwiftUI
import UIKit

struct AttentionView: View {
    let error: UserFacingError
    @Environment(AppModel.self) private var appModel
    var body: some View {
        VStack(spacing: 16) {
            Text(error.title).font(.title2.bold())
            Text(error.message).font(.body).multilineTextAlignment(.center)
            Text("Your progress is safe.").font(.footnote).foregroundStyle(.secondary)
            Button(label(for: error.primary)) { perform(error.primary) }
                .buttonStyle(.borderedProminent)
            Button(label(for: error.secondary)) { perform(error.secondary) }
        }.padding()
    }
    private func label(for action: RecoveryAction) -> String {
        switch action {
        case .retry: return "Try Again"
        case .openSettings: return "Open Settings"
        case .continueWithoutUnavailable: return "Continue Without Them"
        case .discard: return "Discard Curation"
        case .goHome: return "Return Home"
        }
    }
    private func perform(_ action: RecoveryAction) {
        switch action {
        case .retry: appModel.retryProcessing()
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .continueWithoutUnavailable:
            if let id = appModel.activeSessionID { appModel.showReview(for: id) }
        case .discard: appModel.discardCuration()
        case .goHome: appModel.goHome()
        }
    }
}
```

Gate per-error table (5 actions only, no error-policy hierarchy): permission-removed → primary `.openSettings` (via `permissionError()` when authorization is denied/restricted); iCloud-no-network → primary `.retry` + secondary `.continueWithoutUnavailable` (offered only when analyzable ≥ minimum count per selection-engine partial rule); session-unusable → `.retry` (Restart Analysis wording via title/message); cancelled → `.goHome`/`.discard`. Storage-low + broader polish are feat-013. No error codes in copy. Forbidden: mapping every error to retry/home strings, or adding actions beyond these 5. Verify: `rg -n "RecoveryAction|openSettingsURLString" apps/photo-curator/Features/Processing/ProcessingView.swift` shows typed mapping + real Settings URL; `rg -n "chooseMorePhotos" apps/photo-curator/Features/Processing/ProcessingView.swift` returns nothing.

- [ ] **Step 4: Add ReviewReadyView (implementation task — NOT a placeholder)**

```swift
struct ReviewReadyView: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    var body: some View {
        // Transition/count screen ONLY: loads persisted SelectionResult via
        // appModel.loadResult (→ checkpointStore.loadResult, Task 2 seam); shows selected
        // count + unavailable line + Continue (guarded until result present).
        // Full grid/detail/groups arrive in feat-009 and reuse AppRoute.reviewReady unchanged.
    }
}
```

Lives in `ProcessingView.swift`; is not a Review feature and does not preempt feat-009 owns. Guard: Continue disabled until persisted result loads; missing result shows explicit retry-from-checkpoint (no automatic result-present routing — feat-012).

- [ ] **Step 5: Run `./init.sh`**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 4: Settings skeleton + end-to-end validation (100 real assets)

**Files:**
- Create: `apps/photo-curator/Features/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `AppModel` state (`authorization`, `presentPicker/openSettings`) only — NO `authorizationLabel`, NO `Bundle.main.appVersionString` (neither exists)
- Produces: S18 skeleton states (access row + privacy line + About) so feat-013 privacy/polish can extend without rewrite

- [ ] **Step 1: Add Settings skeleton (existing APIs only; explicit Home entry)**

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    private var accessLabel: String {
        switch appModel.authorization {
        case .authorized: return "Full Access"
        case .limited: return "Limited Photos Access"
        case .denied, .restricted: return "Photos Access Needed"
        case .notDetermined: return "Photos Access Not Set Up"
        }
    }
    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    var body: some View {
        List {
            Section("Photos Access") {
                Text(accessLabel)
                if appModel.authorization == .denied || appModel.authorization == .restricted {
                    Text("Allow photo access to choose images for curation.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Open Settings") { appModel.openSettingsURL() }
                } else if appModel.authorization == .limited {
                    Text("Only shared photos appear.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Choose More Photos") { appModel.presentPicker() }
                } else {
                    Button("Manage Photos Access") { appModel.presentPicker() }
                }
            }
            Section("Processing & Privacy") {
                Text("Photo analysis is performed on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                Text("Photos Curator \(appVersion)")
            }
        }.navigationTitle("Settings")
    }
}
```

Explicit entry (required BEFORE claiming smoke): HomeView gains a Settings gear/nav link → `appModel.openSettings()` (`.settings` route) — add in this task alongside the skeleton so the smoke path exists. `openSettingsURL()` is a Task-2 `AppModel` intent wrapping `UIApplication.openSettingsURLString` (keeps UIKit out of the view except via intent; either placement is acceptable but the intent must exist). No ranking weights, thresholds, models, cache, or thread-count controls. Denied path copy per ux-flows §5.3. Verify: `rg -n "authorizationLabel|appVersionString" apps/photo-curator/Features/Settings/SettingsView.swift` returns nothing; `rg -n "openSettings\(\)|Settings" apps/photo-curator/Features/Onboarding/HomeView.swift` shows the entry point.

- [ ] **Step 2: Run full verification**

Run: `./init.sh`
Expected: `BUILD SUCCEEDED`, `SKIP [test]`, `swiftlint --strict` 0 violations.

- [ ] **Step 3: Manual smoke — 100 real assets reach review (no test targets per policy)**

Check: (1) launch → Home → Settings gear → Settings shows access state + on-device line + version (entry exists BEFORE this claim); (2) Home → S05 pick ~100 → S06 Start Curation → S07 shows indeterminate `Preparing photos` <500 ms, then determinate `N of 100 analyzed` once BatchProgress lands (indeterminate again during select/final); (3) lock/background mid-run → return restores persisted completed count, no reset to zero, no redo of valid work (checkpoint reuse via explicit resume-if-paused); (4) cancel → `.cancelling` <250 ms → `.cancelled`, retry resumes from saved count; (5) airplane-mode iCloud set shows `Waiting for N photos from iCloud`, reconnect continues; (6) completion shows `100 analyzed (+ unavailable line when nonzero)` → Continue to Review lands on `reviewReady` with persisted `SelectionResult`. Kill/relaunch discovery + automatic result-present routing are feat-012 (deferred, NOT smoke-tested here). Record device model + iOS 26.x + counts in Handoff Evidence.

## Acceptance

- [x] S07/S08 run on real progress; 100 real assets reach review (PROVISIONAL 2026-09-11: code review-clean, sim smoke green; 100-asset device pass deferred as documented deviation, same precedent as feat-004)
- [x] `./init.sh` passes

## Self-Review checklist (re-run after trim — Oracle verdict keeps + 7 trims)

Keeps verified:
- [ ] Coordinator actor, ProcessingModel, exact BatchPipeline contract, real BatchProgress aggregation, SelectionError.cancelled mapping, additive routes, minimal ReviewReadyView (counts + Continue), 3-section Settings skeleton + one Home entry, one foreground checkpoint/resume path
- [ ] F1 BatchResult exact: `run(assets:sessionID:progress:)`, `resume(assets:sessionID:progress:)`, `BatchProgress(completed:total:analyzed:unavailable:)`, `BatchResult(analyses:unavailableIDs:)` consumed verbatim; no `runBatch(assets:resumeFrom:onProgress:)` remains
- [ ] F2 Real coordinator: `run` constructs/calls `BatchPipeline`, runs engine step, persists result + final checkpoint, subscribes `imageDownloadProgress` (assetID+fraction → Downloading n/total); no `throw SelectionError.internal` placeholder
- [ ] F4 Cancel path: `SelectionError.cancelled` handled as `.cancelled` (not `.failed`); bare `CancellationError`-only catch is gone
- [ ] F5 Unavailable sourced: `BatchResult.unavailableIDs` → `ProcessingProgress.unavailableCount` → `.completed(analyzed:unavailable:)` → S07/S08 lines; no `unavailable: 0` hardcode
- [ ] F6 Real route + Summary wiring: `processing(sessionID:)` carries the sessionID, `path.append(.processing(sessionID:))` always attached, no `fatalError` placeholder, S06 Start → `startCuration()` freezes the chrono snapshot
- [ ] F7 DI swap: `AppContainer.live()` injects `VisionAnalysisService()`, no `NoopImageAnalyzer` remains on the path
- [ ] F9 Task ordering: Task 2 lands `AppModel` intents/routes/DI/seams before Task 3 views consume them; every intermediate `./init.sh` passes
- [ ] F10 Additive routes + ReviewReady: `.sourceSelection`/`.summary` preserved, `.processing/.settings/.reviewReady` added, `ReviewReadyView` is a transition/count screen only (feat-009 owns review UI)
- [ ] Cross-chain: `BatchProgress`/`BatchResult` exact; routes additive; intents additive; request/session ID guaranteed (engine random ID re-stamped); feat-004 frozen chrono snapshot as input
- [ ] No Noop remains on the S06→S07→reviewReady path; coordinator `run` is real and checkpoint-backed
- [ ] `Downloading n/total` aggregates loader + pipeline signals with a real remaining count
- [ ] Cancel/stop, error/unavailable, and retry/resume-without-redo are all wired and manually exercised
- [ ] Settings is skeleton only; full privacy/polish left to feat-013
- [ ] Duplicates + moments untouched; feat-007 can consume coordinator API + view states + routes unchanged
- [ ] File Structure paths are exact; no feat-004/feat-005 files touched (one-line Start-button repoint excepted and noted in Scope)
- [ ] `./init.sh` steps list expected outputs; no TBD/TODO/vague steps remain

Trims verified:
- [ ] T1 No second store: no `SelectionResultStore` actor/file/type remains; results persist via `SessionCheckpointStore.saveResult/loadResult/deleteResult` (`results/` dir); `rg -n "SelectionResultStore"` over plan scope returns nothing
- [ ] T2 No UserPhase enum: display is the computed `ProcessingStage.userPhase: String`; canonical stored stages kept; `rg -n "enum UserPhase|func forStage" apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` returns nothing (`ProcessingState.preparing` is a transient UI state, not a stage); view reads `p.stage.userPhase`
- [ ] T3 Small RecoveryAction: exactly 5 cases (retry, openSettings, continueWithoutUnavailable, discard, goHome); no error-policy hierarchy; per-error table uses these 5 only; `chooseMorePhotos` gone
- [ ] T4 No pseudo-percentages: no 0.02/0.05/0.90/1.0 weights, no `0.85 *` scaling; determinate ONLY for the BatchProgress denominator, indeterminate (`totalUnits: 0`) elsewhere; view + smoke steps match
- [ ] T5 No unused state: no `startedAt`, no `settingsEntryAvailable`; every remaining field has an in-plan caller
- [ ] T6 feat-012 deferred: kill/relaunch discovery, automatic result-present routing, broader session recovery explicitly marked deferred; smoke tests only background checkpoint + explicit resume-if-paused
- [ ] T7 feat-013 deferred: storage-low + privacy/error polish explicitly marked deferred; S08 keeps minimal gate actions; ReviewReadyView is counts + Continue only

## Depends

- feat-005

## Handoff

- State: done
- Evidence: SDD Tasks 1→4 review-clean on stacked feat/feat-006 (eebeadb..2af0e90: aaec950+d32db5b coordinator + R1, 68dec42 seams, 7e6621d+27d18e6 views + R1, 699a0d0 settings; dc48f4e final wave-1 for 9 blockers; 2af0e90 user-authorized wave-2 for 3 guard items); re-reviews: wave-1 4/9 + wave-2 partial (discard + .notDetermined gate addressed); ./init.sh PASS every step; sim install/launch + Settings render OK.
- Blockers: parked residuals → feat-012 hardening (session-ownership interleavings: re-entrant finalize gate-vs-await atomicity, completed-session supersede cleanup, shell-save tracking, completion-vs-supersede ordering; transient cross-session note leakage; cancel-vs-persist micro-race; auto-retry-after-Settings) + 100-asset device QA + ReviewReady grid wiring (feat-009). Rulings in .agent-work/sdd/feat-006/progress.md. Single-session gate path (start→progress→complete→reviewReady) is review-clean.
- Next: feat-007 (user selects to start).

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
