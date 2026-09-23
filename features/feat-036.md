# feat-036 — Confirmed original deletion

## Status

- Status: `active`.
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

This safety-sensitive feature is unblocked by completed feat-035; no code is
claimed in this tracker activation.

## Handoff

- State: Active; feat-035 is complete and the existing scope and acceptance
  remain unchanged.
- Baseline: `./init.sh` PASS on 2026-09-23; validation is owned by the parent
  coordinator.
- Next: Implement and verify the core deletion lane, including its operation
  state, migration, service, and reconciliation boundaries.
