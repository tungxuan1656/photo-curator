# feat-036 — Confirmed original deletion

## Status

- Status: `done`.
- Depends on: `feat-035`.

## Goal and acceptance

Add the bounded, explicit original-deletion lane. Acceptance: only a reviewed
exact staged set with a persisted digest, explicit confirmation, and full
Photos read-write access can start; limited access cannot start; a separate
`PhotoDeletionService` persists per-ID outcomes before mutation; interrupted
operations reconcile without automatic retries; PhotoKit/iCloud/Recently
Deleted outcomes and no-immediate-bytes claim are truthful; `./init.sh` passes
without test targets, test files, or proof harness.
Feat-036 owns the deletion operation entity/state and adds it through an
explicit SwiftData schema migration; feat-033 does not own it.

## Relevant docs and plan

Primary owners: [review-rules.md](../docs/product-specs/review-rules.md),
[apple-frameworks.md](../docs/design-docs/apple-frameworks.md),
[privacy.md](../docs/ship-gates/privacy.md), and
[data-model.md](../docs/design-docs/data-model.md). The actionable record is
[docs/plans/feat-036.md](../docs/plans/feat-036.md).

This safety-sensitive feature is complete; its implementation is recorded in
the handoff below.

## Handoff

- State: Done; feat-035 is complete.
- Acceptance: Separate `PhotoDeletionService` and explicit migration; exact
  digest plus full-access gating; durable atomic lifecycle with no automatic
  retry; recovery UI with fresh confirmation for prepared operations and
  read-only reconciliation; truthful en/vi outcome copy.
- Evidence: Final `./init.sh` PASS on 2026-09-23 (SwiftFormat, strict
   SwiftLint, generic Simulator `BUILD SUCCEEDED`, no tests by DEC-040);
  `git diff --check` PASS; Oracle MERGE-READY after the PR review findings.
  Implementation commits: `250b918`, `14bb92f`, `2634b8c`, `5ba07a8`,
  `42bcbbb`, `bdf0530`; follow-up commits: `7eac0b8`, `e21c6ac`, `546ad39`.
- Next: feat-037.
