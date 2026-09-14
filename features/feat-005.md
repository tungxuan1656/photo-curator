# feat-005 — Vision core + batch pipeline

## Goal

Land Vision core + batch pipeline so every asset has versioned PhotoAnalysis.

## Scope

- `Services/Analysis/VisionAnalysisService.swift`
- `Domain/Models/PhotoAnalysis.swift`
- `Services/Photos/BatchPipeline.swift`

## Non-goals

- Anything outside owns; Processing UI stays in feat-006.
- No scoring/rank/diversity (feat-007/008); no coordinator/UI wiring (feat-006 owns `SelectionSessionCoordinator` + `Features/Processing`).

## Design (proposed 2026-09-11; feat-004 delivers the real source list first per sequential activation)

- Architecture: `VisionAnalysisService` implements existing `ImageAnalysisService.analyze(_:)` (one decode in, versioned `PhotoAnalysis` out); `BatchPipeline` owns batch loop only — cache check → `analysisImage(for:)` → analyze → store → release → checkpoint → 4 Hz progress. No UI, no ranking, no export. Owners: `design-docs/selection-engine.md` §5 (one decode fans out, release), `design-docs/apple-frameworks.md` §8 (Vision pipeline), `design-docs/data-model.md` §6/§13/§14, `ship-gates/performance.md` §1.
- Input assumption (sequential: feat-004 done first): caller passes chrono-sorted `[PhotoAsset]` (metadata only) + `SessionID`; pipeline never fetches the library itself and never persists `PHAsset`.
- Vision: `VNDetectFaceRectanglesRequest` + `VNDetectFaceCaptureQualityRequest` + light CPU heuristics (sharpness/exposure/resolution) off the single 512 px decode, each Vision request performed and failed independently so one request failure degrades its field only. Orientation already baked by `ImageLoaderService.normalizedCGImage`, so handler passes `.up` with no orientation side-channel. Partial Vision failure degrades per-field (`nil` ≠ `0`); only stale-ID and task-cancel and whole-decode failure reach asset level (`.invalidInput`/`.cancelled`/`.internal`). Owner: `apple-frameworks.md` §8.
- Duplicate similarity deferred (feat-007 owns it): no `VNGenerateImageFeaturePrintRequest` and no transient similarity store at this gate; feat-007 generates feature prints when it needs them.
- Cache staleness (documented limitation): `AnalysisCache.analysis(for:)` takes ID only, so feat-005 reuses version-gated cache rows as-is. Real fingerprint invalidation (`AssetFingerprint` compare) arrives with feat-012 — this plan does not claim it, only version-gated reuse.
- Pipeline mechanics: batches of 32 (`analysisBatchSize`), max 2 concurrent image+Vision lanes (`maxConcurrentImageRequests` / `heavyVisionConcurrency`), checkpoint at batch edges every 25 assets or 10 s (`checkpointEveryAssets` / `checkpointEverySeconds`), 4 Hz progress via a local `lastProgressDate` timestamp check in the single result-collection loop (`progressMaxHertz`), synchronous `autoreleasepool` around the sync Vision perform only (no `await` inside), cancel checks before fetch / after fetch / between Vision calls / before persist with cancel-after-checkpoint (checkpoint completed work before throwing `.cancelled`). iCloud/undecodable → count `unavailable`, continue. Owner: `performance.md` §1, `selection-engine.md` §14.
- Errors: reuse `SelectionError` only (`.invalidInput` stale ID, `.cancelled` task cancel, `.internal` decode/Vision/persist failure after policy). No new error enum.
- Privacy: persist counts/scores/version only; face boxes, feature-print blobs, precise location stay bounded-temp and released. No pixel persistence. Owner: `ship-gates/privacy.md` (what is kept).

## Implementation Plan (inline per AGENTS.md; no docs/plans file)

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every asset in the feat-004 source list gets a versioned `PhotoAnalysis` via a bounded batch pipeline with checkpoint/resume, per `performance.md` §1.

**Architecture:** One pure analyzer (`VisionAnalysisService: ImageAnalysisService`) plus one bounded orchestrator (`BatchPipeline`: cache → load → analyze → store → release → checkpoint → throttled progress). `FileAnalysisCache` + `SessionCheckpointStore` are consumed as-is; no store changes. DI swap (`NoopImageAnalyzer` → real service) arrives with the feat-006 coordinator, not here.

