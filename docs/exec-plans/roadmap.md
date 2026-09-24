# Roadmap

**Status:** Organization pivot execution order · 2026-09-23.
Owns delivery sequence and feature boundaries.
Live status is in [feature_index.json](../../feature_index.json); evidence belongs to the selected feature and [progress](../../progress.md).

## Direction

The [product contract](../product-specs/product.md) prioritizes comparison groups, then useful labels and filtering.
The implementation grows a persistent catalog underneath those capabilities.
Album and cleanup remain downstream explicit actions.

```text
038 completed native repair
  → 039 organization contracts/docs
    → 040 catalog foundation
      → 041 incremental analysis
        ├→ 042 comparison groups → 043 discovery / inspection ─┐
        └→ 044 AI labels / corrections ──────────────────────┤
                                                            ↓
                                                  045 faceted discovery
                                                    → 046 exact-set actions
                                                      → 047 cutover / hardening
```

Execute the linear default order 039, 040, 041, 042, 043, 044, 045, 046, 047.
The dependency graph permits label work after 041, but grouping remains the product priority.
Only one feature can be active. Activate `todo` work only after user approval and completed dependencies.

## Feature contracts

| Feature | Deliverable | Reuse / change | Plan |
|---|---|---|---|
| [039](../../features/feat-039.md) | Current contracts and code-grounded backlog | Rewrite owners, preserve history | [Plan](../plans/feat-039.md) |
| [040](../../features/feat-040.md) | Durable accessible-asset catalog | Extend SwiftData V2 and PhotoKit metadata reconciliation | [Plan](../plans/feat-040.md) |
| [041](../../features/feat-041.md) | Incremental resumable library jobs | Reuse cache/batches, remove mandatory album-result output | [Plan](../plans/feat-041.md) |
| [042](../../features/feat-042.md) | Coherent retake and cross-date near-copy groups | Extend bounded visual candidates and independent group projections | [Plan](../plans/feat-042.md) |
| [043](../../features/feat-043.md) | Group-first discovery and working photo inspection | Adapt existing inspector and group UI to catalog snapshots | [Plan](../plans/feat-043.md) |
| [044](../../features/feat-044.md) | Supported AI taxonomy and durable corrections | Evaluate native coverage; admit only evidence-backed providers | [Plan](../plans/feat-044.md) |
| [045](../../features/feat-045.md) | Combined filters and label editor | Add faceted queries, contextual counts, filtered groups, temporary selection | [Plan](../plans/feat-045.md) |
| [046](../../features/feat-046.md) | Album/label/cleanup actions on exact selections | Reuse operation services; add destination and catalog-action integration | [Plan](../plans/feat-046.md) |
| [047](../../features/feat-047.md) | Complete default flow and recovery | Cut over routes, preserve legacy saved work, close lifecycle gaps | [Plan](../plans/feat-047.md) |

## Readiness decisions

| Feature | Decision before dependent work | Owner |
|---|---|---|
| 040 | Concrete additive schema and snapshot contracts | Data/architecture implementer; user for unresolved product implications |
| 042 | Bounded cross-date retrieval and visual artifact lifetime | Grouping implementer; user approval for changed privacy/storage contract |
| 044 | Exact supported taxonomy, provider admission, evidence limitations | Intelligence implementer; user for unresolved admission/scope decisions |
| 046 | Destination identity migration and supported writable albums | Action-service implementer |

Plans are readiness plans grounded in current code. Concrete future symbols remain proposed until their owning feature records implementation decisions.
The pivot does not require every candidate label or any named external model.
Unsupported capability gaps cannot be closed by presenting build evidence as accuracy evidence.

## Verification and done

Each behavior feature runs `./init.sh` and records its result and limitations.
No test targets, test files, test frameworks, or standalone proof harnesses are added.
Manual QA is optional and never an acceptance criterion, blocker, or release gate.
Feature completion requires all acceptance items, recorded evidence, and an updated progress handoff.

## History and deferred work

feat-001–030 and feat-032–038 remain completed implementation history, not the active product specification.
feat-031 remains blocked and preserved; its Qwen route is not a dependency of this pivot.
Older plans/evidence retain their original context. Their historical gates do not override current verification rules.

Editing, cloud inference, identity recognition, backup/sync, video, natural-language chat/search, and automatic deletion remain outside this pivot.
