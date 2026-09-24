# iOS Architecture

**Status:** Observed baseline and intended organization architecture · 2026-09-23.
Owns topology, orchestration, code navigation, and concurrency boundaries.

## Observed implementation

The app is one Swift 5 / SwiftUI target with Observation, PhotoKit, Vision, and SwiftData.
The product planning baseline is iPhone 14+ / iOS 26+.

```text
AppContainer.live → AppModel / ProcessingModel / ReviewModel
  → SelectionSessionCoordinator → BatchPipeline → VisionAnalysisService
  → SelectionEngine → SelectionResult → ReviewWorkspaceView
  → WorkspaceStore / file caches / checkpoints
  → AlbumSaveService or PhotoDeletionService
```

| Area under `apps/photo-curator/` | Existing responsibility |
|---|---|
| `App/AppContainer.swift`, `AppModel.swift`, `AppRoute.swift`, `RootView.swift` | Composition, startup, session navigation |
| `Services/Photos/PhotoLibraryPermissionService.swift` | Authorization, asset metadata, library-change notification |
| `Services/Photos/ImageLoaderService.swift` | Bounded thumbnails, oriented analysis images, previews, iCloud handling |
| `Services/Photos/BatchPipeline.swift`, `Services/Session/SelectionSessionCoordinator.swift` | Batches, cancellation, session checkpoints, results |
| `Services/Analysis/` | Native image facts and transient FeaturePrint evidence |
| `Domain/Selection/DuplicateResolver.swift`, `Domain/Models/SelectionGrouping.swift` | Candidate/group logic and canonical group representation |
| `Infrastructure/FileAnalysisCache.swift` | Revision-aware recomputable analysis rows |
| `Infrastructure/WorkspaceStore.swift`, `PhotoCuratorSchema.swift` | Durable scopes/choices and schema migration |
| `Features/Review/` | Shared session review, suggestions, detail, group views |
| `Services/Export/`, `Services/Deletion/` | Separate durable Photos mutation services |

`AppContainer.live` wires native analysis. Qwen source and package dependencies remain, but do not establish an active admitted model.
The change observer currently publishes a notification; it is not a durable incremental catalog.
`SelectionResult` still couples analysis/grouping to album selection output.

## Intended topology

The following names describe planned responsibilities, not implemented symbols.
Feature plans own exact type introduction and integration.

```text
SwiftUI discovery / label / filter / group / inspector views
                      ↓
          LibraryModel + query snapshots
            ├─ LibraryCatalogStore (SwiftData)
            ├─ LibraryAnalysisCoordinator (actor)
            │    ├─ PhotoLibraryService / PhotoImageLoader
            │    ├─ versioned analysis providers + file cache
            │    ├─ comparison-group builder
            │    └─ label mapper → queryable projections
            └─ explicit action snapshot
                 ├─ durable label overrides
                 ├─ album draft → AlbumSaveService
                 └─ staging → PhotoDeletionService
```

The library index outlives any analysis job or user action.
An analysis job enriches assets; it does not select an album or wait for all photos before publishing useful results.
Queries read compact catalog projections instead of loading every analysis JSON file.
Photo detail consumes an asset and a scoped order, not a required `SelectionResult`.

## Responsibility boundaries

- Views send intents and render state. They do not call PhotoKit, Vision, or model runtimes.
- UI models own navigation and temporary selection, not inference or mutation persistence.
- The analysis coordinator owns scheduling, checkpointing, revision reconciliation, and publication order.
- The catalog store owns metadata, query projections, overrides, and index generations.
- Providers return evidence and availability. Label/group policies interpret evidence without writing user choices.
- Album and deletion services retain independent operation stores and mutation gates.
- Existing session readers remain compatibility paths until saved-work recovery is integrated.

Use concrete stores rather than a generic repository abstraction.
Keep dependency seams at Apple/runtime boundaries and between independently versioned evidence producers.
Storage placement and proposed records belong to [data model](data-model.md).

## Flows

### Open and reconcile

Read current authorization → enumerate metadata → reconcile catalog generation → publish browseable assets → enqueue stale/missing evidence.
Notification callbacks request reconciliation; they do not start an unbounded inference task per callback.
Late results with old asset/provider generations cannot replace current evidence.

### Analyze and discover

Load bounded image → extract evidence → persist versioned result → update label/group projections → publish snapshot update.
Group rebuilding is independent of album sizing and selected/rejected output.
Background suspension checkpoints safe work and resumes on the next execution opportunity.

### Act

Freeze explicit selected IDs → resolve current access → preview exact action → commit local state or dispatch durable operation.
The action does not rerun analysis or consume an automatically expanding query.

## Concurrency

Use `@MainActor` UI state and actor-isolated coordination/stores.
Use bounded structured tasks for image work and drain tasks before closing a generation.
Prioritize visible inspection over enrichment work and release image buffers promptly.
Resource policy belongs to [performance](../ship-gates/performance.md).

## Migration and verification

Preserve the current SwiftData V1→V2 history and add an explicit catalog migration.
Do not reinterpret existing scope choices as catalog-wide labels or choices.
Cutover follows the [roadmap](../exec-plans/roadmap.md), with legacy recovery retained until the final integration feature.

Run `./init.sh` for every behavior-changing feature.
Compilation establishes neither image accuracy nor whole-library device capacity.
