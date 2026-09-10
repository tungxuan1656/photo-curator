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

- Self-review + peer fixer review (diff-only) mỗi task, CẤM oracle per-task. Oracle chỉ final khi chạm contracts/Domain-Selection/privacy/perf/export.

## Git

- Branch `feat/<id>` từ `main`, code trong `owns`, PR squash `feat` → `main`; `feature_index.json` + `progress.md` cập nhật trong cùng PR.

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: <One action.>

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
