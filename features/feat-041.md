# feat-041 — Incremental library analysis lifecycle

## Status

- Status: `done`
- Depends on: `feat-040`.

## Goal

Enrich catalog assets incrementally while browsing remains available.

## Scope and ownership

Own catalog-oriented scheduling, per-capability status, checkpoints, generation guards, pause/resume, and cache reuse.
Reuse native providers and image loading without requiring album picks.
Contracts: [architecture](../docs/design-docs/ios-architecture.md), [data model](../docs/design-docs/data-model.md), [performance](../docs/ship-gates/performance.md).

## Acceptance

- [x] Metadata is browseable before analysis completes; partial evidence publishes incrementally.
- [x] Asset/provider revisions gate reuse and late results; cache loss requeues work.
- [x] Pending, running, stale, unavailable, and available states remain distinct by capability.
- [x] Pause, cancellation, suspension, iCloud delay, and relaunch preserve completed work and user state.
- [x] Jobs produce catalog evidence without album sizing, `SelectionResult` picks, or automatic user-choice writes.
- [x] Bounded resource policies and `./init.sh` pass with limitations recorded.

## Readiness plan

1. Separate analysis job lifecycle from selection-session output.
2. Persist capability/revision progress and safe checkpoints.
3. Integrate app lifecycle, status publication, and explicit recovery.

See [plan](../docs/plans/feat-041.md).

## Evidence and handoff

- Added catalog-backed `nativeImageFacts` work states, revision-guarded evidence commits, durable scheduling checkpoints, and foreground lifecycle reconciliation without selection-session output.
- Added shared two-permit arbitration for visible, session, and enrichment image work. Existing Swift 6 isolation warnings remain outside this feature's scope.
- Evidence: `./init.sh` PASS on 2026-09-24 (SwiftFormat, strict SwiftLint, generic Simulator build; tests skipped by DEC-040).
- No tests/proof harnesses or mandatory manual QA.
- Next: feat-042.
