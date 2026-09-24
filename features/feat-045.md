# feat-045 — Faceted discovery and label editing

## Status

- Status: `todo`
- Depends on: `feat-043`, `feat-044`.

## Goal

Find distinct photos through combined labels and inspect their complete comparison groups.

## Scope and ownership

Own facet queries, contextual counts, label browser/editor, Photos/Groups result modes, and frozen temporary selection.
Mutation services are integrated by feat-046.
Contracts: [organization](../docs/product-specs/organization-rules.md), [UX](../docs/product-specs/ux-flows.md), [actions](../docs/product-specs/review-rules.md), [copy](../docs/product-specs/ui-copy.md).

## Acceptance

- [ ] Different facets intersect; labels within a facet union; results/counts deduplicate IDs.
- [ ] Nature AND (blur OR underexposure) has explicit chips, current coverage, and truthful zero-result behavior.
- [ ] Matching groups show matched/total counts and outside-filter context without expanding selection.
- [ ] Label corrections/personal labels update effective results and survive refresh/relaunch.
- [ ] Select All captures the whole result snapshot, not just loaded cells; query changes clear selection.
- [ ] en/vi, accessibility, error states, and `./init.sh` pass.

## Readiness plan

1. Implement revisioned queries and contextual count semantics.
2. Add facet/label editing surfaces and filtered group views.
3. Add snapshot selection ready for explicit action integration.

See [plan](../docs/plans/feat-045.md).

## Evidence and handoff

- Implementation and feature verification not started.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete both dependencies and obtain activation approval.
