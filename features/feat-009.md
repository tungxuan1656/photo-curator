# feat-009 — Review core on real result (overview/grid/detail)

## Goal

Land Review core on real result so S09/S10/S11 are operable.

## Scope

- `Features/Review/ReviewModel.swift` (new: session-owned selection state)
- `Features/Review/ReviewOverview.swift` (new: S09 counts + entry)
- `Features/Review/CuratedGrid.swift` (new: S10 lazy grid + Undo)
- `Features/Review/PhotoDetail.swift` (new: S11 local pager + bounded preview)
- `App/AppModel.swift` (reviewModel + beginReview)
- `App/AppRoute.swift` (reviewOverview + curatedGrid routes)
- `App/RootView.swift` (guarded routing + load-failed state)
- `Features/Processing/ProcessingView.swift` (Continue → beginReview + zero-pick state)
- `Services/ServiceProtocols.swift` (preview entry point)
- `Services/Photos/ImageLoaderService.swift` (bounded 2048px preview)

## Non-goals

- Groups, removed browsing, final review, export (feat-010/011); engine rerun or edit persistence.

## Acceptance

- [ ] S09/S10/S11 operable on real result
- [ ] `./init.sh` passes

## Depends

- feat-008
## Plan

Plan: `docs/plans/feat-009.md`

## Handoff

- State: active
- Evidence: baseline ./init.sh PASS on feat-008 HEAD (2026-09-14; format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test])
- Blockers: none
- Next: Task 1 — create ReviewModel.
