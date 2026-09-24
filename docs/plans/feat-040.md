# Persistent Photo Catalog Foundation Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. This is a readiness plan; activate only with user approval.

**Goal:** Persist accessible library references independently of selection sessions.

**Architecture:** Add a catalog to the current SwiftData schema while retaining scope and operation entities. Reconcile metadata through committed generations.

**Tech Stack:** Swift 5, SwiftData, PhotoKit service seam, existing file analysis cache.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese UI.
- Preserve all existing scope choices and operation IDs.
- Run `./init.sh`; no test targets, test files, or standalone proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes `PhotoLibraryService.fetchAssets`, domain asset fingerprints, and existing SwiftData V2 state.
Produces catalog metadata snapshots and explicit access/revision states for feat-041.
The record requirements are in [data model](../design-docs/data-model.md#intended-catalog-records).
Concrete schema names are proposed until the first task records their migration design.

## Files and tasks

### 1. Freeze the additive schema

Existing: `apps/photo-curator/Infrastructure/PhotoCuratorSchema.swift`, `WorkspaceStore.swift`, `Domain/Models/PhotoAsset.swift`, `ReviewWorkspace.swift`.
Proposed new: `apps/photo-curator/Domain/Models/LibraryCatalog.swift`, `Infrastructure/LibraryCatalogStore.swift`.

- [ ] Record catalog identities, access states, generation commits, and query projection ownership in the data owner.
- [ ] Add explicit versioned migration without redefining V1/V2 historical shape.
- [ ] Keep user overrides and derived assignments separate; retain per-scope legacy state rather than merging conflicting choices.

### 2. Reconcile metadata

Existing: `apps/photo-curator/Services/Photos/PhotoLibraryPermissionService.swift`, `Services/ServiceProtocols.swift`.

- [ ] Enumerate authorized metadata and upsert by asset ID within a new generation.
- [ ] Commit scan completion before classifying previously indexed assets as no longer accessible.
- [ ] On interruption or permission changes, retain the prior committed snapshot and mark reconciliation incomplete.
- [ ] Invalidate affected derived revisions for edited assets without erasing user state.

### 3. Integrate startup and recovery

Existing: `apps/photo-curator/App/AppContainer.swift`, `AppModel.swift`, `Infrastructure/LegacyWorkspaceImporter.swift`.

- [ ] Open catalog storage at startup alongside existing operation stores.
- [ ] Publish available/loading/unavailable catalog state to future browsing consumers.
- [ ] Preserve old saved-work routes and explicit migration failure recovery.
- [ ] Update the Xcode project only if new files require explicit membership.

## Verification

Run baseline and final `./init.sh` and `git diff --check`.
Inspect identity uniqueness, commit boundaries, partial enumeration, edited assets, access loss, repeat migration, and retained operation IDs.
Record code paths and unmeasured runtime limits; compilation does not demonstrate migration on every existing store.

## Rollback and handoff

Disable catalog entry on failure while retaining the migrated schema and existing recovery services.
Never downgrade or delete a store to recover UI access.
Document the concrete snapshot contract for feat-041 before closing.
