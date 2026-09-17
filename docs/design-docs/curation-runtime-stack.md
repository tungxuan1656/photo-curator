# Curation Runtime Stack

**Status:** Current implementation selection for Curation Intelligence V2  
**Architecture owner:** [curation-intelligence.md](curation-intelligence.md)  
**Updated:** 2026-09-17 (feat-024: Tier-C provider shipped, FastViT stays benchmark-only)

This document owns the concrete implementation choices for Curation Intelligence V2: Apple APIs, model candidates, routing, fallbacks, and benchmark decisions. It is deliberately mutable. `curation-intelligence.md` owns the stable architecture; changing a model here does not require changing the architecture when the capability contract stays the same.

Before implementation, re-check API availability and model/license terms against the current SDK/source.

## 1. Status vocabulary

| Status | Meaning |
|---|---|
| **REQUIRED** | Needed by the complete baseline path |
| **SELECTED** | Current implementation choice to build/benchmark; default-on only after gates pass |
| **EXPERIMENTAL** | Concrete candidate for a known hard case; not a commitment to ship |
| **REJECTED** | Evaluated and not worth shipping; keep the record to avoid repeating work |

## 2. Current stack

| Capability | Current implementation | Tier | Population | Status |
|---|---|---:|---:|---|
| Metadata / intent | PhotoKit (`PHAsset`) | A | all | REQUIRED |
| Image loading | `PHCachingImageManager` | A–F | routed | REQUIRED |
| Perceptual similarity | `VNGenerateImageFeaturePrintRequest` | A / shortlist | neighbor pairs + shortlist | REQUIRED |
| Face detection | `VNDetectFaceRectanglesRequest` | A | all/relevant | REQUIRED |
| Face capture quality | `VNDetectFaceCaptureQualityRequest` | A/B | face photos | REQUIRED |
| Blur/exposure/contrast | local image heuristics | A | all | REQUIRED |
| Image aesthetics | Vision image-aesthetics request | A/B | all if cheap enough, else candidates | SELECTED |
| Scene/category | Vision image classification | A/B | all if cheap enough, else candidates | SELECTED |
| Saliency | Vision attention/objectness saliency | B | composition cases | SELECTED |
| Person/foreground masks | Vision subject/person masks | B | people/composition cases | SELECTED |
| Horizon | Vision horizon request | B | landscape/context | SELECTED |
| OCR/document | Vision text/document recognition | B | suspected utility images | SELECTED |
| Lens smudge | Vision lens-smudge request | B | targeted technical cases | EXPERIMENTAL |
| Body pose | Vision body-pose request | B | people/action cases | EXPERIMENTAL |
| Rich visual embedding | native derived embedding (`NativeDerivedEmbeddingProvider`: 8-dim persisted-scalar vector, no model) default-on; FastViT headless family smallest-first stays benchmark-only, not vendored | C | shortlist ≤ 250 assets, ≤ 4,000 pairs | SELECTED (native) / BENCHMARK-ONLY (FastViT) |
| Object/layout specialist | DETR-style segmentation, production-compatible license | D | difficult scenes only | EXPERIMENTAL |
| Depth/context specialist | Depth Anything V2 Small or equivalent | D | difficult cases only | EXPERIMENTAL |
| Precision segmentation | SAM 2.1 Tiny or equivalent | D | rare fallback | EXPERIMENTAL |
| Semantic jury | Foundation Models `SystemLanguageModel` image input | E | 2–6 ambiguous candidates | SELECTED, iOS 27 OPTIONAL |
| High-res verification | targeted PhotoKit load + re-check | F | finalists/borderline rejects | REQUIRED PATH |
| Learned ranker | small Core ML learning-to-rank model | later | only after labels exist | NOT YET JUSTIFIED |

## 3. Routing contract

