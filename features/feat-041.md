# feat-041 — Incremental library analysis lifecycle

## Status

- Status: `active`
- Depends on: `feat-040`.

## Goal

Enrich catalog assets incrementally while browsing remains available.

## Scope and ownership

Own catalog-oriented scheduling, per-capability status, checkpoints, generation guards, pause/resume, and cache reuse.
Reuse native providers and image loading without requiring album picks.
Contracts: [architecture](../docs/design-docs/ios-architecture.md), [data model](../docs/design-docs/data-model.md), [performance](../docs/ship-gates/performance.md).

## Acceptance

- [ ] Metadata is browseable before analysis completes; partial evidence publishes incrementally.
- [ ] Asset/provider revisions gate reuse and late results; cache loss requeues work.
- [ ] Pending, running, stale, unavailable, and available states remain distinct by capability.
- [ ] Pause, cancellation, suspension, iCloud delay, and relaunch preserve completed work and user state.
- [ ] Jobs produce catalog evidence without album sizing, `SelectionResult` picks, or automatic user-choice writes.
- [ ] Bounded resource policies and `./init.sh` pass with limitations recorded.

## Readiness plan

1. Separate analysis job lifecycle from selection-session output.
2. Persist capability/revision progress and safe checkpoints.
3. Integrate app lifecycle, status publication, and explicit recovery.

See [plan](../docs/plans/feat-041.md).

## Evidence and handoff

- Activated after feat-040 merged. The existing plan is approved: catalog-backed incremental analysis, revision-safe cache/checkpoints, lifecycle pause/resume, and no album-selection coupling.
- No tests/proof harnesses or mandatory manual QA.
- Next: implement the bounded catalog analysis lifecycle.
