# Curation Intelligence V2

**Status:** Proposed post-MVP quality architecture  
**Minimum OS:** iOS 26  
**Enhanced tier:** iOS 27 when Apple Foundation Models image input is available  
**Goal:** Maximize curation quality while keeping the core workflow private, on-device, measurable, and debuggable.

This document owns the **future intelligence architecture**: which model families and analysis tiers are allowed, how expensive inference is staged, and how semantic judging fits around deterministic selection rules.

It does **not** replace the current owners:

- Selection policy and reason semantics: [selection-rules.md](../product-specs/selection-rules.md)
- Pipeline mechanics and configuration: [selection-engine.md](selection-engine.md)
- Apple API integration details: [apple-frameworks.md](apple-frameworks.md)
- Stored shapes and cache versions: [data-model.md](data-model.md)
- Privacy and retention: [privacy.md](../ship-gates/privacy.md)
- Performance budgets: [performance.md](../ship-gates/performance.md)
- Manual evaluation: [manual-qa.md](../ship-gates/manual-qa.md)
- Build order: [roadmap.md](../exec-plans/roadmap.md)

Before implementation changes any owner rule, update that owner doc first.

---

## 1. Product objective

The engine should behave like a careful human curator, not a generic image-quality sorter.

It must answer different questions with different evidence:

1. **Is this photo technically usable?**
2. **What is in the photo?**
3. **Are these photos visually or semantically redundant?**
4. **Which photo best represents this cluster or moment?**
5. **Does a second photo add meaningful information?**
6. **Does this candidate improve the album as a collection?**
7. **Which decisions are uncertain enough to deserve human review?**

No single global `qualityScore` should answer all seven.

---

## 2. Architecture

```text
PhotoKit metadata
      |
      v
Universal native analysis
(Vision + lightweight image facts)
      |
      +-------------------+
      |                   |
      v                   v
People intelligence   Scene/content intelligence
      |                   |
      +---------+---------+
                |
                v
Similarity + representation layer
(FeaturePrint + licensed Core ML embeddings)
                |
                v
Variant-aware clusters
                |
                v
Semantic moment segmentation
                |
                v
Context-specific ranking
                |
                v
Shortlist
                |
                v
Global shortlist similarity
                |
                v
Album-level diversity optimization
                |
                v
Uncertainty detection
         /              \
        /                \
 deterministic       ambiguous cases
        |                |
        |         specialist models
        |        + optional semantic jury
        \                /
         \              /
             Final album
                |
                v
        Uncertainty-first review
                |
                v
        Golden evaluation loop
```

The selection engine remains the authority for invariants. Models produce facts, representations, probabilities, or structured judgments; they do not silently bypass album rules.

---

## 3. OS strategy

### iOS 26 baseline

Every supported device must be able to finish a complete curation without Foundation Models.

The iOS 26 path should use:

- PhotoKit metadata
- Vision image aesthetics
- Vision image classification
- Vision feature prints
- Face detection and face capture quality
- Face landmarks where proven useful
- Saliency
- Person / foreground masks where proven useful
- Horizon detection
- Lens-smudge detection where supported
- OCR and document recognition
- Body pose for relevant people/action candidates
- Licensed Core ML specialist models after benchmark gates
- Deterministic selection and diversity logic

### iOS 27 enhanced tier

iOS 27 may add a semantic jury using Foundation Models image input for a **small number of ambiguous comparisons**.

It must be:

- availability-gated;
- optional;
- structured-output oriented;
- bounded to small candidate sets;
- backed by deterministic Vision/Core ML facts when possible;
- safe to disable without losing core functionality.

Apple references:

- iOS 27 guide: https://developer.apple.com/wwdc26/guides/ios/
- Image understanding / image-based tool calling: https://developer.apple.com/videos/play/wwdc2026/237/
- Foundation Models updates: https://developer.apple.com/documentation/Updates/FoundationModels

---

## 4. Intelligence tiers

Do not run every model on every photo.

