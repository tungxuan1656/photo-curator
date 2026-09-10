# Photo Selection Rules

**Product:** Photos Curator  
**Document:** `03_Photo_Selection_[Rules.md](http://Rules.md)`  
**Status:** MVP Specification  
**Priority:** Required  
**Audience:** iOS engineers, selection-engine developers, product owner  
**Related documents:**

- `01_[PRD.md](http://PRD.md)`
- `02_UX_[Flows.md](http://Flows.md)`
- `04_Selection_Engine_[Design.md](http://Design.md)`
- `06_Data_[Model.md](http://Model.md)`
- `08_Performance_[Spec.md](http://Spec.md)`
- `10_Manual_QA_and_Selection_[Evaluation.md](http://Evaluation.md)`

---

# 1. Purpose

This document defines the rules used by Photos Curator to decide:

1. Which photos should be removed from consideration.
2. Which photos represent duplicates or near-duplicates.
3. Which photos belong to the same photographic moment.
4. Which photo is the best representative of a moment.
5. How portraits and group photos should be handled.
6. How landscape and scene photos should be handled.
7. How the final album should preserve visual, temporal, and semantic diversity.
8. How quality should be balanced against diversity.
9. How deterministic selection decisions should be made when multiple photos are similarly good.

This document defines **selection behavior**, not the implementation architecture.

The implementation pipeline, concurrency strategy, Vision integration, caching, and performance details are defined elsewhere.

---

# 2. Product Goal

The selection engine should behave like a careful human curator reviewing photos after a trip.

Given hundreds or thousands of photos, the engine should produce a substantially smaller collection that:

- removes obvious duplicates;
- removes technically poor photos;
- keeps the best image from repeated shots;
- preserves important people;
- preserves important places and activities;
- avoids excessive repetition;
- preserves the chronological story of the trip;
- includes different compositions and perspectives;
- prefers strong photos without creating an album that feels visually repetitive.

The engine should optimize for:

> **“A small collection that still feels like the whole trip.”**

The engine should **not** optimize only for absolute photographic quality.

A technically perfect album containing 40 nearly identical portraits from one location would be worse than a slightly less technically perfect album that represents the entire trip.

---

# 3. Core Principles

The selection engine MUST follow the following principles.

## 3.1 Quality before diversity

A clearly bad image should not normally be selected simply to satisfy diversity.

For example:

- a severely blurred landscape should not be selected only because it is the only landscape from one location;
- a group photo where most faces are unusable should not be selected solely to represent that group;
- a black or accidental photo should not survive because it occurs during an otherwise uncovered time period.

Diversity operates **after a minimum quality threshold has been satisfied**.

---

## 3.2 Diversity before marginal quality differences

Once multiple images pass the minimum quality threshold, diversity may be more important than small differences in quality.

Example:

Photo A and Photo B show the same person in almost the same composition.

Photo A:

- quality score: 0.91

Photo B:

- quality score: 0.88

Only one should normally survive.

Meanwhile, a different scene with a quality score of 0.82 may be more valuable to the final album than keeping both A and B.

---

## 3.3 Select moments, not individual files

The engine should reason about groups of related photos.

Ten photos taken within several seconds of the same subject are usually one photographic moment, not ten independent album candidates.

The engine should therefore primarily answer:

> “What is the best representation of this moment?”

rather than:

> “Is this individual photo good?”

---

## 3.4 Avoid repetition

Near-identical images provide diminishing value.

The engine should aggressively suppress:

- accidental duplicates;
- burst sequences;
- repeated selfies;
- repeated group poses;
- minor framing variations;
- multiple versions of effectively the same composition.

---

## 3.5 Preserve meaningful variation

Not every visually similar photo is redundant.

Two photos from the same location may both deserve inclusion when they communicate meaningfully different information.

Examples:

- wide landscape + close-up detail;
- formal group portrait + candid interaction;
- front view + rear view of a landmark;
- daytime view + nighttime view;
- person portrait + environment portrait;
- landscape orientation + portrait composition with substantially different content.

---

## 3.6 Prefer stable and explainable behavior

Given the same assets and the same selection configuration, the engine SHOULD produce the same result.

Selection decisions should have machine-readable reason codes so they can later be:

- displayed in the UI;
- logged for analytics;
- inspected during manual QA;
- used for future personalization.

---

# 4. Terminology

## 4.1 Asset

A photo from the user's selected PhotoKit input collection.

An asset may contain:

- image metadata;
- capture timestamp;
- dimensions;
- location metadata when available;
- image analysis;
- face information;
- quality information;
- similarity information.

---

## 4.2 Candidate

An asset that remains eligible for final selection.

---

## 4.3 Rejected Asset

An asset that has been removed from consideration.

Examples:

- exact duplicate;
- severely blurred image;
- accidental black frame;
- inferior member of a duplicate cluster.

---

## 4.4 Duplicate Set

A collection of assets that represent effectively the same underlying image.

---

## 4.5 Near-Duplicate Cluster

A collection of visually very similar images representing the same subject and composition.

Example:

Five photos taken consecutively while a person remains in almost the same pose.

