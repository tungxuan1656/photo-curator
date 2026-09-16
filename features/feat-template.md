# feat-xxx — Feature title

## Status and kind

- Status: `todo` | `active` | `blocked` | `done`
- Kind: `integration` | `mini`
- Parent: required for `mini`; omit for `integration`.
- Seam: required for `mini`; state the one independently mergeable responsibility.
- Exclusive owns: required for `mini`; list only files the child may edit or create.
- Merge gate: required for `mini`; state what the integration owner must verify before merge.

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

<!-- Every parent begins with a readiness plan here. Before activating an integration
feature, add docs/plans/feat-xxx.md for shared contracts, >=4 files, >=2 workspaces,
phases/rollback, or two independent risk signals. A mini-feature stays inline. -->

1. <Step.>
2. <Step.>

For an integration feature, reserve mini IDs here with a one-purpose seam, admission
condition, and completion evidence. Materialize a child from `mini-feat-template.md`
only after the parent locks its exact files.

## Verify

- `./init.sh` once at feat end (+ once before PR)

## Review

- Independent reviewer for every merged mini-feature and integration feature; record
  file:line evidence in the handoff.
- Scoped oracle/escalation ONLY for risky: contracts, Domain/Selection scoring, privacy, performance budgets, export/save.
- Repo checklist: SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only; no persisted pixels/face boxes/locations; 120 cols; copy matches ux-flows; no leftover TODO/mock/Noop; YAGNI (nothing extra).
- 2-3 clean feats = healthy; a miss upgrades self-review rigor.

## Git

- Parent: branch `feat/<id>` from `main`; mini: branch `mini/<id>` from the active
  parent. The integration owner alone updates shared contracts, feature index, and
  progress. Merge child PRs into the parent after their merge gate; squash the parent
  PR to `main` when done.

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: <One action.>

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
