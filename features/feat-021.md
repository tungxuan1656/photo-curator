# feat-021 — Variant-aware clustering

## Status

- Status: `todo`
- Depends on: `feat-020`

## Goal

Keep perceptually similar but semantically different photos from collapsing into one
cluster, then select representatives by the moment context.

## Contract boundary

The feature owns cluster membership, representative contract, and any change to
`DuplicateResolver` or `SelectionGrouping`. Calculate coherence evidence inside this feature.

## Acceptance

- [ ] Semantic variation resists transitive union-find collapse in named cases.
- [ ] Representative scoring uses context rather than only pairwise similarity.
- [ ] Existing duplicate removal behavior stays deterministic when evidence is missing.
- [ ] B plus Golden QA passes.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Convert baseline collapse cases into explicit cluster invariants.
2. Implement the evidence calculator after its contract is fixed.
3. Integrate resolver and representative changes, then run cluster QA.

## Verify

- Cluster manual QA: B plus Golden.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-020 establishes people-context policy.
- Next: create `docs/plans/feat-021.md`, then choose the first collapse cases.
