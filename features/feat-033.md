# feat-033 — Durable workspace and migration

## Status

- Status: `blocked` — Gate 2 attempt 1 BLOCKED on 2026-09-21; source implementation is partial and this docs-only session performed no remediation.
- Depends on: `feat-032`.

## Goal and acceptance

Implement the durable shared workspace and one-way legacy import without
changing user choices. Acceptance: SwiftData stores only `ReviewScope`,
workspace-item state, and the migration marker/store for this feature;
album-save and deletion operation entities/state are explicitly owned by
feat-035 and feat-036 through their own SwiftData schema migrations. Analyses,
thumbnails, caches, checkpoints, and model artifacts stay in appropriate
files/cache; independent dimensions round-trip;
legacy selected/restored and rejected/removed mappings are exact; all cleanup
imports undecided and progress unseen; migration is idempotent and retains the
legacy source until a durable commit marker; `./init.sh` passes with no test
targets, test files, or proof harness.

## Relevant docs and plan

Primary owners: [data-model.md](../docs/design-docs/data-model.md),
[ios-architecture.md](../docs/design-docs/ios-architecture.md),
[review-rules.md](../docs/product-specs/review-rules.md), and
[privacy.md](../docs/ship-gates/privacy.md). The actionable implementation
record is [docs/plans/feat-033.md](../docs/plans/feat-033.md). Define concrete
entities and rollback before coding; do not introduce a generic repository
abstraction.

The source implementation is partial within the dependency and plan scope.
Existing review routes and file/cache ownership remain unchanged; startup
performs the additive import before the existing resume probe. Gate 2 remains
blocked by the findings below.

## Activation handoff

Start with the linked [feat-033 plan](../docs/plans/feat-033.md). Own only
`ReviewScope`, workspace-item state, migration marker/store infrastructure, and
legacy importer. Album-save and deletion operation schemas remain reserved for
feat-035 and feat-036 with their own SwiftData migrations.

## Implementation handoff

- `ReviewWorkspace.swift` defines the three owned SwiftData models and the
  independent cleanup, album, and progress dimensions.
- `WorkspaceStore.swift` owns one concrete actor-backed `ModelContainer` and
  value snapshots; it does not define a generic repository or operation state.
- Remaining acceptance work, separate from the Gate 2 safety blockers below:
  `WorkspaceStore.swift` must offer general scope create/list/load APIs and
  independent per-dimension update APIs. No current review route must consume
  them yet.
- `LegacyWorkspaceImporter.swift` maps legacy result/feedback records
  additively and attempts to commit a durable marker after discovery. Gate 2
  found that unreadable present artifacts can be skipped by the current
  discovery path.
- `SessionCheckpointStore.swift` exposes narrow read-only legacy artifact
  discovery for the importer, but its current decode result does not preserve
  per-present-artifact failure status.
- `AppContainer`, `PhotoCuratorApp`, and `AppModel.startup()` wire one store and
  startup import without changing routes or existing file/cache use. The current
  container-open failure is fatal; Gate 2 requires the non-crashing replacement.

## Gate 2 attempt 1 — BLOCKED

### Changed source paths

The partial implementation changed these exact source paths:

- `apps/photo-curator/Domain/Models/ReviewWorkspace.swift`
- `apps/photo-curator/Infrastructure/WorkspaceStore.swift`
- `apps/photo-curator/Infrastructure/LegacyWorkspaceImporter.swift`
- `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift`
- `apps/photo-curator/App/AppContainer.swift`
- `apps/photo-curator/App/AppModel.swift`
- `apps/photo-curator/PhotoCuratorApp.swift`

### Exact blockers and required remediations

1. In `LegacyWorkspaceImporter.swift` and
   `SessionCheckpointStore.swift`, a present but unreadable checkpoint, result,
   or feedback artifact can be silently skipped, after which the global
   migration marker can be committed. Required remediation: expose explicit
   per-present-artifact decode status, block marker commitment, and record a
   recoverable failure.
2. In `AppContainer.swift`, opening the workspace `ModelContainer` uses
   `preconditionFailure` on failure. Required remediation: provide a
   non-crashing workspace-unavailable composition state that preserves the
   legacy flow/files and skips migration.

No source remediation was performed in this docs-only stop.

## Verification

- Initial implementation verification (partial evidence before Gate 2):
  `swiftformat .` passed; `swiftlint lint --strict` passed with 0 violations;
  `./init.sh` passed with a generic Simulator build and tests skipped under the
  repository no-test policy; `git diff --check` passed.
- Gate 2 attempt 1 is BLOCKED by the two findings above. No final `./init.sh`
  result is claimed after this docs-only update.
