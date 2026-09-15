# feat-015 — Flow + screens interaction repair (S01–S20)

## Goal

Fix the verified interaction-only flow/screen defects (stranded sessions, unconfirmed destructive starts, extra interstitial, wrong destinations, dead-end permission states, unreadable controls) without touching engine, scoring, or pipeline logic.

## Scope

- `apps/photo-curator/App/AppModel.swift` (resume snapshot, continue/resume, guarded Start New, `showReview` rewire)
- `apps/photo-curator/App/AppRoute.swift` (delete `.reviewReady`)
- `apps/photo-curator/App/RootView.swift` (delete `.reviewReady` destination, launch resume refresh)
- `apps/photo-curator/App/AppModel+Save.swift` (trim album name at save)
- `apps/photo-curator/Infrastructure/FileStore.swift` (list helper)
- `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift` (`latestCheckpoint()`)
- `apps/photo-curator/Features/Onboarding/HomeView.swift` (Continue card + Start New confirm)
- `apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift` (Dismiss everywhere)
- `apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift` (denied/empty/limited recovery)
- `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` (conditional iCloud line)
- `apps/photo-curator/Features/Processing/ProcessingView.swift` (delete `ReviewReadyView`, pause copy stays in model)
- `apps/photo-curator/Features/Processing/ProcessingModel.swift` (unified pause copy)
- `apps/photo-curator/Features/Review/ReviewOverview.swift` (grid-first entry, stats, unavailable, Discard)
- `apps/photo-curator/Features/Review/CuratedGrid.swift` (real checkmark control, Undo toast copy)
- `apps/photo-curator/Features/Review/SimilarGroups.swift` (real checkmark control, best-pick a11y)
- `apps/photo-curator/Features/Review/RemovedPhotos.swift` (Add copy unify)
- `apps/photo-curator/Features/Review/PhotoDetail.swift` (swipe, load-failure state, a11y)
- `apps/photo-curator/Features/Review/FinalReview.swift` (trimmed-name Save gate)
- `apps/photo-curator/Features/Review/Completion.swift` (partial-context line)
- `apps/photo-curator/Features/Settings/SettingsView.swift` (notDetermined requests permission)

## Non-goals

- No engine, scoring, clustering, threshold, or batch-pipeline changes.
- No new analytics, accounts, sync, sharing, editing, paywall, personalization, or test targets.
- No S12 swap-semantics redesign: the explicit "Choose as best pick" stays; only labels/a11y change (spec deviation recorded).
- No full swipe-back lockdown on S15 beyond what `NavigationStack` allows; duplicate pushes stay harmless via the existing save flight join.

## Acceptance

- [x] Cold start with an unfinished checkpoint/result/save-state shows a Home Continue card; Continue lands on Processing / S09 / S15 correctly; no stranded session.
- [x] Start New over an existing session asks for confirmation with the §4.3 copy; review has a Discard path.
- [x] Processing `completed` → Continue lands directly on S09 (or S15 when an interrupted save exists, or the load-failed state when empty); no `ReviewReadyView` remains.
- [x] S09 primary entry opens the grid first; S05 denied/empty/limited all have working recovery actions.
- [x] S10/S12 selection controls are 44pt icon targets with non-color state; copy uses Selected/Removed vocabulary only.
- [x] S11 supports Previous/Next buttons plus horizontal swipe, announces position and date, and shows retry (never an infinite spinner) on preview failure.
- [x] `./init.sh` passes.

## Relevant docs

- `docs/product-specs/ux-flows.md` (§4 back/discard, §6 home/source/summary, §7 processing, §8 review, §9 save, §10 resume, §11 settings/sheet, §12 empty states, §13 copy/a11y)
- `docs/ship-gates/manual-qa.md` (§5.1 smoke, §5.2 permissions/loading, §5.3 states/cancel/interrupt/review/save)
- `docs/design-docs/data-model.md` (checkpoint/result/feedback/save-state shapes — read only, no shape changes)

## Plan

Plan: `docs/plans/feat-015.md`

1. Resume store seam + snapshot (`FileStore`, `SessionCheckpointStore`, `AppModel`).
2. Home Continue card + Start New confirm + launch refresh (`HomeView`, `RootView`).
3. Review discard + `showReview` rewire + `ReviewReadyView` deletion (`ReviewOverview`, `AppModel`, `AppRoute`, `RootView`, `ProcessingView`).
4. Review entry + S09 stats/unavailable (`ReviewOverview`).
5. Checkmark controls + vocab + Undo copy (S10/S12/S13).
6. S05/S06/S18/S19 recovery + copy conditions.
7. S11 pager/swipe/error/a11y + S14 trim + Completion partial line + pause copy.
8. Close: `./init.sh`, Dataset A device tap-through, feature + progress records.

Task convention: each Task runs `swiftlint` on changed files only; NO `./init.sh` mid-feat; batch the `.pbxproj` edit at feat end.

## Verify

- `./init.sh` once at feat end (+ once before PR)
- Manual Dataset A tap-through: first-run → pick → summary → processing → review (grid/detail/groups/removed/final) → save → completion → Done; Home Continue after kill; denied/limited/empty S05 paths.

## Review

- Single agent, sequential (1 active feat): run self-checklist on every feat with file:line evidence.
- Scoped oracle/escalation ONLY for risky: contracts, Domain/Selection scoring, privacy, performance budgets, export/save.
- Repo checklist: SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only; no persisted pixels/face boxes/locations; 120 cols; copy matches ux-flows; no leftover TODO/mock/Noop; YAGNI (nothing extra).
- 2-3 clean feats = healthy; a miss upgrades self-review rigor.

## Git

- Branch `feat/feat-015` from `main`, code in `owns`, PR squash `feat` → `main`; update `feature_index.json` + `progress.md` in same PR.

## Handoff

- State: done
- Evidence: `./init.sh` PASS 2026-09-15 — `PASS [format] swiftformat .` (2/55 files formatted, 38 skipped), `Done linting! Found 0 violations, 0 serious in 55 files.` / `PASS [lint] swiftlint lint --strict`, `** BUILD SUCCEEDED **` / `PASS [build] xcodebuild -project apps/photo-curator.xcodeproj -scheme photo-curator -configuration Debug -destination 'generic/platform=iOS Simulator' build`, `SKIP [test] no automated tests — manual validation only`; swiftformat touched `AppModel.swift` + `HomeView.swift` (whitespace only, committed here). Simulator smoke (iPhone 17 Pro, iOS 26.5): install + launch PID 83950 no-crash, Home "Photos Curator" + "Curate Photos" renders, no crash/fatal log lines. Code-verified: zero `reviewReady`/`ReviewReadyView` refs; `ResumeSnapshot`/`refreshResumeSnapshot`/`continueResumedSession`/`showReview(for:)` route Continue to Processing/S09/S15; Start New confirm (`confirmingNewSession`, §4.3 copy) + Discard in Processing/S09; S09 "Review Selection" grid-first + stats/unavailable; S05 denied/empty/limited recovery; `SelectionToggle` Selected/Removed vocab; S11 Previous/Next + swipe + position/date a11y + retry state; S14 trim gate + S16 partial line + unified pause copy. Dataset A device tap-through (manual-qa §5.1–§5.3) NOT run — no physical iPhone; user-owned follow-up, no device evidence claimed.
- Blockers: none — device QA is user-owned follow-up, not a code blocker.
- Next: Update `feature_index.json` + `progress.md` and open PR squash `feat(015)` → `main` per Git section.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