---

## 4.6 Moment

A group of photos representing the same real-world photographic event.

Examples:

- taking a group photo in front of a temple;
- photographing a meal;
- taking several shots of a sunset;
- photographing one person beside a landmark;
- taking ten burst photos while someone jumps.

A moment may contain multiple duplicate or near-duplicate clusters.

---

## 4.7 Keeper

A photo selected as a strong candidate for the final album.

---

## 4.8 Representative

The preferred photo representing a duplicate cluster or photographic moment.

---

## 4.9 Final Album

The collection of photos presented to the user after selection and ranking.

---

# 5. Selection Rule Priority

Rules are applied conceptually in the following priority order:

1. **Asset eligibility**
2. **Hard rejection**
3. **Exact duplicate suppression**
4. **Near-duplicate suppression**
5. **Moment-level selection**
6. **Technical quality**
7. **People and group-photo rules**
8. **Landscape and scene rules**
9. **Meaningful variation**
10. **Diversity balancing**
11. **Chronological coverage**
12. **Final target-count adjustment**
13. **Stable tie-breaking**

A lower-priority rule MUST NOT normally override a high-confidence higher-priority rejection.

For example:

A diversity rule should not rescue a completely blurred duplicate.

---

# 6. Asset Eligibility

The MVP is primarily designed to curate photographic images.

## 6.1 Eligible

Normal camera photos SHOULD be eligible.

This includes:

- standard photos;
- Live Photo still images;
- portrait-mode photos;
- panoramas;
- edited photos;
- RAW-derived images when they can be analyzed normally.

---

## 6.2 Excluded by default

The following SHOULD normally not become final album candidates:

- videos;
- screen recordings;
- screenshots;
- obviously non-photographic system images;
- corrupted or unreadable assets.

The implementation may still retain metadata for these assets so that the UI can explain why they were ignored.

---

## 6.3 Hidden assets

Photos marked as hidden SHOULD NOT be automatically included unless the user explicitly selected a source that includes them and product behavior explicitly allows them.

---

## 6.4 User favorites

A PhotoKit favorite SHOULD be treated as a **soft positive signal**, not an unconditional selection requirement.

A favorite may receive a ranking bonus.

However, the favorite flag MUST NOT automatically force the engine to keep:

- an exact duplicate;
- a severely unusable photo;
- multiple nearly identical frames.

Future personalization may change this policy.

---

# 7. Hard Rejection Rules

Some photos should be rejected before diversity calculations.

Hard rejection should be conservative.

The engine should reject a photo only when there is strong evidence that it has very low curation value.

---

## 7.1 Severe blur

A photo MAY be rejected if blur is severe enough that the intended subject is clearly unusable.

Mild softness MUST NOT automatically cause rejection.

Intentional motion blur must not be treated the same as accidental camera shake whenever the distinction can reasonably be made.

---

## 7.2 Severe exposure failure

The engine MAY reject photos that are effectively unusable because of extreme:

- underexposure;
- overexposure;
- clipping;
- black frames.

Ordinary high-contrast scenes MUST NOT be rejected merely because some highlights or shadows are clipped.

---

## 7.3 Accidental frames

Examples include:

- camera pointed at the floor;
- inside of a pocket;
- mostly blocked lens;
- almost entirely black image;
- accidental transitional image between intended photographs.

Only high-confidence accidental frames should be removed automatically.

---

## 7.4 Corrupted assets

An asset that cannot be decoded or analyzed MUST not block the entire selection operation.

It should be:

- marked unavailable;
- excluded from selection;
- reported through an appropriate reason code.

---

# 8. Exact Duplicate Rules

Exact duplicates provide no additional album value.

Examples:

- duplicate imports;
- copied files;
- multiple assets representing effectively the same image;
- export/re-import of the same photograph.

---

## 8.1 Number retained

For each exact duplicate set:

> **Keep exactly one representative.**

---

## 8.2 Representative preference

When duplicate copies differ in metadata or representation, prefer the version with the greatest useful photographic information.

Suggested priority:

1. valid full-resolution asset;
2. user-edited version when the edit appears intentional;
3. higher usable resolution;
4. better available image representation;
5. stable deterministic tie-breaker.

The engine should avoid selecting both the original and edited derivative when they visually represent the same final photograph.

---

## 8.3 Reason codes

Rejected duplicates should receive:

`exactDuplicate`

The selected representative may receive:

`duplicateRepresentative`

---

# 9. Near-Duplicate Rules

Near-duplicates are different files with almost identical visual content.

Examples:

- rapid consecutive shots;
- minor expression changes;
- tiny framing changes;
- small camera movement;
- burst sequences;
- repeated photos of an unmoving landmark.

---

# 9.1 Default behavior

For a highly similar near-duplicate cluster:

> **Keep one best representative by default.**

---

# 9.2 Keep multiple only for meaningful differences

More than one image MAY survive when the difference changes the value or meaning of the image.

Examples:

### Different expression

One person smiling versus a substantially different candid expression.

### Different interaction

Formal pose versus spontaneous interaction.

### Different subject state

Person standing versus jumping.

### Different composition

