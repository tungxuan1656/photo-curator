# Catalog Cutover and Lifecycle Hardening Implementation Plan

> **Execution:** Complete after feat-046. The approved decision is that catalog discovery is the default; legacy review/session is compatibility recovery only, with no new-session entry.

> **Status:** Done. All executed phases and invariant checks below are complete.

**Goal:** Complete the organization-first default flow, recover historical work without changing catalog authority, and make reset/lifecycle limits truthful.

**Architecture:** Wire every durable owner through `AppContainer.live`, aggregate saved-work recovery across catalog and legacy records, cut new entry through catalog discovery, and retain only compatibility readers/routes required for existing data.

**Tech Stack:** Existing SwiftUI app, catalog/services, SwiftData migrations, file cache/checkpoint recovery.

## Global constraints and invariants

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese.
- Catalog discovery is the default route. Legacy review/session is compatibility recovery only; no new-session entry point is added or retained.
- Recovery opens persisted identities and operation state. It does not rerun a query, expand a frozen action set, or import legacy selection into catalog authority.
- Reset clears only derived analysis evidence, projections, status, and checkpoints after workers drain and their run tokens are invalidated. It preserves user organization and mutation state.
- No inferred deletion, lost overrides, or erased unresolved operation state.
- Source-verifiable bounds remain: 32-asset analysis page, 2-image comparison batch, one shared two-permit image-work arbiter, and scoped image loading. Device-scale, latency, thermal, battery, and whole-library capacity remain unmeasured.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes completed feat-040–046 contracts and actual integration evidence. Produces the default organization route, compatibility saved-work recovery, bounded reset/lifecycle behavior, and owner documentation matching shipped capabilities.

## Phased work

### Phase 1 — Repair the feat-046 prerequisite and inventory recovery

1. [x] Repair the prerequisite seam by wiring `WorkspaceStore.actionContexts` through `AppContainer.live`; verify the live container exposes the same durable `LibraryActionContextStore` used by catalog album/deletion actions.
2. [x] Inventory persisted records and readers before changing routes:
   - SwiftData V1–V9: legacy `ReviewScope`/`WorkspaceItem`/migration markers, `AlbumSaveOperation`, `PhotoDeletionOperation`, catalog assets/generations/state, `AnalysisWorkState`, comparison state/snapshots/groups/members/evidence, label analysis/automatic assignments/overrides/personal-label definitions and assignments/effective projections, and `LibraryActionContext`.
   - File-backed authority and handoffs: `FileAnalysisCache`, `LibraryAnalysisEvidenceStore`, `LibraryAnalysisCheckpointStore`, `SessionCheckpointStore`, legacy session artifacts, and their importer.
   - Readers and routes: Saved Work, `AppModel` library action recovery, legacy workspace/session recovery, album-save recovery, and deletion-operation recovery.
3. [x] Aggregate Saved Work from unfinished catalog action contexts plus legacy workspace/session, album, and deletion records. Preserve each record's identity, exact IDs, revisions, destinations, status, and per-item evidence; show typed unavailable/inaccessible/schema-failure states rather than silently dropping entries.
4. [x] Make recovery idempotent and read-only with respect to catalog authority: it must not rerun the saved query, import legacy selected/removed choices as catalog labels or catalog-wide selection, or create a new session. A legacy importer may restore compatibility workspace state only.

**Phase 1 invariants:** catalog metadata and projections remain authoritative for discovery; action contexts remain fixed exact sets; legacy scopes do not collapse into catalog choices; operation recovery never dispatches a Photos mutation automatically.

### Phase 2 — Drain workers and define reset boundaries

