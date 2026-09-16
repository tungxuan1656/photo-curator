# feat-025 — Conditional specialist models

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-023`

## Goal

Evaluate difficult-only specialist candidates only when a remaining baseline failure has
no cheaper accepted remedy. Rejection is a successful outcome.

## Contract boundary

The parent owns candidate selection, target failure, accept/reject decision, routing,
resource budget, license/provenance, and rollback. Do not pre-admit DETR, depth, or SAM
as a bundle. Create a mini-feature only for one candidate with one named failure.

## Reserved mini-features

None. At activation, the parent may reserve `mini-025a`, then `mini-025b`, only after
each prior candidate is accepted or rejected. Every record must identify one model, one
failure, one device benchmark, one license/checksum record, and one reject path.

## Acceptance

- [ ] Every attempted specialist has a named residual failure and a cheaper-alternative check.
- [ ] Each candidate has on-device quality, latency, memory, license, checksum, and
  availability evidence.
- [ ] Each candidate is explicitly accepted or rejected; rejection leaves no speculative
  runtime dependency.
- [ ] Accepted routing is difficult-only, bounded, and reversible.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/ship-gates/manual-qa.md`
- `docs/ship-gates/privacy.md`

## Inline plan

1. Select a single unresolved feat-023 failure and verify no cheaper signal fixes it.
2. Create one mini-feature admission card for one candidate; benchmark and decide.
3. Integrate only an accepted candidate, otherwise record the rejection and close.

## Verify

- Target fixture plus Golden and 1k smoke for any accepted candidate.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: no work starts without a residual failure after feat-023.
- Next: create `docs/plans/feat-025.md` only if a residual failure exists; a documented no-op is valid.