Wide environmental portrait versus close portrait.

### Different relevant detail

One photograph emphasizes the people while another emphasizes the landmark.

Minor differences do NOT count.

Examples that normally remain duplicates:

- head rotated by a few degrees;
- tiny crop difference;
- tiny camera shift;
- one frame taken 0.5 seconds later with no meaningful change.

---

# 9.3 Maximum representatives

For a standard near-duplicate cluster:

- preferred: **1**
- exceptional: **2**
- more than 2: generally prohibited

More than two should require the cluster to have been incorrectly grouped or contain multiple meaningful sub-moments.

---

# 10. Burst Photography

Burst sequences should be treated as a strong near-duplicate signal.

The default goal is:

> **Find the strongest frame, not preserve the burst.**

---

## 10.1 Ordinary burst

Keep one photo.

---

## 10.2 Action burst

For movement such as:

- jumping;
- sports;
- dancing;
- running;
- animals moving;
- expressive sequences;

two images MAY be retained when they represent clearly different stages or poses.

The engine should not keep multiple frames simply because individual quality scores are similar.

---

# 11. Moment Detection Rules

Time proximity alone is insufficient to define a moment.

Moment grouping should combine signals such as:

- capture time;
- visual similarity;
- faces;
- subject identity;
- scene;
- composition;
- location when available.

Implementation details belong in `04_Selection_Engine_[Design.md](http://Design.md)`.

---

## 11.1 Strong same-moment evidence

Photos are likely part of the same moment when they:

- occur close together in time;
- show substantially the same people;
- show the same scene;
- contain similar composition;
- represent one obvious photographic activity.

---

## 11.2 Default temporal guidance

Suggested initial configuration:


| Time difference | Interpretation                                          |
| --------------- | ------------------------------------------------------- |
| `0–15 s`        | Very strong same-moment evidence                        |
| `15–45 s`       | Strong same-moment evidence                             |
| `45–180 s`      | Possible same moment; require visual/context similarity |
| `>180 s`        | Increasingly likely to be a new moment                  |


These values are **starting heuristics**, not immutable product rules.

Time MUST NOT be the only grouping signal.

---

# 12. Moment-Level Selection

After a moment is identified, the engine determines how many representatives it deserves.

---

## 12.1 Ordinary moment

Typical:

> Keep 1 representative.

Examples:

- person posing beside landmark;
- one plate of food;
- one stationary object;
- single selfie attempt.

---

## 12.2 Rich moment

Keep up to 2–3 representatives when multiple images provide genuinely different information.

Example:

A family reaches a scenic viewpoint.

Possible representatives:

1. wide landscape;
2. family group photo;
3. candid interaction.

These are part of the same real-world moment but are not redundant.

---

## 12.3 Important moment

Some moments naturally justify more photographs.

Examples:

- wedding-like event during a trip;
- unusual activity;
- performance;
- major landmark;
- group event;
- action sequence.

The MVP SHOULD avoid attempting to infer deep emotional importance.

Instead, importance should primarily emerge from measurable evidence such as:

- photo count;
- people;
- visual variation;
- user favorite signals;
- duration;
- distinct compositions.

---

# 13. Photo Quality Model

Quality is multi-dimensional.

A single metric MUST NOT define photo quality.

The engine should conceptually evaluate:

- sharpness;
- exposure;
- subject visibility;
- face quality;
- eye state when reliably detectable;
- obstruction;
- composition;
- camera stability;
- aesthetic quality when available.

---

# 14. Quality Score

A normalized internal score may be represented as:

`qualityScore ∈ [0, 1]`

Example conceptual model:

```text
qualityScore =
    sharpnessScore
  + exposureScore
  + subjectScore
  + faceScore
  + compositionScore
  + aestheticScore

```

with implementation-defined weights.

This document does not mandate the exact numerical formula.

The engine design document should define how these signals are computed.

---

# 15. Quality Tiers

Using only one precise score tends to make selection fragile.

The engine SHOULD reason in approximate tiers.

Example:


| Tier       | Meaning                                |
| ---------- | -------------------------------------- |
| Excellent  | Strong final-album candidate           |
| Good       | Suitable candidate                     |
| Acceptable | Can be selected for coverage/diversity |
| Poor       | Usually reject                         |
| Unusable   | Reject                                 |


This lets diversity influence selection among photos that are all reasonably acceptable.

---

# 16. Face and Portrait Rules

Photos containing people require additional rules because small facial defects strongly affect perceived photo quality.

---

# 16.1 Portrait preference

When comparing otherwise similar portraits, prefer:

- sharper face;
- unobstructed face;
- natural expression;
- eyes open when appropriate;
- better illumination;
- stronger composition.

---

# 16.2 Eyes closed

Closed eyes SHOULD be treated as a negative signal when:

- the person is clearly posing;
- a better alternative exists.

Closed eyes MUST NOT automatically cause rejection.

Examples where closed eyes may be intentional:

- laughing;
- candid moment;
- sleeping;
- emotional expression;
- looking downward.

---

# 16.3 Face obstruction

Strong facial obstruction is a negative signal.

Examples:

- face hidden behind another person;
- finger covering face;
- face cut off accidentally.

Intentional partial framing should not automatically be penalized.

---

# 16.4 Multiple portraits of the same person

The final album SHOULD avoid excessive repetition of the same person in the same:

- location;
- pose;
- composition;
- moment.

However, the same person may appear repeatedly across different parts of a trip.

The goal is not equal representation of every person.

The goal is avoiding visually redundant representation.

---

# 17. Group Photo Rules

Group photos require different scoring from single-person portraits.

A group photo should not be considered strong merely because one face looks excellent.

The weakest important faces matter.

---

# 17.1 Preferred group photo

Among similar group photos, prefer the image with the best overall combination of:

- face sharpness;
- face visibility;
- open eyes when appropriate;
- natural expressions;
- complete framing;
- absence of major obstruction;
- technical image quality.

---

# 17.2 Group fairness principle

The group-photo score SHOULD penalize cases where one or more clearly visible people have serious defects.

For example:

Photo A:

- four people look excellent;
- one person has eyes closed.

Photo B:

- all five look good.

Photo B should normally win even if Photo A has slightly better global sharpness.

---

# 17.3 Repeated group poses

If the user takes ten versions of the same group pose:

> Normally keep exactly one.

Two MAY survive if:

- expressions are meaningfully different;
- the compositions differ;
- one is formal and one is candid.

---

# 18. Selfie Rules

Selfies should follow the same duplicate and quality rules as portraits.

The engine MUST NOT treat selfies as inherently less valuable than photos taken with the rear camera.

However, repeated selfies at the same location should be aggressively deduplicated.

Example:

20 similar selfies in front of one landmark should normally result in approximately one representative, or two if compositions are meaningfully different.

---

# 19. Landscape Rules

Landscape selection should prioritize both photographic quality and scene diversity.

---

## 19.1 Repeated landscape shots

Multiple nearly identical photos of the same scene should normally produce one keeper.

---

## 19.2 Different compositions

Multiple photographs of the same location MAY be kept when their compositions communicate different information.

Examples:

- wide panorama;
- medium landscape;
- architectural detail;
- foreground subject with environment;
- day versus sunset.

---

## 19.3 Small framing changes

Tiny differences in:

- zoom;
- crop;
- camera angle;
- horizon position;

do not normally justify multiple selections.

---

## 19.4 Landscape quality considerations

Relevant signals include:

- sharpness;
- exposure;
- excessive clipping;
- horizon stability where applicable;
- visual obstruction;
- composition;
- aesthetic score.

A slightly tilted horizon MUST NOT by itself result in automatic rejection.

---

# 20. Landmark and Architecture Rules

Repeated documentation of a landmark can easily dominate a trip album.

The engine should distinguish:

- full landmark;
- contextual view;
- architectural detail;
- person with landmark;
- alternative perspective.

These can be meaningful separate candidates.

Near-identical facade photos should be deduplicated.

---

# 21. Food and Object Photos

Repeated photos of the same food or object should usually be treated as one moment.

Keep one representative unless the images show meaningful differences.

Example:

For a meal:

- whole-table photograph;
- close-up of a special dish;

may both be useful.

Five close-ups of the same plate usually are not.

---

# 22. Document and Utility Images

Trip photo libraries sometimes contain:

- tickets;
- maps;
- receipts;
- QR codes;
- parking locations;
- informational signs.

These photos may have utility value but low album value.

For the MVP, the selection engine SHOULD avoid prioritizing obvious utility/document images for the final curated album.

However, uncertain cases should not be aggressively removed.

This is not a document-classification product.

---

# 23. Meaningful Variation

Meaningful variation is one of the most important concepts in the selection engine.

Two visually related photos should both survive only when the second contributes something the first does not.

---

## 23.1 Meaningful variation examples

Keep both:

```text
Wide beach landscape
+
Portrait of traveler on the beach

```

Keep both:

```text
Family group portrait
+
Candid family interaction

```

Keep both:

```text
Temple exterior
+
Architectural detail

```

Keep both:

```text
Daytime city skyline
+
Nighttime skyline

```

---

## 23.2 Non-meaningful variation examples

Keep only one:

```text
Portrait A
+
Portrait B taken 1 second later with tiny head movement

```

Keep only one:

```text
Landscape A
+
Landscape B with 3% framing difference

```

Keep only one:

```text
Group photo
+
Nearly identical group photo with negligible expression change

```

---

# 24. Diversity Model

The final album should preserve diversity across several dimensions.

The engine SHOULD consider:

1. temporal diversity;
2. scene diversity;
3. people diversity;
4. composition diversity;
5. subject diversity;
6. visual diversity.

These dimensions do not need separate complex ML models in the MVP.

They may be represented through available metadata and image-analysis signals.

---

# 25. Temporal Diversity

A long trip should not have most of its selected photos concentrated within one short period unless the source library itself is concentrated there.

The selection engine SHOULD attempt to preserve representative moments throughout the selected time range.

Example:

If a user selects photos covering seven days, the final album should normally contain usable photographs from multiple days.

---

# 26. Chronological Coverage

