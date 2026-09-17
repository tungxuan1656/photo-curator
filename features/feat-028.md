# feat-028 — Ranker decision gate

## Status

- Status: `todo`
- Depends on: `feat-027`

## Goal

Make a measured, versioned decision to use a learning-to-rank layer or to close V2 with
the deterministic ranker. Either outcome is valid when supported by evidence.

## Contract boundary

The feature owns labels, offline evaluation, acceptance threshold, ranker version,
rollback, and the final product decision. It does not depend on feat-025: specialist
models may be rejected and are not a ranker prerequisite.

## Acceptance

- [ ] Labels and evaluation splits have recorded provenance and no prohibited user data.
- [ ] Candidate ranker demonstrably beats the deterministic baseline on the agreed gates,
  or the no-ranker decision is recorded with the same evidence.
- [ ] Any accepted ranker has explicit version, migration, rollback, and fallback behavior.
- [ ] Final Golden, Real Trip, and 1k gates pass.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Freeze labels, metrics, and the deterministic baseline before evaluating candidates.
2. Evaluate candidate only if the baseline exposes a material remaining gap.
3. Integrate a versioned ranker or record the no-ranker decision and close V2.

## Verify

- Final pipeline manual QA: smoke plus Golden plus Real Trip plus 1k.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: requires feat-027 completion; feat-025 is deliberately optional.
- Next: create the external plan before activation because rollback and product decision are required.