| Tier | Typical population | Purpose |
|---|---:|---|
| A — universal | all input assets | Cheap metadata, aesthetics, classification, FeaturePrint, basic faces, technical facts |
| B — contextual | relevant subsets | Face detail, saliency, horizon, OCR/document, smudge, pose, masks |
| C — candidate | shortlist-scale | Stronger Core ML representation and composition/context features |
| D — difficult cases | ambiguous clusters/moments | DETR/depth/SAM-style specialists or equivalent licensed models |
| E — semantic jury | small ambiguous sets, iOS 27 only | Structured multimodal comparison |
| F — verification | finalists / borderline rejects | Higher-resolution or targeted re-check when evidence is weak |

Routing into a more expensive tier must have a reason: ambiguity, high album impact, missing evidence, or a known failure mode.

---

## 5. Native Vision signal stack

The target signal contract should include independent fields rather than one blended score.

### Technical

- sharpness / blur evidence;
- exposure / clipping evidence;
- resolution and usable-detail evidence;
- lens-smudge probability where supported;
- higher-resolution verification for borderline cases.

### Aesthetic and composition

- image aesthetics score;
- saliency summary;
- foreground / subject coverage;
- horizon evidence;
- composition descriptors derived from masks, depth, and subject layout.

### People

- face count;
- per-face capture quality;
- important-face prominence;
- lower-tail / weakest-important-face quality;
- crop / visibility / obstruction proxies;
- optional face landmarks;
- person masks;
- optional body-pose facts for action/context.

### Content and utility

- image classification labels + confidence;
- OCR text density / text facts;
- document-recognition facts;
- screenshot and media subtype from PhotoKit;
- scene/category facts derived from classification and metadata.

### Similarity

- Vision FeaturePrint distance for perceptual similarity;
- stronger licensed embeddings only where they add measurable value;
- cluster coherence and global-shortlist similarity.

Apple references:

- Vision overview: https://developer.apple.com/machine-learning/
- Vision image classification: https://developer.apple.com/documentation/vision/classifying-images-for-categorization-and-search
- Documents and lens smudge: https://developer.apple.com/videos/play/wwdc2025/272/

---

## 6. People and group-photo intelligence

Group selection is a first-class subsystem.

Do not rank a group photo by the single best face.

For each group candidate, derive:

- count of important faces;
- face-quality distribution;
- lower quantiles / weakest-important-face value;
- visibility and crop quality;
- prominence / size / centrality;
- optional landmark geometry when reliable;
- person-mask coverage and composition;
- pose/action context when useful;
- confidence for every uncertain inference.

Desired behavior:

```text
6 people: 5 excellent + 1 failed important face
should usually lose to
6 people: 6 consistently good faces
```

Do not add face identity, demographic inference, or hard emotion labels.

Eye-state-like heuristics must remain conservative. A candid, laugh, sleep, or downward gaze must not be rejected because a weak landmark proxy guessed incorrectly.

---

## 7. Core ML specialist layer

Core ML is a **quality tool**, not a requirement to use large models everywhere.

Initial model families to evaluate:

| Candidate | Intended role | Routing |
|---|---|---|
| FastViT headless variant | Strong visual representation / embedding backbone | Candidate tier |
| DETR-style segmentation | Object/layout understanding | Difficult scenes |
| Depth Anything V2 Small or equivalent | Depth/context/composition representation | Difficult scenes |
| SAM 2.1 Tiny or equivalent | Precise segmentation if native Vision masks are insufficient | Rare fallback |

Requirements before any model becomes production-default:

1. Verify current redistribution and commercial-use license.
2. Record exact model/version/checksum/source.
3. Measure binary/download size.
4. Measure latency, memory, thermal behavior, and compute-unit choice.
5. Define supported-device fallback.
6. Show measurable quality improvement on Golden / Real Trip evaluation.
7. Keep a complete native-only path.

Apple model catalog: https://developer.apple.com/machine-learning/models/

### Research-only weights

Do not ship model weights whose terms restrict them to research/non-commercial use.