Chronological coverage is a soft constraint.

The engine should ask:

> “Are there major sections of the trip with good photos but no selected representatives?”

If yes, the engine MAY promote a good candidate from the underrepresented period.

It MUST NOT promote clearly poor photos simply to fill a timeline gap.

---

# 27. Scene Diversity

Similar scenes should not unnecessarily dominate the album.

Example source:

- 300 beach photos;
- 100 city photos;
- 50 restaurant photos;
- 50 museum photos.

The final album does not need to reproduce the exact source ratio.

The engine should reduce repetitive scenes more aggressively than unique scenes.

---

# 28. People Diversity

The engine should avoid selecting many highly similar photos involving the same people while omitting other meaningful moments.

However:

> **People diversity is not demographic balancing.**

The engine does not need to identify or enforce equal representation among individuals.

It only needs to reduce redundancy.

---

# 29. Composition Diversity

The album should contain a natural mixture of compositions when available.

Examples:

- wide;
- medium;
- close-up;
- portrait;
- group;
- environmental portrait;
- landscape;
- detail.

The engine MUST NOT enforce fixed quotas for composition types.

Diversity should emerge through redundancy reduction and coverage.

---

# 30. Orientation Diversity

Portrait and landscape orientation can contribute to visual variation.

However, orientation itself MUST NOT be a reason to select an otherwise redundant image.

Example:

Two near-identical photographs where one is landscape and one is portrait may both survive only when their content or composition differs meaningfully.

---

# 31. Day/Night Diversity

When the same place is photographed under meaningfully different lighting conditions, both versions may be valuable.

Examples:

- sunrise;
- daytime;
- sunset;
- nighttime illumination.

This is stronger evidence of meaningful variation than a minor framing change.

---

# 32. Diversity Must Not Become a Quota System

The MVP MUST NOT require rules such as:

```text
20% portraits
20% landscapes
20% food
20% group photos
20% architecture

```

Such quotas produce unnatural albums.

Instead, diversity should primarily be achieved by:

- duplicate suppression;
- moment grouping;
- repetition penalties;
- coverage bonuses.

---

# 33. Repetition Penalty

As similar selected photos accumulate, additional photos from the same cluster, moment, scene, or composition should become progressively less valuable.

Conceptually:

```text
candidateValue =
    baseQuality
  + diversityBonus
  + coverageBonus
  - duplicatePenalty
  - repetitionPenalty

```

The exact numerical formula belongs in `04_Selection_Engine_[Design.md](http://Design.md)`.

---

# 34. Quality vs. Diversity Example

Suppose a final album has room for one more photo.

Candidate A:

- same landmark already represented three times;
- excellent quality;
- score 0.94.

Candidate B:

- unique activity not yet represented;
- good quality;
- score 0.86.

Candidate B should often be preferred because it contributes substantially more album information.

However:

Candidate C:

- unique activity;
- severely blurred;
- score 0.31.

Candidate C should normally not be selected simply for diversity.

---

# 35. Target Album Size

Selection rules should accept a `targetCount` from the product/UX layer whenever available.

The rules defined here should work regardless of whether the requested output is:

- 30 photos;
- 50 photos;
- 100 photos;
- another supported size.

---

## 35.1 When target count is smaller

The engine should progressively favor:

1. strongest moments;
2. strongest representatives;
3. broad coverage;
4. high diversity.

Repeated content should disappear first.

---

## 35.2 When target count is larger

The engine may progressively include:

- secondary representatives from rich moments;
- alternative compositions;
- additional good candid photographs;
- additional landscape variants.

It should not refill the album with obvious duplicates merely to reach an exact count.

---

# 36. Target Count Is a Goal, Not an Absolute Requirement

If there are fewer than `targetCount` genuinely useful images, the engine MAY return fewer photos.

Example:

A source contains 100 images, but 80 are copies or failed burst frames.

The engine should not create 50 poor selections simply because the requested count is 50.

---

# 37. User Intent Signals

The MVP may use lightweight existing user intent signals.

Examples:

- Favorite status;
- user-created edits;
- explicit inclusion during review;
- explicit exclusion during review.

---

## 37.1 Explicit user action has highest priority

If the user manually selects a photo during the review process:

> The engine MUST preserve the user's explicit decision unless the asset becomes unavailable.

Similarly, an explicitly removed photo should remain removed during that selection session.

---

## 37.2 Favorite

Favorite is a soft signal.

Suggested behavior:

```text
favoriteBonus > 0

```

but:

```text
favorite != forcedSelection

```

---

## 37.3 Edited image

An intentionally edited image may receive a small positive preference when compared with its original or near-identical alternative.

The engine should not attempt to judge whether the user's edit was aesthetically correct.

The edit itself represents user intent.

---

# 38. Previously Selected Photos

Within one curation session, user feedback should override automatic rules.

Example:

The engine chooses photo A from a duplicate pair.

The user replaces it with photo B.

Subsequent recomputation during that session SHOULD preserve B whenever possible.

Long-term personalization is outside the MVP unless explicitly defined elsewhere.

---

# 39. Stable Tie-Breaking

