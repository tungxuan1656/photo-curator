# feat-038 — Native analysis and actionable review repair

## Status

- Status: `todo`; depends on `feat-037`.
- User requested a re-audit and repair plan, not implementation in this session.
- Native-only production direction is approved. Algorithm refinements in the
  linked plan remain proposals until implementation approval.

## Scope and ownership

Repair native execution, evidence preservation, cache recovery, suggestion
coverage, and durable review actions. Own the source areas and phased changes
listed in [the plan](../docs/plans/feat-038.md). Preserve existing user choices,
legacy readers, album operations, and confirmed-deletion safeguards.

Primary contracts: [review rules](../docs/product-specs/review-rules.md),
[intelligence](../docs/design-docs/photo-intelligence.md),
[data model](../docs/design-docs/data-model.md),
[architecture](../docs/design-docs/ios-architecture.md),
[copy](../docs/product-specs/ui-copy.md), and
[performance](../docs/ship-gates/performance.md).

## Acceptance

- A1: Production consistently uses native analysis; no download prompt or
  misleading Qwen/AI fallback claim remains.
- A2: Every source asset has an explainable analyzed/unavailable outcome.
  Zero picks never blocks otherwise valid review.
- A3: Picks, groups, uncertainty and unavailable evidence reach review;
  ordinary photos do not disappear from suggestions because no duplicate exists.
- A4: Cleanup, album and progress remain independent, reactive, durably ordered,
  and truthful on write failure and retry.
- A5: Native policy does not silently change at 100/101 photos; missing evidence
  never masquerades as quality, scene certainty, or maximum novelty.
- A6: Edited assets invalidate cached facts; lost cache rows can be recomputed.
- A7: Reasons, versions, counts and en/vi labels describe actual execution.
- A8: Required `./init.sh` passes; evidence and limitations are recorded.

## Readiness and handoff

The linked plan records confirmed findings, withdrawn claims, proposed remedies,
ownership, phases, rollback and acceptance scenarios. Start with baseline
`./init.sh` after activation. No code changes or new build evidence are claimed.
Preserve the user's existing String Catalog edits. No tests or proof harnesses.
