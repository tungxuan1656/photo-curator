# feat-043 — Group-first discovery and photo inspection

## Status

- Status: `todo`
- Depends on: `feat-042`.

## Goal

Reach useful groups and inspect every displayed photo without a selection session.

## Scope and ownership

Own discovery entry, All Photos, group navigation, comparison, and session-independent inspector state.
Reuse existing preview/zoom components. Label filtering and bulk mutation integration belong to later features.
Contracts: [UX](../docs/product-specs/ux-flows.md), [organization](../docs/product-specs/organization-rules.md), [copy](../docs/product-specs/ui-copy.md).

## Acceptance

- [ ] The main entry exposes groups directly rather than after the complete photo grid.
- [ ] Every photo thumbnail opens scoped, zoomable detail with loading/failure/retry states.
- [ ] Group members, reasons, counts, partial coverage, and missing evidence are visible.
- [ ] Opening/comparing photos never changes album membership or deletion staging.
- [ ] Incremental updates preserve the current photo/order until refresh; saved legacy work remains reachable.
- [ ] en/vi, VoiceOver, Dynamic Type, and `./init.sh` requirements pass.

## Readiness plan

1. Introduce catalog navigation and bounded browse models.
2. Adapt group/detail/compare components to catalog snapshots.
3. Integrate analysis status and recovery without removing saved-work routes.

See [plan](../docs/plans/feat-043.md).

## Evidence and handoff

- Implementation and feature verification not started.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete feat-042 and obtain activation approval.