Two candidates may receive nearly identical evaluation.

The result should still be deterministic.

Suggested tie-breaking sequence:

1. explicit user selection;
2. stronger quality tier;
3. higher quality score;
4. intentional edit preference;
5. favorite preference;
6. higher usable resolution where relevant;
7. stable asset identifier ordering.

Creation time SHOULD NOT randomly cause repeated changes between runs.

---

# 40. Confidence

Some decisions have much stronger evidence than others.

The engine SHOULD internally distinguish confidence.

Example:

### High confidence

- exact duplicate;
- completely blurred burst frame;
- identical repeated photo.

### Medium confidence

- one expression clearly better than another;
- two photos probably represent the same moment.

### Low confidence

- aesthetic preference;
- which of two different compositions is more meaningful.

Low-confidence differences should allow diversity to play a larger role.

---

# 41. Selection Reason Codes

Every automatic keep/reject decision SHOULD expose a primary reason.

Recommended initial reason codes:

## Eligibility

```text
unsupportedAsset
assetUnavailable
corruptedAsset

```

## Quality rejection

```text
severeBlur
severeUnderexposure
severeOverexposure
accidentalFrame
lowQuality

```

## Duplicate handling

```text
exactDuplicate
duplicateRepresentative
nearDuplicate
nearDuplicateRepresentative
burstRejected
burstRepresentative

```

## Moment selection

```text
bestInMoment
secondaryMomentRepresentative

```

## People

```text
bestPortrait
bestGroupPhoto
betterFaceQuality

```

## Scene

```text
bestLandscape
bestSceneRepresentative

```

## Diversity

```text
sceneDiversity
peopleDiversity
compositionDiversity
temporalCoverage
meaningfulVariation

```

## User intent

```text
userSelected
userExcluded
favoriteBoost
editedVersionPreferred

```

Reason codes should be stable enough to be stored in analytics and QA logs.

---

# 42. Primary and Secondary Reasons

A decision MAY contain:

```text
primaryReason
secondaryReasons[]

```

Example:

```text
primaryReason: bestGroupPhoto

secondaryReasons:
- betterFaceQuality
- nearDuplicateRepresentative

```

This is useful because a photo may survive for several reasons.

---

# 43. Rule Conflicts

When rules conflict, use the following conceptual priority.

```text
Explicit user decision
        ↓
Asset eligibility
        ↓
Hard technical failure
        ↓
Exact duplicate suppression
        ↓
Near-duplicate suppression
        ↓
Moment representation
        ↓
Quality
        ↓
Meaningful variation
        ↓
Diversity
        ↓
Coverage
        ↓
Target count

```

This hierarchy prevents lower-value objectives from producing obviously incorrect results.

---

# 44. Examples

## Example 1 — Ten nearly identical portraits

Input:

```text
10 photos
Same person
Same location
12 seconds
Similar pose

```

Expected:

```text
1 selected
9 rejected as near duplicates

```

Exception:

Two may survive when one is a formal portrait and another is a meaningfully different candid expression.

---

# 45. Example 2 — Group photo sequence

Input:

```text
Photo A: one person blinking
Photo B: everyone visible, good expressions
Photo C: slight blur
Photo D: nearly identical to B

```

Expected:

```text
Select B.
Reject A, C, D.

```

Primary reason:

```text
bestGroupPhoto

```

---

# 46. Example 3 — Landscape viewpoint

Input:

```text
5 similar wide landscapes
1 panoramic landscape
1 traveler portrait with landscape
1 close-up architectural detail

```

Possible result:

```text
1 best wide landscape
1 panorama if meaningfully different
1 traveler portrait
1 detail photo

```

Do not retain all five wide landscapes.

---

# 47. Example 4 — Action burst

Input:

```text
20 frames of a person jumping.

```

Expected:

Select the best peak-action frame.

Optionally select a second frame only if it represents a substantially different phase or expression and adds value.

Do not treat 20 technically sharp burst images as 20 independent album candidates.

---

# 48. Example 5 — Seven-day trip

Input:

```text
Day 1: 200 photos
Day 2: 80 photos
Day 3: 300 photos
Day 4: 20 photos
Day 5: 250 photos
Day 6: 100 photos
Day 7: 50 photos

```

The final album should not mechanically preserve those proportions.

However, good photographs from Days 2, 4, 6, and 7 should not disappear merely because Days 1, 3, and 5 contain more photos.

---

# 49. Example 6 — Quality vs coverage

Input:

```text
Morning:
30 excellent repetitive portraits.

Afternoon:
5 good museum photos.

Evening:
15 good city photos.

```

Bad result:

```text
40 morning portraits
5 afternoon/evening photos

```

Better result:

```text
Small number of morning portraits
Representative museum photos
Representative evening photos

```

---

# 50. Example 7 — Poor unique photo

Input:

```text
Only photograph from Location X:
severely blurred and unusable.

```

Expected:

Do not automatically select it solely for geographic or chronological coverage.

Coverage cannot override the quality floor.

---

# 51. Example 8 — Favorite duplicate

Input:

