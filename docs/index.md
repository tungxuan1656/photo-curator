# Project Documentation Index

Start at [AGENTS.md](../AGENTS.md), then select one owner for the task.
Current direction: [Photos companion product](product-specs/product.md).
Current code and target architecture are explicitly separated in [architecture](design-docs/ios-architecture.md).

## Task routes and ownership

| Read when | Canonical owner | Update when |
|---|---|---|
| Purpose, scope, priority | [Product](product-specs/product.md) | Accepted product decision |
| Labels, facets, group meaning, filter logic | [Organization rules](product-specs/organization-rules.md) | Domain behavior changes |
| Screens, navigation, inspection, visible states | [UX flows](product-specs/ux-flows.md) | Route or interaction changes |
| Selection, album, staging, deletion | [Review rules](product-specs/review-rules.md) | User-action semantics change |
| English/Vietnamese wording | [UI copy](product-specs/ui-copy.md) | User-visible state/label changes |
| Code map, orchestration, dependencies | [iOS architecture](design-docs/ios-architecture.md) | Topology or ownership changes |
| Schema, projections, revisions, migration | [Data model](design-docs/data-model.md) | Stored/query contracts change |
| Group/label evidence and quality claims | [Photo intelligence](design-docs/photo-intelligence.md) | Evidence policy changes |
| Concrete AI/runtime candidates and admission | [Runtime stack](design-docs/curation-runtime-stack.md) | Provider/artifact decision changes |
| Framework service boundaries | [Apple frameworks](design-docs/apple-frameworks.md) | Framework integration changes |
| Data sensitivity, reset, retention | [Privacy](ship-gates/privacy.md) | Data lifecycle or network behavior changes |
| Work bounds and lifecycle budgets | [Performance](ship-gates/performance.md) | Scheduling/resource policy changes |
| Optional event collection | [Analytics](ship-gates/analytics.md) | Provider/consent decision |
| Optional user exploration | [Manual QA](ship-gates/manual-qa.md) | Useful exploratory cases change |
| Build order and feature dependencies | [Roadmap](exec-plans/roadmap.md) | Delivery graph changes |
| Rationale and superseded decisions | [Decision log](design-docs/decision-log.md) | Consequential accepted decision |

A durable fact has one owner. Other documents link to that owner instead of redefining it.
New features update the affected owner when implementation changes the intended contract.

## Execution records

- Status/dependencies: [feature_index.json](../feature_index.json).
- Scope, acceptance, evidence, handoff: `features/feat-<id>.md`.
- Substantial work: linked `docs/plans/feat-<id>.md`.
- Session results: append-only [progress.md](../progress.md).
- Organization pivot: feat-039–047, routed by the [roadmap](exec-plans/roadmap.md).

Only activate user-approved features with completed dependencies.
Behavior changes require `./init.sh`; no test targets or standalone proof harnesses are allowed.
Manual QA is not an acceptance or release gate.

## Historical references

These retain earlier design context and do not own current behavior:

- [Selection rules](product-specs/selection-rules.md): former automatic album policy.
- [Selection engine](design-docs/selection-engine.md): former album pipeline design.
- [Curation intelligence V2](design-docs/curation-intelligence.md): former quality architecture.
- Plans through feat-038 and [universal request evidence](evidence/universal-request-cost.md): historical implementation/evaluation records.

feat-031 remains blocked and does not authorize Qwen production use.
Historical success records do not prove the organization pivot is implemented or visually accurate.