1. [x] Before clearing anything, stop admission of new analysis/comparison work, invalidate the active run/generation tokens, and drain structured workers and image leases. Late evidence, status, projection, or checkpoint writes must be rejected.
2. [x] Reset only derived analysis state: authoritative analysis evidence/cache rows, automatic label assignments and effective derived projections, comparison/group projections and evidence, analysis work status, and analysis/reconciliation checkpoints or handoff hints. Rebuildable generation/projection pointers must not make cleared work appear current.
3. [x] Preserve label definitions, user overrides, personal labels and assignments, legacy workspace choices, catalog action contexts, album drafts, deletion staging, and album/deletion operation records plus their destinations, exact sets, digests, and per-ID outcomes.
4. [x] Requeue only from current catalog assets and revisions after reset. Reset must not mutate originals, rerun a query as recovery, or reinterpret staging/drafts/operation evidence.

**Phase 2 invariants:** drain-before-clear; invalidate-before-publish; no late-result resurrection; user labels/overrides/personal labels and all action/mutation evidence survive; reset failures leave a truthful recoverable state.

### Phase 3 — Catalog default and compatibility-only routes

1. [x] Route launch and normal discovery directly to browseable catalog state; analysis enriches the library progressively and does not require cleanup or album intent.
2. [x] Remove legacy new-session entry points and any active-session prerequisite from the default organization flow. Do not remove compatibility readers/routes needed to open saved legacy workspace/session work or recover album/deletion operations.
3. [x] Keep legacy review/session code behind explicit compatibility recovery. It may render or complete its own persisted workspace, but it cannot become catalog authority and cannot be offered as a new-session choice.
4. [x] Preserve exact-set action semantics for label, album, staging, and deletion actions: snapshot IDs and revisions once, then recover the durable action/operation rather than reading a live query.

**Phase 3 invariants:** catalog discovery is the only default entry; legacy compatibility is explicit and finite; saved work remains reachable; no route silently converts a legacy selection into catalog truth.

### Phase 4 — Lifecycle bounds, errors, and truthful documentation

1. [x] Reconcile foreground/resume, new or edited assets, access changes, cache loss, interrupted generations, schema/migration failure, and unavailable image states with typed, user-visible recovery outcomes.
2. [x] Keep source-verifiable work bounds: analysis pages are capped at 32 assets, comparison image batches at 2 images, all image work uses the shared two-permit arbiter, and thumbnails/detail/analysis images are scoped and released rather than retained as a library-wide decoded set.
3. [x] Document that device-scale, whole-library capacity, latency, battery, thermal, and quality behavior are unmeasured; do not turn Simulator build evidence into a device-capacity claim.
4. [x] Reconcile current owner docs and English/Vietnamese localization for catalog default, compatibility recovery, reset preservation, access/schema/error states, and unsupported/unmeasured limits. Do not advertise a legacy new-session route or unsupported label/state.

**Phase 4 invariants:** every failure identifies what remains recoverable; inaccessible is not deletion; reset and cache loss preserve user state; localization and documentation describe shipped behavior rather than roadmap intent.

## Files and ownership targets

- Route/composition and prerequisite wiring: `AppContainer`, `AppModel`, `AppRoute`, `RootView`, Home/catalog entry, Saved Work, and legacy recovery callers.
- Durable recovery and reset: workspace/catalog/action stores, operation stores, evidence/cache/checkpoint stores, importers, and analysis/comparison coordinators.
- Truthful owner documentation and localization: relevant `docs/` owners plus English/Vietnamese String Catalog entries; update `init.sh` only if verification commands or workspace modules actually change.

## Acceptance evidence

Acceptance is source-verifiable and must include recovery/reset route evidence plus the final `./init.sh`. Do not claim implementation, runtime scale, image quality, or device capacity from documentation activation or Simulator compilation alone.

## Verification

Final verification: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0, generic iOS Simulator `BUILD SUCCEEDED`; test skipped per DEC-040); `git diff --check` PASS; final @oracle invariant review APPROVED. The catalog default route, no-new-session boundary, aggregate Saved Work recovery, drain-before-reset ordering, preserved records, exact-set action recovery, localization, and source bounds were reconciled without a device-capacity claim.

## Rollback and handoff

Preserve the latest supported schema and compatibility recovery entry when disabling catalog routes. Do not roll back to a binary that cannot read the migrated schema. Feature closed after all acceptance items and final verification passed; no blocker remains.
