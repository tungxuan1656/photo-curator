# iOS Architecture (topology and orchestration owner)

**Doc:** `ios-architecture.md` (native filename kept)
**Status:** MVP implementation baseline
**Role:** Single owner of app topology and runtime orchestration. Other docs link here. This doc does not copy them.

**Ownership:**
This doc owns single-target SwiftUI + Observation topology, AppContainer/DI, service boundaries, engine façade, scheduling and task groups, structured concurrency and cancellation, foreground-first checkpoints, runtime memory behavior, state machines, versioned config, and OSLog.

This doc does not own selection pipeline logic ([04](selection-engine.md)), selection policy ([03](../product-specs/selection-rules.md)), stored shapes ([06](data-model.md)), PhotoKit/Vision call shapes ([07](apple-frameworks.md)), budgets and resume numbers ([08](../ship-gates/performance.md)), UX flows and copy ([02](../product-specs/ux-flows.md)), privacy policy ([09](../ship-gates/privacy.md)), QA procedure ([10](../ship-gates/manual-qa.md)), or metrics events ([11](../ship-gates/analytics.md)). Where those topics appear below, this file states the boundary; the linked file states the rule.

**Incoming links:** 04, 06, 07, 08 link here for structure and scheduling. They do not restate it.
**Outgoing links:** This doc links to 02, 03, 04, 06, 07, 08, 09, 11. It does not copy their content.

Related docs:

- `ux-flows.md` — screens, copy, review actions
- `selection-rules.md` — what gets selected and why
- `selection-engine.md` — pipeline order and stage mechanics
- `data-model.md` — stored entity and cache shapes
- `apple-frameworks.md` — PhotoKit and Vision API use
- `performance.md` — budgets, concurrency numbers, resume intervals
- `privacy.md` — privacy, retention, redaction
- `analytics.md` — event schemas

---

## 1. System context (read first)

The app sits between SwiftUI and the Photos library. One session coordinator sequences work; services do the work; the engine decides.

```text
┌──────────────────────────────────────────────────┐
│                  Photos Curator                  │
│                                                  │
│  SwiftUI screens ──▶ AppModel (route + session)  │
│                            │                     │
│                            ▼                     │
│               SelectionSessionCoordinator        │
│               (actor: sequencing + progress)     │
│                 │          │           │         │
│                 ▼          ▼           ▼         │
│     PhotoLibrary  ImageAnalysis   SelectionEngine │
│     + loader      + cache         (façade, §7)    │
│                 │          │           │         │
│                 ▼          ▼           ▼         │
│              PhotoKit    Vision    Pure Swift     │
│                                                  │
│  AlbumExportService ──▶ User Photos Library      │
└──────────────────────────────────────────────────┘
```

Rules:

- Views trigger intents and render state. They do no fetching, analysis, or scoring.
- The coordinator owns order, progress, cancellation, and checkpoints. It owns no scoring formula.
- Services own Apple-framework contact. Domain code sees IDs and structs, not `PHAsset` or Vision request types.
- The engine is a callable façade. Its stage logic lives in [04](selection-engine.md).

---

## 2. Decisions at a glance

| Area | Decision |
|---|---|
| UI | SwiftUI + Observation (`@Observable`), `NavigationStack` with typed routes |
| App shape | One iOS app target, iOS 18+; folders bound behavior, no MVP packages |
| Composition | `PhotosCuratorApp` builds `AppContainer.live()` once, injects `AppModel` |
| UI state | `@MainActor @Observable` models; explicit enums, not boolean soup |
| Shared mutable background state | Actors (coordinator, cache, file store) |
| Concurrency | Swift structured concurrency: tasks, task groups, actors |
| Processing | Foreground-first, resumable at stage edges; no dependence on long background execution |
| Persistence | Light files and cache only; no database for MVP |
| Logging | OSLog `Logger` with subsystem and category |
| Analytics | Thin internal interface; provider deferred; schemas in [11](../ship-gates/analytics.md) |
| Validation | Manual QA per [10](../ship-gates/manual-qa.md); no test targets in repo |

