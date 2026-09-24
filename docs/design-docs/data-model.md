# Data Model

**Status:** Observed persistence plus intended catalog contract · 2026-09-23.
Owns storage, record identity, revisions, migration, and operation recovery.
PhotoKit remains authoritative for originals. Domain behavior belongs to [organization rules](../product-specs/organization-rules.md) and [review rules](../product-specs/review-rules.md).

## Observed storage

- `PhotoCuratorSchemaV1`: `ReviewScope`, `WorkspaceItem`, `WorkspaceMigrationMarker`, `AlbumSaveOperation`.
- `PhotoCuratorSchemaV2`: V1 plus `PhotoDeletionOperation` through an additive migration.
- `PhotoCuratorSchemaV3`: V2 plus `LibraryAsset`, `CatalogAssetObservation`, `CatalogGeneration`, and `CatalogState` through an additive migration.
- `PhotoCuratorSchemaV4`: V3 plus additive per-asset/capability `AnalysisWorkState` through a lightweight migration.
- `WorkspaceItem`: per-scope cleanup, album, progress, and analysis-reference dimensions.
- `FileAnalysisCache`: authoritative schema/version/asset-revision checked `nativeImageFacts` evidence records.
- `AnalysisWorkState`: current SwiftData status for one asset/capability; it never replaces evidence-file authority.
- Session checkpoint and result files remain compatibility inputs; the analysis checkpoint is a durable reconciliation handoff and resume hint, not completion evidence.
- FeaturePrint objects are transient and rebuilt when necessary; no persisted visual search index exists.
- Catalog observations are immutable per generation. `CatalogState.currentGenerationID` is the only browseable snapshot pointer.

## Intended persistence boundary

| Data | Location | Lifetime |
|---|---|---|
| Asset catalog metadata and committed access membership | SwiftData | Durable index; reconciled with Photos |
| Label definitions, overrides, personal labels | SwiftData | Versioned taxonomy and user-owned state |
| Automatic label and group projections | SwiftData, compact and rebuildable | Query index referencing evidence revisions |
| Immutable analysis facts | Evidence file/cache boundary | Authoritative, atomically written per asset/fingerprint/analysis/provider revision |
| Current analysis status | SwiftData V4 `AnalysisWorkState` | Queryable pending/running/available/unavailable/stale state for `nativeImageFacts` |
| Analysis handoff/checkpoint | Compact durable file record | Resume hint only; never proof that evidence or status committed |
| Temporary action selection | UI state | One result snapshot, not durable membership |
| Drafts, staging, operation records | SwiftData | User work and unresolved outcomes survive restart |
| Thumbnail cache | Bounded local cache | Evictable |
| Model artifacts | Verified local artifact storage | Versioned, removable |
| Original images and `PHAsset` objects | Apple Photos / transient services | Never copied into domain persistence |

Derived query projections are not user truth. Their rebuild cannot erase overrides, drafts, staging, or operation evidence.
Use SwiftData directly for durable catalog state. No generic repository layer is required.

## Intended catalog records

`LibraryAsset`, `CatalogAssetObservation`, `CatalogGeneration`, and `CatalogState` ship in V3. V4 adds only `AnalysisWorkState`; the remaining names are feature-owned proposals.

| Record | Identity and required content |
|---|---|
| `LibraryAsset` | Asset ID; stable catalog attachment point; last observed generation |
| `AnalysisWorkState` | Asset ID + `nativeImageFacts` capability; requested/completed asset, analysis, and provider/runtime revisions; pending/running/available/unavailable/stale state; typed reason |
| `LabelDefinition` | Stable label ID; facet; taxonomy revision; localization keys; supported capability |
| `AutomaticLabelAssignment` | Asset + label + evidence revision; provider reference; confidence/evidence status |
| `LabelOverride` | Asset + label; confirm/reject; user revision and timestamp |
| `PersonalLabelAssignment` | Asset + user label ID; explicit user assignment |
| `ComparisonGroupSnapshot` | Group ID/revision; relation; ordered exact members; representative; evidence refs; grouping version |
| `CatalogGeneration` | Enumeration generation, authorization snapshot, status, timestamps, count, and non-sensitive failure category; prevents partial scans becoming deletion evidence |

Effective labels resolve user overrides over current automatic assignments.
Unknown confidence stays absent; it cannot be invented for metadata or user labels.
Raw provider names do not become stable label IDs.

Group identity derives deterministically from relation kind and canonical member IDs.
Membership changes produce a new group revision/identity; open comparison snapshots remain stable until explicit refresh.
Group replacement does not transfer implicit reviewed, selected, or deletion intent.

## Revision and query contract

