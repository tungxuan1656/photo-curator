# feat-033 — Durable workspace and migration

## Status

- Status: `done` — Gate 2 final attempt 3 GO; historical attempts 1 and 2 and their remediations remain recorded below.
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

The implementation is complete within the dependency and plan scope. Existing
review routes and file/cache ownership remain unchanged; startup performs the
additive import before the existing resume probe. No current blockers remain.

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
- `WorkspaceStore.swift` offers general scope create/list/load APIs and
  independent per-dimension update APIs. Cleanup, album, progress, and analysis
  dimensions remain isolated; scope timestamps update atomically with item
  creation or mutation.
- `LegacyWorkspaceImporter.swift` records explicit status for present legacy
  artifacts, blocks the migration marker on unreadable artifacts, records a
  recoverable failure, and retains legacy files until a safe marker commit.
- Workspace initialization has a non-crashing unavailable-workspace fallback
  that preserves the legacy flow/files and skips migration. Diagnostics use
  stable non-sensitive log categories.
- `AppContainer`, `PhotoCuratorApp`, and `AppModel.startup()` wire one store and
  startup import without changing routes or existing file/cache use. No UI
  routes were added, and feat-035/036 operation schemas remain out of scope.

## Gate 2 attempts — historical evidence

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

Attempt 1 was a prior docs-only stop; its source remediation was not performed
in that session. The findings were subsequently remediated before final
closure.

### Attempt 2 — BLOCKED

Attempt 2 additionally identified raw error logging that needed stable,
non-sensitive categories and required `ReviewScope.updatedAt` to be updated in
the same transaction as workspace-item creation or dimension mutation. Both
findings were remediated before final closure.

### Final attempt 3 — GO

Oracle Gate 2 final attempt 3 returned GO after the attempt 1 and attempt 2
findings were remediated. The accepted result includes safe artifact
status/marker gating, unavailable-workspace legacy fallback, general scope/item
APIs with dimension isolation, stable log categories, and atomic scope
timestamp updates.

## Verification

- Historical initial implementation verification (partial evidence before Gate 2):
  `swiftformat .` passed; `swiftlint lint --strict` passed with 0 violations;
  `./init.sh` passed with a generic Simulator build and tests skipped under the
  repository no-test policy; `git diff --check` passed.
- Final source-fixer evidence: `./init.sh` passed with format, strict lint,
  generic Simulator build, and tests skipped under DEC-040; `git diff --check`
  passed. Oracle Gate 2 final attempt 3 returned GO. No current blockers.