Invariants (only use of MUST in this doc):

- The MVP MUST start with zero third-party runtime dependencies.
- The session MUST NOT retain decoded full-resolution images for the whole job.
- Every long-running loop and expensive stage MUST cooperate with Swift task cancellation.
- The selection engine MUST NOT import SwiftUI.
- Photo pixels, face data, and embeddings MUST NOT leave the device through app code; see [09](../ship-gates/privacy.md).

---

## 3. Design principles

- Keep views thin: render state, collect input, trigger intents, show progress and errors.
- Keep the engine UI-free: it takes IDs, analyses, config, and feedback, and returns decisions. No navigation, alerts, PhotoKit, or progress bars inside.
- Use protocols only at boundaries that vary or isolate Apple frameworks: photo library, image loading, analysis, cache, export, analytics. Do not add a protocol per class.
- Prefer value types (`struct`, `enum`, `Sendable`) for data crossing actors. Shared mutable coordinators are actors, not locked classes.
- Bound concurrency at every expensive stage. Exact numbers live in [08](../ship-gates/performance.md); this doc makes them configurable (§12).
- Treat cancellation as a normal path (leave flow, restart, source change, background, memory pressure, explicit Cancel).
- Persist little: in-memory session state, cache-directory derived data, small checkpoint manifest, settings storage for small prefs. Add SwiftData only when durable history needs it.

---

## 4. Repository topology

Single Xcode project, one application target.

```text
PhotosCurator/
├── App/            PhotosCuratorApp, AppContainer, AppModel, AppRoute, AppEnvironment
├── Features/       Onboarding, SourceSelection, Processing, Results, Review, Settings
├── Domain/         Models, Selection (engine façade + stages), Scoring
├── Services/       Photos, Analysis, Cache, Export, Analytics
├── Infrastructure/ FileStore, SessionCheckpointStore, MemoryPressureObserver, Logging
├── SharedUI/       AsyncPhotoThumbnail, EmptyStateView, ErrorStateView, Components
├── Resources/      Assets.xcassets, Localizable.xcstrings
└── Configuration/  AppConfiguration
```

Deliberately absent for MVP: test targets and `Tests/`, mock frameworks, DI frameworks, Swift packages per layer, generic networking, database abstraction, global event bus, Redux/TCA-style framework, custom operation queues, background scheduler, third-party image pipeline.

---

## 5. Composition (App + DI)

Entry point creates the container once and injects the root model. No expensive Photos or Vision work in `App.init()`.

```swift
@main
struct PhotosCuratorApp: App {
    @State private var appModel: AppModel

    init() {
        let container = AppContainer.live()
        _appModel = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
    }
}
```

`AppContainer` is a plain dependency holder, not a framework. It holds no feature state.

```swift
struct AppContainer: Sendable {
    let photoLibrary: any PhotoLibraryService
    let imageLoader: any PhotoImageLoader
    let analyzer: any ImageAnalysisService
    let analysisCache: any AnalysisCache
    let selectionEngine: SelectionEngine
    let exporter: any AlbumExportService
    let checkpointStore: SessionCheckpointStore
    let analytics: any AnalyticsService
}
```

Dependency direction:

```text
SwiftUI Views
    ↓
Feature / App models
    ↓
Service protocols + SelectionEngine façade
    ↓
PhotoKit / Vision / file-system implementations
```

---

## 6. Service boundaries

Each service owns one seam. Call shapes and API facts live in [07](apple-frameworks.md); stored shapes live in [06](data-model.md).

| Service | Owns | Must not own |
|---|---|---|
| `PhotoLibraryService` | Auth state, asset fetch, metadata map, missing-asset handling, change observation for live flows | Pixel analysis, scoring, clustering |
| `PhotoImageLoader` | Sized image delivery (thumbnail, analysis image), request choice, cancellation | Ranking, duplicates, moments |
| `ImageAnalysisService` | Image → `PhotoAnalysis` (feature print, faces, technical signals) | Albums, SwiftUI, final picks |
| `AnalysisCache` | Actor-isolated store of recomputable derived analysis, versioned and bounded | Original photo bytes |
| `AlbumExportService` | Create or reuse album, add selected assets, map write errors | Image copies, scoring |
| `AnalyticsService` | `track(_:)` for semantic events only | Image pixels, face data |

