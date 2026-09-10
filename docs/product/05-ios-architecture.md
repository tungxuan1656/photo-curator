# 05 — iOS Architecture

**Product:** Photos Curator  
**Repository artifact:** `05_iOS_Architecture.md`  
**Status:** Required / implementation baseline  
**Primary platform:** iPhone / iOS  
**Architecture style:** SwiftUI + Observation + Swift Concurrency, single application target  
**Related documents:** `01_PRD.md`, `02_UX_Flows.md`, `03_Photo_Selection_Rules.md`, `04_Selection_Engine_Design.md`, `06_Data_Model.md`, `07_Apple_Framework_Integration.md`, `08_Performance_Spec.md`, `09_Privacy_and_Permissions.md`, `10_Manual_QA_and_Selection_Evaluation.md`, `11_Analytics_and_Metrics.md`

---

## 1. Purpose

This document defines the implementation architecture for **Photos Curator**, an iOS application that analyzes a large set of user photos and produces a smaller, high-quality, diverse album.

The architecture is intentionally optimized for:

- rapid MVP development;
- native Apple frameworks;
- on-device processing;
- predictable memory usage when processing roughly 1,000–5,000 photo assets;
- clean separation between UI, photo-library access, image analysis, and selection logic;
- interruption and cancellation support;
- future evolution of the selection engine without rewriting the application shell;
- minimal infrastructure and minimal abstraction that does not directly improve implementation clarity.

This is **not** a generic enterprise architecture. Photos Curator should remain a small, comprehensible codebase until product requirements prove that more modularity is necessary.

---

## 2. Architectural Decisions at a Glance

| Area | Decision |
|---|---|
| UI framework | SwiftUI |
| UI observation | Observation framework (`@Observable`) |
| Concurrency | Swift structured concurrency (`async/await`, task groups, actors) |
| Language mode | Swift 6 preferred |
| App structure | One iOS application target |
| Internal modularity | Folder / namespace boundaries, not separate packages initially |
| Dependency management | Native frameworks only for MVP unless a dependency solves a demonstrated problem |
| Photo access | PhotoKit |
| Image analysis | Vision + Core Image / ImageIO where needed |
| Selection engine | Pure Swift domain/service layer, independent from SwiftUI |
| Main application state | `@MainActor @Observable` models |
| Shared mutable background state | Actors |
| Persistence | Lightweight files/cache for MVP; no database required initially |
| Processing | Foreground-first, resumable/checkpointed; do not rely on long-running background execution |
| Cancellation | Cooperative cancellation throughout the pipeline |
| Navigation | SwiftUI `NavigationStack` / explicit app route state |
| Logging | `OSLog` / `Logger` |
| Analytics | Thin internal analytics interface; provider choice deferred |
| Tests in repository | None for MVP by project decision |
| Validation | Manual QA and curated selection-evaluation datasets as defined in document 10 |

---

## 3. Design Principles

### 3.1 Keep the UI thin

SwiftUI views should be responsible for:

- rendering state;
- collecting user input;
- triggering high-level intents;
- displaying progress, errors, and selection results.

Views must **not** contain:

- PhotoKit fetch logic;
- Vision requests;
- duplicate detection;
- moment clustering;
- ranking formulas;
- cache coordination;
- long-running loops over photo assets.

### 3.2 Keep the selection engine independent from iOS presentation

The selection engine should operate on domain values such as:

- asset identifiers;
- analysis records;
- moments;
- duplicate groups;
- quality scores;
- selection constraints;
- user feedback;
- final decisions.

It should not know about:

- SwiftUI views;
- navigation;
- alerts;
- UIKit controllers;
- `PHImageManager` callbacks;
- progress bars.

This makes the core algorithm easier to reason about and allows its implementation to change without destabilizing UI code.

### 3.3 Use protocols only at meaningful boundaries

Protocols are useful where the implementation is likely to vary or where an Apple framework needs to be isolated from domain code.

Recommended protocol boundaries include:

- photo-library access;
- image loading;
- image analysis;
- analysis cache;
- album export;
- analytics.

Do **not** create a protocol for every class or every SwiftUI model.

### 3.4 Prefer value types for analysis data

Analysis output should primarily use `struct` and `enum` values that are immutable or mutated locally. These values should be `Sendable` wherever practical.

Examples:

- `PhotoAssetRecord`
- `PhotoAnalysis`
- `QualityScore`
- `Moment`
- `DuplicateCluster`
- `SelectionDecision`

Shared mutable coordinators should normally be actors rather than reference types protected by manual locks.

### 3.5 Bound concurrency explicitly

A 1,000-photo job must not launch 1,000 full-resolution analysis tasks simultaneously.

Every expensive stage must have a concurrency limit based on resource cost. The processing pipeline should prefer several small concurrent workers over unbounded task creation.

Exact values are performance-tuned in `08_Performance_Spec.md`; the architecture must make those limits configurable.

### 3.6 Treat cancellation as a normal control path

Cancellation is expected when the user:

- leaves the processing flow;
- starts over;
- changes the source album or date range;
- sends the app to the background;
- encounters memory pressure;
- explicitly taps Cancel.

Every long-running loop and expensive stage should cooperate with Swift task cancellation.

### 3.7 Avoid unnecessary persistence

For the MVP, the app does not need a general-purpose database simply because it processes many assets.

Use:

- in-memory session state for the active job;
- the app cache directory for derived/recomputable data;
- a small checkpoint/session manifest when resume behavior requires it;
- app settings storage only for small preferences.

Introduce SwiftData or another persistent database only when durable personalization/history becomes a product requirement that cannot be handled cleanly with lightweight storage.

---

## 4. Technology Baseline

The recommended baseline is:

