# Curation Intelligence V2 Parallel Delivery Plan

> **Execution:** Follow `AGENTS.md` until Task 1 is complete. Use one integration feature and no more than four active mini-features after Task 1.

**Goal:** Deliver measured Curation Intelligence V2 improvements with 5–10 people, without conflicting changes to selection contracts or untraceable quality regressions.

**Architecture:** An integration feature owns shared contracts and release evidence. Mini-features own a deep module behind one seam. They merge into the integration branch only after a focused gate. The integration feature alone changes shared pipeline behavior.

**Tech stack:** Swift 5, SwiftUI, PhotoKit, Vision, Core ML, Foundation Models on iOS 27, SwiftFormat, SwiftLint, and manual device QA.

## Global constraints

- Keep all photo processing on device.
- Keep iOS 26 as a complete deterministic path.
- Do not create test targets, `*Test*.swift` files, or test-only architecture.
- Run `./init.sh` for every mini-feature merge and every integration gate.
- Do not persist pixels, face boxes, precise locations, FeaturePrint blobs, or raw embeddings.
- Record model source, version, license, checksum, and benchmark result before default-on use.
- Start selection changes only after the baseline in `feat-017` exists.
- Use the cheapest layer that fixes the measured failure.

---

## 1. Responsibility and reading route

This document owns the Curation Intelligence V2 delivery protocol: concurrency, mini-feature admission, integration gates, evidence, and handoff.

It does not own product behavior, selection policy, pipeline mechanics, stored shapes, API choices, model choices, privacy rules, performance limits, or QA procedures.

| Read first | Read next when |
|---|---|
| This plan | You coordinate V2 work across people or branches. |
| [curation-intelligence.md](../design-docs/curation-intelligence.md) | You change capability architecture or ship gates. |
| [curation-runtime-stack.md](../design-docs/curation-runtime-stack.md) | You add, replace, or benchmark an API or model. |
| [data-model.md](../design-docs/data-model.md) | You persist a fact or change a cache key. |
| [selection-engine.md](../design-docs/selection-engine.md) | You change pipeline order or a selection stage. |
| [manual-qa.md](../ship-gates/manual-qa.md) | You define or run evaluation evidence. |

## 2. Operating model

Use one active integration feature and up to four active mini-features. A mini-feature is an independently reviewable change behind one seam. A new file alone does not make work independent.

```text
baseline evidence
       ↓
contract gate ──→ mini-feature branches (maximum 4)
       ↓                     ↓
integration branch ←─────────┘
       ↓
Golden / Real Trip / device gate
       ↓
keep, revise, reject, or close
```

The integration owner alone changes a shared contract or turns a routed capability on by default.

### Shared contracts

Treat these files and facts as shared contracts:

- `Domain/Models/PhotoAnalysis.swift`
- `Configuration/AppConfiguration.swift`
- `Services/Analysis/VisionAnalysisService.swift`
- `Services/Photos/BatchPipeline.swift`
- `Infrastructure/FileAnalysisCache.swift`
- `Domain/Selection/SelectionEngine.swift`
- `Domain/Models/SelectionResult.swift`
- selection reasons, `analysisVersion`, and `engineVersion`

A mini-feature can prepare an adapter, model package, benchmark, or view behind a stable seam. It must not modify a shared contract without an integration task.

### Roles

| Role | Authority | Normal work |
|---|---|---|
| Integration owner | Contract changes, merge order, default-on decision | Parent feature and integration gates |
| Module owner | One mini-feature seam and exclusive files | Adapter, model provider, or focused UI module |
| QA owner | Dataset labels and metric records | Baseline, Golden, Real Trip, and regression evidence |
| Device owner | Oldest-device cost evidence | Latency, memory, thermal, and fallback exercise |
| Review owner | Independent evidence review | Privacy, version, fallback, and scope review |

One person can hold multiple roles. The integration owner must not approve their own evidence alone.

## 3. Governance adoption

Task 1 changes repository policy. Until this task merges, `AGENTS.md` keeps the one-active-feature rule.

### Task 1: Add the parallel mini-feature policy

**Files:**

- Modify: `AGENTS.md`
- Modify: `feature_index.json`
- Modify: `features/feat-template.md`

**Produces:** a tracker that retains `todo`, `active`, `blocked`, and `done`, while distinguishing an integration feature from a mini-feature.

