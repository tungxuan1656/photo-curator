# feat-020 — People and group selection

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-019`

## Goal

Choose group photos using per-face quality distribution and protect the weakest relevant
face without retaining sensitive raw face data.

## Contract boundary

Feat-019 supplies raw, ephemeral facts. This parent owns aggregation, candid guards,
selection policy, explanations, and privacy review.

## Reserved mini-features

- `mini-020a` — group evidence calculator. Admit after the aggregation inputs and exact
  new file are locked. Done when it returns derived, non-persisted distributions for the
  parent to consume and documents its unavailable case.

## Acceptance

- [ ] Per-face distribution and weakest-face protections resolve the named group failures.
- [ ] Candid guards do not discard valid non-portrait moments.
- [ ] No face boxes, landmarks, or pixels are persisted in analysis or diagnostics.
- [ ] B plus Golden manual QA passes with reviewable selection reasons.

## Relevant docs

- `docs/product-specs/selection-rules.md`
- `docs/ship-gates/privacy.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Lock group evidence inputs and privacy limits with feat-019 outputs.
2. Admit the isolated calculator if its path is exclusive.
3. Integrate policy, reasons, review surfaces, and B plus Golden QA.

## Verify

- Cluster/people manual QA: B plus Golden.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-019 owns contextual fact availability.
- Next: create `docs/plans/feat-020.md`, then map baseline people failures to section 10.