| Tier | Population | Default work | Escalation |
|---|---:|---|---|
| A — universal | all eligible assets | metadata, technical facts, FeaturePrint, basic faces | cheap selected Vision facts after benchmark |
| B — contextual | relevant subsets | face detail, saliency, horizon, OCR/document, masks | smudge, pose, targeted native facts |
| C — candidate | moment candidates / shortlist ≤ 250 assets, ≤ 4,000 pairs | native derived embedding (no model, no license/size cost) | FastViT pixel-level representation only after its benchmark gate |
| D — difficult | small ambiguous subsets | none by default | object/layout, depth, precision segmentation |
| E — semantic jury | 2–6 images per ambiguity | none on iOS 26 | iOS 27 structured comparison |
| F — verification | finalists/borderline rejects | higher-resolution targeted re-check | missing specialist/native fact |

Every escalation needs a reason: ambiguity, high album impact, missing evidence, or a documented failure mode. Do not run all tools on all assets.

## 4. Failure → tool map

| Failure | Primary | Secondary | Escalation |
|---|---|---|---|
| blur/exposure/unusable frame | local technical facts | aesthetics | high-res verify |
| wrong group winner | face-quality distribution | landmarks/masks/pose | semantic jury |
| near-duplicate leakage | FeaturePrint + time/burst | visual embedding | semantic jury only if meaning differs |
| meaningful variant collapsed | content/layout + embedding | classification/masks | semantic jury |
| transitive cluster collapse | deterministic coherence check | embedding | semantic jury |
| bad moment boundary | time + classification + representation continuity | location | semantic jury |
| repeated scene across trip | global shortlist similarity | embedding + FeaturePrint | normally none |
| landscape/context under-selected | aesthetics + saliency + horizon + category | embedding | specialist if measured gap remains |
| screenshot/document pollution | PhotoKit subtype + OCR/document | classification | deterministic utility policy |
| uncertain high-impact decision | margin/disagreement/coherence | targeted specialist fact | semantic jury / Needs Review |

The cheapest adequate solution wins.

## 5. Native request policy

Required baseline: PhotoKit metadata, FeaturePrint, face rectangles, face capture quality, and current technical heuristics. FeaturePrint is perceptual-nearness evidence only; it must not be treated as semantic equivalence.

Selected native additions: aesthetics, classification, saliency, masks, horizon, OCR/document. Make them universal only if oldest-supported-device benchmarks justify the cost; otherwise route contextually.

Lens smudge is an experimental clue only: never hard-reject solely from it, and benchmark false positives on motion blur, long exposure, and intentional shallow depth of field. Body pose is also contextual, not an all-people-photo requirement.

## 6. Visual embedding provider

The engine depends on the `VisualEmbeddingProvider` capability abstraction (`Domain/Selection/VisualEmbeddingProvider.swift`), never a model-specific domain type. Tier-C routing is bounded by `VisualEmbeddingRouter` (shortlist-scale only: refuses > 250 assets, caps at 4,000 canonical pairs) and `SelectionEngine.select` consumes only explicitly supplied `tierCEdges` for diversity novelty — never cluster membership or moment boundaries. The default (`[]`) is the complete native FeaturePrint fallback. Both production selection paths (`SelectionSessionCoordinator.selectResult` + `finalizeAvailable`) route analyzed assets through `NativeDerivedEmbeddingProvider` via `AppContainer.tierCProvider`; router refusal or empty output falls back to `NoopVisualEmbeddingProvider` (no edges, FeaturePrint fallback exactly). Full decision: DEC-035.

**Selected production representation (feat-024, DEC-035): native derived embedding, wired by default.** Fixed 8-dim vector from already-persisted `PhotoAnalysis` scalars (sharpness, exposure, resolution, aesthetic/horizon/balance nil→0.5, faceCount/6, textLines/10); normalized Euclidean distance + 0.5 penalty when both scenes are known and differ. No pixels, no boxes, no new request, no weights file, no license/size/latency cost, CPU-only scalar math. Vectors are transient (never persisted, never leave the run); only pairwise distances cross as transient `SimilarityEdge` values. Full model record (status, target failure, inputs, fallback, baseline/benchmark evidence, reconsider trigger): `docs/plans/feat-024.md` (Model record section).

