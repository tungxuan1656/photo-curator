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
status, and per-ID outcomes (`pending`, `deleted`, `accessUnknown`, `failed`,
`unresolved`).
A digest is computed from canonical sorted asset IDs plus the operation/schema
version and is checked before mutation.

## Deletion operation state machine

This is the target feat-036 schema contract, not an entity implemented by feat-033.

| Operation status | Meaning and allowed transition |
|---|---|
| `prepared` | Exact set, digest, confirmation and authorization snapshot persisted; → `executing` after fresh preflight, or `cancelled` before dispatch |
| `executing` | Persisted before dispatch; → `completed`, `partial`, `failed`, or `needsReconciliation` |
| `needsReconciliation` | Dispatch/result persistence uncertain; explicit read-only reconciliation → a resolved outcome or stays here |
| `completed` | Every member has durably recorded `deleted` evidence; terminal |
| `partial` | All outcomes resolved, with both `deleted` and `failed` members; terminal |
| `failed` | All outcomes resolved as failed; terminal |
| `cancelled` | No mutation dispatched; terminal |

`pending` is pre-dispatch. `deleted` requires persisted successful PhotoKit
completion for the recorded mutation set. `failed` requires a known failure
or a preflight failure before dispatch. `accessUnknown` means current access
prevents resolution. `unresolved` means execution or its result is uncertain.
Neither `accessUnknown` nor `unresolved` is a terminal success/failure outcome.

| Recovery observation | Durable result / next action |
|---|---|
| Successful callback persisted | Mark only that submitted set `deleted`; never infer results for unsubmitted IDs |
| Known failed callback persisted | Mark that submitted set `failed` |
| Relaunch finds `prepared` | No automatic dispatch; repeat preflight and require fresh confirmation before an explicit start |
| Relaunch finds `executing` without durable completion | `needsReconciliation`; pending submitted members become `unresolved` |
| Access is limited/denied/restricted | Unresolved members become `accessUnknown`; preserve prior durable outcomes |
| Full access restored, asset absent | Remain `unresolved`; absence is not successful-deletion evidence |
| Full access restored, asset present | Remain `unresolved` without a recorded completion; offer an explicit new review |

Reconciliation performs reads and records evidence; it never dispatches deletion.
A user may start a new operation only for a freshly resolved, reviewed and
confirmed set. Do not rewrite the old uncertain operation as successful.
Retain uncertain operations even if the user dismisses their outcome screen.
Known successful outcomes survive later authorization loss.

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
