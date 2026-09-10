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

<!-- Bounded (default): 1-3 files, 1 workspace, <200 lines, inline. Split into 2 sequential feats when >=4 files or >=2 workspaces. Substantial (>=4 files or >=2 workspaces, DB migration/breaking API, or needs phases/rollback -> use docs/plans/feat-xxx.md, needs >=2 substantial signals). -->

1. <Step.>
2. <Step.>

Task convention: each Task runs `swiftlint` on changed files only; NO `./init.sh` mid-feat; batch the `.pbxproj` edit at feat end.

## Verify

- `./init.sh` once at feat end (+ once before PR)

## Review

- Classify each Task, then review by risk (never all-oracle, never no-review):
  - Transcription (plan already has exact code): fixer-cheap implementer + fixer-cheap peer (diff-vs-brief).
  - Integration (new logic, multi-file): fixer-mid implementer + fixer-mid peer with repo checklist below.
  - Risky (contracts, Domain/Selection scoring, privacy, performance budgets, export/save): fixer-mid implementer + oracle review, scoped diff-only.
- Repo checklist (every peer review, file:line evidence): SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only; no persisted pixels/face boxes/locations; 120 cols; copy matches ux-flows; no leftover TODO/mock/Noop; YAGNI (nothing extra).
- Oracle per-task is FORBIDDEN except Risky tasks above. Final per-feat: fixer final by default; oracle only when the feat is risky.
- Spot-check: orchestrator sends the riskiest task of each feat to oracle (scoped). 2–3 clean feats in a row = process healthy; a miss upgrades that task class to a stronger reviewer.

## Git

- Branch `feat/<id>` từ `main`, code trong `owns`, PR squash `feat` → `main`; `feature_index.json` + `progress.md` cập nhật trong cùng PR.

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: <One action.>

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