MobileCLIP and FastVLM may be useful as R&D benchmarks, but production inclusion requires a fresh license review at implementation time.

---

## 8. Context-specific scoring

Avoid one universal ranking formula.

Maintain independent feature groups such as:

```text
technicalViability
aestheticQuality
peopleQuality
groupConsistency
compositionQuality
semanticValue
utilityLikelihood
uniqueness
momentImportance
userIntent
```

Then derive task-specific decisions.

### Duplicate / retake representative

```text
representative value =
  technical viability
+ subject-specific quality
+ composition
+ aesthetics
+ user intent
```

### Moment representative

Add moment coverage and representativeness.

### Final album value

Add marginal diversity, global redundancy, temporal coverage, and meaningful variation.

A semantic or aesthetic bonus must never rescue a confidently unusable frame.

---

## 9. Variant-aware clustering

Similarity does not mean “delete the second image.”

The clustering layer must distinguish:

- same image / exact duplicate;
- near-identical retake;
- same subject with meaningful composition difference;
- formal vs candid;
- wide vs close;
- person + landmark vs landmark-only;
- action phases;
- day vs night;
- panorama vs standard;
- detail vs establishing shot;
- materially different group expression/state.

FeaturePrint answers **how visually close** two images are.

Semantic/layout features answer **how they differ**.

The cluster policy answers **whether that difference deserves album space**.

Prevent transitive chain collapse: a cluster must remain coherent even when A≈B and B≈C but A and C are materially different.

---

## 10. Semantic moment segmentation

Moment boundaries should combine:

- time gap;
- shooting density;
- location continuity when available;
- scene classification;
- visual representation similarity;
- FeaturePrint continuity;
- people/subject continuity;
- layout/composition continuity.

Use conservative change-point logic.

Example:

```text
12:01 street
12:02 street
12:03 cafe exterior
12:04 food
12:05 group at table
```

A dense timeline alone should not force this into one moment if semantic and visual signals show a real activity transition.

---

## 11. Global shortlist similarity

Do not run full-library all-pairs comparison.

After the pipeline reduces the set to roughly shortlist scale, compute global similarity among those candidates.

For 250 candidates, the number of unordered pairs is 31,125, which is bounded enough to evaluate compared with full-library all-pairs work.

Use this pass to detect:

- repeated landmark shots taken hours apart;
- repeated portraits across the same setting;
- repeated compositions missed by temporal duplicate windows;
- album-level visual monotony.

Preserve meaningful day/night, wide/detail, person/context, and other distinct variants.

---

## 12. Optional iOS 27 semantic jury

The semantic jury handles **ambiguous, high-impact comparisons**, not bulk ranking.

Example structured output:

```text
sameMoment
sameSubject
meaningfulVariants
bestRepresentativeAssetID
keepTogetherAssetIDs
confidence
reasonCodes
```

Typical inputs:

- 2–6 candidate images;
- Vision/Core ML derived facts;
- moment context;
- deterministic candidate IDs;
- a narrowly-scoped question.

Typical use cases:

- formal vs candid group;
- best group shot when technical and face signals conflict;
- meaningful composition variation;
- ambiguous moment boundary;
- person-with-landmark vs landmark-only;
- whether two high-quality alternatives both add story value.

Whenever practical, let specialist tools measure facts and let the semantic model reason over those facts.

The final engine still enforces:

- technical floor;
- user override;
- duplicate invariants;
- album-size policy;
- privacy rules;
- deterministic fallback.

---

## 13. Uncertainty-first review

The best review UI is not “show every AI decision equally.”

Prioritize decisions by **uncertainty × album impact**.

Candidate uncertainty signals:

- near-tied representative score;
- rule/model disagreement;
- weak cluster coherence;
- group-face conflict;
- ambiguous meaningful variation;
- uncertain moment boundary;
- favorite/edit/user-intent conflict;
- semantic-jury low confidence;
- borderline technical rejection.

The review surface should offer a compact “Needs Review” queue while preserving access to Selected, Similar, and Removed.

The goal is to let automation handle obvious decisions and focus the user on the small number of consequential ambiguous ones.

