# feat-044 — Useful AI labels and durable corrections

## Status

- Status: `todo`
- Depends on: `feat-041`.

## Goal

Provide a supported multi-label taxonomy with image-sensitive evidence and durable user overrides.

## Scope and ownership

Own provider admission, taxonomy IDs, mapping, automatic assignments, overrides, personal labels, and effective-label projection.
The label browser/editor UI belongs to feat-045.
Contracts: [organization](../docs/product-specs/organization-rules.md), [intelligence](../docs/design-docs/photo-intelligence.md), [runtime](../docs/design-docs/curation-runtime-stack.md).

## Acceptance

- [ ] An explicit decision records provider/runtime evidence and the exact supported taxonomy; unsupported candidates are not claimed.
- [ ] Semantic labels use image-sensitive AI; metadata labels retain truthful source attribution.
- [ ] A photo can have multiple supported labels across facets with evidence/revision/availability.
- [ ] Confirm/reject/personal-label mutations persist separately; re-analysis preserves user overrides.
- [ ] Pending, unsupported, unavailable, stale, and successful empty output remain distinguishable.
- [ ] No beauty/keep/family-identity claims are fabricated; quality gaps and `./init.sh` evidence are recorded.

## Readiness plan

1. Evaluate native coverage and freeze a useful supported taxonomy/provider decision.
2. Implement versioned assignments and correction precedence.
3. Publish effective-label projections and explicit degraded states.

See [plan](../docs/plans/feat-044.md).

## Evidence and handoff

- No new model is admitted by planning. Qwen remains blocked separately.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete feat-041 and obtain activation approval; resolve admission gaps before claiming label delivery.