```text
Photo A: favorite
Photo B: near-identical
Photo B has slightly higher technical score

```

Expected:

Photo A may win because favorite status indicates user intent, assuming Photo A remains technically acceptable.

If Photo A is severely defective and Photo B is clearly usable, Photo B may still win.

---

# 52. Example 9 — Original and edited version

Input:

```text
Original photo
User-edited version of the same photo

```

Expected:

Normally select the edited version if it represents an intentional user edit and has no significant quality problem.

Do not include both merely because they are separate PhotoKit assets.

---

# 53. Example 10 — Same landmark across the day

Input:

```text
Morning landmark photo
Midday landmark photo
Sunset landmark photo
Night illumination

```

These should not automatically be classified as redundant.

Meaningfully different lighting and atmosphere may justify multiple selections.

---

# 54. Default Tunable Parameters

The following values are initial engineering defaults, not permanent product commitments.


| Parameter                          | Initial behavior                                           |
| ---------------------------------- | ---------------------------------------------------------- |
| Exact duplicate representatives    | 1                                                          |
| Near-duplicate representatives     | 1                                                          |
| Near-duplicate exceptional maximum | 2                                                          |
| Ordinary moment representatives    | 1                                                          |
| Rich moment representatives        | 2–3                                                        |
| Strong same-moment temporal window | approximately 45 seconds                                   |
| Extended same-moment window        | up to approximately 180 seconds with contextual similarity |
| Severe quality failure             | reject                                                     |
| Favorite                           | soft positive signal                                       |
| Edited version                     | soft positive signal                                       |
| User manual selection              | hard override                                              |
| User manual exclusion              | hard override                                              |


Thresholds MUST be centralized in selection configuration rather than scattered across the codebase.

---

# 55. Configuration Philosophy

The MVP should use a small number of understandable parameters.

Avoid introducing dozens of independent thresholds before manual evaluation demonstrates that they are necessary.

Prefer parameters such as:

```text
duplicateSimilarityThreshold
nearDuplicateSimilarityThreshold
momentTimeThreshold
minimumQualityThreshold
diversityWeight
coverageWeight
repetitionPenalty
favoriteBonus
targetCount

```

rather than many specialized micro-rules.

---

# 56. Rule Design Guidelines for Implementation

Selection rules SHOULD be:

- deterministic;
- independently understandable;
- configurable;
- explainable;
- cheap enough to apply to thousands of images;
- robust when metadata is missing.

Rules SHOULD NOT assume that:

- GPS data always exists;
- face detection always succeeds;
- capture timestamps are perfect;
- aesthetic scoring is always reliable;
- every photo contains a recognizable semantic category.

---

# 57. Missing Metadata

Missing metadata MUST NOT automatically reduce the quality of a photo.

Example:

A strong photo without GPS data should not lose to a weaker photo solely because the weaker one has location metadata.

Metadata should assist grouping and coverage, not define photographic quality.

---

# 58. Missing Face Analysis

Failure to detect a face does not mean that an image contains no valuable person.

The engine should gracefully fall back to:

- general visual similarity;
- scene analysis;
- image quality;
- timing;
- other available information.

---

# 59. Avoid False Precision

The engine MUST NOT treat tiny score differences as objectively meaningful.

Example:

```text
Photo A = 0.8731
Photo B = 0.8718

```

This does not imply Photo A is meaningfully better.

When candidates are within a small effective quality margin, other criteria such as:

- diversity;
- user intent;
- expression;
- moment coverage;

may decide the winner.

---

# 60. Do Not Optimize for Aesthetic Score Alone

An aesthetic model may prefer:

- sunsets;
- strong compositions;
- bright portraits.

But a travel album also needs documentary value.

Important but less “Instagram-worthy” photos may be essential to the story.

Therefore:

```text
aestheticScore != selectionScore

```

Aesthetic quality is only one input.

---

# 61. Do Not Optimize for Face Count

A photo containing many faces is not automatically more important.

Likewise, landscape photos without people must remain fully eligible.

The engine should support albums that contain:

- mostly people;
- mostly landscapes;
- mixed travel photography;
- architecture;
- food;
- events;

without assuming one category is universally preferred.

---

# 62. Do Not Force Category Balance

The engine should reflect what the user actually photographed.

Example:

If a trip contains almost exclusively wildlife photography, the engine should not artificially search for portraits, food, or architecture simply to make the album “balanced.”

Diversity means:

> removing unnecessary repetition while preserving meaningful variation.

It does not mean manufacturing categories that do not exist.

---

# 63. Final Selection Invariants

The MVP selection engine SHOULD satisfy the following invariants.

### Invariant 1

Exact duplicates should never both appear in the final album.

### Invariant 2

Highly similar near-duplicates should rarely both appear.

### Invariant 3

Severely unusable images should not normally appear.

### Invariant 4

A burst sequence should not dominate the final album.

### Invariant 5

A repeated group-photo attempt should normally produce one representative.

### Invariant 6

A repeated portrait attempt should normally produce one representative.

### Invariant 7

Meaningfully different photographs from the same location may coexist.

### Invariant 8

Diversity must not override severe technical failure.

