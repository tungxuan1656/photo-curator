# Data Model

**Status:** Phase 1 pivot contract · durable representation owner

PhotoKit remains authoritative for original assets. This document defines
which state is durable and where it lives; policy is in
[review-rules.md](../product-specs/review-rules.md).

## Persistence boundary

| Data | Durable location | Rule |
|---|---|---|
| Review scopes and workspace state | SwiftData | product state only |
| Cleanup/album/review choices | SwiftData | independent and user-authoritative |
| Album-save/deletion operations | SwiftData | exact set, digest, status, outcomes; schemas introduced by feat-035/036 migrations |
| Migration marker | SwiftData | committed only after complete import |
| Analysis facts and suggestions | file/cache | versioned, immutable per run |
| Thumbnails and derived groups | bounded cache | evictable/rebuildable |
| Checkpoints | file store | compact, resumable, no pixels |
| Models/artifacts | app support/model cache | verified local artifacts only |
| Original bytes / `PHAsset` | Apple Photos | never copied into models |

Use SwiftData directly for these durable entities. Do not introduce a generic
repository layer.

Feature ownership is explicit: feat-033 owns only `ReviewScope`, workspace-item
state, the migration marker, and workspace store/import infrastructure.
`AlbumSaveOperation` and its state schema belong exclusively to feat-035 and
are added by its explicit SwiftData schema migration. `PhotoDeletionOperation`
and its state schema belong exclusively to feat-036 and are added by its
explicit SwiftData schema migration. This document records their durable
shapes; feat-033 does not create or migrate either operation entity.

## Durable entities

`ReviewScope` identifies an intent (`cleanup` or `album`), source asset IDs,
created/updated times, and migration/schema versions. `WorkspaceItem` is keyed
by `(scopeID, assetID)` and stores four independent values:

- `cleanupDisposition`: `undecided | keep | stagedForDeletion`;
- `albumMembership`: `unset | included | excluded`;
- `reviewProgress`: `unseen | inProgress | reviewed`;
- `analysisRef` plus availability/version metadata.

`AnalysisFact` and `Suggestion` are immutable file/cache records, not choices.
A suggestion stores provenance, reason/evidence status, model/runtime revision,
and candidate IDs. It cannot encode a deletion result.

`AlbumSaveOperation` stores scope ID, exact album-member IDs, digest, status,
per-ID outcomes, and timestamps. `PhotoDeletionOperation` stores scope ID,
exact staged IDs, exact-set digest, confirmation time, authorization snapshot,
status, and per-ID outcomes (`pending`, `deleted`, `accessUnknown`, `failed`).
A digest is computed from canonical sorted asset IDs plus the operation/schema
version and is checked before mutation.

## Migration

The importer is one-way and idempotent. Legacy `selected` and `restored` map to
album `included`; legacy `rejected` and `removed` map to album `excluded`. All
legacy cleanup values map to `undecided`; all imported review progress maps to
`unseen`. Reasons, unavailable assets, and old result status never infer
cleanup or progress.

Import writes the new scope/items and then a durable migration commit marker.
Legacy rows/files are retained until that marker is committed. A crash before
commit repeats safely; it never deletes legacy data. A committed marker makes a
repeat a no-op.

## Invariants

- IDs are `PHAsset.localIdentifier` values wrapped in domain types.
- Missing IDs are unresolved/access-unknown, not deletion evidence.
- No model stores pixel buffers, full photos, Vision objects, face boxes,
  precise GPS, or feature-print blobs.
- Missing facts are unknown, never fabricated zeroes.
- Album save never changes cleanup disposition; deletion never changes album
  membership.
- Per-operation outcomes are not copied into the app-level cleanup disposition.

## Cache/versioning and checkpoints

Analysis version, grouping version, model/runtime revision, and asset fingerprint
control reuse. A choice/config change reuses valid facts. A checkpoint stores
scope ID, source IDs, versions, stage, completion counters, and completed work
refs only. Full reconciliation rules and budgets belong to
[performance.md](../ship-gates/performance.md).
