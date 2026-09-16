# feat-017 — V2 baseline and failure inventory

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-016`

## Goal

Make the current curator measurable before V2 behavior changes. This feature does not
ship a new scoring signal or model.

## Contract boundary

The parent owns the metric ledger, failure taxonomy, and acceptance baselines. Children
may collect independent evidence only; they do not change production scoring or QA gates.

## Reserved mini-features

- `mini-017a` — Golden labels and metric ledger. Admit after the parent fixes the nine
  metric definitions. Done when labels and denominator rules are reviewable.
- `mini-017b` — A-H, Golden, and Real Trip baseline runs. Admit after the ledger exists.
  Done when each result is reproducible and attached to the ledger.
- `mini-017c` — 1k-photo device budget inventory. Admit after the run procedure is fixed.
  Done when time, memory, and thermal observations are recorded.

## Acceptance

- [ ] Nine manual-QA metrics have a baseline, denominator, device, and artifact link.
- [ ] A-H, Golden, and Real Trip failures are classified with candidate V2 remedies.
- [ ] Dataset H is used only for stability and performance claims.
- [ ] No production selection behavior changes.

## Relevant docs

- `docs/ship-gates/manual-qa.md`
- `docs/design-docs/curation-intelligence.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Inline plan

1. Freeze fixture versions, nine metrics, devices, and evidence locations.
2. Admit evidence-only children; merge their ledgers without changing shared QA policy.
3. Consolidate failures into the V2 design document and choose the feat-018 admission gate.

## Verify

- Run the manual baseline procedure in `manual-qa.md` section 4.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-016 is still active.
- Next: finish feat-016, then activate this parent and lock the baseline ledger.
