# feat-035 — Album draft and resilient save

## Status

- Status: `done`.
- Depends on: `feat-034` (done).

## Goal and acceptance

Persist album draft membership independently from cleanup, then save it
resiliently to a Photos album. Acceptance: explicit save creates or resumes a
collision-safe album write without duplicate additions; partial outcomes are
truthful and retry only by explicit user action; save interruption reconciles;
save never clears the workspace or cleanup disposition; limited access reports
the correct recovery path; `./init.sh` passes without test targets, test files,
or proof harness. Feat-035 owns the album-save operation entity/state and adds
it through an explicit SwiftData schema migration; feat-033 does not own it.

## Relevant docs and plan

Primary owners: [review-rules.md](../docs/product-specs/review-rules.md),
[ux-flows.md](../docs/product-specs/ux-flows.md),
[apple-frameworks.md](../docs/design-docs/apple-frameworks.md), and
[data-model.md](../docs/design-docs/data-model.md). The actionable record is
[docs/plans/feat-035.md](../docs/plans/feat-035.md).

## Implementation and verification

- New `Domain/Models/AlbumSaveOperation.swift` (feat-035 owner): `AlbumSaveStatus`
  (`prepared/executing/needsReconciliation/completed/partial/failed/cancelled`),
  durable `@Model AlbumSaveOperation` (session/scope IDs, ordered draft IDs,
  canonical SHA-256 digest over sorted IDs + schema v1, status, album identity,
  per-ID added/missing outcomes, timestamps), plus value snapshot with
  `remainingIDs`. No deletion state; no pixels/faces.
- New `Infrastructure/AlbumSaveOperationStore.swift`: SwiftData load/upsert/
  update/delete over the shared workspace container; absent rows are idempotent
  success; save failure retries on next mutation, never claimed saved.
- New `Services/Export/AlbumSaveService.swift`: independent save boundary and
  only caller of album mutation APIs. Persists `prepared` digest before any
  PhotoKit call; same digest + scope resumes the same album and adds only
  remaining IDs; changed draft starts fresh; interruption/cancel marks
  `needsReconciliation`; terminal mapping is saved/partial/failed truthfully
  with explicit-only retry. Guards denied/restricted via the permission
  service; limited stays valid with Choose More recovery in S15.
- `App/AppContainer.swift`: explicit SwiftData schema migration — workspace
  `ModelContainer` now opens with `AlbumSaveOperation` alongside the feat-033
  models (additive; scope/item/marker rows reopen untouched). Rollback removes
  the model from the list; unresolved operations fall back to the file
  `SaveState` handoff and recoverable review. Wires `albumOperations` +
  `albumSaveService`; nil when workspace storage is unavailable.
- `App/AppModel+Save.swift`: `saveAlbum`/`retryRemainingSave` route through
  the durable service with session claim-once flights intact; mirrors the
  display state into the legacy file handoff for interruption safety;
  `savedAlbum`/`hasInterruptedSave` prefer the operation with legacy fallback.
  Save never clears workspace, draft, progress, or cleanup. New
  `App/LegacySaveFlow.swift` holds the pre-035 file-backed resume/outcome plus
  the moved `PersistLatest` hook (unavailable-workspace path only).
- `App/AppModel.swift`: `deleteSessionData` retires the session operation row
  alongside scope/item/file deletes; `deleteCheckpointFiles`/`deleteOne` split
  keeps lint budgets with the same all-attempted/idempotent rule.
- S14/S15/S16 (`FinalReview`/`Saving`/`Completion`): owner en/vi copy only —
  save disclosure ("Saving an album does not change your cleanup choices."),
  access-check line, truthful partial/interrupted/failed states, `Retry Missing
  Photos`, `Get Full Photos Access to Save`, limited Choose More recovery.
  Added 5 catalog entries en/vi; no untranslated fallback strings.
- Verification: `./init.sh` PASS (SwiftFormat PASS, `swiftlint --strict` 0
  violations, generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
  `git diff --check` PASS. No test targets, test files, or proof harness.
