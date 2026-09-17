# feat-xxx — Feature title

## Status

- Status: `todo` | `active` | `blocked` | `done`

## Goal

<One observable outcome.>

## Scope

- <Included work.>

## Non-goals

- <Excluded work.>

## Acceptance

- [ ] <Concrete condition, provable by reproducible automated evidence.>

## Relevant docs

- `<path>`

## Plan

<!-- Add docs/plans/feat-xxx.md for shared contracts, >=4 files, >=2 workspaces,
phases/rollback, or two independent risk signals. Link it from this feature. -->

1. <Step.>
2. <Step.>

## Verify

- Reproducible automated evidence for every behavior change (Simulator-based proof permitted): record commands, fixtures, and outputs in the handoff.
- `./init.sh` once at feat end (+ once before PR)
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032).
- No test targets, no `*Test*.swift`, no test frameworks.

## Review

- Use an independent reviewer for risky changes; record file:line evidence in the handoff.
- Scoped oracle/escalation ONLY for risky: contracts, Domain/Selection scoring, privacy, performance budgets, export/save.
- Repo checklist: SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only; no persisted pixels/face boxes/locations; 120 cols; copy matches ux-flows; no leftover TODO/mock/Noop; YAGNI (nothing extra).
- 2-3 clean feats = healthy; a miss upgrades self-review rigor.

## Git

- Create branch `feat/<id>` from `main`. Keep implementation, feature state, and
  progress updates together. Squash the feature branch to `main` when done.

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: <One action.>

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