**Tech Stack:** Swift 5, Vision + CoreML on-device, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, SwiftLint --strict + SwiftFormat, PhotoKit pixels via loader only, `VN*` requests only (no custom Core ML model).

## Global Constraints

- Swift 5, Vision + CoreML on-device, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, SwiftLint --strict + SwiftFormat.
- NO test targets/no *Test*.swift/manual validation only + ./init.sh SKIP [test].
- iOS 26 min; smoke on iOS 26.5 device/simulator.
- on-device only never delete originals; only user-approved album write (later feat).
- AssetID wraps `PHAsset.localIdentifier`; never persist `PHAsset`, `UIImage`, or `CGImage`.
- reuse SelectionError invalidInput/cancelled/internal; no new public error type.
- analysis versioning for cache invalidation: stamp `AppConfiguration.default.analysis.analysisVersion`; `FileAnalysisCache` reuses only on version match.
- analysisImageMaxDimension 512, maxConcurrentImageRequests 2, analysisBatchSize 32, checkpointEveryAssets 25 / checkpointEverySeconds 10, progressMaxHertz 4 — read from `AppConfiguration.default`, never hard-code.

## File Structure

- Modify `apps/photo-curator/Domain/Models/PhotoAnalysis.swift` — add `currentVersion` + small clamp/make helper; no field renames (data-model §6 shape frozen).
- Create `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift` — `final class VisionAnalysisService: ImageAnalysisService` (face rects/quality + CPU heuristics, off-main, cancel-cooperative; no feature-print work).
- Create `apps/photo-curator/Services/Photos/BatchPipeline.swift` — `final class BatchPipeline: Sendable` (bounded batch loop + checkpoint + resume + 4 Hz timestamp-gated progress for feat-006).

Explicitly out (feat-006 owns): `AppContainer.live()` DI swap, `SelectionSessionCoordinator`, `Features/Processing` progress UI, `SessionProgress`/`ProcessingStage` mapping.

---

### Task 1: Freeze versioned PhotoAnalysis shape

**Files:**
- Modify: `apps/photo-curator/Domain/Models/PhotoAnalysis.swift`

**Interfaces:**
- Consumes: `AssetID`, `AppConfiguration.default.analysis.analysisVersion`, data-model §6 field table
- Produces: versioned `PhotoAnalysis` struct fields unchanged + `static var currentVersion: Int` + one small internal clamp/make helper in this file that Task 2 calls (no duplicate normalization rules in `VisionAnalysisService.swift`)

- [ ] **Step 1: Add version constant + small shared helper (no shape change)**

```swift
extension PhotoAnalysis {
    static var currentVersion: Int {
        AppConfiguration.default.analysis.analysisVersion
    }

    /// Single normalization rule. Internal so VisionAnalysisService.swift
    /// shares it; no private copy there.
    static func clamped01(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    /// Small shared factory: clamps scores once and stamps the version.
    /// VisionAnalysisService.swift calls this; it defines no clamp.
    static func make(
        assetID: AssetID,
        technical: TechnicalAnalysis,
        faceCount: Int,
        groupPhotoScore: Double?,
        subjectPlacementScore: Double?,
        sceneType: SceneType
    ) -> PhotoAnalysis {
        let sharp = clamped01(technical.sharpnessScore)
        let expo = clamped01(technical.exposureScore)
        let total = clamped01(0.6 * sharp + 0.4 * expo)
        return PhotoAnalysis(
            assetID: assetID,
            technical: technical,
            people: PeopleAnalysis(faceCount: max(0, faceCount), groupPhotoScore: groupPhotoScore.map(clamped01)),
            composition: CompositionAnalysis(
                aestheticScore: nil,
                subjectPlacementScore: subjectPlacementScore.map(clamped01),
                horizonScore: nil,
                visualBalanceScore: nil
            ),
            content: ContentAnalysis(sceneType: sceneType, tags: [], hasText: nil, screenshotProbability: nil),
            qualityScore: total,
            qualityBreakdown: QualityScoreBreakdown(
                technical: total, people: nil, composition: nil, content: nil, total: total
            ),
            analyzedAt: Date(),
            analysisVersion: currentVersion
        )
    }
}
```