- **SwiftUI** for application UI;
- **Observation** for observable UI state;
- **Swift Concurrency** for asynchronous work;
- **PhotoKit** for photo-library authorization, asset discovery, image requests, and album writes;
- **Vision** for supported on-device visual analysis such as face-related observations and image feature prints;
- **Core Image / ImageIO** only where image decoding, orientation, resizing, or auxiliary analysis requires them;
- **Foundation** for file storage, dates, identifiers, Codable manifests, and URL handling;
- **OSLog** for diagnostics;
- **PhotosUI** only when a Photos picker UI is required by a specific flow.

### 4.1 Deployment target

Recommended MVP deployment target: **iOS 18 or later**.

Rationale:

- supports the modern SwiftUI and Observation programming model;
- supports Swift concurrency well;
- retains broader device coverage than targeting only the newest OS generation;
- avoids carrying compatibility layers for substantially older SwiftUI behavior.

If product requirements later demand a different minimum OS, re-evaluate only the affected API availability. Do not fork the architecture by OS version unless necessary.

### 4.2 External dependencies

The MVP should start with **zero third-party runtime dependencies**.

A third-party dependency may be added later only when all of the following are true:

1. a concrete product or engineering problem exists;
2. the Apple platform does not already provide an adequate solution;
3. implementing the capability internally would cost materially more;
4. the dependency has acceptable privacy and maintenance characteristics;
5. the dependency does not require uploading the user's photo content unless that becomes an explicit product decision.

---

## 5. System Context

At runtime, Photos Curator sits between the user interface and the user's Photos library.

```text
┌─────────────────────────────────────────────────────────────┐
│                       Photos Curator                        │
│                                                             │
│  ┌──────────────┐      ┌────────────────────────────────┐  │
│  │ SwiftUI      │      │ Selection Session              │  │
│  │ Screens      │ ───▶ │ orchestration + app state      │  │
│  └──────────────┘      └──────────────┬─────────────────┘  │
│                                       │                    │
│                  ┌────────────────────┼─────────────────┐  │
│                  │                    │                 │  │
│                  ▼                    ▼                 ▼  │
│        ┌────────────────┐   ┌────────────────┐  ┌──────────────┐
│        │ Photo Library  │   │ Image Analysis │  │ Selection    │
│        │ Service        │   │ Service        │  │ Engine       │
│        └───────┬────────┘   └───────┬────────┘  └──────┬───────┘
│                │                    │                  │
│                ▼                    ▼                  ▼
│           PhotoKit               Vision          Pure Swift rules
│                                                        + scoring
│
│        ┌────────────────┐   ┌────────────────┐
│        │ Analysis Cache │   │ Album Export   │
│        └────────────────┘   └───────┬────────┘
│                                     │
└─────────────────────────────────────┼───────────────────────┘
                                      ▼
                               User Photos Library
```

The **Selection Session** is the central orchestration layer. It is responsible for sequencing work, but it should delegate specialized operations to services and the selection engine.

---

## 6. Repository Structure

Use a **single Xcode project and one application target** for the MVP.

Recommended source layout:

```text
PhotosCurator/
├── App/
│   ├── PhotosCuratorApp.swift
│   ├── AppContainer.swift
│   ├── AppModel.swift
│   ├── AppRoute.swift
│   └── AppEnvironment.swift
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── PermissionExplanationView.swift
│   │
│   ├── SourceSelection/
│   │   ├── SourceSelectionView.swift
│   │   └── SourceSelectionModel.swift
│   │
│   ├── Processing/
│   │   ├── ProcessingView.swift
│   │   ├── ProcessingModel.swift
│   │   ├── ProcessingProgressView.swift
│   │   └── ProcessingStageView.swift
│   │
│   ├── Results/
│   │   ├── ResultsView.swift
│   │   └── ResultsModel.swift
│   │
│   ├── Review/
│   │   ├── ReviewView.swift
│   │   ├── PhotoReviewCell.swift
│   │   └── ReviewModel.swift
│   │
│   └── Settings/
│       └── SettingsView.swift
│
├── Domain/
│   ├── Models/
│   │   ├── PhotoAssetRecord.swift
│   │   ├── PhotoAnalysis.swift
│   │   ├── Moment.swift
│   │   ├── Cluster.swift
│   │   ├── SelectionDecision.swift
│   │   └── SelectionSession.swift
│   │
│   ├── Selection/
│   │   ├── SelectionEngine.swift
│   │   ├── SelectionConfiguration.swift
│   │   ├── CandidateBuilder.swift
│   │   ├── DuplicateResolver.swift
│   │   ├── MomentSelector.swift
│   │   ├── DiversitySelector.swift
│   │   └── FinalAlbumBuilder.swift
│   │
│   └── Scoring/
│       ├── QualityScorer.swift
│       ├── FaceScorer.swift
│       ├── TechnicalQualityScorer.swift
│       └── DiversityScorer.swift
│
├── Services/
│   ├── Photos/
│   │   ├── PhotoLibraryService.swift
│   │   ├── PhotoKitLibraryService.swift
│   │   ├── PhotoImageLoader.swift
│   │   └── PhotoKitImageLoader.swift
│   │
│   ├── Analysis/
│   │   ├── ImageAnalysisService.swift
│   │   ├── VisionImageAnalysisService.swift
│   │   └── AnalysisPipeline.swift
│   │
│   ├── Cache/
│   │   ├── AnalysisCache.swift
│   │   └── DiskAnalysisCache.swift
│   │
│   ├── Export/
│   │   ├── AlbumExportService.swift
│   │   └── PhotoKitAlbumExportService.swift
│   │
│   └── Analytics/
│       ├── AnalyticsService.swift
│       └── NoOpAnalyticsService.swift
│
├── Infrastructure/
│   ├── FileStore.swift
│   ├── SessionCheckpointStore.swift
│   ├── MemoryPressureObserver.swift
│   └── Logging.swift
│
├── SharedUI/
│   ├── AsyncPhotoThumbnail.swift
│   ├── EmptyStateView.swift
│   ├── ErrorStateView.swift
│   └── Components/
│
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
│
└── Configuration/
    └── AppConfiguration.swift
```

