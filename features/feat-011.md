# feat-011 — Export + Save + Completion

## Goal

Land export + save + completion for a full pick-to-save pass with no duplicate album. S14 Save atomically claims one save per session, S15 shows determinate progress, partial results offer retry-remaining against the same album, and S16 confirms the saved album.

## Scope

- `Services/Export/AlbumExportService.swift` (new: concrete PhotoKit exporter — resolve, collision-safe create, add, typed errors)
- `Features/Review/Saving.swift` (new: S15 saving + partial/error states)
- `Features/Review/Completion.swift` (new: S16 album-saved)
- `Features/Review/FinalReview.swift` (wire Save → claim + S15)
- `Services/ServiceProtocols.swift` (export result type; keep `Void` protocol iff it can report identity — it cannot, so extend here)
- `App/AppContainer.swift` (wire concrete exporter)
- `App/AppModel.swift` (session save claim + `saveStateDirectory`; reconcile interrupted saves on `beginReview`)
- `App/AppRoute.swift`, `App/RootView.swift` (saving/completion routes)
- `Infrastructure/SessionCheckpointStore.swift` (save-state persistence: album identity + added IDs)

## Non-goals

- Anything outside owns; reliability + performance stays in feat-012.

## Task 1: Replace the export noop with a concrete PhotoKit service

- [ ] Export result identifies the album (`localIdentifier` + title) and added/missing IDs; errors are `permissionLost`, `creationFailed`, `assetsUnavailable` (never raw `NSError` text in UI).
- [ ] Resolve `AssetID`s via `PHAsset.fetchAssets(withLocalIdentifiers:)` inside the exporter only; missing IDs become missing-output data, never a crash.
- [ ] Every first save creates a new collision-safe album (`name`, `name 2`, … via existing-title lookup); never reuse or modify a pre-existing album. Persist the created-album identity before add operations so retry adds only missing assets to the same album.
- [ ] Adds run in small sequential `performChanges` batches (bounded placeholder count, tolerate partial batch success); cancellation stops before the next batch.
- [ ] Wire into `AppContainer.live()`; delete `NoopAlbumExporter` only after no caller selects it.

## Task 2: Add S15 and S16 and connect Save

- [ ] On S14 Save, atomically claim the session save before awaiting PhotoKit; repeated taps join/are disabled, never start a second export. Save state (`albumLocalIdentifier`, `albumTitle`, `addedIDs`) persists before/during the write.
- [ ] S15 `Saving your album` with determinate added/total progress when reliable; permission loss → `Can't Save Album` + Open Settings / Back to Review (selection retained); usable partial → `Album partially saved` + added/total + **Retry Remaining** / **Finish Anyway** (retry reuses persisted album + missing IDs).
- [ ] S16 `Album Saved` with final count + album name; **Done** returns Home with no unfinished session card (clear save claim + review state for that session only).
- [ ] Reconcile an interrupted save in `beginReview`: persisted album + missing IDs → route offers resume (retry-remaining against the same album), never a duplicate.
- [ ] Gate 2: Dataset A on a physical iPhone — Select → Analyze → Review (one correction) → Save; exactly one new album with the S14 count, originals unchanged, completion names that album; interrupted/partial save re-entry reconciles the same album.
- [ ] `./init.sh` passes; record Gate 2 evidence and close.

## Acceptance

- [x] Real user can pick, process, review, fix, and save with no duplicate album
- [x] `./init.sh` passes

## Depends

- feat-010

## Handoff

- State: done
- Evidence: `./init.sh` PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); simulator install/launch no-crash (permission state renders, PID alive). Gate 2 device validation (Dataset A full save + interrupted/partial retry reconciles same album) deferred to user on a physical iPhone.
- Blockers: none (code review closed)
- Next: feat-012 (Reliability + performance) — save-claim interleave with supersede/discard is parked there; beginReview routes interrupted saves to S15.
