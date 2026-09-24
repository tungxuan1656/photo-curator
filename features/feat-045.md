# feat-045 — Faceted discovery and label editing

## Status

- Status: `done`
- Depends on: `feat-043`, `feat-044`.

## Goal

Find distinct photos through combined labels and inspect their complete comparison groups.

## Scope and ownership

Own facet queries, contextual counts, label browser/editor, Photos/Groups result modes, and frozen temporary selection.
Mutation services are integrated by feat-046.
Contracts: [organization](../docs/product-specs/organization-rules.md), [UX](../docs/product-specs/ux-flows.md), [actions](../docs/product-specs/review-rules.md), [copy](../docs/product-specs/ui-copy.md).

## Approved truthful query contract

- The admitted semantic facets are **Image kind** (`document`, `screenshot`),
  **Content** (`people`, `group`, `landscape`, `architecture`, `food`,
  `animal`), and **Setting** (`indoor`, `outdoor`). These are the only
  semantic labels exposed as chips by this feature.
- Native technical blur/underexposure scalars are unsupported pending
  label-specific evaluation. They never appear as labels, chips, facets, or
  query predicates, and must not be represented as truthful zero matches.
- Every query snapshot atomically captures one catalog generation and one
  label-projection revision, with deterministic ordering, contextual counts,
  coverage, and a complete result-ID snapshot. A query must never mix
  revisions.
- Temporary selection is a non-mutating frozen snapshot of exact result IDs
  plus its query identity/revisions. Opening groups or outside-filter context
  does not expand it; changing the query clears it. Album, cleanup, label, and
  Photos mutation state remain outside this feature.

## Acceptance

- [x] Different facets intersect; labels within a facet union; results/counts deduplicate IDs.
- [x] Landscape AND (Indoor OR Outdoor) has explicit admitted-label chips, current coverage, and truthful zero-result behavior.
- [x] Matching groups show matched/total counts and outside-filter context without expanding selection.
- [x] Label corrections/personal labels update effective results and survive refresh/relaunch.
- [x] Select All captures the whole result snapshot, not just loaded cells; query changes clear selection.
- [x] en/vi, accessibility, error states, and `./init.sh` pass.

## Readiness plan

1. Implement revisioned queries and contextual count semantics.
2. Add facet/label editing surfaces and filtered group views.
3. Add snapshot selection ready for explicit action integration.

See [plan](../docs/plans/feat-045.md).

## Evidence and handoff

- State: `done`; both dependencies are complete and the approved truthful query/snapshot contract is implemented.
- Scope decision: only the ten admitted feat-044 semantic IDs may appear in facets; native blur/underexposure scalars remain unsupported and absent from labels/chips.
- Snapshot handoff: query reads must atomically bind catalog generation and label projection revision; frozen selection is exact-ID, non-mutating, and invalidated by query changes.
- Implementation includes revisioned facet queries, contextual counts, filtered groups, label correction/personal-label editing, and frozen non-mutating selection.
- Verification: `./init.sh` PASS — SwiftFormat, strict SwiftLint with 0 violations, generic iOS Simulator `BUILD SUCCEEDED`; tests skipped under DEC-040. `git diff --check` PASS.
- No tests/proof harnesses or mandatory manual QA.
- Next: feat-046 action integration.