Contract notes:

- Consumers ask for an *analysis representation*, not the original. The loader picks request parameters. Full-resolution use needs a stated feature reason; see [04](selection-engine.md) and [07](apple-frameworks.md).
- The cache holds derived values only, in the app cache directory, safe to delete. Key shape and fingerprint rule: [06](data-model.md). Disk budget: [08](../ship-gates/performance.md).
- Export writes existing assets into an album through PhotoKit changes. Naming and reuse rules follow product docs; API mechanics: [07](apple-frameworks.md).
- Analytics receives events and counts only as [09](../ship-gates/privacy.md) permits. It never receives pixels by default. Event schemas: [11](../ship-gates/analytics.md).

---

## 7. Engine façade (schedule, do not own)

05 schedules the engine; 04 owns its logic. Policy (what wins, thresholds, reason-code meanings) is [03](../product-specs/selection-rules.md). Stage order and mechanics are [04](selection-engine.md).

```swift
struct SelectionEngine: Sendable {
    let duplicateResolver: DuplicateResolver
    let momentBuilder: MomentBuilder
    let qualityScorer: QualityScorer
    let diversitySelector: DiversitySelector
    let finalAlbumBuilder: FinalAlbumBuilder

    func select(
        assets: [PhotoAssetRecord],
        analyses: [PhotoAssetID: PhotoAnalysis],
        configuration: SelectionConfiguration,
        feedback: SelectionFeedback?
    ) throws -> SelectionResult
}
```

Façade rules:

- The engine is synchronous value-type logic where possible. It does not fetch images or await PhotoKit. Image work completes before final selection.
- Same inputs plus same engine version, config version, and feedback give the same result. Any tie-break seed derives from session or config so runs reproduce.
- Decisions carry reason codes and scores; UI formats the wording. Review edits re-enter only the affected balancing step, not full Vision analysis; review actions and copy: [02](../product-specs/ux-flows.md).

---

## 8. Scheduling and task groups

Owner: `ProcessingModel` (UI side) plus `SelectionSessionCoordinator` (actor side).

```swift
@MainActor
@Observable
final class ProcessingModel {
    private(set) var state: ProcessingState = .idle
    private(set) var progress: ProcessingProgress = .zero

    private let coordinator: SelectionSessionCoordinator
    private var processingTask: Task<Void, Never>?

    func start(request: SelectionRequest) {
        guard processingTask == nil else { return }
        processingTask = Task {
            do {
                let result = try await coordinator.run(
                    request: request,
                    onProgress: { [weak self] update in
                        await self?.apply(update)
                    }
                )
                state = .completed(result.summary)
            } catch is CancellationError {
                state = .cancelled
            } catch {
                state = .failed(UserFacingError(error))
            }
            processingTask = nil
        }
    }

    func cancel() {
        state = .cancelling
        processingTask?.cancel()
    }
}
```

```swift
actor SelectionSessionCoordinator {
    func run(
        request: SelectionRequest,
        onProgress: @Sendable (ProcessingProgress) async -> Void
    ) async throws -> SelectionResult {
        // 1. Fetch metadata → 2. Resolve cache/checkpoint
        // 3. Analyze missing assets → 4. Run engine → 5. Save result/checkpoint
    }
}
```

Scheduling rules:

- The actor guards session bookkeeping, checkpoint consistency, cache coordination, and counters. It does not serialize expensive image work; it launches bounded child tasks and collects results.
- Dynamic asset sets use task groups. No detached task per photo, no `DispatchQueue.global().async` as the default path.
- `Task.detached` is avoided unless an executor or inheritance reason requires it and lifetime and cancellation are understood.
- Partial failure is structural: one bad asset does not fail the job. The coordinator classes failures as skippable asset, degraded capability, or fatal session. Thresholds: [04](selection-engine.md) and [08](../ship-gates/performance.md).

