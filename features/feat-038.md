# feat-038 — Native analysis and actionable review repair

## Status

- Status: `active`; depends on `feat-037`.
- Phase 1 implements native-only production routing and recoverable cache
  evidence. Algorithm refinements in the linked plan remain proposals.

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

Implemented native-only routing and revision-aware cache recovery. The batch
pipeline records explicit unavailable outcomes and recomputes missing, stale, or
corrupt cached facts. `./init.sh` passed on 2026-09-23. A3–A5 and A7 remain open.
Preserve the user's existing String Catalog edits. No tests or proof harnesses.
