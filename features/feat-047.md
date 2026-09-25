# feat-047 — Catalog cutover and lifecycle hardening

## Status

- Status: `done`
- Depends on: `feat-046` (done).

## Goal

Make catalog discovery the complete default experience while retaining valid saved work, compatibility recovery, and truthful capability limits. Legacy review/session is compatibility recovery only; there is no new-session entry.

## Scope and ownership

Own the feat-046 prerequisite wiring, persisted-record/reader inventory, aggregate Saved Work recovery, catalog route cutover, derived-only reset behavior, lifecycle/error bounds, and documentation/localization reconciliation.
Remove legacy new-session entry points only after caller and saved-data compatibility review. Retain compatibility readers/routes required by legacy workspace/session, album, and deletion records.
Contracts: [product](../docs/product-specs/product.md), [architecture](../docs/design-docs/ios-architecture.md), [data model](../docs/design-docs/data-model.md), [performance](../docs/ship-gates/performance.md), [privacy](../docs/ship-gates/privacy.md).

## Decision and invariants

- Catalog discovery is the default route and authority for current library browsing, labels, groups, queries, and exact catalog actions.
- Repair the feat-046 prerequisite by wiring `WorkspaceStore.actionContexts` through `AppContainer.live`; Saved Work must aggregate catalog action contexts with legacy workspace/session, album, and deletion recovery.
- Recovery reads persisted exact IDs, revisions, destinations, statuses, and evidence. It never reruns a query, expands a frozen action set, or imports legacy selection as catalog authority; legacy import may restore compatibility workspace state only.
- Reset drains/invalidate workers first, then clears only derived analysis evidence, projections, status, and checkpoints/handoffs. Preserve label definitions, user overrides, personal labels/assignments, legacy workspace choices, catalog action contexts, staging/drafts, and album/deletion evidence.
- Source-verifiable bounds are a 32-asset analysis page, a 2-image comparison batch, one shared two-permit image-work arbiter, and scoped image loading. Device-scale and whole-library capacity remain unmeasured.

## Acceptance

- [x] `WorkspaceStore.actionContexts` is wired through `AppContainer.live`, and Saved Work aggregates unfinished library action contexts plus legacy workspace/session, album, and deletion records without dropping identity, exact sets, destinations, statuses, or per-item evidence.
- [x] Recovery is idempotent and compatibility-only: it does not rerun a query, expand an action set, create a new session, or import legacy selection as catalog authority; legacy readers/routes remain available for existing saved work and operations.
- [x] Catalog discovery is the default entry with no cleanup/album/session prerequisite, and all current organization features are reachable through catalog routes; legacy new-session entry points are removed.
- [x] Reset drains/invalidate workers and rejects late writes before clearing derived analysis evidence, automatic/projection state, analysis status, and checkpoints/handoffs; it preserves labels, overrides, personal labels, legacy workspace choices, catalog action contexts, staging/drafts, and album/deletion evidence.
- [x] New/edited/inaccessible assets, access changes, interrupted jobs, cache loss, schema/migration failure, and unavailable images retain typed, truthful, recoverable states without inferred deletion or automatic mutation retry.
- [x] Source bounds remain visible and enforceable: analysis page 32, comparison image batch 2, shared image-work permits 2, and scoped image lifetime; no device-scale or whole-library capacity claim is made.
- [x] English/Vietnamese copy and owner documentation describe catalog default, compatibility recovery, reset preservation, error states, and unmeasured limits; unsupported legacy new-session behavior is not advertised.
- [x] `./init.sh` passes; no tests/proof harnesses or mandatory manual QA are added.

## Readiness plan

1. Repair the feat-046 dependency seam and inventory all persisted records/readers before route changes.
2. Implement aggregate Saved Work recovery, then drain/invalidate workers and establish derived-only reset boundaries.
3. Cut the default route to catalog discovery while retaining explicit compatibility recovery and removing new-session entry points.
4. Reconcile lifecycle errors, bounds, documentation, and localization; verify with `./init.sh` and `git diff --check`.

See [plan](../docs/plans/feat-047.md).

## Evidence and handoff

- **State:** `done`.
- **Final evidence:** Catalog default; aggregate recovery with no auto-mutation; derived-only reset drain/cache clear; documentation reconciliation.
- **Verification:** Final `./init.sh` PASS (SwiftFormat, strict SwiftLint 0, generic iOS Simulator `BUILD SUCCEEDED`; test skipped per DEC-040); `git diff --check` PASS; final @oracle invariant review APPROVED.
- No tests/proof harnesses or mandatory manual QA were added.
- **Handoff:** Catalog cutover and lifecycle hardening are complete; compatibility recovery remains available for persisted legacy work.
