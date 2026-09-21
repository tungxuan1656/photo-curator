# feat-035 — Album draft and resilient save plan

## Scope and dependency

After feat-034, persist album draft membership independently and save it to an
Apple Photos album. This feature owns album-save state and recovery only; it
does not stage or delete originals. Contracts are in
[review-rules.md](../product-specs/review-rules.md),
[apple-frameworks.md](../design-docs/apple-frameworks.md), and
[data-model.md](../design-docs/data-model.md).

## Anticipated code areas

Existing areas to reshape: `apps/photo-curator/Services/ServiceProtocols.swift`,
`Services/Export/PhotoKitAlbumExporter.swift`,
`Services/Export/SaveState.swift`, `Services/Export/SaveOutcome.swift`,
`App/AppContainer.swift`, `App/AppModel.swift`, `App/AppModel+Save.swift`,
`Features/Review/FinalReview.swift`, `Features/Review/Saving.swift`, and
`Features/Review/Completion.swift`.

Anticipated new areas: `Domain/Models/AlbumSaveOperation.swift` and, only if
the current exporter cannot own reconciliation cleanly,
`Services/Export/AlbumSaveCoordinator.swift`. Update
`Infrastructure/SessionCheckpointStore.swift` only for durable operation
handoff; do not combine it with deletion state. `AlbumSaveOperation` and its
state schema are owned exclusively by feat-035.

## API and safety constraints

Save only the explicit album draft. Use PhotoKit album changes through the
existing service boundary, resolve accessible IDs, and persist operation state
and per-ID outcomes. A partial write is never complete; retry is explicit and
adds only missing IDs. Limited/denied access has a truthful recovery path.
Saving never clears workspace, review progress, album draft, or cleanup
disposition.

Data safety: operation records retain exact draft IDs and per-ID outcomes.
UX safety: partial and limited-access states remain actionable and truthful.
API safety: only the album-save service may call album mutation APIs; it never
shares a mutator with deletion. The operation entity/state must be introduced
through an explicit SwiftData schema migration owned by feat-035; feat-033
must not create or migrate it.

## Work steps

1. Define album operation identity, ordered draft IDs, status, and per-ID
   outcome in the owner data model, including the feat-035 SwiftData schema
   migration and rollback path.
2. Adapt `PhotoKitAlbumExporter` behind the independent save service and make
   repeated resume idempotent against persisted operation state.
3. Wire Final Review, Saving, Completion, and Home resume without changing
   cleanup state.
4. Map authorization, missing/iCloud, duplicate-name, partial, cancellation,
   and interruption outcomes to recoverable UX states.
5. Verify explicit retry never re-adds successful IDs and completed album save
   does not erase the review workspace.

## Validation

Run `./init.sh` after implementation. Do not add tests, test targets, test
files, proof harnesses, or automatic retries. Inspect `git diff --check` and
retain the project's no-test policy evidence from `./init.sh`.

## Rollback and migration

Keep legacy result/checkpoint decoding while new album operations migrate. If
operation state is unreadable, preserve the draft and route to recoverable
review rather than creating a second album. Rollback disables new save resume
only after reconciling known PhotoKit writes; it never alters cleanup or
deletes assets.

## Acceptance mapping

- Independent draft → workspace membership plus feat-035-owned
  `AlbumSaveOperation`.
- Schema evolution → explicit SwiftData migration added and rolled back by
  feat-035, not feat-033.
- Resilient PhotoKit save → exporter/coordinator and per-ID outcomes.
- Truthful partial/retry → SaveState, Saving, Completion, resume paths.
- State preservation → AppModel/checkpoint integration.
- Gate → feature acceptance and `./init.sh` without tests/harnesses.
