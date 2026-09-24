# Exact-set Organization Actions Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Activate after feat-045 with user approval.

**Goal:** Apply explicit actions to selected catalog photos through existing durable mutation boundaries.

**Architecture:** Convert frozen selection into named action contexts. Reuse independent album and deletion services, extending destination identity and recovery instead of bypassing them.

**Tech Stack:** SwiftUI, SwiftData operation stores, PhotoKit export/deletion services.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese.
- Preserve exact-set confirmation, full-access deletion gating, and no automatic deletion retry.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes feat-045 exact selection IDs/revision and effective label intents.
Produces durable draft/staging contexts and recoverable album/deletion operations independent of selection sessions.

## Files and tasks

### 1. Bridge selection to durable actions

Existing: `apps/photo-curator/App/AppModel+Save.swift`, `AppModel+Deletion.swift`, `Infrastructure/WorkspaceStore.swift`, `Features/Review/ReviewModelActions.swift`.
Proposed new: `apps/photo-curator/Features/Library/LibraryActionModel.swift`, `LibraryActionTray.swift`.

- [ ] Freeze action type and IDs at preview; re-resolve access without silently shrinking the confirmed set.
- [ ] Create/reuse an explicit action context without importing legacy picks as selection.
- [ ] Keep bulk local label/staging changes atomic and retain committed state on persistence failure.
- [ ] Prevent duplicate dispatch while an operation owns the action.

### 2. Support album destinations

Existing: `apps/photo-curator/Services/Export/AlbumSaveService.swift`, `PhotoKitAlbumExporter.swift`, `Domain/Models/AlbumSaveOperation.swift`, `Infrastructure/AlbumSaveOperationStore.swift`, `PhotoCuratorSchema.swift`.
Proposed new: `apps/photo-curator/Features/Library/AlbumDestinationView.swift`.

- [ ] Add supported writable-album enumeration behind the Photos service boundary.
- [ ] Persist new/existing destination identity with a schema migration where required.
- [ ] Retain collision-safe new-album creation and reconcile interrupted saves by stored destination ID.
- [ ] Retry only missing/unresolved members through explicit action; report partial results truthfully.

### 3. Integrate staging and recovery

Existing: `apps/photo-curator/Features/Cleanup/CleanupReviewView.swift`, `Services/Deletion/PhotoDeletionService.swift`, `Infrastructure/DeletionOperationStore.swift`, `App/RootView.swift`.

- [ ] Open exact staged-set review from catalog selection without requiring an old cleanup entry intent.
- [ ] Preserve full-access preflight, digest, fresh confirmation, immutable executing set, and per-ID outcomes.
- [ ] Route saved drafts, staged contexts, and unresolved outcomes from Saved Work.
- [ ] Keep legacy operation recovery reachable and update bilingual disclosures in `Localizable.xcstrings`.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Inspect changed-set confirmation, limited access, double taps, persisted executing state, lost completion, album retry identity, and unrelated state preservation.
Source/build evidence is not proof of a real Photos mutation outcome; record actual limitations.

## Rollback and handoff

Disable new action entry on migration/integration failure while retaining operation stores and recovery routes.
Never rollback by deleting staged sets or unresolved operations.
Hand all new route/schema dependencies to feat-047 before cutover.