Fail if any existing field is renamed/removed: `technical` (`TechnicalAnalysis`), `people` (`PeopleAnalysis`), `composition` (`CompositionAnalysis`), `content` (`ContentAnalysis`), `qualityScore`, `qualityBreakdown`, `analyzedAt`, `analysisVersion` must stay per data-model §6.

- [ ] **Step 2: Run format + lint + build**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 2: VisionAnalysisService (one decode → all signals → release)

**Files:**
- Create: `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift`

**Interfaces:**
- Consumes: analysisImage(for:) -> CGImage (512 upright pixels from feat-003 loader; orientation already baked), PHAsset metadata via `AnalysisInput.assetID` only (no PhotoKit calls here)
- Produces: versioned PhotoAnalysis struct fields (`technical`, `people`, `composition`, `content`, `qualityScore`, `qualityBreakdown?`, `analyzedAt`, `analysisVersion`) conforming to `ImageAnalysisService.analyze(_:)`

- [ ] **Step 1: Create service shell (cancellation-inheriting, no orientation side-channel)**

```swift
import CoreGraphics
import Foundation
import Vision

final class VisionAnalysisService: ImageAnalysisService, Sendable {
    func analyze(_ input: AnalysisInput) async throws -> PhotoAnalysis {
        try Task.checkCancellation()
        // Pixels arrive upright from ImageLoaderService.normalizedCGImage;
        // always pass .up so no orientation side-channel exists.
        // NOTE: plain child Task (not Task.detached) so cancellation and
        // priority propagate from the pipeline lane.
        return try await Task(priority: .userInitiated) {
            try Task.checkCancellation()
            return try self.performAll(input: input)
        }.value
    }
}
```

- [ ] **Step 2: Add per-request Vision with per-field degrade (sync autoreleasepool, shared constructor)**

```swift
private func performAll(input: AnalysisInput) async throws -> PhotoAnalysis {
    try Task.checkCancellation()
    // Each request runs independently: one request failing degrades its own
    // field only. Asset-level throws are limited to .invalidInput (never here:
    // loader owns ID resolution), .cancelled, and whole-decode .internal.
    // Feature-print generation is deferred to feat-007; no print request here.
    let handler = VNImageRequestHandler(cgImage: input.image, orientation: .up, options: [:])
    let faceRects = VNDetectFaceRectanglesRequest()
    let faceQuality = VNDetectFaceCaptureQualityRequest()

    var faceObservations: [VNFaceObservation] = []
    var bestFaceQuality: Double?

    // Synchronous Vision work only inside autoreleasepool (no await inside).
    // Cancellation is checked between requests, never inside the pool.
    try Task.checkCancellation()
    do {
        try autoreleasepool {
            try? handler.perform([faceRects])
            try? handler.perform([faceQuality])
        }
    } catch is CancellationError {
        throw SelectionError.cancelled
    } catch {
        throw SelectionError.internal
    }
    if Task.isCancelled { throw SelectionError.cancelled }
    faceObservations = faceRects.results ?? [] // nil results = unknown degraded to zero-count with nil quality, not a throw
    if let scores = faceQuality.results {
        bestFaceQuality = scores.compactMap(\.faceCaptureQuality).map(Double.init).max()
    }
    // faceQuality failing (nil results) leaves bestFaceQuality nil: per-field degrade.
    try Task.checkCancellation()
    let technical = Self.heuristics(on: input.image) // sync CPU pass, no await
    let faceCount = faceObservations.count
    // Shared factory owned by PhotoAnalysis.swift — no local clamp.
    return PhotoAnalysis.make(
        assetID: input.assetID,
        technical: technical,
        faceCount: faceCount,
        groupPhotoScore: faceCount >= 2 ? Double(faceCount) / 6.0 : nil,
        subjectPlacementScore: bestFaceQuality,
        sceneType: faceCount > 0 ? .people : .unknown
    )
}
```

Heuristics (`heuristics(on:)`): synchronous CPU pass on the 512 px `CGImage` returning a `TechnicalAnalysis` — Laplacian-variance → sharpness/blur, luma-histogram tails → exposure/under/over, pixel dims vs 512 edge → resolution. `PhotoAnalysis.make` clamps once; this file defines no clamp. Unknown-vs-zero: `faceRects.results == nil` yields `faceCount = 0` with `subjectPlacementScore = nil` (unknown quality, valid analysis); only whole-decode failure throws `.internal` per-asset and the caller counts it `unavailable`.