- [ ] Add `kind: integration` or `kind: mini` to each new V2 record.
- [ ] Add `parent`, `seam`, `exclusive_owns`, and `merge_gate` to each mini-feature record.
- [ ] Limit active records to one `integration` and four `mini` records.
- [ ] Require a completed dependency before activation, unless the record only prepares a detached adapter or evaluation artifact.
- [ ] Require the parent feature file to link every active child record.
- [ ] Keep existing features valid without new fields.
- [ ] Add the mini-feature admission checklist from Section 4 to the feature template.
- [ ] Require `./init.sh` after each mini-feature merge and at parent close.
- [ ] Replace the single-agent review rule with an independent-reviewer rule for integration features.

**Acceptance:**

- [ ] Existing feature records remain readable.
- [ ] A coordinator can identify the parent, seam, exclusive files, and merge gate for every active mini-feature.
- [ ] No mini-feature can claim a shared contract in `exclusive_owns`.
- [ ] `./init.sh` passes.

## 4. Mini-feature admission card

Create a mini-feature only after its parent integration feature is active. Put this card in its feature file.

```markdown
## Mini-feature admission

- Parent: `feat-xxx`
- Seam: `<one module interface>`
- Exclusive owns: `<exact paths>`
- Shared contract task: `<parent task that wires this result>`
- Target failure: `<failure-inventory ID>`
- Input: `<stable facts or candidate IDs>`
- Output: `<compact facts, transient representation, or view state>`
- Fallback: `<native or deterministic result>`
- Version effect: `none | analysisVersion | engineVersion | model record only`
- Focused QA: `<dataset and metric>`
- Merge gate: `<command and manual evidence>`
- Reject condition: `<measured result that ends this candidate>`
```

A mini-feature is ready only when every card field has a concrete value.

Do not open a mini-feature in these cases:

- It changes `PhotoAnalysis`, a pipeline stage, a reason code, or a cache key.
- It changes selection behavior before the parent integration gate.
- It has no baseline failure or focused metric.
- It needs two candidate models to be useful.
- It has no native or deterministic fallback.

Move that work into the parent integration task.

## 5. Branch and merge flow

1. The integration owner creates the parent integration branch from `main`.
2. The integration owner creates a contract commit before module work starts.
3. Each module owner creates one branch from that contract commit.
4. Each module owner changes only `exclusive_owns` files.
5. Each module owner records focused evidence in the child feature file.
6. The integration owner reviews the evidence and merges the child branch into the parent branch.
7. The integration owner applies shared-contract changes in one integration task.
8. The QA owner runs the parent gate against the integrated result.

If a branch needs a shared-contract edit, stop the branch. Move that edit to the parent integration task.

If an integration gate fails, keep the baseline result. Revert or disable the routed capability before the next candidate merge.

## 6. Version and persistence rules

| Change | Owner | Required action |
|---|---|---|
| Per-photo image reading or persisted fact | Integration owner | Bump `analysisVersion`; requeue stale cache and checkpoints. |
| Ranking, clustering, moment, or diversity decision | Integration owner | Bump `engineVersion`; re-rank stored analyses. |
| Model, conversion, or OS revision | Runtime-stack owner | Update the model record and preserve the fallback. |
| Raw FeaturePrint or embedding | Module owner | Keep it transient unless a privacy decision permits persistence. |

The integration gate must make sure that a stale cache requeues work instead of marking an asset unavailable.

## 7. Delivery waves

The planned feature count remains twelve parents. Mini-features increase parallel throughput inside those parents. They do not create mandatory model work.

| Wave | Parent feature | Work and allowed parallel mini-features | Gate |
|---|---|---|---|
| 0 | PR #25, `feat-016` | Merge docs. Close the two remaining `feat-016` manual cases. | PR merged; `feat-016` done. |
| 1 | `feat-017` / #24-P0 | Baseline run, Golden labels, failure taxonomy, metric ledger, device inventory. | Baseline exists before selection changes. |
| 2 | `feat-018` / #16a and `feat-019` / #16b | Native adapters, contextual routing, compact-fact mapping, old-device request cost. | Native facts are interpretable and bounded. |
| 3 | `feat-020` / #17, `feat-021` / #19, `feat-022` / #20 | People facts → variant-aware clusters → semantic moments. Prepare adapters only when the parent seam permits it. | A/D, B/D, and C/Real Trip gates pass in order. |
| 4 | `feat-024` / #18a, then `feat-023` / #21 | `VisualEmbeddingProvider` benchmark before global diversity. Use FeaturePrint fallback. | Embedding gain justifies cost, or FeaturePrint remains selected. |
| 5 | `feat-025` / #18b | Select at most one difficult-case specialist for one measured failure. Mark unhelpful candidates `REJECTED`. | License, device, privacy, fallback, and quality gates pass. |
| 6 | `feat-026` / #22, `feat-027` / #23, `feat-028` / #24-P2 | Needs Review, iOS 27 jury, then ranker decision gate. | Core iOS 26 path stays complete. |

