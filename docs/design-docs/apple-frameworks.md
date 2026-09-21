# Apple Frameworks

**Status:** Phase 1 pivot contract · PhotoKit/Vision API owner

This doc owns API facts and service calls. UX wording is in
[ux-flows.md](../product-specs/ux-flows.md) and [ui-copy.md](../product-specs/ui-copy.md);
choice/deletion semantics are in [review-rules.md](../product-specs/review-rules.md).

## Access and reads

Request `.readWrite` access in context. Full access supports review, album save,
and deletion. Limited access supports review and cleanup staging but cannot
start original deletion. Recheck authorization immediately before each write
operation; do not loop prompts.

Use `PHAsset.localIdentifier` as the domain ID. Fetch metadata first. Resolve
IDs again before save or deletion because Photos/iCloud state can change. A
missing ID is unavailable/access-unknown, never evidence that deletion worked.

`PHCachingImageManager` supplies bounded thumbnails and analysis images. Keep
PhotoKit objects behind services, release decoded images, and make callbacks
cancellation-aware. Vision receives oriented bounded images and returns compact
facts; no Vision request or pixel buffer enters durable state.

## Album save

Album save is a separate `AlbumSaveService` using
`PHAssetCollectionChangeRequest` and `PHPhotoLibrary.performChanges`. It writes
only after explicit **Save Album**. Persist progress and per-ID outcomes so a
partial or interrupted write can be reconciled and retried only by explicit
user action. Save never calls a deletion API and never clears cleanup state.

## Original deletion

Original deletion is exclusively a `PhotoDeletionService`. Before
`performChanges`, it requires:

1. current full read-write authorization;
2. a user-reviewed exact staged set;
3. explicit confirmation; and
4. a persisted canonical exact-set digest and operation state.

Resolve every ID again and persist the pending/per-ID operation state before
mutation. Limited authorization is a hard stop, not a partial deletion mode.
There is no automatic retry. An interruption reconciles authorization, exact ID
resolution, and recorded outcomes, then asks for an explicit next action.

Persist successful completion for the submitted mutation set before reporting
`deleted`. If the callback or persistence result is lost, retain uncertainty.
Re-fetching an absent asset is not proof of successful deletion. Follow the
[operation recovery table](data-model.md#deletion-operation-state-machine);
reconciliation never issues another mutation automatically.

PhotoKit deletion can synchronize through iCloud and can place items in
Recently Deleted. The app must not promise immediate recovered bytes or infer
storage change from asset file-size estimates.

## Errors and privacy

Map authorization, missing asset, iCloud, cancellation, album, and deletion
errors to stable app states. Never show raw framework errors. Keep IDs, faces,
location, pixels, and model outputs out of logs and network paths. No cloud
inference is part of the core flow.

## Acceptance

- Full/limited/denied/restricted paths are distinct and stable.
- Album save and deletion use separate services and PhotoKit mutation paths.
- Exact-set digest and per-ID outcomes survive interruption.
- No full-resolution batch retention, pixel persistence, or automatic deletion
  retry exists.
