# feat-046 — Exact-set organization actions

## Status

- Status: `todo`
- Depends on: `feat-045`.

## Goal

Apply labels, album actions, or confirmed cleanup to an explicit catalog selection.

## Scope and ownership

Own bulk action previews, album destination selection, durable action contexts, and existing save/deletion service integration.
Preserve operation IDs and legacy recovery.
Contracts: [actions](../docs/product-specs/review-rules.md), [data](../docs/design-docs/data-model.md), [frameworks](../docs/design-docs/apple-frameworks.md), [copy](../docs/product-specs/ui-copy.md).

## Acceptance

- [ ] Temporary photo selection never means album membership or deletion staging.
- [ ] Bulk actions preview exact IDs/counts; changing access/set invalidates preflight and cannot silently expand dispatch.
- [ ] New/existing writable album destinations use stable identity, truthful partial outcomes, and retry without duplicate destinations.
- [ ] Staging remains reversible; deletion retains exact confirmation, full-access checks, durable digest, and no automatic retry.
- [ ] User labels, other drafts, staging, and unresolved operations survive unrelated actions and restart.
- [ ] en/vi, accessibility, migration evidence, and `./init.sh` pass.

## Readiness plan

1. Bridge action snapshots to independent durable contexts.
2. Add destination selection and resilient album writes.
3. Integrate exact-set staging/deletion and recovery.

See [plan](../docs/plans/feat-046.md).

## Evidence and handoff

- Implementation and feature verification not started.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete feat-045 and obtain activation approval.
