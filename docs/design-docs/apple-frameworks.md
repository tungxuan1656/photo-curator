# Apple Framework Boundaries

**Status:** Existing service boundary with intended catalog integration · 2026-09-23.
Owns framework contact points. This is a repository integration map, not a substitute for current SDK documentation.

## Photos reads and reconciliation

`PhotoLibraryPermissionService` owns authorization and metadata fetches.
`PHAsset.localIdentifier` supplies domain identity within the authorized library.
The existing `LibraryChangeTracker` posts a change notification; catalog reconciliation is planned work.

The catalog enumerates accessible metadata first and reconciles new, edited, and inaccessible assets.
Recheck access when the app returns to the foreground and before writes.
A missing identifier does not prove deletion or successful app mutation.

The app requests read-write authorization in context because optional album/deletion actions write to Photos.
Limited access remains useful for browsing and organization.
Blocking deletion under limited access is a [product rule](../product-specs/review-rules.md#deletion-gate), not a claim about every possible PhotoKit API.

## Image and inference services

`ImageLoaderService` uses `PHCachingImageManager` for bounded thumbnails, analysis images, and detail previews.
The current protocol describes a 512-pixel analysis edge and a preview capped at 2048 pixels.
These sizes are implementation facts, not image-quality guarantees.
Image-loading callbacks remain cancellation-aware and expose iCloud waiting separately from failure.

`VisionAnalysisService` receives oriented bounded images and returns compact facts plus transient similarity artifacts.
Vision requests, `PHAsset`, and decoded pixel buffers remain behind services.
Provider changes use the [runtime admission contract](curation-runtime-stack.md).

## App lifecycle

Analysis can continue while the app remains active without blocking browsing.
The app checkpoints when execution time ends and resumes valid work later.
Background execution is opportunistic; a closed app cannot promise to finish a complete library scan.
Any new background API integration requires SDK verification and an explicit feature decision.

## Album writes

`AlbumSaveService` coordinates durable state with `PhotoKitAlbumExporter`.
The exporter uses `PHAssetCollectionChangeRequest` and `PHPhotoLibrary.performChanges`.
It can create a collision-safe album and add exact IDs to a known destination identifier.
The user-facing existing-album chooser is planned work; exporter capability alone does not imply that UI exists.

Resolve current destination/asset access before mutation.
Persist destination identity and per-ID outcomes for reconciliation.
An album write never calls the deletion service.

## Original deletion

`PhotoDeletionService` owns the separate mutation path.
Require full current authorization, exact staged IDs, explicit confirmation, and durable digest before dispatch.
Re-resolve IDs and record pending/executing state before `performChanges`.
No automatic retry occurs after interruption.

Successful completion must be persisted for the submitted set before reporting deleted assets.
Lost callback/persistence evidence remains uncertain.
Follow [operation recovery](data-model.md#deletion-operation-state-machine); reconciliation never dispatches a mutation.
Disclose iCloud synchronization and Recently Deleted without promising immediate recovered storage.

## Error boundary

Map access, missing asset, iCloud, cancellation, persistence, and mutation failures to stable app states.
Keep raw framework errors and photo-linked data out of UI copy, logs, and network paths.
Views use service/model intents, not framework calls.
