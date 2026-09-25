# Exact-set Organization Actions Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Feat-045 is complete; this approved exact-set contract is now active for implementation.

**Goal:** Apply explicit actions to selected catalog photos through existing durable mutation boundaries.

**Architecture:** Convert frozen selection into named independent durable action contexts. Key each context by exact IDs and the frozen query/catalog/label-projection revisions. Reuse album and deletion services, extending destination identity and recovery instead of bypassing them.

**Tech Stack:** SwiftUI, SwiftData operation stores, PhotoKit export/deletion services.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese.
- Preserve exact-set confirmation, full-access deletion gating, and no automatic deletion retry.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Approved exact-set action contract

An action context is durable and independent from browsing, album membership,
cleanup staging, and other drafts. It is keyed by the frozen feat-045
selection's exact asset IDs, query identity, catalog generation, and
label-projection revision. `ReviewModel` and legacy selected-asset state are
not authority and must never be imported as a new action set.

Preflight must reject a changed or access-mismatched set, including any
revision mismatch or missing access to a frozen ID. It must not silently shrink,
expand, substitute, or rediscover the dispatch set. The preview and dispatch
must retain the same exact-set identity.

Existing and newly created writable album destinations are addressed by stable
identity. Retry reconciles the same destination and only unresolved members;
it must not create duplicate destinations. Deletion retains the existing
full-access check, exact confirmation, durable digest, immutable executing set,
and per-ID outcomes. There is no automatic deletion retry; recovery is explicit
and durable.

## Inputs and outputs

Consumes feat-045 exact selection IDs/revision and effective label intents.
Produces durable draft/staging contexts and recoverable album/deletion operations independent of selection sessions.

## Files and tasks

### 1. Bridge selection to durable actions

Existing: `apps/photo-curator/App/AppModel+Save.swift`, `AppModel+Deletion.swift`, `Infrastructure/WorkspaceStore.swift`, `Features/Review/ReviewModelActions.swift`.
Proposed new: `apps/photo-curator/Features/Library/LibraryActionModel.swift`, `LibraryActionTray.swift`.

- [ ] Freeze action type and IDs at preview; reject revision/access mismatch without silently shrinking the confirmed set.
- [ ] Create/reuse an independent durable action context without importing legacy `ReviewModel` picks as selection authority.
- [ ] Keep bulk local label/staging changes atomic and retain committed state on persistence failure.
- [ ] Prevent duplicate dispatch while an operation owns the action.

### 2. Support album destinations

Existing: `apps/photo-curator/Services/Export/AlbumSaveService.swift`, `PhotoKitAlbumExporter.swift`, `Domain/Models/AlbumSaveOperation.swift`, `Infrastructure/AlbumSaveOperationStore.swift`, `PhotoCuratorSchema.swift`.
Proposed new: `apps/photo-curator/Features/Library/AlbumDestinationView.swift`.

- [ ] Add supported writable-album enumeration behind the Photos service boundary.
- [ ] Persist stable new/existing destination identity with a schema migration where required.
- [ ] Retain collision-safe new-album creation and reconcile interrupted saves by stored destination ID.
- [ ] Retry only missing/unresolved members through explicit action; report partial results truthfully.

### 3. Integrate staging and recovery

Existing: `apps/photo-curator/Features/Cleanup/CleanupReviewView.swift`, `Services/Deletion/PhotoDeletionService.swift`, `Infrastructure/DeletionOperationStore.swift`, `App/RootView.swift`.

- [ ] Open exact staged-set review from catalog selection without requiring an old cleanup entry intent.
- [ ] Preserve full-access preflight, digest, fresh confirmation, immutable executing set, per-ID outcomes, and no automatic retry.
- [ ] Route saved drafts, staged contexts, and unresolved outcomes from Saved Work.
- [ ] Keep legacy operation recovery reachable and update bilingual disclosures in `Localizable.xcstrings`.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Inspect changed/access-mismatched set rejection, legacy-selection isolation, limited access, double taps, persisted executing state, lost completion, stable album retry identity, deletion confirmation/no-retry, and unrelated state preservation.
Source/build evidence is not proof of a real Photos mutation outcome; record actual limitations.

## Rollback and handoff

Disable new action entry on migration/integration failure while retaining operation stores and recovery routes.
Never rollback by deleting staged sets or unresolved operations.
Hand all new route/schema dependencies to feat-047 before cutover.
