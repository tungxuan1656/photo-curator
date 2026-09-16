# feat-022 — Semantic moments

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-021`

## Goal

Build coherent moments from change points and continuity, while retaining a deterministic
fallback for sparse or unavailable semantic evidence.

## Contract boundary

The parent owns `MomentBuilder`, moment boundaries, continuity policy, and fallback.
Any child may calculate boundary evidence only after the parent freezes its input/output
types and assigns an exclusive new file.

## Reserved mini-features

- `mini-022a` — moment boundary evidence calculator. Admit after representative and
  cluster inputs are stable. Done when it produces bounded evidence for the named trip
  cases and leaves all boundary policy to the parent.

## Acceptance

- [ ] Change points improve named trip moment boundaries over feat-017 baseline.
- [ ] Continuity avoids over-splitting and respects chronological fallback behavior.
- [ ] Missing semantic facts produce deterministic legacy-compatible grouping.
- [ ] Golden, Real Trip, and 1k smoke evidence pass.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/selection-rules.md`
- `docs/ship-gates/manual-qa.md`

## Inline plan

1. Specify boundary and continuity invariants from the failure ledger.
2. Admit the isolated evidence calculation only if its source path is exclusive.
3. Integrate moment policy and fallback; record Golden, Real Trip, and 1k evidence.

## Verify

- Pipeline manual QA: smoke plus Golden plus Real Trip plus 1k.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-021 must define stable cluster representatives.
- Next: create `docs/plans/feat-022.md`, then lock the deterministic fallback.
