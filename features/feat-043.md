# feat-043 — Group-first discovery and photo inspection

## Status

- Status: `done`
- Depends on: `feat-042`.

## Goal

Reach useful groups and inspect every displayed photo without a selection session.

## Scope and ownership

Own discovery entry, All Photos, group navigation, comparison, and session-independent inspector state.
Reuse existing preview/zoom components. Label filtering and bulk mutation integration belong to later features.
Contracts: [UX](../docs/product-specs/ux-flows.md), [organization](../docs/product-specs/organization-rules.md), [copy](../docs/product-specs/ui-copy.md).

## User-approved localization design

- All new discovery, group, and inspector strings will be added to
  `apps/photo-curator/Localizable.xcstrings` with Vietnamese translations.
- Localization preserves the existing layout and behavior; it does not add
  copy-specific layout branches or interaction changes.

## Acceptance

- [x] The main entry exposes groups directly rather than after the complete photo grid.
- [x] Every photo thumbnail opens scoped, zoomable detail with loading/failure/retry states.
- [x] Group members, reasons, counts, partial coverage, and missing evidence are visible.
- [x] Opening/comparing photos never changes album membership or deletion staging.
- [x] Incremental updates preserve the current photo/order until refresh; saved legacy work remains reachable.
- [x] en/vi, VoiceOver, Dynamic Type, and `./init.sh` requirements pass.

## Readiness plan

1. Introduce catalog navigation and bounded browse models.
2. Adapt group/detail/compare components to catalog snapshots.
3. Integrate analysis status and recovery without removing saved-work routes.

See [plan](../docs/plans/feat-043.md).

## Evidence and handoff

- State: `done`; implementation is present for the catalog discovery, group detail, scoped inspector, refresh guards, legacy-route handoff, and approved localization.
- Scope delivered: direct group-first discovery with All Photos browsing; group/member/reason/coverage surfaces; session-independent zoomable inspection with loading, failure, and retry states; read-only navigation that does not alter album or deletion state.
- Acceptance evidence: all six acceptance items are supported by the implementation; discovery/group/inspector copy and accessibility strings have English and Vietnamese catalog entries, while existing accessible controls and system text styles preserve VoiceOver and Dynamic Type behavior.
- Verification: final `./init.sh` PASS on 2026-09-24 after review fixes (SwiftFormat, strict SwiftLint with 0 violations, generic Simulator build succeeded); `git diff --check` PASS; tests skipped under DEC-040. No manual QA or proof harness was added.
- Oracle review resolution: localization review findings were resolved; no outstanding review findings remain for this feature.
- Handoff: parent owns final diff validation. Source implementation and localization are complete; saved-work routes and shared image loading remain available to downstream work.
- Next: feat-044 — Useful AI labels and durable corrections.
