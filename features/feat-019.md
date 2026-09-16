# feat-019 — Contextual quality signals

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-018`

## Goal

Route expensive contextual analysis only where feat-017 evidence shows a material need.

## Contract boundary

The parent owns Tier-B eligibility, cache/version behavior, fact schema, and pipeline
wiring. This feature produces raw composition or utility facts only; feat-020 owns the
people/group decision policy.

## Reserved mini-features

- `mini-019a` — composition evidence: saliency, masks, and horizon. Admit after target
  failures and output limits are locked. Done when every unavailable result has fallback.
- `mini-019b` — utility evidence: OCR and document classification. Admit after privacy
  and retention review. Done when text is not persisted beyond allowed derived facts.
- `mini-019c` — experimental smudge, pose, and landmark availability matrix. Admit only
  for a named residual failure. Done with a benchmark-backed accept/reject recommendation.

## Acceptance

- [ ] Tier-B work is bounded, observable, and skipped when its expected value is low.
- [ ] Contextual facts correct named baseline failures and have deterministic fallback.
- [ ] No raw OCR text, masks, landmarks, or face boxes are persisted.
- [ ] A plus Golden QA and the applicable performance budget pass.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/ship-gates/privacy.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Select only baseline-proven contextual needs and lock Tier-B routing inputs.
2. Admit bounded fact/evidence children with exclusive files.
3. Integrate accepted facts, availability, cache/version policy, and manual QA.

## Verify

- Scoring manual QA: A plus Golden; add 1k run if Tier-B is invoked at scale.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-018 must establish universal fallback facts.
- Next: create `docs/plans/feat-019.md`, then define the Tier-B admission threshold.