### 6.1 Deliberate omissions

The MVP repository should **not** contain:

- unit-test target;
- UI-test target;
- `Tests/` directory;
- snapshot-test infrastructure;
- mock-generation framework;
- dependency-injection framework;
- separate Swift packages for each layer;
- generic networking layer when the app does not need networking;
- database abstraction when the app does not need a database;
- global event bus;
- Redux/TCA-style state framework unless future complexity clearly justifies it.

Manual validation is handled through `10_Manual_QA_and_Selection_Evaluation.md`.

---

## 7. Application Composition

### 7.1 `PhotosCuratorApp`

The application entry point should create the dependency container once and inject the root app model into SwiftUI.

Conceptually:

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

Do not perform expensive Photos or Vision work in `App.init()`.

### 7.2 `AppContainer`

`AppContainer` is a simple dependency holder, not a general dependency-injection framework.

Example responsibilities:

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

The live factory constructs real implementations:

```swift
extension AppContainer {
    static func live() -> AppContainer {
        // Construct native-framework-backed services here.
    }
}
```

The container should not contain feature state.

### 7.3 Dependency direction

Dependencies should point inward:

```text
SwiftUI Views
    ↓
Feature/App Models
    ↓
Service protocols + Selection Engine
    ↓
PhotoKit / Vision / File system implementations
```

The domain selection code must not import SwiftUI.

---

## 8. UI Architecture

### 8.1 Root state

Use a small `@MainActor @Observable` root model.

```swift
@MainActor
@Observable
final class AppModel {
    var route: AppRoute = .sourceSelection
    var activeSession: ProcessingModel?
    var presentedError: UserFacingError?

    let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }
}
```

The root model owns only application-level state.

### 8.2 Feature state

Create a feature model when a screen or multi-screen flow has meaningful asynchronous state.

Examples:

- `SourceSelectionModel`
- `ProcessingModel`
- `ResultsModel`
- `ReviewModel`

Avoid creating a view model for tiny stateless components.

### 8.3 Main actor rule

Anything directly observed by SwiftUI should normally be `@MainActor`.

That includes:

- current screen state;
- processing progress shown to the user;
- error presentation;
- final selection state;
- review edits;
- navigation state.

CPU-heavy work must not run on the main actor.

### 8.4 State as explicit enums

Prefer explicit state machines over many loosely related booleans.

Bad:

```swift
var isLoading: Bool
var didFail: Bool
var isFinished: Bool
var isCancelled: Bool
```

Preferred:

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

This prevents impossible combinations such as `isLoading == true` and `isFinished == true`.

---

## 9. Navigation Architecture

Use `NavigationStack` with a small typed route model.

Example:

```swift
enum AppRoute: Hashable {
    case sourceSelection
    case processing(sessionID: UUID)
    case results(sessionID: UUID)
    case review(sessionID: UUID)
    case settings
}
```

The app should avoid deep-link infrastructure for MVP unless required by the PRD.

Navigation rules:

- permission denial routes back to an actionable permission state;
- processing completion routes to results;
- cancellation returns to source selection or the previous stable screen;
- review edits do not restart the complete analysis pipeline unless required by the rule being changed;
- exporting an album is an action from results/review, not a separate navigation subsystem.

Detailed screen behavior belongs in `02_UX_Flows.md`.

---

## 10. Service Boundaries

## 10.1 Photo library service

Purpose: isolate PhotoKit library operations from the rest of the app.

```swift
protocol PhotoLibraryService: Sendable {
    func authorizationStatus() -> PhotoAuthorizationStatus
    func requestReadWriteAuthorization() async -> PhotoAuthorizationStatus

    func fetchAssets(
        source: PhotoSource,
        options: PhotoFetchOptions
    ) async throws -> [PhotoAssetRecord]
}
```

Responsibilities:

- authorization state;
- asset enumeration;
- mapping `PHAsset` to internal identifiers/metadata;
- detecting unavailable or deleted assets;
- observing relevant library changes if needed.

It should not analyze image pixels.

## 10.2 Image loader

Purpose: request appropriately sized image representations from PhotoKit.

```swift
protocol PhotoImageLoader: Sendable {
    func thumbnail(
        for assetID: PhotoAssetID,
        targetSize: CGSize
    ) async throws -> LoadedImage

    func analysisImage(
        for assetID: PhotoAssetID,
        specification: AnalysisImageSpecification
    ) async throws -> LoadedImage
}
```

Key rule: consumers ask for an **analysis representation**, not automatically the original full-resolution image.

The loader decides the PhotoKit request parameters required to meet the specification.

## 10.3 Image analysis service

Purpose: convert image representations into structured analysis features.

```swift
protocol ImageAnalysisService: Sendable {
    func analyze(
        asset: PhotoAssetRecord,
        image: LoadedImage,
        configuration: AnalysisConfiguration
    ) async throws -> PhotoAnalysis
}
```

The live implementation can use Vision and lightweight image statistics.

Potential outputs include:

- feature-print descriptor/reference;
- face count and face geometry;
- face quality-related signals supported by the chosen analysis design;
- exposure/brightness estimates;
- blur/sharpness estimate;
- orientation/crop metadata;
- scene-level signals needed by selection rules.

