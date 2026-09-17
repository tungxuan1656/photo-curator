# feat-024 — Visual embedding foundation

## Status

- Status: `todo`
- Depends on: `feat-022`

## Goal

Choose and safely route the smallest viable on-device visual embedding before global
diversity relies on it.

## Contract boundary

The feature owns `VisualEmbeddingProvider`, model selection, Tier-C routing, schema,
cache/version policy, and pipeline integration. It records license and checksum evidence.
This feature owns model consumers and shared contracts.

## Acceptance

- [ ] A selected embedding candidate is measured via reproducible automated benchmarks (Simulator permitted) and retains a fallback.
- [ ] Tier-C routing is bounded and does not silently force model work for every photo.
- [ ] Model license, source/version, and checksum are recorded before inclusion.
- [ ] Golden-shaped plus 1k-scale automated evidence meets the parent budget.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`

## Inline plan

1. Use feat-022 evidence to lock the provider contract and benchmark protocol.
2. Implement the provider and benchmark as slices of this feature.
3. Integrate the accepted candidate, version/cache policy, routing, and fallback.

## Verify

- Reproducible automated evidence for every behavior change (Simulator permitted): Golden-shaped plus 1k-scale, on every supported routing fallback; record commands, fixtures, and outputs in the handoff.
- `./init.sh`
- Manual QA per `docs/ship-gates/manual-qa.md` is optional non-blocking exploratory guidance only, never an acceptance blocker (DEC-032). No test targets, no `*Test*.swift`, no test frameworks.

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-022 must establish moment evidence and benchmark need.
- Next: create the external plan before activation; this shared model contract is substantial.
