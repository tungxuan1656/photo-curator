# feat-042 — Library-wide comparison groups

## Status

- Status: `done`
- Depends on: `feat-041`.

## Goal

Publish coherent comparison groups independently of album selection, including cross-date near-copies.

## Scope and ownership

Own candidate retrieval, visual validation, group consistency, relation reasons, and versioned group projections.
Reuse inspected native similarity code where its evidence matches the contract.
Contracts: [organization](../docs/product-specs/organization-rules.md), [intelligence](../docs/design-docs/photo-intelligence.md), [performance](../docs/ship-gates/performance.md).

## Acceptance

- [x] Retake and cross-date near-copy candidate paths use bounded work and image-sensitive evidence.
- [x] Shared labels/time alone never establish a group; transitive chains cannot merge unrelated endpoints.
- [x] Every published group has exact members, relation, reason, representative, revision, and current evidence references.
- [x] Unknown dates/evidence remain honest; ungrouped assets remain browseable.
- [x] Rebuilds preserve user choices and stable open snapshots; no album-count policy controls coverage.
- [x] Retrieval/storage decisions and quality limitations are recorded; `./init.sh` passes.

## Readiness plan

1. Select bounded retrieval and artifact lifetime; record any required storage/privacy decision.
2. Decouple group production from selection and implement coherent snapshots.
3. Integrate revision-aware invalidation and coverage publication.

See [plan](../docs/plans/feat-042.md).

## Evidence and handoff

- Retrieval decision: use bounded same-capture neighbors and transient cross-date perceptual-hash buckets, followed by image-sensitive Vision validation. Do not persist hashes, FeaturePrints, vectors, decoded images, or bucket contents.
- Candidate and bucket overflow reduce recall and publish incomplete coverage; no whole-library recall or accuracy claim is made.
- Implemented V5/V6 additive comparison projections, complete-link validation, generation/revision guards, and bounded snapshot retention.
- No tests/proof harnesses or mandatory manual QA.
- Evidence: `./init.sh` PASS on 2026-09-24 (SwiftFormat, strict SwiftLint, generic Simulator build; tests skipped by DEC-040).
- Next: feat-043.
