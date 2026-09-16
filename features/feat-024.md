# feat-024 — Visual embedding foundation

## Status and kind

- Status: `todo`
- Kind: `integration`
- Depends on: `feat-022`

## Goal

Choose and safely route the smallest viable on-device visual embedding before global
diversity relies on it.

## Contract boundary

The parent owns `VisualEmbeddingProvider`, model selection, Tier-C routing, schema,
cache/version policy, and pipeline integration. It records license and checksum evidence.
No child changes a model consumer or shared contract.

## Reserved mini-features

- `mini-024a` — embedding-provider implementation. Admit after the parent fixes the
  provider protocol and exact new source path. Done when it returns versioned embeddings
  or an explicit unavailable result with no UI or pipeline wiring changes.
- `mini-024b` — FastViT candidate benchmark and provenance record. Admit after fixtures,
  device, and model candidates are locked. Done with quality, latency, memory, license,
  and checksum evidence plus accept/reject recommendation.

## Acceptance

- [ ] A selected embedding candidate is measured on target devices and retains a fallback.
- [ ] Tier-C routing is bounded and does not silently force model work for every photo.
- [ ] Model license, source/version, and checksum are recorded before inclusion.
- [ ] Golden plus 1k smoke evidence meets the parent budget.

## Relevant docs

- `docs/design-docs/curation-intelligence.md`
- `docs/ship-gates/manual-qa.md`
- `docs/exec-plans/curation-intelligence-v2-parallel-delivery.md`

## Inline plan

1. Use feat-022 evidence to lock the provider contract and benchmark protocol.
2. Admit provider and benchmark children with exclusive outputs.
3. Integrate the accepted candidate, version/cache policy, routing, and fallback.

## Verify

- Pipeline manual QA: Golden plus 1k, on every supported routing fallback.
- `./init.sh`

## Handoff

- State: todo
- Evidence: —
- Blockers: feat-022 must establish moment evidence and benchmark need.
- Next: create the external plan before activation; this shared model contract is substantial.
