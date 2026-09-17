# feat-026 — Uncertainty review and feedback

## Status

- Status: `todo`
- Depends on: `feat-023`

## Goal

Expose uncertain selection decisions as clear, reviewable work and capture bounded user
feedback without changing the on-device privacy promise.

## Contract boundary

The feature owns uncertainty thresholds, decision reasons, session state, feedback schema,
and review-flow integration. Implement the presentation component as part of this feature after its view model is fixed.

## Acceptance

- [ ] Uncertain decisions enter a comprehensible Needs review queue with actionable reasons.
- [ ] Feedback capture is bounded, on-device, and does not retain prohibited raw data.
- [ ] Deterministic decisions retain the existing review flow.
- [ ] Manual review QA shows reason, action, recovery, and persistence behavior.

## Relevant docs

- `docs/product-specs/ux-flows.md`
- `docs/ship-gates/privacy.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Define uncertainty and feedback contracts from feat-023 selection outputs.
2. Implement the view component after exact ownership is assigned.
3. Integrate queue, reasons, capture, recovery, and review QA.

## Verify

- Review manual QA: normal, uncertain, unavailable, and recovery paths.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: requires stable feat-023 decision reasons.
- Next: create the external plan before activation because state, selection, and review flow change.
