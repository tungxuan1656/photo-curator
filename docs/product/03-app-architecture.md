# Photos Curator — App Architecture

**Document:** `docs/product/[03-app-architecture.md](http://03-app-architecture.md)`  
**Project:** `photos-curator`  
**Status:** MVP Architecture  
**Platform:** iPhone / iOS  
**Primary UI Framework:** SwiftUI  
**Primary Photo Framework:** PhotoKit

---

## 1. Purpose

This document defines the application architecture for **Photos Curator**.

The architecture is intentionally optimized for:

- fast MVP development;
- clear separation between UI, photo access, and photo-selection logic;
- processing large photo sets without blocking the UI;
- minimizing unnecessary abstractions;
- keeping the codebase understandable for both human developers and AI coding agents;
- making the selection engine independently understandable without turning the project into an over-engineered framework.

This document should be used together with:

- `docs/product/[01-product-spec.md](http://01-product-spec.md)` — product behavior and product requirements;
- `docs/product/[02-selection-engine.md](http://02-selection-engine.md)` — photo analysis, grouping, scoring, ranking, and selection logic.

The architecture described here is the default implementation direction unless a later technical decision explicitly supersedes it.

---

# 2. Architecture Goals

The application should satisfy five architectural goals.

### 2.1 Keep the MVP simple

Photos Curator is a single-purpose iOS application.

It does not require:

- a backend;
- user accounts;
- remote databases;
- cloud synchronization;
- dependency injection frameworks;
- a complex navigation framework;
- a repository layer for every data source;
- separate packages for every feature;
- Clean Architecture ceremony;
- unit test targets;
- UI test targets.

Additional architectural layers should only be introduced when a concrete implementation problem requires them.

---

### 2.2 Keep photo processing outside the UI layer

SwiftUI views must not directly perform:

- PhotoKit enumeration;
- image decoding;
- feature extraction;
- similarity computation;
- clustering;
- quality scoring;
- final ranking.

Views should display application state and communicate user intent.

Heavy processing belongs in dedicated services and the selection engine.

---

### 2.3 Keep the selection engine conceptually independent

The selection engine is the core product logic.

It should receive normalized photo inputs and return selection results without depending on SwiftUI.

Conceptually:

```text
PhotoKit assets
      ↓
Photo loading / metadata extraction
      ↓
PhotoCandidate
      ↓
Selection Engine
      ↓
SelectionResult
      ↓
UI

```

This makes the algorithm easier to modify without rewriting the interface.

---

### 2.4 Never block the main actor with photo analysis

Operations involving hundreds or thousands of photos may be expensive.

The following must run asynchronously:

- PhotoKit requests;
- thumbnail generation;
- feature extraction;
- similarity comparison;
- clustering;
- quality analysis;
- ranking.

The main actor should primarily be responsible for observable UI state.

---

### 2.5 Process incrementally when possible

The application should avoid loading 1,000 full-resolution images into memory simultaneously.

The architecture should prefer:

```text
asset
→ request appropriately sized image
→ analyze
→ retain compact analysis result
→ release image

```

The long-lived representation of a photo during processing should contain metadata and analysis features rather than a full-resolution image.

---

# 3. High-Level Architecture

Photos Curator uses a lightweight feature-oriented architecture.

```text
┌──────────────────────────────────────────────┐
│                   SwiftUI                    │
│                                              │
│  Library → Review → Result → Export          │
└───────────────────────┬──────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────┐
│                App State Layer               │
│                                              │
│              CurationSession                 │
└───────────────────────┬──────────────────────┘
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
┌─────────────────────┐   ┌─────────────────────┐
│    Photo Library    │   │  Selection Engine   │
│                     │   │                     │
│ PhotoKit integration│   │ analysis            │
│ thumbnails          │   │ similarity          │
│ metadata            │   │ grouping            │
│ export              │   │ scoring             │
└─────────────────────┘   │ ranking             │
                          │ diversity            │
                          └─────────────────────┘

```

There are three main architectural areas:

**UI Layer**

SwiftUI screens and reusable visual components.

**Application Layer**

