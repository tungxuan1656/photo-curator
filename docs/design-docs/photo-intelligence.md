# Photo Intelligence

**Status:** Intended evidence contract with observed native baseline · 2026-09-23.
Owns evidence production, label/group interpretation boundaries, and quality claims.
Concrete provider candidates belong to [runtime stack](curation-runtime-stack.md).

## Flow

```text
Photo metadata + bounded oriented pixels
  → independent evidence capabilities
  ├─ visual similarity → comparison groups
  ├─ content classification → versioned label mapping
  └─ technical evidence → technical labels / comparative explanation
  → immutable evidence → rebuildable catalog projections
  → user discovery and explicit decisions
```

Grouping is the primary capability. Labels improve discovery and filtering.
Album target counts, diversity quotas, and selected/rejected decisions do not constrain catalog coverage.

## Observed native baseline

- `VisionAnalysisService` supplies native image evidence and transient FeaturePrint artifacts.
- `UniversalFactAdapter` maps classification output and records classification/aesthetic availability and a semantic mapping revision.
- `PhotoAnalysis.content` contains a scene type and confidence-bearing tags, not a complete user-facing taxonomy.
- `DuplicateResolver` builds time-bounded candidates, checks visual edges and variant consistency, and produces deterministic membership IDs.
- `NativeDerivedEmbeddingProvider` derives eight scalars from existing facts. It is not a learned pixel embedding or semantic image model.
- Session selection still produces representative/album advice around those facts.

This foundation does not establish whole-library duplicate recall, reliable selfie classification, or calibrated beauty judgments.

## Capability boundary

| Capability | Input and output | Forbidden inference |
|---|---|---|
| Metadata | Native asset facts → kind/date/resolution evidence | Guessing known metadata through a language model |
| Visual similarity | Image-derived evidence → candidate edges and coherent groups | Same label or timestamp alone means duplicate |
| Content labels | Image-sensitive AI output → supported taxonomy IDs | Face count alone means selfie or personal identity |
| Technical condition | Pixel/metadata evidence → qualified defect signals | Dark means bad; low resolution means blurred |
| Comparative advice | Same-group evidence → supported reasons or abstention | Representative means mandatory keeper |

Native Vision is an AI provider where it performs image classification.
A new external model is not required merely to use the word AI.
Semantic labels require image-sensitive evidence; scalar similarity and filename rules cannot masquerade as semantic understanding.

## Label production

Each assignment references a stable taxonomy ID, facet, asset revision, provider revision, mapping revision, and evidence state.
Apply label-specific admission thresholds only after evaluating their behavior.
Model scores are not automatically calibrated probabilities and must not be displayed as certainty percentages.

Keep automatic evidence immutable. User corrections live separately and override effective assignments.
Re-analysis can replace automatic evidence, but cannot erase a user confirmation or rejection.
Unsupported labels remain unavailable; empty successful output differs from unavailable inference.

The taxonomy must define positive meaning, exclusions, compatible labels, localization, and source for each enabled label.
Personal relationships are user labels. The app never infers “my children” from a child detector.

## Group production

Maintain separate candidate retrieval for time-local retakes and cross-date near-copies.
Validate candidates with image evidence before exposing a group.
Do not run unbounded library-wide all-pairs comparisons.
A consistency check prevents a chain of locally similar edges from merging unrelated endpoints.

Group output records exact members, relation, evidence reason, grouping revision, and source asset revisions.
Changing a filter does not rerun or redefine grouping.
Missing evidence leaves a photo outside groups with an explicit coverage state.
Exact duplicate wording requires exactness evidence; approximate visual distance supports only near-duplicate wording.

Thresholds and retrieval algorithms are implementation decisions for feat-042, not claims in this contract.
Persisted visual artifacts need the explicit decision described in [data model](data-model.md).

## Shared review input contract

Compatibility suggestions retain stable IDs, exact candidates, source revisions, provenance, evidence status, and a named optional proposal.
Opening a suggestion never changes state.
The new catalog exposes groups and labels directly rather than requiring album suggestions for discovery.
Stale or incomplete proposals cannot enable an apply action.
All choice semantics belong to [review rules](../product-specs/review-rules.md).

## Evidence and quality

| Evidence kind | What it establishes | What it does not establish |
|---|---|---|
| `./init.sh` | Format, strict lint, Simulator compilation | Label accuracy, grouping quality, device fit |
| Source/contract review | Wiring, state boundaries, explicit failure behavior | Image-sensitive correctness |
| Recorded provider/image evaluation, when available | Behavior on the named inputs and revision | Universal accuracy or unseen library performance |
| Device measurement, when available | Named device/resource observations | All-device performance |

Use group coherence, false merges, missed near-copies, per-label precision/recall, abstention, and correction behavior to describe quality.
Report denominators, provider revisions, input provenance, and unknown coverage with any measured result.
No numeric quality threshold is accepted by this rewrite.

Repository policy prohibits new test targets and standalone proof/benchmark harnesses.
Manual QA remains optional. Missing quality measurements must remain explicit, not replaced with compile evidence.
If admission needs an unavailable evaluation method, record the gap and obtain a decision before claiming admission.

## Admission and fallback

Provider admission records artifact/license provenance, image-sensitive evidence, supported labels, resource behavior, cancellation, and fallback.
The feature must not report complete semantic labeling when no provider satisfies the supported taxonomy.
Fallback exposes supported native facts and unknown capabilities; it never fabricates labels.
Qwen remains frozen and unadmitted. Model selection is a separate recorded decision, not implied by this pivot.
