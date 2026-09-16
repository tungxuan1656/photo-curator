# feat-023 — Global diversity shortlist

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-022`, `feat-024`

## Goal

Use an embedding-backed global shortlist of about 150–250 candidates to balance novelty
and saturation across moments without regressing selection quality or the 1k-photo budget.

## Contract boundary

The parent owns shortlist size, graph construction policy, `DiversitySelector` integration,
selection ordering, fallback, and `engineVersion`. Children do not modify those shared
selection contracts.

## Reserved mini-features

- `mini-023a` — global similarity-graph calculation. Admit after feat-024 locks the
  embedding output and the parent assigns an exclusive new path. Done when it yields a
  bounded candidate graph and explicit unavailable result; parent owns selection policy.

## Acceptance

- [ ] Global novelty and saturation correct the named baseline failures.
- [ ] Candidate graph stays within the approved 150–250 bound and 1k budget.
- [ ] Missing embeddings retain deterministic pre-graph selection behavior.
- [ ] Golden, Real Trip, and 1k manual QA passes.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Lock engine-version and embedding-fallback behavior using feat-024 output.
2. Admit graph calculation only with a non-overlapping source path.
3. Integrate shortlist and diversity policy; validate quality and scale gates.

## Verify

- Pipeline manual QA: smoke plus Golden plus Real Trip plus 1k.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: embeddings are a hard dependency; feat-024 precedes this feat despite ID order.
- Next: create the external plan before activation because selector and engine contracts change.