---

## 14. Evaluation and learning loop

Do not train a custom ranker before the baseline is measured.

Use the existing manual QA datasets plus an annotated Golden set.

Minimum tracked metrics:

- Must-Keep Recall;
- Good Selection Rate;
- Bad Pick Rate;
- Duplicate Leakage;
- Best-Shot Accuracy;
- Moment Coverage;
- Human Edit Rate;
- review time;
- subjective album score on unseen trips.

User corrections are strong supervision:

- swap winner;
- add back;
- remove selected;
- keep both variants;
- moment corrections when exposed.

### Custom Core ML ranker gate

Only after enough representative labels exist, evaluate an on-device learning-to-rank model for:

```text
P(A beats B inside this cluster)
P(A and B should both survive)
P(A belongs in the final album | moment + album context)
```

Inputs can include licensed visual embeddings, Vision facts, metadata, and album context.

Do not ship it unless it beats the deterministic/specialist baseline on held-out trips and has a rollback/fallback path.

---

## 15. Privacy and determinism

Curation Intelligence V2 inherits the existing privacy posture.

- No app-server upload of photo pixels, face data, or embeddings.
- No face identity store.
- No demographic inference.
- No automatic deletion.
- Persist only compact facts allowed by privacy/data-model owners.
- Raw feature prints, face boxes, masks, and large embeddings remain transient unless a future privacy decision explicitly permits otherwise.
- Identical inputs/configuration must have a deterministic fallback result even when an optional semantic model is unavailable.

If an iOS 27 path can invoke any non-local model, it needs a separate explicit privacy/product decision before use. The core path stays on-device.

---

## 16. Implementation order

Implementation is tracked as GitHub issues until the current active repository feature is complete. Do not create a second active feature.

1. [#16 — expand native Vision signal stack](https://github.com/tungxuan1656/photo-curator/issues/16)
2. [#17 — people and group-photo intelligence](https://github.com/tungxuan1656/photo-curator/issues/17)
3. [#18 — Core ML specialist inference layer](https://github.com/tungxuan1656/photo-curator/issues/18)
4. [#19 — variant-aware clustering and representative selection](https://github.com/tungxuan1656/photo-curator/issues/19)
5. [#20 — semantic moment segmentation](https://github.com/tungxuan1656/photo-curator/issues/20)
6. [#21 — global shortlist similarity and album-level diversity](https://github.com/tungxuan1656/photo-curator/issues/21)
7. [#22 — uncertainty-first review](https://github.com/tungxuan1656/photo-curator/issues/22)
8. [#23 — iOS 27 Foundation Models semantic jury](https://github.com/tungxuan1656/photo-curator/issues/23)
9. [#24 — Golden evaluation loop and custom Core ML ranker gate](https://github.com/tungxuan1656/photo-curator/issues/24)

Program epic: [#15](https://github.com/tungxuan1656/photo-curator/issues/15).

Evaluation work for #24 may begin in parallel as data preparation, but a learned ranker must not become a production dependency before the earlier baseline layers are measured.

---

## 17. Ship gates

A new intelligence layer becomes default-on only when it passes all relevant gates:

| Gate | Requirement |
|---|---|
| Quality | Demonstrable gain on targeted Golden/real-trip failures |
| Recall | No unacceptable drop in Must-Keep Recall |
| Privacy | Complies with privacy owner doc and on-device core rule |
| License | Production redistribution/commercial use verified |
| Performance | Oldest supported-device latency/memory/thermal acceptable |
| Reliability | Missing model/request degrades safely |
| Explainability | Decisions expose useful reason/confidence facts |
| Fallback | Complete album still produced without optional tier |

“More AI” alone is not a gate.

---

## 18. Non-goals

- Running every available model on every image.
- Face recognition or person identity.
- Demographic balancing.
- Generic emotion classification as a hard selector.
- Cloud AI as a core requirement.
- Generative retouching.
- Training before Golden evaluation exists.
- Replacing deterministic album invariants with free-form LLM output.
