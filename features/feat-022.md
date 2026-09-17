# feat-022 — Semantic moments

## Status

- Status: `todo`
- Depends on: `feat-021`

## Goal

Build coherent moments from change points and continuity, while retaining a deterministic
fallback for sparse or unavailable semantic evidence.

## Contract boundary

The feature owns `MomentBuilder`, moment boundaries, continuity policy, and fallback.
Calculate boundary evidence inside this feature after its input and output types are fixed.

## Acceptance

- [ ] Change points improve named trip moment boundaries over feat-017 baseline.
- [ ] Continuity avoids over-splitting and respects chronological fallback behavior.
- [ ] Missing semantic facts produce deterministic legacy-compatible grouping.
- [ ] Golden-shaped, trip-shaped, and 1k-scale reproducible automated evidence passes (Simulator permitted).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`

## Inline plan

1. Specify boundary and continuity invariants from the failure ledger.
2. Implement the isolated evidence calculation behind the fixed source path.
3. Integrate moment policy and fallback; record Golden-shaped, trip-shaped, and 1k-scale automated evidence.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): smoke plus Golden-shaped plus trip-shaped plus 1k-scale; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-021 must define stable cluster representatives.
- Next: create `docs/plans/feat-022.md`, then lock the deterministic fallback.
