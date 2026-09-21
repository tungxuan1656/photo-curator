# feat-033 — Durable workspace and migration

## Status and scope

- Status: `done`; depends on `feat-032`.
- Owns `ReviewScope`, `WorkspaceItem`, migration marker, concrete SwiftData store,
  legacy importer, and startup composition.
- Album/deletion operation schemas belong to feat-035/036. Existing review
  routes remain file/checkpoint-backed until feat-034.

## Owners and readiness plan

Read [data model](../docs/design-docs/data-model.md),
[architecture](../docs/design-docs/ios-architecture.md),
[review rules](../docs/product-specs/review-rules.md), and
[privacy](../docs/ship-gates/privacy.md).
The completed implementation plan is [feat-033](../docs/plans/feat-033.md).

## Acceptance and implementation handoff

- `Domain/Models/ReviewWorkspace.swift` defines the three owned SwiftData models.
- `Infrastructure/WorkspaceStore.swift` exposes scope/item create/list/load and
  independent cleanup, album, and progress mutations. Scope/item timestamps
  update in the same transaction; value snapshots cross actor boundaries.
- `Infrastructure/SessionCheckpointStore.swift` discovers legacy artifacts;
  `Infrastructure/LegacyWorkspaceImporter.swift` blocks marker commitment on
  unreadable present artifacts and retains legacy files for safe retry.
- Selected/restored imports included; rejected/removed imports excluded.
  Cleanup imports undecided and progress unseen. Repeated import is idempotent.
- `App/AppContainer.swift`, `App/AppModel.swift`, and `PhotoCuratorApp.swift`
  compose startup. Unavailable workspace storage skips migration and preserves
  the legacy flow. Diagnostics use stable, non-sensitive categories.
- Analyses, thumbnails, caches, checkpoints, and model artifacts remain outside
  SwiftData product state. Paths above are relative to `apps/photo-curator/`.

## Verification and next action

Final source verification: `./init.sh` PASS (format, strict lint, generic
Simulator build; tests skipped under DEC-040), `git diff --check` PASS.
Gate 2 attempt 3: GO. Earlier findings and their resolution are retained in
[progress.md](../progress.md); no current blocker remains.

Next: feat-034 can bind shared review to these APIs after user approval.
