# feat-047 — Catalog cutover and lifecycle hardening

## Status

- Status: `todo`
- Depends on: `feat-046`.

## Goal

Make the organization flow the complete default experience while retaining valid saved work and truthful capability limits.

## Scope and ownership

Own final route cutover, obsolete active-session coupling removal, incremental-library recovery, reset behavior, and documentation reconciliation.
Remove legacy runtime code only after caller and saved-data compatibility review.
Contracts: [product](../docs/product-specs/product.md), [architecture](../docs/design-docs/ios-architecture.md), [performance](../docs/ship-gates/performance.md), [privacy](../docs/ship-gates/privacy.md).

## Acceptance

- [ ] Default discovery requires no cleanup/album session; all current features are reachable through catalog routes.
- [ ] Legacy drafts, staged choices, and unresolved operations remain recoverable after cutover.
- [ ] New/edited/inaccessible assets, interrupted jobs, cache loss, and schema failure retain truthful recoverable states.
- [ ] Analysis reset preserves user organization data and mutation evidence.
- [ ] Candidate work, query paging, and image lifetime remain bounded; unsupported scale/quality claims are absent.
- [ ] All new strings are localized, owners match implementation, and `./init.sh` passes.

## Readiness plan

1. Audit old callers, readers, and navigation before route retirement.
2. Close lifecycle/reset/scale gaps and preserve compatibility recovery.
3. Reconcile owner documents with shipped capabilities and record remaining limitations.

See [plan](../docs/plans/feat-047.md).

## Evidence and handoff

- Implementation and feature verification not started.
- No tests/proof harnesses or mandatory manual QA.
- Next: complete feat-046 and obtain activation approval.
