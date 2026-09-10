# feat-xxx — Feature title

## Goal

<One observable outcome.>

## Scope

- <Included work.>

## Non-goals

- <Excluded work.>

## Acceptance

- [ ] <Concrete condition.>

## Relevant docs

- `<path>`

## Plan

<!-- Bounded (default): 1-3 files, 1 workspace, <200 lines, inline. Split into 2 sequential feats when >=4 files or >=2 workspaces. Substantial (>=4 files or >=2 workspaces, DB migration/breaking API, or needs phases/rollback -> use docs/plans/feat-xxx.md, needs >=2 substantial signals). Each split result is assessed independently; 4 files alone does not require docs/plans/ (needs >=2 substantial signals). -->

1. <Step.>
2. <Step.>

Task convention: each Task runs `swiftlint` on changed files only; NO `./init.sh` mid-feat; batch the `.pbxproj` edit at feat end.

## Verify

- `./init.sh` once at feat end (+ once before PR)

## Review

- Single agent, sequential (1 active feat): run self-checklist on every feat with file:line evidence.
- Scoped oracle/escalation ONLY for risky: contracts, Domain/Selection scoring, privacy, performance budgets, export/save.
- Repo checklist: SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only; no persisted pixels/face boxes/locations; 120 cols; copy matches ux-flows; no leftover TODO/mock/Noop; YAGNI (nothing extra).
- 2-3 clean feats = healthy; a miss upgrades self-review rigor.

## Git

- Branch `feat/<id>` from `main`, code in `owns`, PR squash `feat` → `main`; update `feature_index.json` + `progress.md` in same PR.

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: <One action.>

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