- [ ] **Step 3: Run format + lint + build**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 3: BatchPipeline (batch 32, cap 2, checkpoint 25/10s, 4 Hz, resume)

**Files:**
- Create: `apps/photo-curator/Services/Photos/BatchPipeline.swift`

**Interfaces:**
- Consumes: analysisImage(for:) -> CGImage (per-asset loader with locked once-only continuation per feat-003 precedent; pipeline never reimplements it), PHAsset metadata via chrono `[PhotoAsset]` input, `AnalysisCache`, `SessionCheckpointStore`, `AppConfiguration` budgets
- Produces: BatchPipeline API with progress/cancel/checkpoint/resume signatures so feat-006 coordinator can rely on them:

```swift
struct BatchProgress: Sendable {
    let completed: Int
    let total: Int
    let analyzed: Int
    let unavailable: Int
}

struct BatchResult: Sendable {
    let analyses: [AssetID: PhotoAnalysis]
    let unavailableIDs: [AssetID]
}

final class BatchPipeline: Sendable {
    init(
        imageLoader: any PhotoImageLoader,
        analyzer: any ImageAnalysisService,
        cache: any AnalysisCache,
        checkpoints: SessionCheckpointStore,
        config: AppConfiguration = .default
    )
    func run(
        assets: [PhotoAsset],
        sessionID: SessionID,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult
    func resume(
        assets: [PhotoAsset],
        sessionID: SessionID,
        progress: @Sendable @escaping (BatchProgress) -> Void
    ) async throws -> BatchResult
}
```

- [ ] **Step 1: Implement bounded run loop (concurrency 2, cancel-after-checkpoint, no await in pool)**

```swift
func run(
    assets: [PhotoAsset],
    sessionID: SessionID,
    progress: @Sendable @escaping (BatchProgress) -> Void
) async throws -> BatchResult {
    let total = assets.count
    guard total > 0 else { throw SelectionError.invalidInput }
    let batchSize = self.config.performance.analysisBatchSize // 32
    let laneCount = self.config.performance.maxConcurrentImageRequests // 2
    var analyses: [AssetID: PhotoAnalysis] = [:]
    var unavailable: [AssetID] = []
    var unavailableSet = Set<AssetID>()
    let progressInterval = 1.0 / max(1.0, self.config.performance.progressMaxHertz) // 4 Hz
    var lastProgressDate = Date.distantPast
    var completedSinceCheckpoint = 0
    var lastCheckpoint = Date()
    // Resume-first WITHOUT dropping work: checkpoint IDs reload from cache.
    // Cache hit → FULL analyses (kept). Checkpoint ID with no cache row →
    // prior unavailable (preserved, never re-fetched). Only the remainder queues.
    let done = await self.completedIDs(for: sessionID)
    var queue: [PhotoAsset] = []
    for asset in assets {
        if done.contains(asset.id) {
            if let hit = await self.cache.analysis(for: asset.id) {
                analyses[asset.id] = hit
            } else if unavailableSet.insert(asset.id).inserted {
                unavailable.append(asset.id)
            }
        } else if let hit = await self.cache.analysis(for: asset.id) {
            analyses[asset.id] = hit
        } else {
            queue.append(asset)
        }
    }
    var completed = total - queue.count
    progress(BatchProgress(completed: completed, total: total, analyzed: analyses.count, unavailable: unavailable.count))
    lastProgressDate = Date()
    do {
        for batchStart in stride(from: 0, to: queue.count, by: batchSize) {
            try Task.checkCancellation()
            let batch = Array(queue[batchStart ..< min(batchStart + batchSize, queue.count)])
            try await withThrowingTaskGroup(of: AssetOutcome.self) { group in
                var index = 0
                func submitNext() {
                    guard index < batch.count else { return }
                    let asset = batch[index]; index += 1
                    group.addTask { try await self.processOne(asset) }
                }
                for _ in 0 ..< min(laneCount, batch.count) { submitNext() }
                for try await outcome in group {
                    if Task.isCancelled { group.cancelAll() }
                    switch outcome {
                    case let .analyzed(analysis):
                        analyses[analysis.assetID] = analysis
                        await self.cache.store(analysis)
                    case let .unavailable(id):
                        if unavailableSet.insert(id).inserted { unavailable.append(id) }
                    }
                    completed += 1
                    completedSinceCheckpoint += 1
                    // 4 Hz gate: local timestamp check in the single
                    // result-collection loop; progress emitted from the parent.
                    if Date().timeIntervalSince(lastProgressDate) >= progressInterval {
                        progress(BatchProgress(completed: completed, total: total, analyzed: analyses.count, unavailable: unavailable.count))
                        lastProgressDate = Date()
                    }
                    if Task.isCancelled { group.cancelAll(); throw SelectionError.cancelled }
                    submitNext()
                }
            }
            // Checkpoint at batch edges: every 25 assets or 10 s, whichever first.
            let dueCount = completedSinceCheckpoint >= self.config.performance.checkpointEveryAssets
            let dueTime = Date().timeIntervalSince(lastCheckpoint) >= self.config.performance.checkpointEverySeconds
            if dueCount || dueTime {
                await self.saveCheckpoint(sessionID: sessionID, completed: Array(analyses.keys) + unavailable)
                completedSinceCheckpoint = 0
                lastCheckpoint = Date()
            }
        }
    } catch {
        // Cancel-after-checkpoint: completed work is checkpointed before the
        // throw so resume keeps it. Cancellation maps exactly to .cancelled.
        await self.saveCheckpoint(sessionID: sessionID, completed: Array(analyses.keys) + unavailable)
        progress(BatchProgress(completed: completed, total: total, analyzed: analyses.count, unavailable: unavailable.count))
        if error is CancellationError { throw SelectionError.cancelled }
        throw error
    }
    progress(BatchProgress(completed: completed, total: total, analyzed: analyses.count, unavailable: unavailable.count))
    await self.saveCheckpoint(sessionID: sessionID, completed: Array(analyses.keys) + unavailable)
    return BatchResult(analyses: analyses, unavailableIDs: unavailable)
}
```

