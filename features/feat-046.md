# feat-046 — Exact-set organization actions

## Status

- Status: `done`
- Depends on: `feat-045`.

## Goal

Apply labels, album actions, or confirmed cleanup to an explicit catalog selection.

## Scope and ownership

Own bulk action previews, album destination selection, durable action contexts, and existing save/deletion service integration.
Preserve operation IDs and legacy recovery.
Contracts: [actions](../docs/product-specs/review-rules.md), [data](../docs/design-docs/data-model.md), [frameworks](../docs/design-docs/apple-frameworks.md), [copy](../docs/product-specs/ui-copy.md).

## Approved exact-set architecture

- Each bulk action owns an independent durable action context keyed by the
  frozen feat-045 selection: exact asset IDs, query identity, catalog
  generation, and label-projection revision. Action contexts survive view
  navigation and restart without becoming album membership, cleanup staging,
  or another action's draft.
- `ReviewModel` and its legacy selected-asset state are not authority for
  catalog actions. New actions never import legacy picks as the selected set;
  only the frozen selection snapshot can create an action context.
- Preflight rejects a changed or access-mismatched set, including revision
  mismatch or missing access to any frozen ID. It never silently shrinks,
  expands, or substitutes the dispatch set.
- Album destinations use stable identity for existing and newly created
  writable albums, so retries reconcile the same destination rather than
  creating duplicates.
- Deletion preserves the existing full-access gate, exact-set confirmation,
  durable digest, immutable executing set, and per-ID outcomes. Deletion has
  no automatic retry; recovery remains explicit and durable.

## Acceptance

- [x] Temporary photo selection never means album membership or deletion staging, and legacy `ReviewModel` selection is never action authority.
- [x] Independent durable action contexts are keyed by frozen IDs and revisions; changed/access-mismatched sets are rejected at preflight without silent shrink, expansion, or substitution.
- [x] New/existing writable album destinations use stable identity, truthful partial outcomes, and retry without duplicate destinations.
- [x] Staging remains reversible; deletion retains exact confirmation, full-access checks, durable digest, immutable executing set, and no automatic retry.
- [x] User labels, other drafts, staging, and unresolved operations survive unrelated actions and restart.
- [x] en/vi, accessibility, migration evidence, and `./init.sh` pass.

## Readiness plan

1. Bridge action snapshots to independent durable contexts.
2. Add destination selection and resilient album writes.
3. Integrate exact-set staging/deletion and recovery.

See [plan](../docs/plans/feat-046.md).

## Evidence and handoff

- State: `done`.
- Evidence: Exact-set action contexts; stable album destination/retry; exact deletion safeguards/recovery; en/vi/a11y/migration.
- Verification: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations, generic iOS Simulator `BUILD SUCCEEDED`; tests skipped DEC-040); `git diff --check` PASS.
- Handoff: feat-047 — catalog cutover and lifecycle hardening.