The first analysis capability is `nativeImageFacts`; its evidence identity includes the asset modification fingerprint, analysis revision, and provider/runtime revision. Later capabilities add records rather than widening this contract implicitly.
Evidence references include asset modification fingerprint, analysis revision, provider/runtime revision, and mapping/grouping revision where applicable.
Only matching current revisions populate current query projections.
Stale projections can support a visibly stale display, but cannot silently match current label filters.

Analysis publication is ordered and durable: (1) atomically write authoritative evidence, (2) guarded-commit the matching catalog status, (3) publish the new query snapshot, and (4) advance the reconciliation checkpoint. A later step never makes an earlier missing step appear complete.

`AnalysisWorkState.reason` is typed. Minimum reasons are `accessRequired`, `iCloudWaiting`, `modelUnavailable`, `revisionStale`, `cancelled`, `transientFailure`, and `unsupported`; `completedEmpty` is a successful result, not an unavailable reason. Retry policy is derived from the reason, never from a counter alone.

A query returns distinct accessible IDs, deterministic order, snapshot revision, facet counts, and coverage counts.
Pagination never changes the semantics of Select All.
The selected action stores a fixed ID set and query/group revision, not a live predicate.

## Durable action contexts

Existing scope-bound choices remain intact.
New action contexts reference explicit catalog IDs and a chosen draft/staging destination, not inferred `SelectionResult` picks.
Multiple legacy scopes for one asset do not collapse into a single choice.

Album operations store the exact member set, canonical digest, destination identity, status, and per-ID outcomes.
The destination distinguishes newly created and existing writable albums.
Retry retains the destination identity and does not reconstruct it from a display name.

Deletion operations retain the existing exact set, digest, confirmation/access snapshots, timestamps, and per-ID outcomes.
Operation outcomes never overwrite cleanup disposition by inference.

## Deletion operation state machine

| Status | Meaning and transitions |
|---|---|
| `prepared` | Exact set persisted; explicit fresh preflight/confirmation → `executing`, or cancel before dispatch |
| `executing` | Persisted before mutation; → completed, partial, failed, or needs reconciliation |
| `needsReconciliation` | Execution/completion uncertain; explicit read-only reconciliation |
| `completed` | Every submitted member has durable successful deletion evidence |
| `partial` | Resolved mixture of deleted and failed members |
| `failed` | All outcomes are known failures |
| `cancelled` | No mutation dispatched |

| Recovery observation | Result |
|---|---|
| Successful callback persisted | Mark only submitted members `deleted` |
| Known failed callback persisted | Mark submitted members `failed` |
| Relaunch finds prepared operation | No automatic dispatch; repeat preflight and confirmation |
| Relaunch finds executing without completion | Preserve `unresolved`, require reconciliation |
| Access prevents inspection | `accessUnknown`; keep prior known outcomes |
| Asset absent with full access | Remains unresolved without persisted completion |
| Asset present with full access | No inferred failure/success; offer new explicit review |

`pending` is pre-dispatch. `unresolved` and `accessUnknown` are not terminal success/failure evidence.
Reconciliation never dispatches deletion. Dismissing an outcome never discards uncertain operation records.

## Migration

1. V3 adds catalog entities without replacing existing scope and operation schemas.
2. Enumerate authorized assets into a generation; commit only a complete metadata reconciliation boundary.
3. V4 adds per-asset/capability work state without moving `nativeImageFacts` evidence out of its file authority.
4. Import reusable analysis only when asset/provider revisions match.
5. Rebuild automatic projections from valid evidence; preserve existing scope choices and operation IDs.
6. Commit a migration marker only after required writes succeed.
7. On interruption, repeat idempotently. Preserve source data until committed migration.

The earlier importer still maps selected/restored to album included and rejected/removed to album excluded.
It maps cleanup to undecided and progress to unseen; those historical mappings do not create catalog labels.
The new migration never unions legacy album drafts or staging sets.

Unknown schema or migration failure preserves existing data and offers explicit recovery.
An old binary must not reopen an incompatible migrated store; rollback is a code route rollback against the supported schema.

## Retention and unknown access

Access loss hides affected assets from actionable query results without deleting user state.
Missing IDs mean inaccessible/unresolved unless an authoritative observation establishes otherwise.
Analysis reset removes derived evidence/projections and requeues work. It preserves user labels, overrides, drafts, and operations.
It never removes originals.

No durable entity stores original pixels, face boxes, face identities, precise GPS, or Vision objects.
Persisted embeddings/FeaturePrint archives are not authorized by this rewrite.
Any proposed visual retrieval artifact requires an explicit privacy/storage decision in the grouping feature before implementation.