The exact model is specified in `06_Data_Model.md` and feature definitions in `04_Selection_Engine_Design.md`.

## 10.4 Analysis cache

Purpose: avoid recomputing expensive derived analysis for unchanged assets.

```swift
protocol AnalysisCache: Sendable {
    func value(for key: AnalysisCacheKey) async -> PhotoAnalysis?
    func insert(_ analysis: PhotoAnalysis, for key: AnalysisCacheKey) async throws
    func removeValue(for key: AnalysisCacheKey) async
    func removeAll() async throws
}
```

The implementation should be actor-isolated.

The cache is **recomputable data** and belongs in the app cache directory.

## 10.5 Album export service

Purpose: write selected existing assets into a Photos album.

```swift
protocol AlbumExportService: Sendable {
    func createAlbum(
        named name: String,
        assetIDs: [PhotoAssetID]
    ) async throws -> ExportResult
}
```

The export service should create/reuse the destination album according to product rules and add the selected assets through PhotoKit changes.

## 10.6 Analytics service

Analytics should use a very thin interface.

```swift
protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent) async
}
```

The default development implementation may be a no-op or local logger.

Analytics must receive metadata/events only as permitted by `09_Privacy_and_Permissions.md`; it should never receive image pixels by default.

---

## 11. Selection Engine Architecture

The selection engine is the product's core logic. It should be a composition of understandable stages rather than one giant function.

Recommended logical flow:

```text
Fetched assets
    ↓
Analysis records
    ↓
Eligibility filtering
    ↓
Near-duplicate grouping
    ↓
Moment grouping
    ↓
Per-photo quality scoring
    ↓
Best-of-cluster / best-of-moment candidates
    ↓
Shortlist
    ↓
Diversity balancing
    ↓
Final album size enforcement
    ↓
Selection decisions + explanations
```

### 11.1 `SelectionEngine`

The engine itself should be a value-type façade where possible.

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
    ) throws -> SelectionResult {
        // Pure/mostly-pure selection logic.
    }
}
```

The engine should not fetch images or await PhotoKit unless a future algorithm absolutely requires additional pixels. Prefer completing image analysis before entering final selection.

### 11.2 Determinism

Given the same:

- asset metadata;
- image-analysis values;
- engine version;
- configuration;
- feedback;

the selection result should be deterministic.

If randomness is ever useful for tie-breaking, use a deterministic seed derived from the session/configuration so results remain reproducible.

### 11.3 Explainability

Each final decision should retain enough structured information to answer questions such as:

- Why was this photo selected?
- Why was another near-duplicate rejected?
- Which moment did this photo represent?
- Did diversity constraints affect the decision?

Do not store user-facing explanation strings as the primary logic output. Store reason codes and underlying scores; format them for UI separately.

---

## 12. Processing Orchestration

The orchestration layer connects services to the selection engine.

A recommended owner is `ProcessingModel` plus a background coordinator actor.

### 12.1 UI-facing model

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

This model does not directly manipulate PhotoKit or Vision.

### 12.2 Coordinator actor

```swift
actor SelectionSessionCoordinator {
    // Services and session bookkeeping.

    func run(
        request: SelectionRequest,
        onProgress: @Sendable (ProcessingProgress) async -> Void
    ) async throws -> SelectionResult {
        // 1. Fetch metadata
        // 2. Restore cache/checkpoint
        // 3. Analyze missing assets
        // 4. Run selection engine
        // 5. Save result/checkpoint
    }
}
```

The actor protects:

- active session bookkeeping;
- checkpoint consistency;
- analysis-cache coordination when needed;
- mutable counters used by orchestration.

The actor must not serialize all expensive image analysis into one-at-a-time work. It can launch bounded child tasks and collect their results.

---

## 13. Concurrency Model

Swift structured concurrency is the default concurrency system.

### 13.1 Concurrency ownership

| Work | Isolation |
|---|---|
| SwiftUI state mutations | `MainActor` |
| Session orchestration | actor |
| Cache index/mutations | actor |
| PhotoKit async wrappers | service implementation; not assumed main-thread unless API requires it |
| Vision analysis | concurrent child tasks with a limit |
| Pure scoring / selection | synchronous values or child tasks if demonstrably beneficial |
| File checkpoint writes | actor / serialized file store |

### 13.2 Prefer structured child tasks

Use task groups for a dynamic collection of assets.

Do not create one detached task per photo.

Do not use `DispatchQueue.global().async` as the default mechanism for CPU work when Swift concurrency can express the same lifecycle.

### 13.3 Bounded parallelism

A conceptual bounded worker implementation:

```swift
func analyzeAssets(
    _ assets: [PhotoAssetRecord],
    maxConcurrent: Int
) async throws -> [PhotoAssetID: PhotoAnalysis] {
    var iterator = assets.makeIterator()
    var output: [PhotoAssetID: PhotoAnalysis] = [:]

    return try await withThrowingTaskGroup(
        of: (PhotoAssetID, PhotoAnalysis).self
    ) { group in
        for _ in 0..<maxConcurrent {
            if let asset = iterator.next() {
                group.addTask {
                    try await analyzeOne(asset)
                }
            }
        }

        while let result = try await group.next() {
            output[result.0] = result.1

            try Task.checkCancellation()

            if let next = iterator.next() {
                group.addTask {
                    try await analyzeOne(next)
                }
            }
        }

        return output
    }
}
```

The exact implementation may differ, but the important property is that the number of simultaneously expensive tasks is bounded.

### 13.4 Cancellation

At minimum, check cancellation:

- before requesting the next asset image;
- after each image load;
- before expensive Vision requests;
- after analysis completion;
- between major selection stages;
- before cache/checkpoint writes when safe;
- before export.

Use:

```swift
try Task.checkCancellation()
```

and ensure wrapper APIs resume continuations correctly even when underlying Apple APIs have their own cancellation mechanism.

### 13.5 `Task.detached`

Avoid `Task.detached` in the MVP.

Use it only when there is a specific executor/inheritance reason and the lifetime/cancellation implications are fully understood. Normal image processing should remain inside the structured session task hierarchy.

### 13.6 Sendability

Enable strict concurrency checking and make domain values `Sendable` whenever practical.

Do not pass non-sendable UIKit/Core Graphics objects broadly across actors. Convert them into the smallest required representation or constrain their use to a specific task/service scope.

---

## 14. Image Ownership and Memory Architecture

A photo-selection application can fail primarily through memory pressure even when its algorithm is correct.

### 14.1 Never retain decoded full-resolution images for the complete job

The session should retain:

- lightweight asset metadata;
- compact analysis values;
- compact feature descriptors where needed;
- selected thumbnail cache entries.

It should not retain 1,000 decoded originals.

### 14.2 Per-asset lifecycle

Recommended analysis lifecycle:

```text
PHAsset identifier
    ↓
