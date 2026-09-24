# Persistent Photo Catalog Foundation Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Activated on 2026-09-24.

**Goal:** Persist accessible library references independently of selection sessions.

**Architecture:** Add immutable PhotoKit metadata observations to a V3 SwiftData schema. A `CatalogState` pointer publishes only complete generations, so an interrupted scan leaves the prior snapshot visible. Existing workspace and operation rows remain untouched.

**Tech Stack:** Swift 5, SwiftData, PhotoKit service seam, existing file analysis cache.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese UI.
- Preserve all existing scope choices and operation IDs.
- Run `./init.sh` once after implementation and review fixes; no test targets, test files, or standalone proof harnesses. Manual QA is not a gate.
- `PhotoLibraryService.fetchAssets()` is the only Photos metadata input. Do not persist pixels, `PHAsset`, GPS, faces, OCR text, embeddings, or Vision objects.
- Do not add label, override, analysis-work, or comparison-group models. These features own their own durable records.
- Never write `ReviewScope`, `WorkspaceItem`, `WorkspaceMigrationMarker`, `AlbumSaveOperation`, or `PhotoDeletionOperation` during migration or reconciliation.

## Inputs and outputs

Consumes `PhotoLibraryService.fetchAssets`, domain asset fingerprints, and existing SwiftData V2 state.
Produces catalog metadata snapshots and explicit access/revision states for feat-041.
The record requirements are in [data model](../design-docs/data-model.md#intended-catalog-records).
`LibraryAsset` is the stable future attachment point. `CatalogAssetObservation` holds immutable metadata for one scan. `CatalogGeneration` records attempt/commit state. `CatalogState.currentGenerationID` is the sole browseable snapshot pointer.

## Files and tasks

### 1. Freeze the additive schema and migration

Existing: `apps/photo-curator/Infrastructure/PhotoCuratorSchema.swift`, `Domain/Models/PhotoAsset.swift`, `Domain/Models/ReviewWorkspace.swift`.
Create: `apps/photo-curator/Domain/Models/LibraryCatalog.swift`.
Modify: `apps/photo-curator/Infrastructure/PhotoCuratorSchema.swift`.

- [ ] Define `LibraryAsset` with unique asset ID and only stable bookkeeping.
- [ ] Define `CatalogAssetObservation` with unique `generationID::assetID`, cheap `PhotoAsset` metadata, and explicit fingerprint-presence representation.
- [ ] Define `CatalogGeneration` (`building`, `committed`, `abandoned`) with authorization snapshot, timestamps, count, and non-sensitive failure category.
- [ ] Define singleton `CatalogState` with `currentGenerationID`, latest attempt, and availability state.
- [ ] Add `PhotoCuratorSchemaV3 = PhotoCuratorSchemaV2.models + catalog models`, plus one V2-to-V3 lightweight migration stage. Do not alter V1/V2 declarations.
- [ ] Record that future user truth is keyed independently from generation observations; derived projections require current evidence revisions.

### 2. Reconcile immutable metadata generations

Create: `apps/photo-curator/Infrastructure/LibraryCatalogStore.swift`.
Consume: `PhotoLibraryService.fetchAssets()` and `PhotoAsset` only; do not extend the protocol or access PhotoKit directly.

- [ ] Serialize attempts in an actor. Create a `building` generation and update only last-attempt state before enumeration.
- [ ] Fetch outside SwiftData transactions. Reject duplicate asset IDs, then write immutable observations with bounded idempotent transactions.
- [ ] Before commit, require authorized or limited access, a successful complete fetch, and a staged unique count equal to the fetched unique count.
- [ ] In one transaction, commit the generation and flip `CatalogState.currentGenerationID`. Readers therefore see all old rows or all new rows.
- [ ] On cancellation, authorization loss, or a write failure, abandon the attempt without committing an empty generation or changing the current pointer.
- [ ] After publication, report changed fingerprints as stale derived work. Never erase user state, infer deletion outcomes, or mark absent IDs deleted.
- [ ] Retain old and abandoned generations. Defer cleanup to retryable maintenance after feat-041 proves a safe policy.

### 3. Integrate startup and recovery

Modify: `apps/photo-curator/App/AppContainer.swift`.
Consume: existing `WorkspaceStore`, operation stores, and legacy importer unchanged.

- [ ] Open V3 once with the migration plan and inject `LibraryCatalogStore` only when that container succeeds.
- [ ] Expose catalog `available`, `accessRequired`, and `unavailable` state for future browsing consumers without adding a discovery UI.
- [ ] If V3 container open or migration fails, preserve the store file and report durable workspace storage unavailable. Never reopen a V3 store through the lower-version fallback.
- [ ] If reconciliation fails after a successful open, keep V2 workspace and operation services available while the catalog reports unavailable or stale.
- [ ] Retain legacy saved-work routes, scope IDs, item identities, album session IDs, and deletion operation IDs unchanged.
- [ ] Do not edit `project.pbxproj`; its filesystem-synchronized root includes new source files.

## Verification

Run `git diff --check`, inspect the exact schema/store/startup paths, then run `./init.sh` once after implementation and review fixes.
Establish: unique identities; atomic pointer flip; incomplete-scan retention; access-loss no-empty-commit; fingerprint change detection; and no writes to legacy workspace/operation models.
Record that `fetchAssets()` materializes the accessible library and `modificationDate` does not prove every content edit. Compilation does not demonstrate every historical-store migration.

## Rollback and handoff

On a reconciliation failure, retain the last committed catalog generation and all workspace services.
On a schema-open failure, preserve the store file and expose durable storage unavailable. Never downgrade, delete, or reopen a V3 store as V2 to recover UI access.
Document the concrete snapshot contract for feat-041 before closing.
