# feat-023 — Global diversity shortlist

## Status

- Status: `todo`
- Depends on: `feat-022`, `feat-024`

## Goal

Use an embedding-backed global shortlist of about 150–250 candidates to balance novelty
and saturation across moments without regressing selection quality or the 1k-photo budget.

## Contract boundary

The feature owns shortlist size, graph construction policy, `DiversitySelector` integration,
selection ordering, fallback, and `engineVersion`. Implementation does not modify those shared
selection contracts.

## Acceptance

- [ ] Global novelty and saturation correct the named baseline failures.
- [ ] Candidate graph stays within the approved 150–250 bound and 1k-photo-scale budget.
- [ ] Missing embeddings retain deterministic pre-graph selection behavior.
- [ ] Golden-shaped, trip-shaped, and 1k-scale reproducible automated evidence passes (Simulator permitted).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`

## Inline plan

1. Lock engine-version and embedding-fallback behavior using feat-024 output.
2. Admit graph calculation only with a non-overlapping source path.
3. Integrate shortlist and diversity policy; validate quality and scale gates.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): smoke plus Golden-shaped plus trip-shaped plus 1k-scale; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: todo
- Evidence: —
- Blockers: embeddings are a hard dependency; feat-024 precedes this feat despite ID order.
- Next: create the external plan before activation because selector and engine contracts change.