request bounded-size analysis image
    ↓
decode / normalize only as required
    ↓
run Vision / quality analysis
    ↓
produce compact PhotoAnalysis
    ↓
write analysis cache if needed
    ↓
release image representation
```

Use `autoreleasepool` around Objective-C-heavy per-image operations if profiling shows temporary objects accumulating within long loops.

### 14.3 Different sizes for different purposes

Do not use one image size everywhere.

Maintain conceptual specifications such as:

- grid thumbnail;
- review thumbnail;
- analysis image;
- optional higher-resolution verification image for a narrow subset.

The analysis stage should use the smallest representation that preserves the signal required by the algorithm.

### 14.4 iCloud-backed assets

An asset may not be immediately available locally.

The image-loading layer must surface states/errors that allow the coordinator to distinguish:

- local success;
- network/iCloud fetch in progress where permitted;
- temporarily unavailable asset;
- permanently unavailable/deleted asset;
- cancellation.

The UI should not need to understand PhotoKit-specific error details.

---

## 15. Cache Architecture

### 15.1 What to cache

Cache expensive derived values that are safe to recompute:

- image feature prints or normalized descriptor data;
- face observations transformed into app-defined values;
- technical quality metrics;
- computed analysis vectors;
- optionally generated thumbnails if PhotoKit caching is insufficient for a specific UI flow.

### 15.2 Cache key

A cache key should include enough information to invalidate stale analysis.

Conceptually:

```text
assetLocalIdentifier
+ assetModificationSignal
+ analysisSchemaVersion
+ algorithm/revision configuration
```

Do not key only by local identifier if edited assets can change analysis results.

### 15.3 Cache implementation

For MVP, prefer a simple actor-backed disk cache:

```text
Library/Caches/Analysis/
├── index.json                 # optional compact metadata index
└── <hashed-key>.analysis      # JSON or compact binary representation
```

The exact representation depends on the data model.

Requirements:

- safe to delete at any time;
- versioned;
- bounded by a configurable disk budget;
- does not contain original photo bytes;
- corruption affects only cache reuse, not the user's photo library.

### 15.4 No database by default

Do not introduce Core Data/SwiftData solely for analysis caching in the MVP.

Reconsider a database when the product needs durable cross-session history such as:

- long-term learned preferences;
- many saved curation sessions;
- searchable decision history;
- sophisticated cache eviction/querying;
- synchronization of app-owned metadata.

---

## 16. Checkpoint and Resume Architecture

Large jobs can be interrupted. Resume support should be designed without pretending that iOS guarantees unlimited background execution.

### 16.1 Checkpoint content

A small checkpoint may contain:

- session ID;
- source definition;
- target album size/configuration;
- list/hash of source asset identifiers;
- completed analysis asset IDs;
- analysis schema version;
- current pipeline stage;
- timestamps;
- engine version;
- enough metadata to determine whether resume is still valid.

Do not duplicate all image data in the checkpoint.

### 16.2 Checkpoint frequency

Checkpoint periodically at safe stage boundaries rather than after every tiny operation.

Examples:

- after source fetch;
- after every analysis batch;
- after analysis completes;
- after shortlist creation;
- after final selection.

Frequency details are owned by `08_Performance_Spec.md`.

### 16.3 Resume validation

Before resuming:

1. confirm the session/checkpoint schema is supported;
2. confirm the source is still accessible;
3. verify that materially changed/deleted assets are handled;
4. reuse valid cached analyses;
5. re-run only invalid/missing work;
6. restart a stage completely when partial state would create difficult correctness risks.

Correctness is more important than resuming at the exact instruction where the app stopped.

---

## 17. App Lifecycle and Backgrounding

The MVP is **foreground-first**.

Do not make successful curation dependent on `BGProcessingTask` or on the app receiving arbitrary background CPU time.

When the app moves to the background:

- persist a safe checkpoint if useful;
- reduce or cancel expensive new work according to performance policy;
- release unnecessary decoded image memory;
- allow currently safe operations to settle when the system permits;
- restore from cache/checkpoint when the app becomes active again.

If later product data shows strong demand for unattended processing, background task support can be evaluated as an optimization, not as the fundamental execution model.

---

## 18. PhotoKit Integration Boundary

`07_Apple_Framework_Integration.md` owns API-level details. Architecturally:

- PhotoKit types should remain inside Photos service implementations as much as practical;
- domain code should use `PhotoAssetID` and `PhotoAssetRecord`, not `PHAsset` everywhere;
- use the access-level-aware Photos authorization API rather than deprecated authorization entry points;
- image requests must be cancellable or safely ignorable after task cancellation;
- Photo Library changes must be observed only if they affect a live flow or resume correctness;
- export mutations must be isolated in the export service.

This boundary prevents Apple-framework callbacks and object lifecycles from leaking throughout the codebase.

---

## 19. Vision Integration Boundary

Vision belongs behind `ImageAnalysisService`.

The rest of the app should not depend on specific Vision request classes.

Benefits:

- Vision request revisions can change without changing the selection engine API;
- different analysis stages can be selectively enabled;
- expensive requests can be tuned independently;
- the domain model can preserve stable normalized fields even if underlying Apple APIs evolve.

If image feature prints are used for visual similarity, convert the result into an app-controlled representation or wrap it tightly enough that cache/version behavior remains explicit.

Never assume that the default algorithm revision remains identical forever. Include an analysis/engine version in cache invalidation rules.

---

## 20. Error Architecture

### 20.1 Typed internal errors

Each infrastructure/service layer should expose errors meaningful to the coordinator.

Example:

```swift
enum PhotoLibraryError: Error, Sendable {
    case permissionDenied
    case limitedAccessInsufficient
    case assetUnavailable(PhotoAssetID)
    case imageRequestFailed(PhotoAssetID)
    case libraryChanged
}
```

### 20.2 User-facing errors

Do not show raw technical errors directly.

Map internal errors into actionable UI categories:

- Photos permission required;
- selected photos are no longer available;
- some iCloud photos could not be downloaded;
- processing was interrupted;
- not enough eligible photos;
- album creation failed;
- storage/cache issue;
- unexpected processing error.

### 20.3 Partial failure policy

A single bad asset should normally not fail a 1,000-photo job.

The coordinator should classify failures into:

- **skippable asset failure** — record and continue;
- **degraded capability** — continue with reduced signals if selection quality remains acceptable;
- **fatal session failure** — stop because result correctness cannot be trusted.

Thresholds and exact policies belong in documents 04 and 08.

---

## 21. Progress Reporting

Progress is a domain/UI contract, not a count of arbitrary internal operations.

Use stage-based progress:

```swift
struct ProcessingProgress: Sendable, Equatable {
    var stage: ProcessingStage
    var completedUnits: Int
    var totalUnits: Int
    var overallFraction: Double
}

