# feat-040 — Persistent photo catalog foundation

## Status

- Status: `todo`
- Depends on: `feat-039`.
- Planning requested; implementation activation requires user approval.

## Goal

Open a durable index of accessible Photos assets without creating an album-selection session.

## Scope and ownership

Own additive catalog schema/store, metadata reconciliation, revision identity, and legacy coexistence.
Reserve versioned label/group projection shapes without implementing inference or discovery UI.
Use [data model](../docs/design-docs/data-model.md), [architecture](../docs/design-docs/ios-architecture.md), and [privacy](../docs/ship-gates/privacy.md).

## Acceptance

- [ ] Metadata enumeration creates one catalog identity per accessible asset without copying originals.
- [ ] New/edited/inaccessible assets reconcile through complete generations; interrupted scans do not erase user data.
- [ ] V2 scopes, choices, drafts, staged sets, and operation IDs survive migration unchanged.
- [ ] Catalog failure preserves the old store and exposes explicit unavailable state.
- [ ] User overrides and derived projections have separate versioned ownership.
- [ ] `./init.sh` passes; schema and recovery limitations are recorded.

## Readiness plan

1. Freeze additive schema and query contracts before migration.
2. Implement catalog persistence and metadata reconciliation.
3. Integrate startup while retaining legacy saved-work routes.

Detailed ownership and rollback: [plan](../docs/plans/feat-040.md).

## Evidence and handoff

- Verification not run for this feature; documentation baseline is not implementation evidence.
- No tests or proof harnesses. Manual QA is not a gate.
- Next: obtain activation approval, then run baseline `./init.sh`.
