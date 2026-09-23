# feat-038 — Native analysis and actionable review repair

## Status

- Status: `done`; depends on `feat-037` (`done`).
- The user approved the repair policy and activated this feature after feat-037.
- Approved policy: one native path for every photo count; conservative
  duplicate-representative grouping with unknown dates separate; bounded album
  selection that never silently exceeds its maximum; and no uncalibrated scalar
  Tier-C novelty influence.
- The feature is complete: native-only production routing, legacy artifact
  management, recoverable analysis evidence, canonical grouping, and actionable
  review repair are implemented.

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

- [x] A1: Production consistently uses native analysis; no download prompt or
  misleading Qwen/AI fallback claim remains.
- [x] A2: Every source asset has an explainable analyzed/unavailable outcome.
  Zero picks never blocks otherwise valid review.
- [x] A3: Picks, groups, uncertainty and unavailable evidence reach review;
  ordinary photos do not disappear from suggestions because no duplicate exists.
- [x] A4: Cleanup, album and progress remain independent, reactive, durably ordered,
  and truthful on write failure and retry.
- [x] A5: Native policy does not silently change at 100/101 photos; missing evidence
  never masquerades as quality, scene certainty, or maximum novelty.
- [x] A6: Edited assets invalidate cached facts; lost cache rows can be recomputed.
- [x] A7: Reasons, versions, counts and en/vi labels describe actual execution.
- [x] A8: Required `./init.sh` passes; evidence and limitations are recorded.

## Readiness and handoff

Implemented native-only execution and legacy artifact management; revision-aware
recoverable cache/checkpoints; canonical representative grouping, conservative
facts, bounded evidence/sizing, and persisted provenance; zero-pick/actionable
review; atomic reactive workspace actions; and localized accessible UI.

Final evidence: `./init.sh` PASS and `git diff --check` PASS on 2026-09-23.
Limitations: no device PhotoKit/image-quality benchmark or manual QA was run;
compilation does not calibrate visual thresholds. Preserve the user's existing
String Catalog edits. No tests or proof harnesses.