enum ProcessingStage: Sendable, Equatable {
    case preparingLibrary
    case loadingMetadata
    case analyzingPhotos
    case groupingMoments
    case removingDuplicates
    case buildingShortlist
    case balancingAlbum
    case finalizing
}
```

Important rules:

- overall progress must not jump backward;
- UI labels use product language, not implementation jargon;
- updates should be throttled/coalesced so the main actor is not updated hundreds of times per second;
- cancellation state should be represented separately from normal progress.

---

## 22. Session State Machine

A curation session should have an explicit lifecycle.

```text
created
  ↓
preparing
  ↓
analyzing ─────────────┐
  ↓                    │
selecting               │ retry/resume
  ↓                    │
readyForReview          │
  ↓                    │
exporting               │
  ↓                    │
completed               │
                       │
any active state ──▶ interrupted/cancelled/failed
```

Persist only states needed for resume or product history.

Do not make every transient UI animation a domain session state.

---

## 23. Data Flow

### 23.1 Start curation

```text
User selects source
    ↓
SourceSelectionModel creates SelectionRequest
    ↓
AppModel navigates to Processing
    ↓
ProcessingModel starts coordinator Task
    ↓
PhotoLibraryService fetches metadata
    ↓
Coordinator resolves cached/missing analyses
    ↓
Image loader + analyzer process missing assets
    ↓
SelectionEngine creates SelectionResult
    ↓
ProcessingModel receives final result
    ↓
App navigates to Results
```

### 23.2 Review changes

```text
User deselects / restores / swaps photo
    ↓
ReviewModel records explicit feedback/override
    ↓
Local result state updates immediately
    ↓
If necessary, rerun only affected selection balancing
    ↓
Updated selection result is rendered
```

Avoid re-running all Vision analysis when the user simply changes a final decision.

### 23.3 Export

```text
Final asset IDs
    ↓
AlbumExportService
    ↓
PhotoKit performChanges
    ↓
ExportResult
    ↓
