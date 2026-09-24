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

## Feat-044 approved native label admission

The approved autonomous decision admits only the existing on-device Vision
built-in classifier. `VNClassifyImageRequest` is image-sensitive evidence on
the bounded oriented analysis image; no new model, Qwen path, cloud inference,
or Photos private semantic API is admitted. The researched native classify
request leaves the SDK revision unpinned because the supported API exposes the
OS-selected default; the mapper freezes an explicit raw-identifier-to-app-label
mapping with `vision-scene-map-v2`.

The durable contract identifiers are:

| Revision | Value |
|---|---|
| Source | `vision-classification-observation-v1` |
| Provider | `vision-classify-sdk-default-unpinned` |
| Runtime | `vision-ios26-native-v1` |
| Mapping | `vision-scene-map-v2` |
| Taxonomy | `vision-scene-taxonomy-v1` |
| Durable label layer | `catalog-labels-v7` |

The exact admitted scene IDs are `people`, `group`, `landscape`,
`architecture`, `food`, `animal`, `indoor`, `outdoor`, `document`, and
`screenshot`. No other raw Vision identifier is silently promoted. The
existing mapper's `0.75` confidence floor and `0.10` lead over a competing
supported scene remain the policy; unsupported, tied, or ambiguous output is
unknown. This is not a claim that the full Vision taxonomy is useful or that
the ten labels are calibrated for every library.

V7 makes automatic assignments immutable evidence rows and keeps user state
separate: confirm/reject/restore-automatic overrides are asset-and-label
scoped, personal labels are explicit stable user assignments, and the
effective projection is rebuildable with corrections taking precedence over
current automatic rows. Re-analysis can replace automatic evidence but cannot
erase overrides or personal labels. Pending, unsupported, unavailable, stale,
successful-empty, and successful assignments remain distinct. Metadata facts
retain metadata attribution; personal relationships and family identity are
never inferred.

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