**FastViT headless family: benchmark-only, NOT vendored.** Benchmark the smallest practical production-compatible variant first only when a named residual failure shows persisted facts call two frames identical but diversity needs them separated. Before any vendoring, record exact source/version, license and commercial redistribution decision, checksum, Core ML conversion details, input/output, precision, packaged size, compute units, minimum device/OS, latency/memory/thermal measurements, and fallback. License terms must be re-verified at vendoring time; no license/source/version/checksum evidence exists yet because nothing is vendored.

Fallback: FeaturePrint + native facts + deterministic rules (complete; proven identical by the feat-024 fallback/noop proof arms).

## 7. Specialist candidates

DETR-style object/layout, Depth Anything V2 Small (or equivalent), and SAM 2.1 Tiny (or equivalent) are **experimental candidates, not a mandatory model bundle**. Add one only when cheaper native/embedding evidence still leaves a documented failure and the measured quality gain justifies size, latency, memory, thermal cost, and maintenance.

A candidate that fails its gate should be marked REJECTED rather than kept because it is technically impressive.

## 8. iOS 27 semantic jury

**Production target:** Foundation Models `SystemLanguageModel` with image input. Use only for 2–6 ambiguous, high-impact candidates. The iOS 26 path remains complete without it.

Input: supplied images, deterministic candidate IDs, relevant derived facts, moment/cluster context, and one narrow question.

Structured output: `decision = chooseA | chooseB | keepBoth | abstain`, `certainty = clear | ambiguous`, `reasonCodes`, sameMoment/sameSubject/meaningfulVariants, and candidate IDs constrained to the supplied set.

Do not treat model certainty as a calibrated probability. `abstain` is valid. The deterministic engine still enforces technical floor, album size, user override, duplicate invariants, privacy, and fallback.

The production privacy target is on-device `SystemLanguageModel`. Any path that can send photo content to PCC/server/another provider requires a separate explicit privacy/product decision.

## 9. Evaluation-first gate

Before #16–#23 change selection behavior, record the current demo baseline on A–G/Golden per `manual-qa.md` and create a failure inventory.

Every change records: target failure, cheapest candidate solution, baseline cases/metrics, post-change cases/metrics, latency/memory/thermal impact when relevant, and keep/reject/revise decision.

Use Must-Keep Recall, Good Selection Rate, Bad Pick Rate, Duplicate Leakage, Best-Shot Accuracy, Moment Coverage, Human Edit Rate, review time, and subjective score together. A gain in one metric does not justify a material recall or usability regression.

## 10. Current implementation sequence

1. Record demo baseline and failure taxonomy (#24 evaluation phase).
2. Implement/measure selected native Vision additions (#16).
3. Improve people/group logic (#17).
4. Make clustering variant-aware and coherent (#19).
5. Improve semantic moment segmentation (#20).
6. Add global shortlist redundancy/diversity (#21).
7. Introduce FastViT embedding where #19–#21 demonstrate need; benchmark before default-on (#18).
8. Add only specialist models that solve remaining measured failures (#18).
9. Build uncertainty-first review (#22).
10. Add iOS 27 semantic jury for remaining ambiguous high-impact cases (#23).
11. Consider a learned ranker only after enough labels exist and simpler baselines are strong (#24 ranker phase).

Dependencies may move a measured lightweight embedding earlier. No issue requires shipping every candidate.

## 11. Privacy/training boundary

Production user photos/corrections are not global training data under the current privacy policy. Any cross-user training, cloud inference, or new personalization storage requires an explicit owner-doc/decision update.

## 12. Model/API record template

For each selected/replaced/rejected model record: capability, status, target failure, implementation/model, source, version, license, commercial redistribution, checksum, input/output, precision, size, minimum hardware/OS, compute units, tier/routing, load/unload strategy, fallback, baseline evidence, benchmark evidence, decision, reconsider trigger, and last-reviewed date.

## 13. Definition of implementation-ready

An intelligence issue is ready to activate only when it names the observed problem, selected implementation or benchmark candidate, input/output contract, routing tier, fallback, baseline/quality metric, performance gate where relevant, privacy/license decision, affected owner docs/files, and acceptance criteria. Unknown items mean the issue is still research/benchmark work rather than production implementation.
