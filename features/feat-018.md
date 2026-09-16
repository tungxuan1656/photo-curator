# feat-018 — Universal quality signals

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-017`

## Goal

Add cheap, universal facts that improve quality decisions without tier-B or model cost.

## Contract boundary

The parent owns `PhotoAnalysis`, cache migration, `analysisVersion`, and pipeline wiring.
Raw facts remain separate from selection weights. No child may edit those shared files.

## Reserved mini-features

- `mini-018a` — universal aesthetics and classification adapter. Admit after the parent
  locks the fact schema and exact new adapter path. Done when request output is bounded
  and unavailable values are explicit.
- `mini-018b` — universal-request cost benchmark. Admit after adapter input is stable.
  Done when cold/warm cost and Quality-of-Service evidence meet the parent budget.

## Acceptance

- [ ] Aesthetics, classification, FeaturePrint policy, and allowed PhotoKit metadata are
  represented with availability and provenance.
- [ ] Persisted per-photo fact changes bump `analysisVersion` and preserve cache safety.
- [ ] A plus Golden manual QA improves the baseline target without performance regression.
- [ ] Fallback is deterministic when a fact is unavailable.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/ship-gates/manual-qa.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Inline plan

1. Use feat-017 failures to select fact fields and establish their version contract.
2. Admit adapter and benchmark children with non-overlapping new files or evidence paths.
3. Integrate facts, cache/version migration, routing, scoring consumers, and manual QA.

## Verify

- Scoring manual QA: A plus Golden.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: requires the feat-017 baseline.
- Next: create `docs/plans/feat-018.md`, lock the universal fact schema, then admit a child.
