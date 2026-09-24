# Catalog Cutover and Lifecycle Hardening Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Activate only after feat-046 and user approval.

**Goal:** Complete the organization-first default flow and retain recoverable historical user work.

**Architecture:** Cut active entry over to catalog discovery after all consumers exist. Retire only proven obsolete selection-session callers; keep migration and operation readers required by saved data.

**Tech Stack:** Existing SwiftUI app, catalog/services, SwiftData migrations, file cache/checkpoint recovery.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese.
- No inferred deletion, lost overrides, or erased unresolved operation state.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes completed feat-040–046 contracts and actual integration evidence.
Produces the default organization route, documented compatibility boundaries, and current owner docs matching shipped capabilities.

## Files and tasks

### 1. Audit and cut over routes

Existing: `apps/photo-curator/App/AppModel.swift`, `AppModel+ReviewEntry.swift`, `AppRoute.swift`, `RootView.swift`, `AppContainer.swift`, `Features/Onboarding/HomeView.swift`.

- [ ] Trace active `SelectionResult`, `ReviewIntent`, and session coordinator callers before removal.
- [ ] Make catalog discovery the default without an album/cleanup intent prerequisite.
- [ ] Keep Saved Work entries for migrated drafts, staging, and unresolved operations.
- [ ] Remove dead active branches only after verifying compatibility readers do not depend on them.

### 2. Close lifecycle and reset gaps

Existing: `apps/photo-curator/Features/Settings/SettingsView.swift`, `Infrastructure/FileAnalysisCache.swift`, `LegacyWorkspaceImporter.swift`, `MemoryPressureObserver.swift`.
Also own new catalog/coordinator files introduced by earlier pivot features.

- [ ] Make Reset Analysis invalidate derived evidence/projections while preserving user labels, overrides, and operations.
- [ ] Reconcile app foreground, new/edited photos, changed permissions, cache loss, and interrupted catalog generations.
- [ ] Review bounded candidate work, query pagination, projection rebuild cost, and image lifetime against performance contracts.
- [ ] Document unmeasured device/scale behavior without claiming whole-library performance from a Simulator build.

### 3. Reconcile shipped documentation

Own `README.md`, current `docs/` owners, `apps/photo-curator/Localizable.xcstrings`, `InfoPlist.xcstrings`, and relevant privacy manifest declarations.

- [ ] Replace planned type/status descriptions with observed implementation evidence where features actually landed.
- [ ] Verify all supported labels/states have en/vi copy and unsupported labels are not advertised.
- [ ] Remove obsolete active owner routes while retaining labeled history.
- [ ] Update `init.sh` only if actual verification commands/workspace modules changed.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Review catalog-to-group-to-detail, label-to-filter-to-action, legacy recovery, access changes, reset, and interrupted mutations end to end in source.
Record observed runtime evidence only when actually collected; no mandatory manual QA or invented accuracy claim.

## Rollback and handoff

Preserve the latest supported schema and recovery entry when disabling new discovery routes.
Do not roll back to a binary that cannot read the migrated schema.
Close only after all feature acceptance items and final verification pass; record concrete remaining limits and one next action if needed.