`feat-024` precedes `feat-023` because #21 declares a representation-layer dependency. `feat-025` is conditional. A rejected specialist candidate is a valid completion.

## 8. Allowed mini-feature seams

| Parent | Good mini-feature seam | Parent integration work | Forbidden split |
|---|---|---|---|
| #24-P0 | Dataset label audit, metric ledger, device inventory | Baseline decision and failure taxonomy | Separate metric definitions |
| #16a/#16b | One Vision adapter or one benchmark harness | `PhotoAnalysis` mapping, request routing, cache version | Two branches edit `VisionAnalysisService.swift` |
| #17 | Group-fact calculator behind settled raw facts | Ranking policy and reason codes | Identity or emotion inference |
| #19 | Coherence evaluator or representative evidence calculator | Cluster definition and `DuplicateResolver` wiring | Parallel cluster-policy edits |
| #20 | Boundary-evidence calculator | `MomentBuilder` threshold and stage behavior | Parallel moment-policy edits |
| #18a | `VisualEmbeddingProvider` adapter, conversion record, benchmark runner | Candidate routing and default-on decision | FastViT-specific domain type |
| #18b | One specialist adapter for one failure | Difficult-case routing and fallback | DETR, depth, and SAM in one mini-feature |
| #22 | Queue presentation after the uncertainty input is settled | Queue ranking and feedback persistence | A UI contract that invents uncertainty fields |
| #23 | Availability-gated semantic-jury adapter | Candidate routing and engine enforcement | Full-library semantic inference |

The module interface must hide implementation complexity. `VisualEmbeddingProvider` is a valid seam because the app needs both a model adapter and a FeaturePrint/native fallback. Do not create one public seam for every Vision request.

## 9. Evidence gates

| Change type | Focused evidence before child merge | Parent integration evidence |
|---|---|---|
| Native signal | Target dataset facts, fallback result, oldest-device cost | A + Golden when selection changes |
| Scoring or people | A/D samples and reason review | A + Golden |
| Cluster or representative | B/D samples and coherence cases | B + Golden |
| Moment | C boundary cases | C + Real Trip + Golden |
| Diversity | E cases and shortlist bound | E + Real Trip + Golden |
| Model | Source/license/checksum, packaged size, latency, memory, thermal, fallback | Golden + Real Trip on representative devices |
| Review UI | Queue order, non-blocking save, fact-based copy | Targeted review flow + Golden edit record |
| Pipeline or persistence | Cache requeue, cancellation, resume | Smoke + Golden + Real Trip + 1,000-photo run |

Dataset H reports stability, memory, thermal behavior, cancel, and resume. It does not require every quality metric.

Every merge records the target failure, baseline value, post-change value, cost, decision, and next action. Record durable model decisions in `curation-runtime-stack.md`. Record feature evidence in its feature file and `progress.md` when state changes.

## 10. Team allocation

| Team size | Integration | Build lanes | Evidence lanes |
|---:|---:|---:|---:|
| 5 | 1 owner | 2 module owners | 2 QA/device reviewers |
| 6–7 | 1 owner | 3 module owners | 2 QA/device reviewers; 1 independent reviewer |
| 8–10 | 1 owner | 4 module owners | 2 QA owners; 1 device owner; 1 privacy/license reviewer; 1 independent reviewer |

Rotate roles between parent features. Keep the integration owner fixed for a parent feature.

## 11. Parent close and handoff

Close a parent integration feature only after all accepted child changes merge or all rejected candidates have a recorded decision.

- [ ] Every child feature is `done` or `blocked` with a recorded rejection reason.
- [ ] The parent acceptance criteria pass.
- [ ] `./init.sh` passes on the integrated branch.
- [ ] Required manual evidence is recorded.
- [ ] The runtime stack records every kept, replaced, or rejected model/API candidate.
- [ ] The parent feature file and `progress.md` identify the next parent feature.

At handoff, give the next integration owner the parent feature file, the latest `progress.md` block, the baseline ledger, the runtime-stack record, and the unresolved failure inventory.

## 12. First handoff checklist

1. Merge PR #25.
2. Finish the two fixture-dependent `feat-016` cases.
3. Create and approve the Task 1 governance feature.
4. Activate `feat-017` and lock the baseline ledger.
5. Open only mini-features that pass the admission card.
6. Assign one integration owner before any module branch starts.
