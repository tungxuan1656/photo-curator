# Product Docs Index (start here)

Start at `AGENTS.md`. Then read one owner doc below. Then code.

## Task routes (task → read this one doc)

| If you need to | Read first |
|---|---|
| Change what the app is or what ships | [product.md](product-specs/product.md) |
| Change screens, copy, or review steps | [ux-flows.md](product-specs/ux-flows.md) |
| Change what gets picked and why | [selection-rules.md](product-specs/selection-rules.md) |
| Change pipeline order or stage rules | [selection-engine.md](design-docs/selection-engine.md) |
| Change app structure, jobs, or threads | [ios-architecture.md](design-docs/ios-architecture.md) |
| Change saved data, IDs, or cache shape | [data-model.md](design-docs/data-model.md) |
| Change PhotoKit or Vision calls | [apple-frameworks.md](design-docs/apple-frameworks.md) |
| Change speed, limits, or size targets | [performance.md](ship-gates/performance.md) |
| Change privacy, access, or what is kept | [privacy.md](ship-gates/privacy.md) |
| Run QA checks by hand | [manual-qa.md](ship-gates/manual-qa.md) |
| Add or change an event log | [analytics.md](ship-gates/analytics.md) |
| Change build order or what is later | [roadmap.md](exec-plans/roadmap.md) |
| Ask why a past choice was made | [decision-log.md](design-docs/decision-log.md) |

Rule: read the owner doc only. Links inside point to other docs. Do not copy text between docs.

## Ownership (doc → owns → read when)

| Doc | Owns | Read when |
|---|---|---|
| [product.md](product-specs/product.md) | Vision, scope, ship gates | You change goals or scope |
| [ux-flows.md](product-specs/ux-flows.md) | Screens, copy, review acts | You change what the user sees |
| [selection-rules.md](product-specs/selection-rules.md) | Pick rules, ranks, reason codes | You change picks |
| [selection-engine.md](design-docs/selection-engine.md) | Pipeline steps, config, reruns | You change how picks run |
| [ios-architecture.md](design-docs/ios-architecture.md) | App shape, jobs, logs | You change code shape |
| [data-model.md](design-docs/data-model.md) | Saved shapes, cache keys | You change saved fields |
| [apple-frameworks.md](design-docs/apple-frameworks.md) | PhotoKit, Vision use | You touch photos APIs |
| [performance.md](ship-gates/performance.md) | Limits, time goals | You change speed or size |
| [privacy.md](ship-gates/privacy.md) | Privacy, keep rules | You touch data or access |
| [manual-qa.md](ship-gates/manual-qa.md) | Hand QA steps | You test a build |
| [analytics.md](ship-gates/analytics.md) | Event names only | You log events |
| [roadmap.md](exec-plans/roadmap.md) | Build order | You plan next work |
| [decision-log.md](design-docs/decision-log.md) | Past reasons, open items | You need why or what is open |

## Open decisions

Open items live in [decision-log.md](design-docs/decision-log.md). Read it before you change a past choice.