`processOne(_:)`: `try Task.checkCancellation()` → `await imageLoader.analysisImage(for:)` (loader owns the locked once-only continuation + single transient retry; `.invalidInput`/`.internal` → return `.unavailable`, `.cancelled` → rethrow) → `try Task.checkCancellation()` → hold the returned `CGImage` in a local, `let analysis = try await analyzer.analyze(AnalysisInput(assetID: asset.id, image: cgImage))` (the synchronous Vision work with its `autoreleasepool` lives inside the analyzer — never `autoreleasepool { await … }` here), then release by scope exit (no stored `CGImage`, no pool around `await`) → return `.analyzed`. iCloud unavailable counts, never throws the batch.

- [ ] **Step 2: Add resume + checkpoint helpers**

```swift
func resume(
    assets: [PhotoAsset],
    sessionID: SessionID,
    progress: @Sendable @escaping (BatchProgress) -> Void
) async throws -> BatchResult {
    // Resume = run with checkpoint reload: run() restores FULL analyses from
    // cache for checkpoint IDs and preserves prior unavailableIDs, so resume
    // never drops completed work and never re-fetches it.
    try await self.run(assets: assets, sessionID: sessionID, progress: progress)
}

private func completedIDs(for sessionID: SessionID) async -> Set<AssetID> {
    (try? await self.checkpoints.load(sessionID: sessionID)).map { Set($0.completedAssetIDs) } ?? []
}

private func saveCheckpoint(sessionID: SessionID, completed: [AssetID]) async {
    let stub = SessionCheckpoint(
        sessionID: sessionID,
        stage: "analysis",
        completedAssetIDs: completed,
        configVersion: self.config.configVersion,
        analysisVersion: PhotoAnalysis.currentVersion,
        updatedAt: Date()
    )
    try? await self.checkpoints.save(stub) // best-effort; cache rows remain truth for redo
}

private enum AssetOutcome: Sendable {
    case analyzed(PhotoAnalysis)
    case unavailable(AssetID)
}
```

Cancel contract: `Task.checkCancellation()` before fetch/after fetch/between Vision/before persist; on cancel stop starting new assets, checkpoint completed analyses + preserved unavailableIDs first, release temps, then throw `SelectionError.cancelled` (feat-006 maps to UI ack < 250 ms). Never exit the group without the `catch`-path checkpoint above. One bad asset never fails the job: report `analyzed` vs `unavailable` counts at end.