UI success / recoverable failure state
```

---

## 24. Selection Result Ownership

The final selection is app-owned metadata that references Photos assets; it should not duplicate the original media.

The active session can retain:

- ordered selected asset IDs;
- rejected/alternative asset IDs where needed;
- scores;
- reason codes;
- user overrides;
- summary statistics.

When an asset is removed from the user's library, the app must tolerate a missing reference and update the result appropriately.

---

## 25. Configuration Architecture

Centralize algorithm and performance knobs instead of scattering constants through views/services.

Example:

```swift
struct AppConfiguration: Sendable {
    var analysis: AnalysisConfiguration
    var selection: SelectionConfiguration
    var performance: PerformanceConfiguration
    var cache: CacheConfiguration
}
```

Configuration examples:

- analysis image target dimension;
- maximum concurrent analysis jobs;
- near-duplicate threshold;
- moment time-gap threshold;
- shortlist multiplier;
- desired album size;
- minimum/maximum representatives per moment;
- diversity weighting;
- cache schema version.

Rules and defaults are defined by documents 03, 04, and 08.

Do not create a remote-config system for MVP.

---

## 26. Algorithm Versioning

Every selection result should be attributable to an engine version.

Example:

```swift
struct SelectionEngineVersion: RawRepresentable, Codable, Sendable {
    let rawValue: String
}
```

Track at least:

- analysis schema version;
- selection-engine version;
- relevant configuration version.

This enables:

- invalidating incompatible caches;
- comparing manual evaluation results over time;
- debugging why two app builds produce different albums;
- future analytics segmentation.

---

## 27. Logging

Use Apple's `Logger` with subsystem/category separation.

Suggested categories:

- `app`
- `photos`
- `analysis`
- `selection`
- `cache`
- `export`
- `performance`

Log examples:

- session started / finished / cancelled;
- asset counts by stage;
- cache hit/miss counts;
- stage duration;
- skipped/unavailable asset count;
- memory-pressure events;
- export success/failure.

Do not log:

- full image data;
- face images;
- private filenames/captions unless explicitly necessary and privacy-reviewed;
- raw sensitive metadata that is not required for debugging.

Use privacy-aware interpolation when logging identifiers.

---

## 28. Analytics Boundary

Analytics must be separate from logging.

Logging answers: **What happened on this device during debugging?**

Analytics answers: **How does the product perform across sessions/users within the approved privacy model?**

The app model/coordinator may emit semantic events such as:

- curation started;
- curation completed;
- curation cancelled;
- review changed selection;
- album exported;
- processing failed by category.

The selection engine should return measurable result metadata but should not call an analytics SDK directly.

Metrics and event schemas belong in `11_Analytics_and_Metrics.md`.

---

## 29. Memory Pressure Handling

The app should observe memory warnings and respond at infrastructure/coordinator level.

On memory pressure:

1. clear nonessential in-memory thumbnails;
2. stop prefetching;
3. reduce future concurrency if the performance policy supports dynamic limits;
4. allow current per-asset image buffers to release promptly;
5. checkpoint if appropriate;
6. never discard the only copy of user-generated review state.

A memory warning should not automatically destroy the active selection result.

---

## 30. SwiftUI Thumbnail Architecture

Photo grids can themselves become a memory/performance problem.

Use a reusable async thumbnail view backed by the image loader or a dedicated thumbnail loader.

Properties:

- requests only the displayed target size;
- cancels when the cell disappears or identifier changes;
- does not keep full-resolution images;
- handles degraded/placeholder state;
- supports scrolling without creating a new permanent cache per cell.

SwiftUI cells should not hold `PHAsset` instances as global app state.

---

## 31. Review Architecture

The review screen is performance-sensitive because it may show dozens or hundreds of selected and rejected candidates.

`ReviewModel` should hold:

- ordered selection IDs;
- grouped alternatives where applicable;
- explicit user overrides;
- lightweight decision metadata.

It should request thumbnails lazily.

User actions should be modeled explicitly:

```swift
enum ReviewAction: Sendable {
    case remove(PhotoAssetID)
    case restore(PhotoAssetID)
    case replace(selected: PhotoAssetID, with: PhotoAssetID)
    case markFavorite(PhotoAssetID)
    case resetAutomaticSelection
}
```

The exact actions are governed by the UX and product documents.

---

## 32. Personalization Boundary

Personalization is intentionally not deeply embedded in the MVP architecture.

The selection engine accepts an optional normalized `SelectionFeedback` / preferences input.

```text
User feedback/history
    ↓
Feedback summarizer (future)
    ↓
SelectionFeedback
    ↓
