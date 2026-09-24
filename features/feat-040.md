# feat-040 — Persistent photo catalog foundation

## Status

- Status: `done`
- Depends on: `feat-039`.
- Activated by user on 2026-09-24.

## Goal

Open a durable index of accessible Photos assets without creating an album-selection session.

## Scope and ownership

Own additive catalog schema/store, metadata reconciliation, revision identity, and legacy coexistence.
Reserve versioned label/group projection shapes without implementing inference or discovery UI.
Use [data model](../docs/design-docs/data-model.md), [architecture](../docs/design-docs/ios-architecture.md), and [privacy](../docs/ship-gates/privacy.md).

## Acceptance

- [x] Metadata enumeration creates one catalog identity per accessible asset without copying originals.
- [x] New/edited/inaccessible assets reconcile through complete generations; interrupted scans do not erase user data.
- [x] V2 scopes, choices, drafts, staged sets, and operation IDs survive migration unchanged.
- [x] Catalog failure preserves the old store and exposes explicit unavailable state.
- [x] User overrides and derived projections have separate versioned ownership.
- [x] `./init.sh` passes; schema and recovery limitations are recorded.

## Readiness plan

1. V3 additive schema and committed-generation query contract complete.
2. Immutable metadata observations and coalesced reconciliation complete.
3. Startup integration and explicit unavailable state complete.

Detailed ownership and rollback: [plan](../docs/plans/feat-040.md).

## Evidence and handoff

- `./init.sh` PASS on 2026-09-24: SwiftFormat, strict SwiftLint, and Simulator build passed; tests skipped by DEC-040.
- V3 keeps V1/V2 entities additive and untouched. Complete observations publish only through `CatalogState.currentGenerationID`.
- Limits: `PHAsset.fetchAssets` itself is synchronous; cancellation stops enumeration before partial results publish. Current snapshot reads materialize the published generation.
- Next: feat-041.