---

## 9. Concurrency and cancellation rules

| Work | Isolation |
|---|---|
| SwiftUI state mutation | `MainActor` |
| Session orchestration | Coordinator actor |
| Cache and checkpoint mutation | Actors / serialized file store |
| PhotoKit wrappers | Service implementation; main-thread only where the API requires it |
| Vision and image analysis | Bounded concurrent child tasks |
| Pure scoring and selection | Synchronous values; child tasks only if profiling justifies it |

Cancellation checkpoints (minimum): before the next image request, after each load, before and after expensive Vision work, between selection stages, before cache or checkpoint writes when safe, before export. Use `try Task.checkCancellation()` and make wrapper continuations resume correctly under Apple-API cancellation.

Concurrency shape (bounded workers; exact limits in [08](../ship-gates/performance.md)):

```swift
// Conceptual: bounded worker pool over a task group.
var iterator = assets.makeIterator()
return try await withThrowingTaskGroup(of: (PhotoAssetID, PhotoAnalysis).self) { group in
    for _ in 0..<maxConcurrent {
        if let asset = iterator.next() { group.addTask { try await analyzeOne(asset) } }
    }
    while let result = try await group.next() {
        output[result.0] = result.1
        try Task.checkCancellation()
        if let next = iterator.next() { group.addTask { try await analyzeOne(next) } }
    }
    return output
}
```

Sendability: enable strict concurrency checking. Keep domain values `Sendable`. Do not spread non-sendable image or UIKit objects across actors; convert to the smallest needed representation at the service edge.

---

## 10. Foreground-first checkpoints

Design for interruption; do not depend on extended background execution. Checkpoint shape: [06](data-model.md). Frequency and resume budgets: [08](../ship-gates/performance.md).

- Checkpoint content is small: session ID, source definition, target size and config versions, source hash, completed analysis IDs, pipeline stage, timestamps. No image bytes.
- Write at safe stage edges (after source fetch, per analysis batch, after analysis, after shortlist, after final selection), not after every tiny op.
- Resume validates schema, source access, and changed or deleted assets, reuses valid cached analyses, and re-runs only invalid or missing work. Restart a stage fully when partial state risks correctness.
- On backgrounding: write a safe checkpoint if useful, stop starting expensive work, release decoded images, settle safe ops, and restore from cache or checkpoint on return.

---

## 11. Runtime memory behavior

- Retain metadata, compact analyses, compact descriptors, and visible thumbnails. Do not retain the job's decoded originals.
- Per-asset lifecycle: identifier → bounded analysis image → decode only as needed → Vision and quality signals → compact `PhotoAnalysis` → cache write if needed → release image. Wrap Objective-C-heavy per-image loops in `autoreleasepool` when profiling shows buildup.
- Use different sizes for grid, review, analysis, and the rare verification pass. The analysis stage uses the smallest size that keeps its signal; per-feature sizes: [04](selection-engine.md); delivery: [07](apple-frameworks.md).
- iCloud-backed assets surface as local success, network fetch where permitted, temporarily unavailable, permanently unavailable, or cancelled. The coordinator classifies; UI shows product language without PhotoKit detail.
- On memory pressure: drop nonessential thumbnails, stop prefetching, lower future concurrency per policy, release image buffers promptly, checkpoint if useful, and keep user review state. A warning does not destroy the active result.

---

## 12. State machines and progress contract

Prefer explicit enums over boolean groups.

```swift
enum ProcessingState: Equatable {
    case idle
    case preparing
    case running(ProcessingProgress)
    case cancelling
    case completed(SelectionSummary)
    case failed(UserFacingError)
    case cancelled
}
```

Session lifecycle:

```text
created → preparing → analyzing → selecting → readyForReview
    → exporting → completed
any active state → interrupted / cancelled / failed ──▶ retry / resume
```

