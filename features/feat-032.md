# feat-032 — Photo review pivot contracts and docs

## Status

- Status: `done` — documentation/tracker contracts closed after Gate 1 Oracle re-review GO on 2026-09-21.
- Depends on: `feat-031` is paused/blocked; pivot contracts may proceed while its incomplete Qwen work is preserved.
- Branch: `feat/photo-review-pivot`.

## Goal and ownership

Freeze the shared cleanup/album review contract, independent state dimensions,
copy, deletion safety, intelligence boundary, persistence direction, and
execution order before implementation. Owned docs are listed in the Phase 1
task request; no Swift, project configuration, `init.sh`, or archived plan is
in scope.

## Relevant docs and plan

The completed owner-doc scope is summarized in
[docs/index.md](../docs/index.md), [product.md](../docs/product-specs/product.md),
[ux-flows.md](../docs/product-specs/ux-flows.md),
[review-rules.md](../docs/product-specs/review-rules.md), and
[data-model.md](../docs/design-docs/data-model.md). The actionable closure
record is [docs/plans/feat-032.md](../docs/plans/feat-032.md).

## Acceptance

- [x] Product and UX describe two intents entering one shared review workspace.
- [x] Review rules define independent cleanup disposition, album membership,
  review progress, immutable facts/suggestions, and authoritative user choices.
- [x] Full read-write authorization, exact-set confirmation digest,
  `PhotoDeletionService`, no automatic retry, truthful iCloud/Recently Deleted
  disclosure, and separate album save are documented.
- [x] SwiftData/file-cache boundary and non-destructive legacy migration are
  documented; no generic repository abstraction is introduced.
- [x] Candidate/model docs make no unverified benchmark or device-fit claims;
  en/vi copy and review states have one owner each.
- [x] `feature_index.json` has exactly one active feature and feat-033–037 are
  sequentially `todo`.
- [x] Documentation validation passes: `swiftformat .` is non-mutating,
  `git diff --check`, Markdown links/anchors, and JSON parsing.

## Inline readiness plan

1. Reconcile owner docs, routes, decision IDs, and schema ownership.
2. Preserve feat-031 as blocked and add the dependent tracker records.
3. Run focused documentation checks and obtain Gate 1 Oracle approval.
4. Record fresh `./init.sh` evidence, close feat-032, and activate feat-033.

This documentation-only change spanned shared contracts and more than four
docs. Its separate plan is linked above; no implementation is claimed by this
record. The closure path is complete; feat-033 is the next active feature.

## Verify and handoff

Verification: `./init.sh` passed on 2026-09-21 after final DEC-054 remediation;
`git diff --check` passed; JSON/status and focused documentation checks passed.
Gate 1 Oracle re-review was GO. Handoff: activate feat-033 as the sole active
feature; implementation begins only under its linked plan.
