# iOS Architecture

**Status:** Observed catalog architecture and legacy recovery boundaries · 2026-09-25.
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
| `App/AppContainer.swift`, `AppModel.swift`, `AppRoute.swift`, `RootView.swift` | Composition, startup, catalog and recovery navigation |
| `Services/Photos/PhotoLibraryPermissionService.swift` | Authorization, asset metadata, library-change notification |
| `Services/Photos/ImageLoaderService.swift` | Bounded thumbnails, oriented analysis images, previews, iCloud handling |
| `Services/Photos/BatchPipeline.swift`, `Services/Session/SelectionSessionCoordinator.swift` | Legacy session batches, cancellation, checkpoints, and results |
| `Services/Analysis/` | Native image facts and transient FeaturePrint evidence |
| `Domain/Selection/DuplicateResolver.swift`, `Domain/Models/SelectionGrouping.swift` | Candidate/group logic and canonical group representation |
| `Infrastructure/FileAnalysisCache.swift` | Revision-aware recomputable analysis rows |
| `Infrastructure/WorkspaceStore.swift`, `PhotoCuratorSchema.swift` | Durable scopes/choices and schema migration |
| `Features/Review/` | Shared session review, suggestions, detail, group views |
| `Services/Export/`, `Services/Deletion/` | Separate durable Photos mutation services |

`AppContainer.live` wires native analysis and injects the durable `actionContexts` store.
Qwen source and package dependencies remain historical material, but do not establish an active admitted model.
Catalog reconciliation is durable; legacy session navigation/readers remain recovery-only compatibility paths.
Legacy `SelectionResult` still couples the historical session analysis/grouping path to album selection output;
catalog discovery and action contexts do not depend on it.

## Intended topology

The following names describe catalog/action responsibilities; feature plans own exact type integration.

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

The coordinator uses one `nativeImageFacts` capability and its evidence file,
V4 per-asset/capability work state, a durable reconciliation handoff, a two-image
comparison batch, and a shared two-permit `ImageWorkArbiter`.

The library index outlives any analysis job or user action.
An analysis job enriches assets; it does not select an album or wait for all photos before publishing useful results.
Queries read compact catalog projections instead of loading every analysis JSON file.
Photo detail consumes an asset and a scoped order, not a required `SelectionResult`.

## Responsibility boundaries

- Views send intents and render state. They do not call PhotoKit, Vision, or model runtimes.
- UI models own navigation and temporary selection, not inference or mutation persistence.
- The analysis coordinator actor owns scheduling, run tokens, checkpointing, revision reconciliation, and publication order.
- The catalog store owns metadata, query projections, overrides, and index generations.
- Evidence files own immutable `nativeImageFacts`; SwiftData V4 owns current per-asset/capability status; checkpoints are durable handoff hints only.
- `ImageWorkArbiter` owns two shared image-work permits across session analysis, catalog enrichment, and visible inspection; no lane creates a private pool.
- Providers return evidence and availability. Label/group policies interpret evidence without writing user choices.
- Album and deletion services retain independent operation stores and mutation gates.
- Existing session readers are historical compatibility paths surfaced through Saved Work recovery;
  they are not new entry routes.

Use concrete stores rather than a generic repository abstraction.
Keep dependency seams at Apple/runtime boundaries and between independently versioned evidence producers.
Storage placement and proposed records belong to [data model](data-model.md).

## Flows

### Open and reconcile

Read current authorization → enumerate metadata → reconcile catalog generation → publish browseable assets → enqueue stale/missing evidence.
Notification callbacks request reconciliation; they do not start an unbounded inference task per callback.
Late results with old asset/provider generations cannot replace current evidence.

### Analyze and discover

Load bounded image → extract `nativeImageFacts` → durably write evidence → guarded-commit matching V4 status → publish snapshot update → advance the reconciliation handoff/checkpoint.
Group rebuilding is independent of album sizing and selected/rejected output.
Background suspension checkpoints safe work and resumes on the next execution opportunity.

### Act

Freeze explicit selected IDs → resolve current access → preview exact action → commit local state or dispatch durable operation.
The action does not rerun analysis or consume an automatically expanding query.

## Concurrency

Use `@MainActor` UI state and actor-isolated coordination/stores.
Use bounded structured tasks for image work and drain tasks before closing a generation. Every evidence/status commit checks the actor-owned run token, catalog generation, asset fingerprint, and capability/provider revisions.
New work invalidates the prior run token; cancellation drains tasks before terminal publication.
Reset cancels and drains catalog plus legacy workers, invalidates the token, clears derived
cache/evidence/projections/status/checkpoints safely, preserves labels/overrides, workspace
choices, action contexts, staged drafts, and mutation records, and rejects late results.
Unavailable and retryable outcomes use typed reasons rather than raw errors or inferred counters.
The shared `ImageWorkArbiter` has two permits and prioritizes visible inspection without exceeding
the global image-work bound. Image loading is scoped to each analysis/comparison/inspection
operation and released rather than retained as a library-wide decoded set.
Prioritize visible inspection over enrichment work and release image buffers promptly.
Resource policy belongs to [performance](../ship-gates/performance.md).

## Migration and verification

Preserve the current SwiftData V1→V2 history and add an explicit catalog migration.
Do not reinterpret existing scope choices as catalog-wide labels or choices.
Catalog entry follows the [roadmap](../exec-plans/roadmap.md); legacy recovery remains available through Saved Work.

Run `./init.sh` for every behavior-changing feature.
Compilation establishes neither image accuracy nor whole-library device capacity.
