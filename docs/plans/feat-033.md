# feat-033 — Durable workspace and migration plan

## Scope and dependency

Implement the durable shared workspace after feat-032 closes and before any
review UI, album save, or deletion lane. The feature owns persistence and
migration only; it does not implement the grouped review shell, PhotoKit
deletion, album-save operation state, or deletion operation state. Contracts
live in [data-model.md](../design-docs/data-model.md),
[ios-architecture.md](../design-docs/ios-architecture.md), and
[review-rules.md](../product-specs/review-rules.md).

## Anticipated code areas

Existing areas to reshape: `apps/photo-curator/App/AppContainer.swift`,
`App/AppModel.swift`, `Infrastructure/FileStore.swift`,
`Infrastructure/SessionCheckpointStore.swift`,
`Services/Session/SelectionSessionCoordinator.swift`, and
`Domain/Models/{SelectionResult,PhotoAnalysis}.swift`.

Anticipated new areas: `Domain/Models/ReviewWorkspace.swift` for
`ReviewScope` and workspace-item state, `Infrastructure/WorkspaceStore.swift`
for the concrete SwiftData container/store, and
`Infrastructure/LegacyWorkspaceImporter.swift` for the idempotent import and
commit marker. Exact names may change only with an owner-doc update; no generic
repository abstraction is planned. `AlbumSaveOperation` and
`PhotoDeletionOperation` are explicitly out of scope and belong to feat-035
and feat-036 respectively.

## Safety and data constraints

SwiftData is limited here to `ReviewScope`, workspace-item choices, and the
migration marker/store. Album-save and deletion operation entities/state are
not part of feat-033; feat-035 and feat-036 add them through their own explicit
SwiftData schema migrations. Analyses, thumbnails, caches, checkpoints, and
model artifacts remain file/cache-backed. Keep cleanup disposition, album
membership, review progress, and immutable facts/suggestions independent.
Legacy `selected`/`restored` maps to album included; `rejected`/`removed` maps
to album excluded; cleanup imports undecided and progress unseen. Retain the
legacy source until the durable migration marker; a crash before it must be
safe to repeat. See the owner docs rather than copying schema details here.

UX safety: migration and restore expose recoverable states without inventing a
user choice. API safety: keep PhotoKit access behind existing services and do
not make SwiftData a photo or image repository. Data safety is governed by the
marker-before-legacy-removal rule above.

## Work steps

1. Freeze the workspace SwiftData schema/version and map each entity to the
   owner doc; do not reserve or define operation schemas.
2. Add the concrete model container/store and scope/workspace CRUD with
   transaction boundaries that preserve all independent dimensions.
3. Add importer discovery, deterministic mapping, validation, and durable
   commit marker; make rerun after a crash idempotent.
4. Adapt composition and session restore to load workspace state while
   retaining existing file/cache stores for derived data.
5. Add migration observability without logging photo IDs or content.
6. Run persistence/restart/migration fault scenarios using production code
   paths only; do not create a test or proof harness.

## Validation

Run `./init.sh` after implementation. Also run the repository's assigned
format/lint/build checks through that command and inspect `git diff --check`.
No test target, `*Test.swift`, test framework, or standalone proof file may
be added. Compilation does not establish image quality or device fit.

## Rollback and migration

The importer is one-way and idempotent. Never delete legacy files before the
commit marker. If the new schema cannot load, keep legacy data and route to a
recoverable migration state; do not infer deletion or progress. Rollback of
the feature must disable new workspace reads without removing legacy data and
must preserve already-committed operation records for later reconciliation.

## Acceptance mapping

- Durable scope/workspace state → SwiftData entities/store and round-trip restore.
- File/cache boundary → existing cache/checkpoint/file services remain owners.
- Legacy mapping → importer, marker, crash-repeat and no-legacy-delete paths.
- Operation schemas → explicitly excluded; feat-035 owns album save and
  feat-036 owns deletion through separate SwiftData schema migrations.
- Choice preservation → workspace transaction and coordinator restore review.
- Gate → feature acceptance plus `./init.sh` and no-test policy.
