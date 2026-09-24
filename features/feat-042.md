# feat-042 — Library-wide comparison groups

## Status

- Status: `todo`
- Depends on: `feat-041`.

## Goal

Publish coherent comparison groups independently of album selection, including cross-date near-copies.

## Scope and ownership

Own candidate retrieval, visual validation, group consistency, relation reasons, and versioned group projections.
Reuse inspected native similarity code where its evidence matches the contract.
Contracts: [organization](../docs/product-specs/organization-rules.md), [intelligence](../docs/design-docs/photo-intelligence.md), [performance](../docs/ship-gates/performance.md).

## Acceptance

- [ ] Retake and cross-date near-copy candidate paths use bounded work and image-sensitive evidence.
- [ ] Shared labels/time alone never establish a group; transitive chains cannot merge unrelated endpoints.
- [ ] Every published group has exact members, relation, reason, representative, revision, and current evidence references.
- [ ] Unknown dates/evidence remain honest; ungrouped assets remain browseable.
- [ ] Rebuilds preserve user choices and stable open snapshots; no album-count policy controls coverage.
- [ ] Retrieval/storage decisions and quality limitations are recorded; `./init.sh` passes.

## Readiness plan

1. Select bounded retrieval and artifact lifetime; record any required storage/privacy decision.
2. Decouple group production from selection and implement coherent snapshots.
3. Integrate revision-aware invalidation and coverage publication.

See [plan](../docs/plans/feat-042.md).

## Evidence and handoff

- No accuracy or library-scale measurement is claimed.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete feat-041 and approve the retrieval readiness decision before implementation.