Owns the current curation session and coordinates operations between the UI, PhotoKit, and selection engine.

**Domain / Engine Layer**

Contains the models and algorithms required to determine which photos should be kept.

---

# 4. Suggested Repository Structure

The MVP should use one application target.

```text
photos-curator/
│
├── PhotosCurator/
│   │
│   ├── App/
│   │   ├── PhotosCuratorApp.swift
│   │   └── AppRootView.swift
│   │
│   ├── Features/
│   │   ├── Library/
│   │   ├── Curation/
│   │   ├── Results/
│   │   └── Settings/
│   │
│   ├── Components/
│   │
│   ├── Models/
│   │
│   ├── PhotoLibrary/
│   │
│   ├── SelectionEngine/
│   │
│   ├── Utilities/
│   │
│   └── Resources/
│
├── docs/
│   ├── 01-product-spec.md
│   ├── 02-selection-engine.md
│   └── 03-app-architecture.md
│
└── README.md

```

No test folders or test targets are required for the MVP.

Avoid structures such as:

```text
Domain/
Data/
Infrastructure/
Repositories/
UseCases/
Interactors/
Coordinators/
Factories/
DependencyInjection/

```

unless the project later develops a genuine need for them.

---

# 5. Application Entry Point

The application should have one simple entry point.

```swift
@main
struct PhotosCuratorApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

```

`AppRootView` determines which primary application state should be displayed.

For example:

```text
permissionRequired
      ↓
library
      ↓
curating
      ↓
results

```

Navigation should remain understandable from the code.

A custom routing framework is unnecessary for the MVP.

---

# 6. Primary Application Flow

The main user journey is:

```text
Launch
   ↓
Check Photos permission
   ↓
Show photo library / album selection
   ↓
User chooses photos or album
   ↓
Create CurationSession
   ↓
Analyze photos
   ↓
Group similar photos
   ↓
Score photos
   ↓
Select best photos
   ↓
Display curated result
   ↓
User reviews result
   ↓
Save / export curated selection

```

The architecture should optimize this path above all secondary functionality.

---

# 7. CurationSession

`CurationSession` is the central application-level state for a single curation run.

It represents the work currently being performed by the user.

A session may contain:

```swift
@MainActor
@Observable
final class CurationSession {

    var sourceAssets: [PhotoAsset] = []

    var status: CurationStatus = .idle

    var progress: CurationProgress = .zero

    var result: SelectionResult?

    var error: CurationError?
}

```

The exact syntax may vary based on deployment requirements, but the architectural responsibility should remain the same.

`CurationSession` should coordinate the workflow.

It should not implement the selection algorithms itself.

---

# 8. Curation Status

Processing should be represented explicitly.

Recommended states:

```swift
enum CurationStatus {
    case idle
    case preparing
    case analyzing
    case grouping
    case ranking
    case completed
    case failed
    case cancelled
}

```

This makes UI behavior deterministic.

For example:

```text
.analyzing
→ show progress UI

.completed
→ show results

.failed
→ show recoverable error state

```

Avoid implementing processing state through several unrelated Boolean values such as:

```swift
isLoading
isProcessing
isFinished
hasError

```

because invalid combinations become possible.

---

# 9. Curation Progress

The UI should receive meaningful progress information from the processing pipeline.

Example:

```swift
struct CurationProgress {
    var completedItems: Int
    var totalItems: Int
    var phase: CurationPhase
}

```

The UI can convert this into a percentage when useful.

Possible phases include:

```text
Preparing photos
Analyzing photos
Finding similar photos
Choosing the best photos
Finishing

```

Internal algorithm terminology does not need to be exposed directly to the user.

For example, the application should prefer:

> Finding similar photos

instead of:

> Computing pairwise perceptual similarity clusters

---

# 10. Photo Library Layer

All PhotoKit interaction should live behind a small dedicated service.

Suggested responsibility:

```swift
actor PhotoLibraryService

```

It should handle operations such as:

```text
authorization
asset fetching
album fetching
thumbnail requests
analysis-sized image requests
full-resolution requests when necessary
export / album creation

```

