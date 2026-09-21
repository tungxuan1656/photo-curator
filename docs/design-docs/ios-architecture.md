# iOS Architecture

**Status:** Phase 1 pivot contract · topology and orchestration owner
**Baseline:** Swift 5 / SwiftUI, iPhone 14+, iOS 26+

This doc owns app topology, coordination, concurrency, and service boundaries.
[data-model.md](data-model.md) owns persistence shape; [apple-frameworks.md](apple-frameworks.md)
owns API calls; [review-rules.md](../product-specs/review-rules.md) owns behavior.

## Target topology

This diagram describes the intended architecture, not a list of implemented
symbols. Execution status belongs to the feature tracker.

```text
SwiftUI views → AppModel / WorkspaceModel
                    ↓
          ReviewWorkspaceCoordinator (actor)
          ├─ PhotoLibraryService
          ├─ PhotoAnalysisService + AnalysisCache
          ├─ WorkspaceStore (SwiftData state only)
          ├─ FileStore / CheckpointStore / model artifacts
          ├─ AlbumSaveService
          └─ PhotoDeletionService
                    ↓
              PhotoKit / Vision / local runtime
```

Views render state and send intents. The coordinator owns scope lifecycle,
progress, cancellation, checkpointing, resume, and operation sequencing. Domain
logic receives IDs and compact values, not `PHAsset`, image objects, or Vision
requests.

There is no generic repository abstraction. A concrete workspace store is
sufficient; service protocols are used only at Apple/runtime seams that vary.
The old selection engine is a legacy adapter during migration, not the active
behavior owner.

## Durable/runtime boundary

### Implementation map

| Existing seam | Target integration owner |
|---|---|
| `AppContainer`, `AppModel.startup`, `WorkspaceStore`, `LegacyWorkspaceImporter` | feat-033 supplies durable state and startup import; unavailable storage preserves the legacy flow |
| `AppModel`, `ReviewModel`, `SelectionSessionCoordinator`, current checkpoint-backed routes | feat-034 binds shared review and resume to workspace state |
| `PhotoKitAlbumExporter`, `AppModel+Save`, file-backed save state | feat-035 introduces durable album operations and save reconciliation |
| No original-deletion service in the completed foundation | feat-036 introduces the separate confirmed-deletion boundary |
| Legacy selection/analysis adapters | feat-037 integrates suggestions and retires active legacy routing |

Target coordinator/model names describe responsibilities. Introduce or adapt
concrete types within the owning feature; do not assume those names already exist.

SwiftData stores only durable product state: review scopes, workspace state,
independent user choices, and migration markers in feat-033. Album-save
operation state is introduced by feat-035's explicit SwiftData schema
migration; deletion operation state is introduced by feat-036's explicit
SwiftData schema migration. File/cache stores hold photo analyses, thumbnails, derived group data,
checkpoints, cache entries, and model artifacts as appropriate. Full photo
bytes, decoded images, Vision objects, and runtime tensors remain transient.

A workspace is the one authoritative source for the four state dimensions.
Suggestions are immutable records and are applied only through an explicit user
intent. Every long-running task is cancellable and checkpoints at safe edges;
no extended background execution is promised.

## Services

| Service | Owns | Does not own |
|---|---|---|
| `PhotoLibraryService` | auth, asset IDs/metadata, access changes | choices or scoring |
| `PhotoAnalysisService` | local facts and availability | album/cleanup choices |
| `AnalysisCache` | evictable derived facts/thumbs | originals |
| `WorkspaceStore` | SwiftData scopes/workspace state/migration marker | operation schemas, image/cache blobs |
| `AlbumSaveService` | independent Photos album save | original deletion |
| `PhotoDeletionService` | exact-set confirmed deletion and outcomes | album save or suggestions |
| `ReviewWorkspaceCoordinator` | ordering, progress, resume, reconciliation | UI copy or ranking formula |

`PhotoDeletionService` checks full read-write access, verifies the persisted
exact-set digest, resolves IDs again, persists per-ID outcomes, then calls
PhotoKit. It never automatically retries.

## Concurrency and safety

Use `@MainActor` for UI models and actors for coordination, cache, and durable
stores. Use bounded structured task groups for analysis; release decoded images
promptly. Cancellation is checked before loads, after loads, around analysis,
and before persistence or PhotoKit mutation. Interruption reconciles persisted
state rather than assuming work completed.

## Validation and non-goals

The app remains one target with no test targets, `*Test*.swift` files, test
frameworks, or standalone proof harnesses. Required behavior verification is
reproducible automated evidence plus `./init.sh`. Do not treat compilation as
image-quality or device-performance evidence.