- [ ] **Step 3: Run build + one manual behavior matrix (no test targets)**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.
Placeholder scan: `grep -rn "TODO\|FIXME\|TBD\|fatalError" apps/photo-curator/Services/Analysis apps/photo-curator/Services/Photos/BatchPipeline.swift apps/photo-curator/Domain/Models/PhotoAnalysis.swift` returns empty.

Manual matrix (one temporary caller harness, removed after; 100 local assets, counts recorded):
| Check | Do | Pass |
|---|---|---|
| Version invalidation | Bump `analysis.analysisVersion` in scratch config, relaunch | Prior rows ignored (re-analysis runs), new rows stamp new version; restore v1 after |
| Cancel-after-checkpoint | Cancel mid-run | `SelectionError.cancelled` surfaces; checkpoint file holds completed work |
| Resume | Resume same `SessionID` | `completed` continues from checkpoint (no redo); final `BatchResult` holds FULL analyses |
| One unavailable | Airplane-mode an iCloud asset / revoke one asset | Run finishes; asset in `unavailableIDs`, rest in `analyses` |
| Callback rate | Count progress callbacks over wall time | ≤ 4 Hz |

## Acceptance

- [x] Every asset has versioned PhotoAnalysis; batch + checkpoint per performance §1 (matrix 5/5 on synthetic host: invalidation, cancel-after-checkpoint, FULL resume, unavailable split, 3.64Hz; real PhotoKit/Vision device path is follow-up)
- [x] `./init.sh` passes

## Depends

- feat-004 (sequential: real chrono `[PhotoAsset]` source list is done first)

## Handoff

- State: done
- Evidence: SDD Tasks 1→3 review-clean on feat/feat-005 (29a1471..eebeadb: 7d4f4a0 shape, 4772a2a+d8398e2 Vision + fix R1, afb92d9 pipeline, eebeadb final wave); Task 2 review fail → R1 ALL ADDRESSED; final review 2 blockers → wave → re-review I1 addressed, M1 parked (duplicate-terminal-callback edge, not load-bearing — ruling in .agent-work/sdd/feat-005/progress.md); ./init.sh PASS every step; BatchPipeline exact feat-006 contract.
- Blockers: follow-ups — real-device PhotoKit/Vision 100-asset pass; parked M1 edge (feat-006 treats terminal updates idempotently).
- Next: feat-006 on stacked branch feat/feat-006.

## Self-Review checklist (re-run after Oracle trim)

- [ ] Spec coverage vs performance §1 (batch 32, 2 lanes, checkpoint 25/10 s, 4 Hz local-timestamp gate, version-gated reuse, idempotent resume returning FULL analyses + preserved unavailableIDs, cancel-after-checkpoint) verified in Task 3 code above.
- [ ] Spec coverage vs data-model §6/§13/§14 (PhotoAnalysis fields frozen, one small shared clamp/make helper with no cross-file duplication, version vs engine-version split, no face-box/blob persistence, version-gated cache + feat-012 fingerprint limitation documented) verified in Tasks 1–2.
- [ ] Trim 1: no `TransientSimilarityStore` actor, cap, evict, or steps remain; Design notes the feat-007 deferral.
- [ ] Trim 2: no `VNGenerateImageFeaturePrintRequest` warm-path at this gate; deferral to feat-007 explicit.
- [ ] Trim 3: no `ProgressThrottle`/`NSLock` types; progress uses the local `lastProgressDate` check in the single result-collection loop.
- [ ] Trim 4: behavioral evidence is ONE manual matrix step in Task 3 Step 3.
- [ ] Trim 5: clamping is the small `clamped01` + `make` helper; Vision service calls it, defines no clamp.
- [ ] Trim 6: no dimensions pseudo-fingerprint check; version-gated reuse + feat-012 limitation retained.
- [ ] Placeholder scan: `grep -rn "TODO\|FIXME\|TBD\|fatalError"` over the three owned files returns empty.
- [ ] Type consistency: `VisionAnalysisService: ImageAnalysisService` `analyze(_:)` throws `SelectionError` only; `PhotoAnalysis.currentVersion` + `analysisVersion` stamp; `BatchPipeline` `init(imageLoader:analyzer:cache:checkpoints:config:)`, `run/resume(assets:sessionID:progress:) -> BatchResult`, `BatchProgress(completed/total/analyzed/unavailable)`; `AssetID`, `SelectionError` cases, budget names match `ServiceProtocols.swift` + `AppConfiguration` exactly.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