Views should not contain substantial `PHAsset` fetching logic.

---

# 11. Photo Authorization

Authorization should be checked during application startup or immediately before photo access is required.

The UI should distinguish between:

```text
not determined
authorized
limited
denied / restricted

```

Limited Photos access must be treated as a valid usable state.

The application should operate on whichever assets the user has granted access to.

Permission logic should remain within the Photo Library boundary rather than being duplicated across multiple views.

---

# 12. PhotoAsset

`PHAsset` should not become the universal domain object used throughout the application.

Instead, introduce a lightweight application representation.

Example:

```swift
struct PhotoAsset: Identifiable, Hashable {
    let id: String

    let pixelWidth: Int
    let pixelHeight: Int

    let creationDate: Date?

    let isFavorite: Bool

    let source: PHAsset
}

```

For the MVP, retaining a reference to `PHAsset` inside this wrapper is acceptable.

There is no need to build a fully independent persistence abstraction.

The purpose of `PhotoAsset` is primarily to:

- provide stable application terminology;
- centralize metadata;
- prevent PhotoKit-specific details from spreading unnecessarily;
- make engine inputs easier to construct.

---

# 13. PhotoCandidate

The selection engine should operate on a more analysis-oriented model.

Example:

```swift
struct PhotoCandidate: Identifiable {
    let id: String

    let metadata: PhotoMetadata

    let features: PhotoFeatures

    let quality: PhotoQualityMetrics
}

```

A `PhotoCandidate` represents a photo after the relevant analysis has been performed.

It should not normally retain the decoded full-resolution image.

---

# 14. PhotoMetadata

Example:

```swift
struct PhotoMetadata {
    let creationDate: Date?

    let pixelWidth: Int
    let pixelHeight: Int

    let isFavorite: Bool
}

```

Additional metadata should only be added when the selection algorithm actually uses it.

Do not collect metadata simply because PhotoKit exposes it.

---

# 15. PhotoFeatures

`PhotoFeatures` contains the compact information required for similarity analysis.

Its exact contents are defined by the selection-engine implementation.

Conceptually it may contain:

```swift
struct PhotoFeatures {
    let visualEmbedding: VisualEmbedding?
    let perceptualSignature: PerceptualSignature?
}

```

The specific representation may evolve.

The rest of the application should not depend on the mathematical implementation.

---

# 16. Photo Quality Metrics

Image-quality analysis should produce explicit values rather than immediately deciding whether a photo survives.

Example:

```swift
struct PhotoQualityMetrics {
    let sharpness: Double
    let exposure: Double
    let faceQuality: Double?
}

```

