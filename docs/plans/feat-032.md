# feat-032 — Pivot contracts/docs/tracker plan

## Scope and order

This plan closes the already-executed documentation/tracker slice for the
photo-review pivot. It is first in the pivot sequence after blocked feat-031;
feat-033 cannot start until this record, its acceptance, and `./init.sh` are
closed. The authoritative contract is
[photo-review-pivot.md](../../.slim/deepwork/photo-review-pivot.md).

The completed docs scope covers the product definition, shared UX route,
independent review/deletion rules, en/vi copy, SwiftData/file-cache direction,
PhotoKit safety, privacy/performance gates, intelligence candidate register,
roadmap, index routes, DEC-054, feat-031 handoff, and feat-032–037 tracker
records. Canonical ownership remains with the owner docs; this plan does not
restate their durable facts.

## Anticipated owned areas

- Documentation already changed in this slice: `docs/index.md`,
  `docs/product-specs/{product,ux-flows,review-rules,ui-copy}.md`,
  `docs/design-docs/{ios-architecture,data-model,photo-intelligence,curation-runtime-stack,apple-frameworks,decision-log}.md`,
  `docs/ship-gates/{privacy,performance}.md`, and
  `docs/exec-plans/roadmap.md`.
- Tracker records: `feature_index.json`, `features/feat-031.md`,
  `features/feat-032.md` through `features/feat-037.md`, and appended
  `progress.md` blocks.
- No Swift, Xcode/project, localization catalog, `init.sh`, or archived
  `docs/plans/*` implementation area is owned by feat-032.

## Safety constraints

Use the owner docs as the source of truth: user choices remain authoritative;
cleanup, album membership, progress, and facts/suggestions stay independent;
full Photos read-write plus exact confirmation gates deletion; limited access
may stage but cannot delete; album save is separate; Qwen remains frozen and
unadmitted. Do not turn a documentation result into a model, quality, device,
or performance claim.

Data safety is contract-only in this feature: no schema or migration is run.
UX safety means the shared intents and en/vi labels have one owner. API safety
means no PhotoKit or model API is changed by this docs/tracker slice.

## Work and closure steps

1. Confirm the owner routes and links resolve without duplicating current facts.
2. Confirm feat-031 is blocked with incomplete acceptance/evidence preserved.
3. Confirm feat-032 is the only `active` record and feat-033–037 are ordered
   `todo` records with dependencies.
4. Record the docs-only verification and hand off the parent Gate 1 review.
5. Close feat-032 only after the parent records post-edit `./init.sh`; then
   activate feat-033, never both at once.

## Validation

Required: `./init.sh` (parent-owned final verification), `git diff --check`,
feature-index JSON parsing, and a relative Markdown link/anchor check. Do not
add tests, test targets, proof harnesses, or manual QA gates.

## Rollback and migration

Rollback is documentation-only: restore the prior docs/tracker tree as one
reviewed change, preserving Git history and archived plans. No persisted-data
migration or runtime rollback is introduced by feat-032. Do not mark feat-031
done as part of rollback or closure.

## Acceptance mapping

- Product/UX/rules/copy → owner-doc rewrite and new `review-rules.md`/`ui-copy.md`.
- Architecture/data/privacy/API/intelligence → corresponding design and gate
  owners, with no unverified candidate admission.
- Tracker/order → `feature_index.json`, feature records, and `progress.md`.
- Verification → parent `./init.sh` plus the assigned docs checks above.
