# Product Docs Index (start here)

Start at `AGENTS.md`. Then read one owner doc below. Then code.

## Task routes (task → read this one doc)

| If you need to | Read first |
|---|---|
| Change what the app is or what ships | [01-product.md](01-product.md) |
| Change screens, copy, or review steps | [02-ux-flows.md](02-ux-flows.md) |
| Change what gets picked and why | [03-photo-selection-rules.md](03-photo-selection-rules.md) |
| Change pipeline order or stage rules | [04-selection-engine-design.md](04-selection-engine-design.md) |
| Change app structure, jobs, or threads | [05-ios-architecture.md](05-ios-architecture.md) |
| Change saved data, IDs, or cache shape | [06-data-model.md](06-data-model.md) |
| Change PhotoKit or Vision calls | [07-apple-framework-integration.md](07-apple-framework-integration.md) |
| Change speed, limits, or size targets | [08-performance-spec.md](08-performance-spec.md) |
| Change privacy, access, or what is kept | [09-privacy-and-permissions.md](09-privacy-and-permissions.md) |
| Run QA checks by hand | [10-manual-qa-and-selection-evaluation.md](10-manual-qa-and-selection-evaluation.md) |
| Add or change an event log | [11-analytics-and-metrics.md](11-analytics-and-metrics.md) |
| Change build order or what is later | [12-roadmap.md](12-roadmap.md) |
| Ask why a past choice was made | [13-decision-log.md](13-decision-log.md) |

Rule: read the owner doc only. Links inside point to other docs. Do not copy text between docs.

## Ownership (doc → owns → read when)

| Doc | Owns | Read when |
|---|---|---|
| [01-product.md](01-product.md) | Vision, scope, ship gates | You change goals or scope |
| [02-ux-flows.md](02-ux-flows.md) | Screens, copy, review acts | You change what the user sees |
| [03-photo-selection-rules.md](03-photo-selection-rules.md) | Pick rules, ranks, reason codes | You change picks |
| [04-selection-engine-design.md](04-selection-engine-design.md) | Pipeline steps, config, reruns | You change how picks run |
| [05-ios-architecture.md](05-ios-architecture.md) | App shape, jobs, logs | You change code shape |
| [06-data-model.md](06-data-model.md) | Saved shapes, cache keys | You change saved fields |
| [07-apple-framework-integration.md](07-apple-framework-integration.md) | PhotoKit, Vision use | You touch photos APIs |
| [08-performance-spec.md](08-performance-spec.md) | Limits, time goals | You change speed or size |
| [09-privacy-and-permissions.md](09-privacy-and-permissions.md) | Privacy, keep rules | You touch data or access |
| [10-manual-qa-and-selection-evaluation.md](10-manual-qa-and-selection-evaluation.md) | Hand QA steps | You test a build |
| [11-analytics-and-metrics.md](11-analytics-and-metrics.md) | Event names only | You log events |
| [12-roadmap.md](12-roadmap.md) | Build order | You plan next work |
| [13-decision-log.md](13-decision-log.md) | Past reasons, open items | You need why or what is open |

## Open decisions

Open items live in [13-decision-log.md](13-decision-log.md). Read it before you change a past choice.