Progress contract:

```swift
struct ProcessingProgress: Sendable, Equatable {
    var stage: ProcessingStage
    var completedUnits: Int
    var totalUnits: Int
    var overallFraction: Double
}
```

- Overall fraction never moves backward. Updates are throttled (rate: [08](../ship-gates/performance.md)) so the main actor is not flooded. Cancellation is separate from progress.
- Stage names here are orchestration labels. Selection-stage semantics: [04](selection-engine.md). User-facing labels and copy: [02](../product-specs/ux-flows.md).
- Typed internal errors per layer map to actionable UI categories (permission, unavailable, iCloud, interrupted, too few eligible, export, storage, unexpected). Never show raw errors. Copy: [02](../product-specs/ux-flows.md).

---

## 13. Versioned config

Centralize knobs; scatter no constants through views or services.

```swift
struct AppConfiguration: Sendable {
    var analysis: AnalysisConfiguration
    var selection: SelectionConfiguration
    var performance: PerformanceConfiguration
    var cache: CacheConfiguration
}
```

- Knob examples: analysis size class, concurrency caps, moment and duplicate thresholds, shortlist multiplier, album size, per-moment bounds, diversity weights, cache schema version. No remote config for MVP.
- Defaults and policy meaning: [03](../product-specs/selection-rules.md) and [04](selection-engine.md). Numeric caps and intervals: [08](../ship-gates/performance.md).
- Every result carries engine, analysis-schema, and config versions so caches invalidate, evaluations compare, and builds debug. Stored version fields: [06](data-model.md).

---

## 14. OSLog

Use `Logger` with subsystem and category separation. Suggested categories: `app`, `photos`, `analysis`, `selection`, `cache`, `export`, `performance`.

Log session starts, finishes, cancellations, asset counts by stage, cache hits and misses, stage durations, skipped counts, memory-pressure events, and export outcomes. Keep identifiers privacy-aware.

Do not log image bytes, face images, or sensitive metadata. Redaction and retention rules: [09](../ship-gates/privacy.md). Analytics stays separate: logging answers what happened on this device; analytics answers product behavior within the approved model. Analytics schemas: [11](../ship-gates/analytics.md).

---

## 15. Anti-patterns and deferred work

Do not: build one massive processing view model; spread `PHAsset` as the domain model; create a task per photo; request full resolution by default; run Vision on the main actor; split MVP packages prematurely; wrap everything in generic repositories; adopt a database before durable history needs it; promise background completion instead of resumability; mutate hidden global weights mid-session.

Deferred until a product need appears: cloud inference, accounts, cross-device sync, collaboration, remote config, flags, plugins, training pipelines, server embeddings, event sourcing, extra targets, custom queues, complex background scheduling, third-party image or state frameworks, in-repo automated tests.

---

## 16. Acceptance criteria

- One app target; folders separate features, domain, and services; engine free of SwiftUI; PhotoKit and Vision confined to services.
- UI-visible state is main-actor isolated with explicit state and progress types; one authoritative active session; review overrides outside transient view state.
- Expensive work uses bounded structured concurrency; cancellation flows from UI to work; no full-job image retention; shared mutable infrastructure is actor-isolated.
- Engine I/O uses domain models; runs reproduce from inputs plus versions and config; decisions carry reason codes; policy can evolve without touching PhotoKit or UI.
- One bad asset does not fail a job; interruption reuses valid work; cache corruption recovers by recomputation; curation never deletes or edits originals.
- No unneeded frameworks, packages, databases, test targets, or background-execution dependence.

---

## Uncertain

- Whether the oldest supported device forces the Vision concurrency default below the [08](../ship-gates/performance.md) starting value; tune from prototype profiling.
- Whether `PHCachingImageManager` preheat alone keeps review scrolling smooth at stress sizes, or a small bounded app-side thumbnail layer is needed.
- Whether resume needs per-batch checkpoints at 5,000 assets or stage-edge checkpoints suffice; confirm against interrupt testing.