### Invariant 9

Small quality differences should not override major diversity benefits.

### Invariant 10

Explicit user decisions must override automatic selection.

### Invariant 11

Running the engine repeatedly with identical inputs and configuration should produce stable results.

### Invariant 12

The final album should represent multiple meaningful moments whenever such moments exist in the source collection.

---

# 64. Manual Validation Scenarios

These scenarios should eventually appear in greater detail in:

`10_Manual_QA_and_Selection_[Evaluation.md](http://Evaluation.md)`

They are listed here to establish expected rule behavior.

The selection engine should be manually evaluated using libraries containing:

- hundreds of near-duplicate portraits;
- burst photography;
- repeated group photos;
- landscape-heavy trips;
- people-heavy trips;
- trips across multiple days;
- low-light photos;
- screenshots mixed with camera photos;
- edited/original duplicates;
- Live Photos;
- photos without GPS;
- photos without detectable faces;
- favorite images;
- mixed portrait/landscape compositions;
- highly repetitive source libraries;
- small source libraries;
- 1,000+ photo libraries.

No automated unit-test or UI-test target is required for these scenarios.

Evaluation is performed through manual QA and selection-quality review.

---

# 65. MVP Non-Goals

This rule set does NOT attempt to solve:

- professional photography editing;
- automatic color correction;
- photo retouching;
- sophisticated emotional-event detection;
- perfect identity recognition;
- demographic balancing;
- professional wedding-photo curation;
- cloud-scale image search;
- natural-language photo understanding;
- long-term personalization;
- learning individual aesthetic preferences from a large behavioral history;
- generative image enhancement.

These capabilities may be considered later if they clearly improve selection quality.

---

# 66. Future Personalization

A future version may learn user preferences such as:

- prefers portraits;
- prefers landscapes;
- prefers candid photos;
- prefers fewer photos;
- frequently restores selfies;
- frequently removes food photos;
- prefers particular compositions.

Personalization should modify ranking and diversity weights.

It SHOULD NOT bypass fundamental safety rules such as exact duplicate suppression.

Conceptually:

```text
FinalSelectionScore =
    GenericSelectionScore
  + UserPreferenceAdjustment

```

This is outside the MVP selection logic.

---

# 67. Recommended MVP Decision Model

The overall behavior can be summarized conceptually as:

```text
for each input asset:
    check eligibility

reject obvious unusable assets

group exact duplicates
keep one representative per group

group near duplicates
keep strongest meaningful representatives

group photos into moments

for each moment:
    rank candidates
    preserve meaningful variation
    generate moment representatives

combine representatives

apply:
    quality floor
    repetition penalties
    diversity bonuses
    chronological coverage bonuses
    user-intent signals

select toward targetCount

apply stable tie-breaking

return final album

```

This pseudocode describes rule semantics only.

The detailed engine pipeline belongs in `04_Selection_Engine_[Design.md](http://Design.md)`.

---

# 68. Product Definition of a Good Result

A successful selection should cause the user to feel:

> “These are mostly the photos I would have chosen myself, and I did not have to review all of them.”

A good final album should therefore have four characteristics:

### 1. Low redundancy

Very few photographs feel interchangeable.

### 2. High technical acceptability

Obvious failed images are absent.

### 3. Strong coverage

The important parts of the selected time period remain represented.

### 4. Natural diversity

The album contains enough variation to feel like a visual story rather than a collection of isolated high-scoring images.

---

# 69. MVP Rule Summary

The core MVP behavior can be reduced to the following rules:

1. Remove unusable assets.
2. Keep only one exact duplicate.
3. Keep one representative from near-identical sequences.
4. Group related photos into moments.
5. Select the strongest representative of each moment.
6. Prefer good faces for portraits and group photos.
7. Keep multiple photos from a moment only when they add meaningful information.
8. Penalize repeated people, scenes, and compositions.
9. Preserve good photos across the chronology of the trip.
10. Prefer diversity when competing photos have similar quality.
11. Never use diversity to rescue obviously bad photos.
12. Respect explicit user decisions.
13. Keep the algorithm deterministic and explainable.
14. Treat all numerical thresholds as tunable configuration.
15. Keep the MVP simple enough to understand, debug, and manually evaluate.

---

# 70. Definition of Done

`03_Photo_Selection_[Rules.md](http://Rules.md)` is considered implemented when the selection engine can consistently perform the following:

- identify and suppress exact duplicates;
- identify and suppress obvious near-duplicates;
- reduce burst sequences;
- identify photographic moments;
- select strong moment representatives;
- prefer stronger portrait and group-photo variants;
- reduce repeated landscape compositions;
- preserve meaningful composition differences;
- maintain reasonable chronological coverage;
- prevent one repetitive moment from dominating the output;
- respond to a requested target album size;
- respect explicit user selection/exclusion;
- produce stable decisions;
- attach explainable reason codes to important decisions;
- process the rules without requiring cloud-based intelligence;
- support manual evaluation using realistic libraries containing approximately 1,000–5,000 photos.

The implementation should remain deliberately simple until real manual-selection evaluation demonstrates a need for additional complexity.