SelectionEngine
```

This prevents future personalization from requiring a rewrite of every scoring component.

However, do not build a learning subsystem before the basic automatic selection quality is strong enough under manual evaluation.

---

## 33. Privacy by Architecture

Architectural defaults:

- analysis happens on device;
- original photo bytes are not copied into long-term app storage;
- derived cache is removable;
- face-related analysis is treated as derived local processing data;
- no image upload service exists in the MVP architecture;
- analytics interfaces accept only explicitly designed event data;
- user can revoke Photos access without corrupting the app.

Detailed policies are defined in `09_Privacy_and_Permissions.md`.

---

## 34. Performance Boundaries

Architecture must support the performance requirements without defining their final numbers here.

Required capabilities:

- incremental asset processing;
- bounded concurrency;
- downsampled analysis images;
- cache reuse;
- batch checkpointing;
- progress coalescing;
- cancellation;
- skipping unavailable assets;
- releasing decoded images promptly;
- avoiding main-actor CPU work;
- scaling from ~1,000 to ~5,000 assets without an architectural rewrite.

Exact budgets and limits belong in `08_Performance_Spec.md`.

---

## 35. Suggested Core Types

The following types define the architectural vocabulary. Their full fields belong in `06_Data_Model.md`.

```swift
struct PhotoAssetID: Hashable, Codable, Sendable { ... }
struct PhotoAssetRecord: Sendable { ... }
struct PhotoAnalysis: Sendable { ... }
struct AnalysisCacheKey: Hashable, Codable, Sendable { ... }
struct Moment: Sendable { ... }
struct DuplicateCluster: Sendable { ... }
struct SelectionConfiguration: Sendable { ... }
struct SelectionRequest: Sendable { ... }
struct SelectionDecision: Sendable { ... }
struct SelectionResult: Sendable { ... }
struct SelectionFeedback: Sendable { ... }
struct ProcessingProgress: Sendable { ... }
```

Keep Apple framework types out of these models unless there is a strong reason not to.

---

## 36. Recommended Implementation Sequence

Implement the architecture in this order.

### Phase A — Application shell

Build:

- `PhotosCuratorApp`;
- `AppContainer`;
- `AppModel`;
- root navigation;
- source selection UI;
- permission flow;
- placeholder processing/results screens.

Goal: complete UX skeleton with no real AI analysis.

### Phase B — Photo access

Build:

- `PhotoLibraryService`;
- `PhotoKitLibraryService`;
- `PhotoImageLoader`;
- real asset enumeration;
- thumbnail rendering.

Goal: user can choose a source and the app can enumerate/display assets reliably.

### Phase C — Analysis pipeline

Build:

- `ImageAnalysisService`;
- bounded analysis workers;
- compact `PhotoAnalysis` values;
- progress reporting;
- cache.

Goal: process a realistic 1,000-photo dataset without retaining originals.

### Phase D — Selection engine

Implement in the order defined by `04_Selection_Engine_Design.md`:

- eligibility;
- duplicates;
- moments;
- quality scoring;
- shortlist;
- diversity;
- final album.

Goal: deterministic selection result with reason codes.

### Phase E — Review and export

Build:

- result grid;
- review actions;
- alternative handling;
- final album export.

Goal: complete end-to-end MVP.

### Phase F — Robustness

Add/tune:

- interruption checkpoints;
- iCloud/unavailable handling;
- memory-pressure behavior;
- cache eviction/versioning;
- logs and product analytics;
- manual quality evaluation workflow.

Do not begin Phase F by adding generic infrastructure; fix observed failure modes first.

---

## 37. Anti-Patterns to Avoid

### 37.1 Massive `ProcessingViewModel`

Do not place Photos fetching, Vision requests, cache code, selection rules, export, and UI state in one observable class.

Split infrastructure/services from orchestration.

### 37.2 `PHAsset` everywhere

Do not make PhotoKit objects the domain model. Convert them to stable internal records/identifiers near the service boundary.

### 37.3 Unbounded task creation

Do not use:

```swift
for asset in assets {
    Task {
        await analyze(asset)
    }
}
```

for thousands of images.

### 37.4 Full-resolution-by-default

Do not request originals unless a specific algorithm proves that lower-resolution input is insufficient.

### 37.5 Main-thread analysis

No Vision loop or image metric loop should be performed synchronously from a SwiftUI action on the main actor.

### 37.6 Premature package modularization

Do not create separate packages named `DomainKit`, `PhotoKitAdapter`, `AnalysisKit`, `SelectionKit`, etc. during MVP unless compile times or team ownership become a real problem.

### 37.7 Generic repository pattern

Do not wrap every source of data in generic CRUD repositories. Photos Curator has specific services with specific operations; model them directly.

### 37.8 Database-first design

Do not build schema migrations, object graphs, and persistent stores before durable history exists as a requirement.

### 37.9 Background execution dependency

Do not promise that a 5,000-photo curation will continue indefinitely after the user leaves the app. Build resumability instead.

### 37.10 Hidden algorithm state

Do not mutate global weights or singleton scoring state during a session. Selection inputs and engine versions must be explicit enough to reproduce results.

---

## 38. What Is Intentionally Deferred

The following are not required for the MVP architecture:

- cloud AI inference;
- backend account system;
- cross-device sync of curation sessions;
- collaborative albums;
- remote configuration;
- feature-flag platform;
- plugin architecture;
- ML training pipeline;
- server-side embedding database;
- durable event sourcing;
- multiple app targets;
- custom operation queues unless profiling proves Swift concurrency insufficient;
- complex background scheduler;
- third-party image pipeline;
- third-party state-management framework;
- automated test targets/files in the repository.

Any deferred item should be added only after a corresponding product requirement appears.

---

## 39. Architecture Acceptance Criteria

The implementation conforms to this architecture when all of the following are true:

### Structure

- the repository has one main iOS app target;
- features, domain code, and services are clearly separated by folders/responsibility;
- the selection engine does not import SwiftUI;
- PhotoKit-specific implementation is concentrated in Photos services;
- Vision-specific implementation is concentrated in analysis services.

### State

- SwiftUI-visible mutable state is main-actor isolated;
- processing uses explicit state/progress types;
- there is only one authoritative active curation session in the app flow;
- user review overrides are not hidden inside view-local transient state.

### Concurrency

- expensive analysis uses structured concurrency;
- concurrency is bounded;
- cancellation propagates from UI to processing work;
- no full-library set of decoded images is retained;
- shared mutable cache/session infrastructure is actor-isolated or otherwise safely serialized.

### Selection engine

- engine input/output uses app-defined domain models;
- selection is deterministic for equivalent inputs/version/configuration;
- decisions retain structured reason information;
- selection rules can evolve without changing PhotoKit/UI layers.

### Reliability

- one unavailable photo does not normally fail the entire job;
- interrupted processing can reuse valid completed work;
- cache corruption can be recovered by recomputation;
- user Photos assets are never deleted or modified by curation unless an explicit future product feature requires it.

### Scope control

- no generic architecture framework has been added without demonstrated need;
- no test target or test files are required in the MVP repository;
- manual QA/evaluation remains the product's validation mechanism during this development phase.

---

## 40. Architecture Decision Summary

The MVP architecture can be summarized in one sentence:

> **A single-target SwiftUI app owns lightweight main-actor UI state, delegates Photos/Vision/file operations to small service boundaries, runs a deterministic pure-Swift selection engine through a cancellable actor-based session coordinator, and processes images incrementally with bounded structured concurrency.**

This design is deliberately small enough to build quickly but establishes the boundaries most likely to matter as Photos Curator evolves: **UI vs. processing, Apple-framework integration vs. domain models, mutable orchestration vs. deterministic selection logic, and original media vs. compact derived analysis.**

---

## 41. References to Apple Platform Concepts

Implementation should be aligned with the current Apple Developer Documentation for:

- SwiftUI;
- Observation and `@Observable`;
- Swift structured concurrency, `Task`, actors, and task groups;
- PhotoKit `PHPhotoLibrary`, access-level authorization, `PHAsset`, and image requests;
- Vision image-analysis requests and feature-print observations;
- OSLog / `Logger`.

`07_Apple_Framework_Integration.md` should contain the concrete API usage decisions and availability notes so that this architecture document remains focused on system structure rather than API reference material.
