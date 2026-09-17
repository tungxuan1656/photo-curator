# feat-027 — Semantic jury

## Status

- Status: `todo`
- Depends on: `feat-026`

## Goal

Use the iOS 27 semantic jury only behind an availability gate and validate every decision
against a small, recoverable schema; iOS 26 remains deterministic.

## Contract boundary

The feature owns OS gate, provider protocol, request policy, choice schema, fallback,
telemetry-free diagnostics, and selection integration. Implement an isolated
adapter only after the parent locks protocol and exact path.

## Acceptance

- [ ] iOS 27 jury work is opt-in and bounded to the approved ambiguity cases.
- [ ] The schema accepts only `chooseA`, `chooseB`, `keepBoth`, or `abstain`.
- [ ] Invalid, unavailable, timed-out, or iOS 26 requests use deterministic fallback.
- [ ] Golden-shaped automated evidence explains jury and fallback outcomes (Simulator permitted).

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/product-specs/ux-flows.md`

## Inline plan

1. Lock availability, schema, ambiguity admission, and fallback contracts.
2. Implement the adapter with the fixed source ownership.
3. Integrate only validated results; record iOS 26 and failure-path evidence.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): Golden-shaped jury evidence on the iOS 27 path plus deterministic fallback evidence on the iOS 26 path; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: todo
- Evidence: —
- Blockers: requires feat-026 uncertainty classification.
- Next: create the external plan before activation; OS-gated contract and fallback are substantial.
