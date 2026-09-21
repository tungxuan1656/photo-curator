# Product Docs Index

Start at `AGENTS.md`, then read the owner doc for the task. These routes are
canonical; do not duplicate an owner's facts in another document.

## Task routes

| Task | Read first | Owner |
|---|---|---|
| Product purpose, scope, platform | [product.md](product-specs/product.md) | Product |
| Screen flow and visible states | [ux-flows.md](product-specs/ux-flows.md) | UX |
| User choices, cleanup, deletion safety | [review-rules.md](product-specs/review-rules.md) | Review rules |
| English/Vietnamese strings | [ui-copy.md](product-specs/ui-copy.md) | UI copy |
| Legacy pick rules (historical route only) | [selection-rules.md](product-specs/selection-rules.md) | Legacy reference; not active behavior owner |
| App topology, coordination, services | [ios-architecture.md](design-docs/ios-architecture.md) | iOS architecture |
| Durable workspace and cache shapes | [data-model.md](design-docs/data-model.md) | Data model |
| Photo intelligence facts and suggestions | [photo-intelligence.md](design-docs/photo-intelligence.md) | Photo intelligence |
| Concrete runtime/model candidates | [curation-runtime-stack.md](design-docs/curation-runtime-stack.md) | Runtime stack |
| PhotoKit, Vision, deletion API facts | [apple-frameworks.md](design-docs/apple-frameworks.md) | Apple frameworks |
| Privacy and access | [privacy.md](ship-gates/privacy.md) | Privacy |
| Performance budgets | [performance.md](ship-gates/performance.md) | Performance |
| Build order | [roadmap.md](exec-plans/roadmap.md) | Roadmap |
| Why a decision was made | [decision-log.md](design-docs/decision-log.md) | Decision history |

`selection-engine.md` and `curation-intelligence.md` remain historical/legacy
references while the pivot is implemented. They are not active behavior owners.
Archived `docs/plans/*` preserve prior implementation history and are not
rewritten by the pivot.

## Current pivot execution records

The current actionable plan records are [feat-032](plans/feat-032.md),
[feat-033](plans/feat-033.md), [feat-034](plans/feat-034.md),
[feat-035](plans/feat-035.md), [feat-036](plans/feat-036.md), and
[feat-037](plans/feat-037.md), in the order owned by
[roadmap.md](exec-plans/roadmap.md). Older `docs/plans/*` records remain
historical implementation records; their links and contents are preserved.

## Platform and validation invariants

The planning baseline is iPhone 14+ and iOS 26+, with on-device processing and
English/Vietnamese UI. The repository has no test targets, test files, test
frameworks, or standalone proof harnesses. Behavior-changing work must run
`./init.sh`; the parent owns that run for this documentation-only phase.

## Ownership rule

Read the owner doc only; follow links when needed. If two docs appear to state
the same current fact, move the fact to the owner named above and link to it.
