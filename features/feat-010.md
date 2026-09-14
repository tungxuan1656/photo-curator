# feat-010 — Review groups + removed + final

## Goal

Land review groups + removed + final so S12/S13/S14 swap and add-back work on a real result. One session-owned `ReviewModel` stays the single source of truth shared by grid, detail, groups, removed, and final review; edits persist as `SelectionFeedback` for the session and never rerun the engine.

## Scope

- `Features/Review/ReviewModel.swift` (all-surfaces state: selected/removed/groups/order + swap/remove/restore + feedback snapshot + album-name draft)
- `Features/Review/SimilarGroups.swift` (new: S12)
- `Features/Review/RemovedPhotos.swift` (new: S13)
- `Features/Review/FinalReview.swift` (new: S14; Save execution stays feat-011)
- `Features/Review/ReviewOverview.swift` (S09 entries for S12/S13/S14)
- `Features/Review/CuratedGrid.swift` (S10 over curated subset only)
- `App/AppModel.swift` (feedback reload in `beginReview` + feedback cleanup)
- `App/AppRoute.swift`, `App/RootView.swift` (S12/S13/S14 routes)
- `Infrastructure/SessionCheckpointStore.swift` (feedback save/load/delete)
- `Domain/Models/SelectionResult.swift` (string-keyed Codable for `SelectionFeedback.swapWinner` only)

## Non-goals

- Export + save execution, S15/S16 (feat-011); engine rerun; reliability + performance (feat-012).

## Task 1: Session-owned review state for all correction surfaces

- [ ] Init from both `selectedAssetIDs` and `rejectedAssetIDs` in chrono order; `displayIDs` covers all live result IDs (S13 needs rejected assets). S10 keeps dim-don't-shift via a `curatedDisplayIDs` query (engine-selected ∪ currently selected).
- [ ] Derive each similar group from decisions with `nearDuplicate` / `nearDuplicateRepresentative`, using `competingIDs[0]` as the winner relation; group ID via `StableSelectionID` (`kind: "cluster"`) so surviving sets match engine cluster IDs. Skip members/groups with no live `sourceByID` photo; hide groups with <2 live members.
- [ ] `selectWinner` inserts the new pick and removes the prior representative (extras the user added stay selected); record `swapWinner` + removed/restored sets; no-op when tapping the current winner.
- [ ] Persist `SelectionFeedback` at every semantic edit (fire-and-forget full snapshot); reload it in `beginReview` and rebuild selection as `(engineSelected − removed + restored) ∩ live`; swap pointers re-applied idempotently. Never rerun the engine.
- [ ] Delete feedback alongside checkpoint + result in session cleanup.

## Task 2: S12, S13, S14 routes and views

- [ ] Routes `.similarGroups/.removedPhotos/.finalReview(sessionID:)` guarded on matching `reviewModel` in `RootView`; S09 entries for all three, Similar entry only when groups exist.
- [ ] S12: per-group `Recommended best pick` badge (engine winner), alternatives with included state, `N selected from M similar photos`, `Group i of N` progress, `Similar photos reviewed` + `Back to Review` at the end. Tap alternative → `selectWinner`.
- [ ] S13: lazy grid over `removedIDs` with reassurance copy, per-photo `Add` (= `restore`, immediate), neutral placeholder on thumbnail failure (existing `AsyncPhotoThumbnail`), `Nothing removed` empty state, `Back to Review`.
- [ ] S14: `N photos ready`, bounded thumbnail preview (≤4), editable album name (default `Curated Photos`), exact note `Your original photos will not be changed.`, `Back to Review`; Save disabled + `Add at least one photo to save this album.` when zero. Save action wiring stays feat-011 (TODO at the call site).
- [ ] Gate 1: on a physical iPhone with a completed real result — swap a similar winner, add back a removed photo, open S14, confirm count + set consistent across S10/S12/S13/S14 (incl. back navigation).
- [ ] `./init.sh` passes; record Gate 1 evidence and close before cutting feat-011.

## Acceptance

- [x] S12/S13/S14 swap and add-back work on real result
- [x] `./init.sh` passes

## Depends

- feat-009

## Handoff

- State: done
- Evidence: self-review + `./init.sh` PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); simulator install/launch no-crash (S02 permission state renders, PID alive). Gate 1 device tap-through (swap winner + add-back + S14 consistency across S10/S12/S13/S14) deferred to user on a physical iPhone with a completed real result.
- Blockers: none (code review closed)
- Next: feat-011 (Export + Save + Completion) — S14 Save button is a TODO placeholder; concrete exporter + S15/S16 pending.
<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