The selection engine can then combine these signals according to the scoring strategy defined in [`02-selection-engine.md`](http://02-selection-engine.md).

This separation makes weighting decisions easier to change.

---

# 17. Selection Engine API

The rest of the application should interact with the engine through one clear entry point.

Conceptually:

```swift
actor SelectionEngine {

    func curate(
        photos: [PhotoCandidate],
        configuration: SelectionConfiguration
    ) async throws -> SelectionResult
}

```

The caller should not need to manually invoke:

```text
similarity engine
cluster builder
quality scorer
diversity optimizer
ranker

```

in the correct order.

Those are implementation details of `SelectionEngine`.

---

# 18. SelectionConfiguration

Behavior that may vary between curation sessions belongs in a configuration object.

Example:

```swift
struct SelectionConfiguration {

    var targetCount: Int?

    var retentionRatio: Double

    var preserveFavorites: Bool
}

```

For example:

```text
1,000 input photos
retentionRatio = 0.15

≈ 150 selected photos

```

Configuration should remain small for the MVP.

Do not expose every internal scoring weight as an application setting.

Algorithm parameters may remain internal constants until experimentation proves they need configuration.

---

# 19. SelectionResult

The engine should return a structured result.

Example:

```swift
struct SelectionResult {

    let selected: [SelectedPhoto]

    let rejected: [RejectedPhoto]

    let groups: [PhotoGroup]

    let statistics: SelectionStatistics
}

```

The UI mainly requires `selected`.

The additional information is useful for:

- debugging;
- result explanations;
- manual algorithm validation;
- future UX features.

---

# 20. SelectedPhoto

Example:

```swift
struct SelectedPhoto: Identifiable {

    let id: String

    let assetID: String

    let score: Double

    let groupID: String?
}

```

Internal scoring information does not necessarily need to be visible in the production UI.

It is primarily useful for development and manual validation.

---

# 21. RejectedPhoto

Rejected photos can optionally record why they were not selected.

Example:

```swift
enum RejectionReason {
    case duplicate
    case lowerQualityAlternative
    case diversityReduction
    case targetLimit
}

```

This information can be extremely useful while manually evaluating selection quality.

It should not require a complex explanation system for the MVP.

---

# 22. Selection Engine Internal Structure

The engine can internally contain small focused components.

Recommended conceptual organization:

```text
SelectionEngine
│
├── FeatureExtractor
├── SimilarityAnalyzer
├── PhotoGrouper
├── QualityAnalyzer
├── PhotoScorer
└── SelectionRanker

```

These components should exist only when they make the implementation clearer.

They do not need protocols unless multiple interchangeable implementations actually exist.

For example, prefer:

```swift
struct PhotoScorer

```

over prematurely creating:

```swift
protocol PhotoScoring {}
final class DefaultPhotoScorer: PhotoScoring {}
final class PhotoScoringFactory {}

```

The MVP should favor concrete types.

---

# 23. Processing Pipeline

A typical curation request should follow this sequence:

```text
PHAsset
   ↓
request analysis-size image
   ↓
extract visual features
   ↓
measure quality
   ↓
create PhotoCandidate
   ↓
release decoded image

```

After candidates have been created:

```text
PhotoCandidate[]
   ↓
similarity analysis
   ↓
grouping
   ↓
intra-group ranking
   ↓
global ranking
   ↓
diversity adjustment
   ↓
target-count enforcement
   ↓
SelectionResult

```

The detailed mathematical rules belong in [`02-selection-engine.md`](http://02-selection-engine.md).

---

# 24. Image Resolution Strategy

The engine should not automatically use original full-resolution photos for every operation.

For most machine-analysis operations, a smaller image is sufficient and dramatically reduces:

- memory pressure;
- decoding time;
- processing time.

The Photo Library layer should therefore support distinct request purposes.

Conceptually:

```swift
enum ImageRequestPurpose {
    case thumbnail
    case analysis
    case fullResolution
}

```

Typical behavior:

```text
thumbnail
→ UI grids

analysis
→ feature extraction and quality estimation

fullResolution
→ final viewing/export only when required

```

Exact pixel dimensions should be tuned experimentally rather than becoming architectural constants.

---

# 25. Memory Management

Memory usage is one of the most important technical constraints of Photos Curator.

A photo library containing 1,000 images must not be represented as 1,000 decoded full-resolution `UIImage` objects.

The application should retain compact information such as:

```text
asset identifier
metadata
feature vector
quality metrics
cluster ID
selection score

```

Decoded images should generally be temporary.

Preferred lifecycle:

```text
request image
↓
analyze image
↓
store compact result
↓
release image

```

Autorelease behavior and image caches may require observation during development, particularly on older supported devices.

---

# 26. Thumbnail Loading

Thumbnail loading should be independent from analysis.

The grid UI does not need to wait for the selection engine.

A dedicated thumbnail-loading mechanism should:

- request appropriately sized thumbnails;
- support asynchronous loading;
- reuse PhotoKit caching where beneficial;
- avoid requesting original images;
- handle cells appearing and disappearing quickly during scrolling.

The UI should be able to show a placeholder until a thumbnail becomes available.

---

# 27. Concurrency Model

Swift concurrency should be the default concurrency mechanism.

Prefer:

```text
async/await
Task
TaskGroup
actor
MainActor

```

over introducing additional reactive or concurrency frameworks solely for processing.

The broad ownership model should be:

```text
UI state
→ @MainActor

Photo library operations
→ actor / asynchronous APIs

Selection engine
→ actor / asynchronous computation

```

Not every type needs to be an actor.

Actors should protect meaningful mutable state or coordinate concurrent work.

Pure scoring functions can remain regular structs/functions.

---

# 28. Bounded Parallelism

Processing photos concurrently is useful, but processing every photo simultaneously is not.

For example, starting 1,000 full image-decoding operations at once could create severe memory pressure.

The analysis pipeline should therefore use bounded concurrency.

Conceptually:

```text
1,000 assets

process N concurrently
↓
complete batch/work items
↓
continue

```

The exact concurrency limit should be determined empirically.

Architecture should make such throttling possible without exposing it to the UI.

---

# 29. Cancellation

A long-running curation operation must be cancellable.

Cancellation may occur when:

- the user taps Cancel;
- the user leaves the curation flow;
- a new curation session replaces the old one.

Long-running processing loops should periodically respect Swift task cancellation.

Conceptually:

```swift
try Task.checkCancellation()

```

Cancellation should propagate from the application layer down into the processing pipeline.

A cancelled session should not later overwrite the UI with stale results.

---

# 30. Progress Reporting

The engine should report progress upward without depending on SwiftUI.

One possible interface is an asynchronous progress callback.

Conceptually:

```swift
func curate(
    photos: [PhotoCandidate],
    configuration: SelectionConfiguration,
    progress: @Sendable (EngineProgress) async -> Void
) async throws -> SelectionResult

```

The exact implementation is flexible.

The important architectural rule is:

```text
engine emits progress
→ session converts it to UI state
→ UI observes session

```

The engine should never manipulate progress views directly.

---

# 31. Feature Structure

Each major screen should be grouped by product feature rather than file type whenever practical.

Example:

```text
Features/
│
├── Library/
│   ├── LibraryView.swift
│   └── AlbumPickerView.swift
│
├── Curation/
│   ├── CurationView.swift
│   └── CurationProgressView.swift
│
├── Results/
│   ├── ResultsView.swift
│   ├── ResultsGrid.swift
│   └── PhotoReviewView.swift
│
└── Settings/
    └── SettingsView.swift

```

Small features do not need dedicated ViewModel types automatically.

Introduce a feature model only when the screen contains enough state or orchestration to justify it.

---

# 32. SwiftUI State Ownership

State should live as close as possible to where it is needed.

Local visual state can remain inside views.

Examples:

```text
selected tab
sheet presentation
temporary zoom state
local selection

```

Long-lived workflow state belongs in the curation session.

Examples:

```text
selected source assets
processing status
processing progress
selection result
processing errors

```

Avoid creating one giant `AppViewModel` containing every property in the application.

---

# 33. Navigation

The MVP can use standard SwiftUI navigation.

Possible flow:

```text
LibraryView
    ↓
CurationView
    ↓
ResultsView
    ↓
PhotoReviewView

```

Navigation state does not require a custom Coordinator architecture unless the app later becomes substantially more complex.

Sheets can be used for secondary flows such as:

```text
settings
photo details
export confirmation

```

---

# 34. Results UI Architecture

The results screen should consume `SelectionResult`.

It should not recompute algorithm decisions.

For example:

```text
SelectionResult.selected
        ↓
ResultsGrid
        ↓
thumbnail requests

```

When the user manually removes a selected photo, that action should modify the session's user-reviewed result rather than rerunning the entire selection engine unless specifically requested.

---

# 35. Automatic Selection vs User Review

The application should distinguish between:

```text
engine selection

```

and:

```text
user-approved selection

```

A useful representation is:

```swift
struct CuratedPhoto {
    let assetID: String

    var isIncluded: Bool
}

```

Initial value:

```text
isIncluded = engine selected the photo

```

The user can then override the automatic decision during review.

This prevents manual choices from being mixed with the algorithm's original result.

---

# 36. Export Architecture

Export should be handled by the Photo Library layer.

The Results UI should express an intent such as:

```text
Save curated album

```

The application layer determines the selected asset IDs and calls the Photo Library service.

Conceptually:

```text
ResultsView
    ↓
CurationSession
    ↓
PhotoLibraryService
    ↓
create/update Photos album

```

Do not put `PHPhotoLibrary.performChanges` directly inside the button action of a SwiftUI view.

---

# 37. Persistence

The MVP should avoid introducing a database unless product requirements require persistent session history.

Most source information already exists in the user's Photos library.

For the first version, lightweight preferences can use platform-standard local storage.

Examples include:

```text
default retention ratio
whether favorites should always be preserved
last-used presentation settings

```

Do not introduce Core Data, SwiftData, SQLite, Realm, or another persistence layer merely to save a few settings.

If persistent curation history becomes a product requirement later, persistence architecture can be added at that point.

---

# 38. Caching

Caching should solve observed performance problems rather than becoming a subsystem of its own.

Useful candidates include:

```text
PhotoKit image caching
temporary thumbnails
computed visual features during an active session

```

The MVP does not require a persistent disk cache for machine-analysis results.

Reprocessing photos is acceptable initially unless profiling shows that it creates unacceptable UX.

---

# 39. Error Model

User-visible failures should be represented by a small application-specific error model.

Example:

```swift
enum CurationError: Error {
    case photoAccessDenied
    case assetUnavailable
    case imageLoadingFailed
    case processingFailed
    case exportFailed
}

```

Low-level errors should be logged or preserved internally when useful.

The UI should display understandable recovery options.

For example:

```text
Photo access unavailable
→ Open Settings

Processing failed
→ Try Again

Some photos unavailable
→ Continue with available photos

```

Do not expose implementation errors directly to the user.

---

# 40. Partial Failures

A single unavailable photo should normally not abort a 1,000-photo curation session.

The pipeline should distinguish between:

```text
recoverable item failure

```

and:

```text
fatal session failure

```

Example:

```text
3 assets cannot be loaded
997 assets successfully analyzed

```

The preferred behavior is generally to continue with the 997 available assets.

The result may record how many photos were skipped.

---

# 41. Logging

Development builds should provide enough structured logging to understand selection behavior.

Useful events include:

```text
curation started
asset count
analysis duration
number of failed assets
similarity group count
selected count
processing duration
curation cancelled
export result

```

Selection-engine diagnostics may additionally include:

```text
group sizes
quality score ranges
rejection reasons
ranking outputs

```

Avoid logging actual image contents or sensitive user information.

Logging should support manual algorithm validation.

---

# 42. Manual Validation Support

The repository intentionally does not require automated test targets for the MVP.

Instead, the architecture should make manual validation practical.

During development, it should be possible to inspect information such as:

```text
photo identifier
similarity group
quality metrics
ranking score
selected/rejected state
rejection reason

```

These diagnostics may be surfaced through:

- debug logging;
- temporary developer UI;
- debug-only overlays;
- exported diagnostic data when useful.

Such tools should remain lightweight.

The goal is to make algorithm mistakes visible without building a large testing infrastructure.

---

# 43. Dependency Policy

The project should prefer Apple frameworks and standard Swift functionality.

Third-party dependencies should only be introduced when they provide substantial value that would otherwise require significant implementation effort.

Every new dependency adds:

```text
maintenance cost
build complexity
API risk
future migration work

```

For the MVP, a small dependency count is preferable.

Do not add libraries simply to wrap APIs that are already straightforward in the platform SDK.

---

# 44. Protocol Policy

Do not create protocols for every service.

Protocols are appropriate when:

- multiple implementations genuinely exist;
- an API boundary benefits from abstraction;
- implementation replacement is expected.

Otherwise, prefer concrete types.

For example:

```swift
actor PhotoLibraryService

```

is preferable to:

```swift
protocol PhotoLibraryServiceProtocol {}

final class PhotoLibraryServiceImpl:
    PhotoLibraryServiceProtocol {}

```

when there is only one implementation.

---

# 45. Dependency Injection

The application does not require a dependency injection framework.

Simple initializer injection is sufficient when dependencies need to be explicit.

Example:

```swift
final class CurationSession {

    private let photoLibrary: PhotoLibraryService
    private let selectionEngine: SelectionEngine

    init(
        photoLibrary: PhotoLibraryService,
        selectionEngine: SelectionEngine
    ) {
        self.photoLibrary = photoLibrary
        self.selectionEngine = selectionEngine
    }
}

```

For very small objects, direct construction at the application composition root is acceptable.

---

# 46. Service Lifetime

A small number of long-lived services is sufficient.

Conceptually:

```text
PhotosCuratorApp
│
├── PhotoLibraryService
├── SelectionEngine
└── CurationSession

```

These can be created near the application root and passed where necessary.

Do not create a service locator or dependency container for the MVP.

---

# 47. Selection Engine Isolation

The following types should ideally remain independent from SwiftUI:

```text
SelectionEngine
PhotoCandidate
PhotoFeatures
PhotoQualityMetrics
PhotoGroup
SelectionResult
SelectedPhoto
RejectedPhoto

```

They may import lower-level Apple frameworks when genuinely necessary, but UI concerns should remain absent.

This boundary is particularly important because the selection engine will likely change more frequently than the surrounding app architecture.

---

# 48. Performance Measurement

Optimization decisions should be based on measurement.

Important metrics include:

```text
time to load asset list
time to analyze 100 photos
time to analyze 1,000 photos
peak memory usage
time spent extracting features
time spent computing similarity
time spent ranking
thumbnail scrolling performance

```

The architecture should remain simple until actual measurements identify bottlenecks.

Avoid speculative optimization.

---

# 49. Expected Scale

The MVP should be designed around typical curation sessions containing approximately:

```text
100–1,000 photos

```

Larger libraries may work, but optimizing extremely large selections should not complicate the initial architecture unnecessarily.

The primary target scenario is:

```text
large trip/event album
        ↓
Photos Curator
        ↓
much smaller high-quality collection

```

For example:

```text
1,000 photos
↓
100–200 curated photos

```

---

# 50. Privacy Architecture

The product should process photos locally whenever the selected algorithms allow it.

The MVP architecture does not require uploading the user's photo library to a server.

Benefits include:

```text
better privacy
no media-upload infrastructure
no cloud processing cost
offline capability
simpler architecture

```

Any future feature that transmits photos externally must be treated as a deliberate architectural and product decision rather than an invisible implementation detail.

---

# 51. Background Processing

The first MVP does not need a complex background-processing architecture.

The default assumption is:

```text
user starts curation
→ application processes the selected photos
→ progress is visible
→ result is returned during the active session

```

Supporting long-running background execution can be revisited if real device testing demonstrates that it is necessary.

Do not design a job scheduler before that requirement exists.

---

# 52. Thermal and Battery Considerations

Photo analysis can be computationally expensive.

The implementation should avoid unnecessary repeated work and uncontrolled concurrency.

Potential improvements can be introduced after profiling, including:

```text
reduced analysis resolution
bounded parallelism
batch processing
reusing extracted features during the session

```

The architecture should permit these optimizations without requiring them from day one.

---

# 53. No Backend for MVP

The MVP architecture is intentionally local-first.

There is no required:

```text
API server
authentication service
cloud database
analytics backend
media storage backend
queue worker
remote ML inference service

```

A backend should only be introduced when a future product requirement cannot reasonably be implemented locally.

---

# 54. No Account System

Users should not need to create an account simply to curate their local Photos library.

This reduces:

```text
onboarding friction
privacy concerns
backend requirements
authentication complexity
development time

```

Account functionality is outside the MVP scope.

---

# 55. No Premature Package Modularization

The initial project should preferably remain a single Xcode application project/target.

Do not immediately extract:

```text
SelectionEngineKit
PhotoLibraryKit
UIComponentsKit
CoreKit
UtilitiesKit

```

into separate Swift packages.

Folder-level boundaries are sufficient during early development.

A module should only become a separate package when build times, reuse, ownership, or complexity create a clear reason.

---

# 56. File Size and Responsibility

Avoid both extremes:

```text
one 2,000-line god file

```

and:

```text
hundreds of tiny single-purpose files

```

Create a separate file when a concept has a meaningful standalone responsibility.

Examples that reasonably deserve their own files:

```text
SelectionEngine.swift
PhotoLibraryService.swift
PhotoCandidate.swift
SelectionResult.swift
CurationSession.swift
ResultsView.swift

```

A four-line private helper does not automatically require another file.

---

# 57. Naming Conventions

Names should reflect product concepts.

Prefer:

```text
PhotoCandidate
PhotoGroup
SelectionResult
CurationSession
PhotoLibraryService
SelectionEngine
QualityScore
SimilarityScore

```

Avoid vague names such as:

```text
Manager
Helper
Processor
Handler
Util
DataModel

```

unless the word precisely represents the responsibility.

For example, `ImageProcessingHelper` gives much less architectural information than `FeatureExtractor`.

---

# 58. Implementation Order

The recommended architecture-driven implementation sequence is:

```text
1. App shell
2. Photo permission
3. Photo/album selection
4. Thumbnail grid
5. CurationSession
6. PhotoLibraryService
7. Analysis image loading
8. SelectionEngine integration
9. Processing progress
10. Results grid
11. Manual inclusion/exclusion
12. Export curated album
13. Performance tuning
14. Algorithm tuning using real photo sets

```

This sequence creates an end-to-end vertical slice early.

Do not spend significant time perfecting isolated infrastructure before the complete flow works.

---

# 59. First End-to-End Milestone

The first important technical milestone should be:

```text
choose an album
        ↓
load assets
        ↓
run a minimal selection engine
        ↓
display selected photos

```

The algorithm can initially be imperfect.

Having the complete pipeline working makes subsequent algorithm development substantially easier because real results can immediately be inspected.

---

# 60. Architecture Evolution Rules

The architecture may evolve, but complexity should be introduced deliberately.

Before creating a new layer, abstraction, framework, module, or persistent subsystem, ask:

> What concrete problem does this solve in the current application?

Good reasons include:

```text
measured performance problem
repeated duplicated logic
genuine multiple implementations
unmanageable feature complexity
persistent product requirement
OS/API limitation

```

Weak reasons include:

```text
“this architecture is more enterprise”
“we may need it someday”
“most production apps have one”
“it makes the folder tree look cleaner”

```

Photos Curator should remain as simple as the product allows.

---

# 61. Architectural Invariants

The following rules should remain true throughout MVP development:

```text
SwiftUI does not implement selection algorithms.

Full-resolution images are not retained for the entire photo set.

The selection engine does not depend on SwiftUI.

PhotoKit access is centralized.

Long-running analysis does not block the main actor.

Curation work supports cancellation.

Processing is memory-aware.

The MVP has no required backend.

The MVP has no required account system.

The MVP has no automated test targets or test files.

Manual validation of selection quality remains easy.

Third-party dependencies remain minimal.

New abstraction requires a concrete reason.

```

These rules are more important than following a particular named architecture pattern.

---

# 62. Target Architecture Summary

The MVP should ultimately resemble:

```text
PhotosCuratorApp
│
├── AppRootView
│
├── Features
│   ├── Library
│   ├── Curation
│   └── Results
│
├── CurationSession
│
├── PhotoLibraryService
│   ├── authorization
│   ├── assets
│   ├── thumbnails
│   ├── analysis images
│   └── export
│
└── SelectionEngine
    ├── feature extraction
    ├── quality analysis
    ├── similarity analysis
    ├── grouping
    ├── scoring
    ├── ranking
    └── diversity selection

```

Data flows downward into services and the engine.

Results and progress flow upward into session state.

SwiftUI renders that state.

That is sufficient architecture for the Photos Curator MVP.

---

# 63. Final Principle

The architecture exists to support the product, not to become a project of its own.

Photos Curator has one technically difficult problem:

> Given a large set of personal photos, reliably reduce it to a much smaller set containing the photos the user is most likely to want to keep.

Engineering effort should therefore be concentrated on:

```text
photo access
efficient image processing
selection quality
responsiveness
memory efficiency
result review UX

```

Everything else should remain as simple as possible until the product proves that additional complexity is necessary.