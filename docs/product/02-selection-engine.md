# photos-curator — Selection Engine Specification

**Document:** `docs/product/02-selection-engine.md`  
**Product:** `photos-curator`
**Platform:** iOS / iPhone
**Status:** Draft
**Version:** 0.1
**Stage:** MVP

---

# 1. Purpose

This document defines the selection engine responsible for converting a large input photo collection into a smaller curated collection.

Example:

```text
Input
1,024 photos

Target
~200 photos

Output
187 curated photos
```

The selection engine is the core differentiating component of `photos-curator`.

Its responsibility is not simply to assign an aesthetic score to every image.

Its responsibility is to answer three progressively harder questions:

```text
1. Which photos represent the same photographic moment?

2. Within each moment, which photo is the best representation?

3. Across all moments, which combination of photos creates the best final collection?
```

The engine should prioritize reliable relative decisions over ambitious but unreliable absolute judgments.

---

# 2. Core Design Principle

The MVP should not attempt to solve:

&gt; “How beautiful is this photo?”

as its primary problem.

Instead, it should solve:

&gt; “Are these photos showing approximately the same moment?”

and then:

&gt; “Which of these similar photos is the strongest one?”

This distinction is important.

Choosing the best photo among six nearly identical photos is usually more tractable than determining whether a single photo is universally “good.”

The MVP should therefore be built around:

```text
Similarity
    ↓
Clustering
    ↓
Within-cluster ranking
    ↓
Global selection
```

rather than:

```text
Aesthetic model
    ↓
Sort all photos
```

---

# 3. Selection Engine Goals

The engine should:

- identify near-duplicate and highly similar photos;
- group photos representing approximately the same moment;
- select a strong representative from each group;
- penalize obvious technical failures;
- handle portraits differently from non-portrait images where useful;
- preserve visual and temporal variety;
- avoid filling the final album with one scene;
- respect the approximate requested target size;
- provide enough internal information for explainable UI;
- operate primarily on-device;
- remain computationally reasonable for approximately 100–2,000 photos.

---

# 4. Non-Goals

The MVP selection engine does not need:

- professional photography critique;
- perfect aesthetic scoring;
- human identity recognition;
- face recognition databases;
- emotion recognition;
- reliable blink detection;
- semantic understanding of every event;
- cloud inference;
- large language models;
- generative AI;
- custom model training infrastructure;
- vector databases;
- approximate-nearest-neighbor servers;
- remote embeddings;
- photo deletion logic;
- personalized ranking models;
- automated learning from user behavior.

These features should only be considered after the basic selection engine proves useful.

---

# 5. High-Level Pipeline

The complete pipeline is:

```text
PHAsset Collection
       │
       ▼
Asset Preparation
       │
       ▼
Analysis Image Loading
       │
       ├───────────────┐
       │               │
       ▼               ▼
Metadata           Image Analysis
       │               │
       │        ┌──────┴───────────────┐
       │        ▼                      ▼
       │   Quality Signals       Feature Print
       │        │                      │
       └────────┴──────────┬───────────┘
                           ▼
                  Moment Clustering
                           │
                           ▼
                Within-Cluster Ranking
                           │
                           ▼
                  Cluster Representatives
                           │
                           ▼
                  Global Curation
                           │
                           ▼
                  Curated Selection
```

---

# 6. Processing Philosophy

The engine should use multiple weak signals rather than depend on one supposedly perfect model.

For example:

```text
Similarity:
- visual feature distance
- capture-time distance
- burst metadata

Quality:
- sharpness
- exposure
- face capture quality
- relative face completeness
- user favorite status

Final selection:
- quality
- uniqueness
- temporal coverage
- redundancy
```

No individual signal should normally determine the final result by itself.

---

# 7. Processing Stages

The MVP engine consists of six major stages.

```text
Stage 1
Prepare assets

Stage 2
Extract compact features

Stage 3
Create moment clusters

Stage 4
Rank photos inside each cluster

Stage 5
Select globally across clusters

Stage 6
Produce selection result
```

Each stage should expose deterministic intermediate values where practical.

This is important for debugging selection mistakes.

---

# 8. Analysis Image Size

Original-resolution photos should not normally be used for the entire analysis pipeline.

A typical iPhone image may contain tens of megapixels.

Processing 1,000 full-resolution images would unnecessarily increase:

- memory usage;
- decode time;
- energy usage;
- thermal load.

Instead, the engine should request a consistently sized analysis representation.

Recommended starting point:

```text
Long edge:
~512–768 px
```

The exact size should be determined through manual quality/performance validation.

For example:

```text
4032 × 3024 original

↓

682 × 512 analysis image
```

The analysis image should preserve aspect ratio.

---

# 9. Why Consistent Analysis Resolution Matters

Several technical metrics depend strongly on image resolution.

For example:

```text
Laplacian variance
```

can change substantially when the same image is evaluated at different sizes.

Therefore the engine should normalize images to approximately the same analysis resolution before calculating quality metrics.

Otherwise:

```text
Photo A at 4,032 px

vs.

Photo B at 1,024 px
```

could produce technically incomparable sharpness measurements.

---

# 10. Image Loading

The engine should use PhotoKit to obtain appropriately sized representations of `PHAsset` objects.

The entire selected collection must not be decoded into memory at once.

Preferred pattern:

```text
PHAsset
   ↓
request analysis image
   ↓
perform analysis
   ↓
store compact result
   ↓
release image
```

The analysis result should remain small.

---

# 11. iCloud-Only Assets

Some selected Photos assets may not currently exist locally because they are stored in iCloud Photos.

This is different from uploading photos to a `photos-curator` server.

The app may allow PhotoKit to retrieve the user's asset from iCloud when required.

If the image cannot be obtained:

```text
analysisStatus = unavailable
```

The engine should continue processing the remaining assets.

Example result:

```text
1,024 selected

1,019 analyzed

5 unavailable
```

The entire curation operation should not fail because a few assets are unavailable.

---

# 12. Core Analysis Record

Each analyzed photo should produce a compact internal representation.

Conceptually:

```swift
struct PhotoAnalysis {
    let assetID: String
    let captureDate: Date?

    let pixelWidth: Int
    let pixelHeight: Int

    let isFavorite: Bool
    let isScreenshot: Bool

    let sharpnessScore: Double?
    let exposureScore: Double?

    let faceCount: Int
    let faceQualityScore: Double?

    let featurePrint: ImageFeature

    let qualityScore: Double
}
```

Exact Swift types belong in the architecture/data-model documents.

The important principle is:

&gt; Keep analysis data, not decoded images.

---

# 13. Metadata Signals

Useful metadata may include:

```text
localIdentifier
creationDate
pixelWidth
pixelHeight
mediaType
mediaSubtypes
burstIdentifier
favorite status
location
```

Not every value needs to affect selection.

Metadata should only be included when it improves a concrete decision.

---

# 14. Capture Time

Capture time is one of the strongest context signals for detecting the same photographic moment.

Example:

```text
10:31:04
10:31:05
10:31:06
10:31:07
```

These four photos are more likely to represent the same moment than two visually similar photos captured six hours apart.

However:

```text
capture time alone
```

is insufficient.

The user could turn around and photograph a completely different scene two seconds later.

Therefore moment detection should combine:

```text
time proximity
+
visual similarity
```

---

# 15. Burst Metadata

If multiple photos share explicit burst metadata, that information provides strong evidence that they belong to the same photographic sequence.

Burst metadata should therefore receive high clustering priority.

However, the selection engine must not depend on burst metadata because many repeated shots are not captured using iOS Burst mode.

---

# 16. Visual Feature Representation

For MVP similarity analysis, use an on-device Vision image feature print.

Conceptually:

```text
Analysis Image
      ↓
Vision
      ↓
Image Feature Print
```

The feature print acts as a compact representation of the image's visual content.

The engine can compare two feature prints to obtain a distance.

Conceptually:

```text
distance(A, B)
```

where:

```text
smaller distance
=
greater visual similarity
```

---

# 17. Feature Distance Must Not Be Treated as Probability

A feature-print distance is not:

```text
93% similar
```

and should not be exposed to the user as such.

It is a distance measure useful for relative comparison.

The engine should therefore use names such as:

```text
featureDistance
```

rather than:

```text
similarityProbability
```

unless an actual calibrated probability model is introduced later.

---

# 18. Similarity Thresholds

The MVP should not assume that a universal hard-coded feature distance represents “same photo.”

Thresholds must be calibrated using real photo collections.

Define configuration values conceptually:

```swift
struct SimilarityConfiguration {
    var nearDuplicateThreshold: Double
    var sameMomentThreshold: Double
    var candidateTimeWindow: TimeInterval
    var maximumMomentSpan: TimeInterval
}
```

Initial threshold values should be determined using the manual validation dataset.

They should not be copied from arbitrary internet examples.

---

# 19. Threshold Stability

Feature representation behavior may depend on:

- Vision implementation;
- operating-system version;
- request revision;
- preprocessing;
- image orientation;
- crop/scale strategy.

Therefore:

```text
thresholds are configuration
```

not fundamental constants.

Selection behavior should be revalidated when the Vision implementation materially changes.

---

# 20. Two Concepts of Similarity

The engine should distinguish conceptually between:

### Near duplicate

Almost the same image.

Examples:

- burst frames;
- repeated shutter presses;
- tiny pose changes;
- tiny camera movement.

### Same moment

Different but strongly related photographs from the same photographic situation.

Examples:

```text
person looking left
person looking at camera
person smiling
slightly wider framing
```

These may not be literal duplicates but usually should not all appear in the final curated collection.

For MVP, both may be represented by the same clustering system with different distance levels.

---

# 21. Moment Clustering

The engine should cluster images into groups representing approximate photographic moments.

Example:

```text
Moment Cluster 42

IMG_1032
IMG_1033
IMG_1034
IMG_1035
IMG_1036
```

The engine then evaluates:

```text
Which image best represents Moment 42?
```

---

# 22. Recommended MVP Clustering Strategy

Do not introduce a heavyweight generic clustering library for the first implementation.

Use a deterministic time-aware greedy clustering algorithm.

High-level approach:

```text
1. Sort photos by capture time.

2. Iterate through the photos chronologically.

3. Find recent clusters that are still inside
   the allowed temporal window.

4. Compare the photo against the representative
   feature print of those clusters.

5. Assign it to the closest compatible cluster.

6. If no compatible cluster exists,
   create a new cluster.
```

This approach is:

- simple;
- deterministic;
- debuggable;
- naturally adapted to photography;
- inexpensive for approximately 1,000 photos.

---

# 23. Why Not Pure Global Clustering?

Suppose a user photographs the Eiffel Tower:

```text
09:00
```

and then again:

```text
21:00
```

The images may be visually similar.

But they represent different moments.

A pure image-similarity clustering algorithm could incorrectly merge them.

Temporal constraints help prevent this.

Therefore:

```text
visually similar
```

does not necessarily mean:

```text
same photographic moment
```

---

# 24. Temporal Candidate Window

Photos should primarily be considered clustering candidates when their capture times are relatively close.

Example configurable starting concept:

```text
candidateTimeWindow:
~30–60 seconds
```

This is not a final product constant.

Manual validation should determine the useful value.

The threshold should be generous enough to capture:

- repeated portraits;
- burst-like sequences;
- several attempts at the same composition.

But narrow enough not to merge an extended activity into one cluster.

---

# 25. Maximum Cluster Span

A cluster should also have a maximum temporal span.

For example:

```text
first photo: 10:31:00
last photo:  10:31:48
```

may reasonably represent one photographic moment.

But:

```text
first photo: 10:31
last photo:  10:47
```

should almost certainly not remain one moment cluster simply because adjacent images form a similarity chain.

This prevents cluster chaining.

---

# 26. Cluster Representative

Each cluster needs an image representing its visual content during clustering.

Prefer:

```text
cluster medoid
```

over an averaged synthetic embedding when practical.

The medoid is an actual member whose feature print is relatively central to the cluster.

For small clusters, recomputing a medoid is inexpensive.

The implementation may initially use a simpler representative and introduce medoid updating if manual validation shows a meaningful improvement.

Avoid complexity before evidence requires it.

---

# 27. Determinism

Given:

- the same input assets;
- the same Vision revision;
- the same configuration;
- the same preprocessing;

the selection engine should produce the same result whenever reasonably possible.

Avoid random clustering initialization.

This makes mistakes reproducible.

It also makes manual tuning significantly easier.

---

# 28. Near-Duplicate Fast Path

If two photos are extremely close in time and have extremely small feature distance, they can be treated as high-confidence near-duplicates.

Conceptually:

```text
very close timestamp
+
very small feature distance
=
high-confidence duplicate relationship
```

This allows the engine to be aggressive when the evidence is strong.

---

# 29. Screenshot Handling

Screenshots should not automatically be mixed with camera-photo ranking.

Recommended MVP behavior:

```text
if screenshot:
    mark contentType = screenshot
```

If the user explicitly included screenshots, they may remain candidates.

However, screenshots can receive a configurable global priority penalty for normal photo curation.

Do not delete or hide them permanently.

---

# 30. Quality Analysis

Quality analysis should answer:

&gt; “Among visually similar images, which one appears technically stronger?”

It should not attempt to judge artistic value comprehensively.

Recommended MVP quality signals:

```text
Sharpness
Exposure
Face capture quality
Face completeness
Favorite status
```

---

# 31. Sharpness Score

A basic sharpness signal can be calculated locally using a traditional image-processing metric.

One reasonable MVP option is:

```text
variance of Laplacian
```

performed on a consistently resized luminance image.

High-level:

```text
Analysis image
      ↓
grayscale / luminance
      ↓
Laplacian
      ↓
variance
      ↓
normalized sharpness score
```

The raw result must be normalized before being combined with other signals.

---

# 32. Sharpness Is Not Absolute Image Quality

Sharpness must remain a soft signal.

Examples of valid photographs with lower sharpness include:

- intentional motion blur;
- shallow depth of field;
- low-light scenes;
- atmospheric photographs;
- portraits with soft backgrounds.

Therefore:

```text
low sharpness
≠
automatic rejection
```

Sharpness is especially useful when comparing nearly identical photographs.

---

# 33. Relative Sharpness Is More Useful

Consider:

```text
Photo A
Photo B
Photo C
```

from the same burst.

If:

```text
A = noticeably blurred
B = sharp
C = slightly soft
```

sharpness is highly useful.

By contrast, comparing:

```text
night street photo
```

against:

```text
sunny landscape
```

using raw sharpness is much less meaningful.

Therefore cluster-relative quality comparison should carry substantial weight.

---

# 34. Exposure Score

The engine can calculate a lightweight luminance histogram.

Potential indicators:

```text
fraction near black
fraction near white
mean luminance
luminance spread
```

The objective is only to identify obvious technical problems.

Examples:

```text
almost completely black
severely blown out
accidental exposure failure
```

---

# 35. Exposure Must Be Conservative

A nighttime photograph may intentionally contain large dark areas.

A snow scene may intentionally contain large bright areas.

Therefore exposure should produce:

```text
soft penalties
```

rather than hard rejection rules.

The system should avoid interpreting:

```text
dark image
```

as:

```text
bad image
```

without additional evidence.

---

# 36. Face Detection

If faces are detected, portrait-aware quality signals become available.

For each significant face, useful information may include:

```text
bounding box
relative face area
face capture quality
```

The engine does not need to identify who the person is.

No facial identity database is required.

---

# 37. Face Capture Quality

Vision face-capture quality can be used as a ranking signal for portrait-like images.

This is particularly useful for comparing similar portraits.

Example:

```text
Photo A:
face quality = lower

Photo B:
face quality = higher

Photo C:
face quality = medium
```

If the photos are otherwise similar, Photo B should receive a ranking advantage.

---

# 38. Significant Faces

Not every detected face should receive equal weight.

A small background face should not dominate ranking.

Define significant faces using relative image area and/or relative size compared with the largest detected face.

Conceptually:

```text
significantFaces =
faces large enough to plausibly represent
intentional subjects
```

Thresholds should be calibrated manually.

---

# 39. Group Photo Face Score

For a group photograph, averaging all face-quality values can hide one particularly poor face.

Example:

```text
Person 1: excellent
Person 2: excellent
Person 3: excellent
Person 4: poor
```

A useful group score may combine:

```text
mean significant-face quality
+
minimum significant-face quality
```

Conceptually:

```text
faceScore =
0.7 × meanQuality
+
0.3 × minimumQuality
```

The exact weights are configuration values, not product truths.

---

# 40. Face Count Consistency

Within the same moment cluster, face count can provide a useful relative signal.

Example:

```text
Photo A: 4 significant faces
Photo B: 4 significant faces
Photo C: 3 significant faces
```

If all three are visually similar group photographs, Photo C may have:

- missed one person;
- obscured a person;
- cropped someone out.

A small relative penalty may therefore be useful.

This signal must remain weak because face detection can occasionally miss a face.

---

# 41. Closed Eyes

Reliable closed-eye detection is not required for MVP.

Do not attempt to infer a strong blink score from unreliable heuristics simply because eye landmarks exist.

If later validation shows that blinks are a major source of selection errors, introduce a dedicated solution such as:

- a suitable on-device model;
- a dedicated eye-state classifier;
- a future native framework capability.

Until then, face capture quality should provide a simpler general-purpose portrait signal.

---

# 42. Facial Expression

Emotion or “best smile” classification is outside the MVP.

Expression preference is subjective.

Avoid adding complexity until manual review shows that it materially improves best-of-cluster selection.

---

# 43. Aesthetic Score

A custom aesthetic model is not required for the first selection-engine version.

Initial MVP:

```text
aestheticScore = not implemented
```

The engine should first prove useful through:

```text
similarity
+
technical quality
+
face quality
+
diversity
```

An aesthetic Core ML model can later become an optional signal if the engine struggles to choose among technically good alternatives.

---

# 44. Why Delay Custom Aesthetic ML?

A custom model introduces additional concerns:

- model selection;
- model size;
- inference cost;
- training-domain bias;
- evaluation;
- version management;
- device compatibility;
- preference subjectivity.

It should only be added if simpler native signals cannot reach acceptable curation quality.

---

# 45. Favorite Status

An existing Apple Photos Favorite is strong evidence of explicit user preference.

For MVP, Favorite status should receive a positive selection bonus.

Recommended behavior:

```text
favorite
=
strong preference signal
```

but not necessarily:

```text
favorite
=
unconditional hard lock
```

This avoids pathological cases where many near-identical photos have all been favorited.

The exact behavior can be adjusted after manual evaluation.

---

# 46. Base Quality Score

Each photo should receive a normalized internal quality score.

Use separate weighting for images with and without significant faces.

Example starting configuration:

### Non-portrait

```text
quality =
0.65 × sharpness
+
0.35 × exposure
```

### Portrait-like

```text
quality =
0.35 × sharpness
+
0.20 × exposure
+
0.45 × faceQuality
```

These are starting weights only.

They must be tuned through manual validation.

---

# 47. Preference Bonuses

Additional signals may modify the score.

Conceptually:

```text
quality += favoriteBonus
quality -= screenshotPenalty
```

Keep bonuses small enough that they do not overpower obvious technical differences.

The final score should be normalized or bounded to a predictable range.

For example:

```text
0...1
```

---

# 48. Missing Quality Signals

Analysis can fail partially.

Example:

```text
feature print: available
sharpness: available
exposure: available
face quality: unavailable
```

Do not fail the entire asset.

Weights should be redistributed among available signals where reasonable.

The engine should distinguish:

```text
signal unavailable
```

from:

```text
signal = zero
```

---

# 49. Cluster-Relative Ranking

After moment clusters have been created, photos should be ranked within each cluster.

This is a key stage.

Example:

```text
Cluster 18

A: quality 0.72
B: quality 0.87
C: quality 0.75
D: quality 0.81
```

The primary candidate becomes:

```text
B
```

But absolute quality should not be the only input.

---

# 50. Within-Cluster Ranking Inputs

Useful relative inputs include:

```text
technical quality
face quality
face count consistency
favorite status
distance from cluster medoid
```

A photo extremely far from the cluster center may represent an outlier.

That can either:

- reduce its representative score;
- indicate that the cluster needs splitting.

---

# 51. Cluster Integrity Check

After initial clustering, validate unusually large or heterogeneous clusters.

Potential warning conditions:

```text
large cluster size

large time span

large maximum feature distance

multiple apparent visual subgroups
```

MVP behavior can remain simple:

&gt; If a cluster violates configured integrity thresholds, split it by rerunning the same clustering logic with stricter thresholds.

Avoid introducing a complex secondary clustering framework unless needed.

---

# 52. Cluster Primary

Every valid cluster should expose:

```text
primaryAssetID
```

representing the default photo chosen from that moment.

Example:

```swift
struct PhotoCluster {
    let id: UUID
    let assetIDs: [String]
    let primaryAssetID: String
}
```

The UI can use this directly for:

```text
Best of 7 similar photos
```

---

# 53. Cluster Ranking

The cluster should retain the full internal ranking:

```text
1. IMG_1035
2. IMG_1033
3. IMG_1036
4. IMG_1032
5. IMG_1034
```

This supports:

- manual override;
- adding secondary photos;
- filling larger target sizes.

---

# 54. Ranking Confidence

A simple confidence signal can be derived from the score separation between top candidates.

Example:

```text
Top score:    0.91
Second score: 0.63

→ high confidence
```

versus:

```text
Top score:    0.86
Second score: 0.85

→ low confidence
```

This does not need to be displayed in MVP.

It can help the engine decide where secondary images may be valuable.

---

# 55. Do Not Force One Photo per Cluster Forever

The primary rule should be:

```text
start with one strong representative
per important moment
```

not:

```text
every cluster can contribute exactly one photo
```

A large or meaningful cluster may eventually contribute multiple images.

Likewise, low-value clusters may contribute none when the requested target is small.

---

# 56. Global Selection Problem

After cluster ranking, suppose the engine has:

```text
720 moment clusters
```

but the user requested approximately:

```text
200 photos
```

The engine cannot keep one representative from every cluster.

It needs to determine which moments deserve space in the final collection.

This is the global curation stage.

---

# 57. Why Global Quality Sorting Fails

A naive implementation might:

```text
sort all cluster primaries by quality
take top 200
```

This creates several failure modes.

For example:

```text
120 excellent sunset photographs
```

could overwhelm:

```text
airport
hotel
street food
friends
museum
night market
```

even though the latter create a much better representation of the trip.

The goal is a collection.

Not a leaderboard.

---

# 58. Global Selection Objectives

Global selection should balance:

```text
quality
visual uniqueness
temporal coverage
user preference
redundancy
```

Conceptually:

```text
marginalSelectionValue =
    quality
  + visualNovelty
  + temporalNovelty
  + preference
  - redundancy
```

---

# 59. Temporal Segments

Before global selection, split the timeline into coarse temporal segments.

A segment boundary can occur when there is a sufficiently long gap between consecutive photos.

Example:

```text
09:00–10:22 Temple

gap

12:10–13:15 Lunch

gap

15:00–17:20 City walk
```

This provides natural event-like groups without needing semantic event recognition.

---

# 60. Segment Gap

A starting configurable segment gap could be on the order of:

```text
15–30 minutes
```

This is substantially larger than the moment clustering window.

Conceptually:

```text
seconds
→ same moment

tens of minutes
→ same activity segment

hours / days
→ different parts of the collection
```

Again, all thresholds require validation.

---

# 61. Target Allocation Across Segments

If multiple temporal segments exist, allocate the target approximately according to the number of useful candidate moments in each segment.

Example:

```text
Target = 200

Segment A:
40% of candidate moments
→ approximately 80 selections

Segment B:
35%
→ approximately 70

Segment C:
25%
→ approximately 50
```

Apply a reasonable minimum allocation to avoid completely removing small segments.

This provides temporal coverage with little algorithmic complexity.

---

# 62. Greedy Marginal Selection

Within each segment, select photos iteratively based on their marginal value given what has already been selected.

Conceptually:

```text
while selectedCount &lt; segmentBudget:

    evaluate every remaining candidate

    choose candidate with highest
    marginalSelectionValue

    add candidate

    update novelty/redundancy values
```

For approximately 1,000–2,000 photos, this straightforward approach is reasonable and easy to debug.

A specialized optimization solver is unnecessary.

---

# 63. Visual Novelty

Visual novelty asks:

&gt; “How different is this candidate from photos already selected?”

Conceptually:

```text
visualNovelty(candidate) =
distance to nearest selected feature print
```

A candidate highly similar to an already selected photo receives less marginal value.

This discourages redundancy.

---

# 64. Temporal Novelty

Temporal novelty asks:

&gt; “Does this candidate represent a portion of the timeline that is currently underrepresented?”

Conceptually:

```text
temporalNovelty(candidate) =
normalized time distance
to nearest selected moment
```

Cap the value beyond a reasonable duration.

There is no need for a photograph captured three days later to receive 100 times more temporal novelty than one captured 30 minutes later.

---

# 65. Starting Global Weights

A reasonable initial configuration may look conceptually like:

```text
marginalValue =

0.55 × quality
+
0.25 × visualNovelty
+
0.20 × temporalNovelty
```

Additional small bonuses or penalties may apply.

These numbers are starting points.

They should not be treated as scientifically established weights.

---

# 66. Target Size Is Approximate

If the user requests:

```text
200 photos
```

the engine should aim near 200.

However, quality should take priority over exact arithmetic.

Example:

```text
Requested:
200

Strong selection:
191
```

may be preferable to adding nine highly redundant photos merely to satisfy the count.

---

# 67. Selection Tolerance

Define a configurable target tolerance.

For example, conceptually:

```text
target = 200

acceptable range =
approximately 180–210
```

The exact tolerance should follow UX decisions.

If the engine can fill the target with reasonable candidates, it should do so.

The tolerance only prevents pathological forced selections.

---

# 68. When Cluster Count Is Below Target

Example:

```text
Target:
200

Strong moment clusters:
145
```

First:

```text
select primary candidate
from each useful cluster
```

Then add secondary photos from clusters.

Secondary photos should be selected using marginal value.

They should receive an explicit same-cluster redundancy penalty.

---

# 69. Secondary Selection

A second photo from a moment may be justified when:

- the cluster is large;
- the first and second photos differ meaningfully;
- both are high quality;
- ranking confidence is low;
- the target size has remaining capacity.

Conceptually:

```text
secondaryMarginalValue =
quality
+
visualNovelty
-
sameClusterPenalty
```

---

# 70. When Cluster Count Exceeds Target

Example:

```text
Target:
200

Moment clusters:
680
```

Only cluster primaries should initially enter the global candidate pool.

The global selection algorithm chooses approximately 200 of them based on:

```text
quality
+
coverage
+
novelty
```

Secondary cluster images should not compete until unique moments have been adequately considered.

---

# 71. Favorite Preference During Global Selection

Favorite photos should receive a meaningful bonus.

A Favorite that is slightly lower quality than another candidate should usually survive.

A catastrophically poor or redundant Favorite may still need special handling.

The initial implementation should log these cases during manual validation before defining rigid behavior.

---

# 72. Selection Reasons

Each photo should receive an internal reason describing its outcome.

Example:

```swift
enum SelectionReason {
    case clusterPrimary
    case secondaryCandidate
    case userFavorite
    case globalCoverage
    case visuallyRedundant
    case lowerRankedSimilarPhoto
    case outsideTargetBudget
    case unavailable
}
```

These reasons are valuable for:

- debugging;
- explainable UI;
- manual validation.

Not every reason needs to be shown to the user.

---

# 73. User-Facing Explanation

The internal system may know:

```text
feature distance = X
sharpness = Y
face score = Z
```

The UI should instead say:

```text
Best of 7 similar photos
```

or:

```text
Similar photo
```

Possibly later:

```text
Sharper shot
```

Do not expose implementation metrics as if they were objective photographic judgments.

---

# 74. Rejected Does Not Mean Bad

Internally, avoid modeling:

```text
goodPhoto = true/false
```

A perfectly good image may be excluded because another image is almost identical.

Preferred concepts:

```text
selected
notSelected
redundant
lowerRankedWithinMoment
outsideBudget
```

This distinction should exist throughout the codebase.

---

# 75. Output Model

The engine should produce a result conceptually similar to:

```swift
struct CurationResult {
    let selectedAssetIDs: [String]
    let unselectedAssetIDs: [String]

    let clusters: [PhotoCluster]

    let requestedCount: Int
    let actualCount: Int

    let analyzedCount: Int
    let unavailableCount: Int
}
```

The result should contain enough information for the review UI without rerunning analysis.

---

# 76. Engine API

The high-level interface should remain small.

Conceptually:

```swift
protocol PhotoSelectionEngine {
    func curate(
        assets: [PHAsset],
        targetCount: Int
    ) async throws -&gt; CurationResult
}
```

Progress can be communicated separately.

Avoid exposing every internal pipeline component through the public interface.

---

# 77. Progress Reporting

The engine should report meaningful progress.

Example stages:

```swift
enum AnalysisStage {
    case preparing
    case analyzing
    case clustering
    case ranking
    case selecting
    case finished
}
```

Progress event:

```swift
struct AnalysisProgress {
    let stage: AnalysisStage
    let completed: Int
    let total: Int
}
```

User-facing copy can convert this into:

```text
Analyzing photos
423 / 1,024
```

---

# 78. Cancellation

The entire curation operation should run inside Swift structured concurrency.

The engine should regularly respect task cancellation.

Potential cancellation points include:

```text
before requesting next asset
after image analysis
before clustering
inside long selection loops
```

Cancellation should discard incomplete transient state safely.

Resume support is not required for MVP.

---

# 79. Concurrency

Processing 1,000 images sequentially may be unnecessarily slow.

Processing hundreds simultaneously may cause:

- memory pressure;
- thermal throttling;
- excessive iCloud requests;
- poor responsiveness.

Use bounded concurrency.

Conceptually:

```text
2–4 concurrent analysis operations
```

is a reasonable starting point.

The exact level should be validated on real devices.

Do not create one unbounded task per photo.

---

# 80. Memory Strategy

At any moment, memory should contain:

```text
a small number of analysis images

+

compact analysis records for all photos
```

It should not contain:

```text
1,000 decoded UIImage objects
```

Release temporary image buffers immediately after feature extraction and quality analysis.

---

# 81. Feature Storage

Feature prints may remain in memory for the duration of the curation session because global similarity calculations require repeated access.

Do not persist feature data permanently unless there is a demonstrated need.

For MVP:

```text
session finishes
→ feature data can be discarded
```

This keeps persistence simple.

---

# 82. Persistent Cache

Do not build a complex persistent feature cache for the initial MVP.

Although caching could accelerate repeated curation of the same assets, it introduces:

- invalidation;
- edited-asset tracking;
- model revision tracking;
- storage management;
- migration logic.

First validate that recomputation is actually a user problem.

---

# 83. Database

The selection engine does not require a database for MVP.

Use in-memory structures during analysis.

Persist only user-visible session state if required by UX.

Do not introduce Core Data, SwiftData, SQLite, or another persistence layer solely because the engine has intermediate data.

---

# 84. Computational Complexity

The engine should avoid unnecessary all-pairs image processing.

However, once compact features have been extracted, several hundred thousand lightweight comparisons are not automatically problematic.

For:

```text
1,000 photos
```

the full pair count is:

```text
499,500
```

For:

```text
2,000 photos
```

it is:

```text
1,999,000
```

Still, moment clustering should exploit capture time to avoid comparing obviously unrelated images.

There is no MVP need for a vector database or approximate nearest-neighbor index.

---

# 85. Avoid Premature Optimization

Do not build:

- HNSW;
- FAISS-like indexing;
- GPU clustering;
- custom Metal kernels;
- distributed inference;
- background servers;

unless profiling demonstrates an actual bottleneck.

The likely expensive operation is image loading and feature extraction, not a few in-memory comparisons between compact analysis objects.

Measure before optimizing.

---

# 86. Processing Order

Recommended implementation order:

```text
1. Fetch metadata

2. Sort by capture date

3. Request analysis representation

4. Compute feature print

5. Compute simple quality metrics

6. Detect significant faces

7. Compute face capture quality if relevant

8. Release image

9. Build moment clusters

10. Rank members

11. Build temporal segments

12. Perform global selection

13. Produce CurationResult
```

---

# 87. Optimization: Two-Pass Analysis

If face analysis becomes expensive, use two passes.

### Pass 1

For every photo:

```text
feature print
sharpness
exposure
basic face detection
```

### Pass 2

Only where useful:

```text
detailed face-quality analysis
```

For example, second-pass portrait analysis could be limited to clusters containing multiple significant faces.

Do not implement this optimization until profiling suggests it is valuable.

---

# 88. Engine Configuration

All tunable algorithm values should live in one configuration object rather than being scattered through the implementation.

Conceptually:

```swift
struct SelectionEngineConfiguration {

    // Image analysis
    var analysisLongEdge: CGFloat

    // Moment detection
    var candidateTimeWindow: TimeInterval
    var maximumMomentSpan: TimeInterval
    var sameMomentDistanceThreshold: Double
    var nearDuplicateDistanceThreshold: Double

    // Quality
    var sharpnessWeight: Double
    var exposureWeight: Double
    var faceQualityWeight: Double
    var favoriteBonus: Double

    // Global selection
    var qualityWeight: Double
    var visualNoveltyWeight: Double
    var temporalNoveltyWeight: Double
    var secondaryClusterPenalty: Double

    // Target
    var targetTolerance: Double
}
```

This is essential for tuning.

It is not over-engineering.

---

# 89. Configuration Version

Associate the engine result with a configuration/algorithm version.

Example:

```text
selectionEngineVersion = 1
```

This helps compare results after tuning.

No complicated migration system is needed.

A simple integer or string is enough.

---

# 90. Debug Mode

Development builds should be able to inspect internal selection information.

For example:

```text
IMG_1035

cluster:
18

sharpness:
0.81

exposure:
0.74

faceQuality:
0.89

quality:
0.84

clusterRank:
1

selected:
true
```

This data does not need to appear in the production interface.

---

# 91. Debug Export

A lightweight JSON debug export can be extremely useful for manual validation.

Example:

```json
{
  "assetID": "...",
  "clusterID": "18",
  "qualityScore": 0.84,
  "clusterRank": 1,
  "selectionReason": "clusterPrimary"
}
```

Do not export image contents.

This makes algorithm changes easier to compare without introducing automated test infrastructure.

---

# 92. Manual Validation Dataset

Selection-engine development requires repeatable manual evaluation.

Maintain several real-world photo sets.

Recommended categories:

```text
Set A
50 near-duplicate portraits

Set B
200 mixed family photos

Set C
300 sightseeing photos

Set D
1,000-photo travel collection

Set E
low-light collection

Set F
group photographs

Set G
rapid sequence / burst-like photographs

Set H
mixed screenshots + camera photos
```

The detailed process belongs in:

```text
docs/manual-validation.md
```

---

# 93. Most Important Validation Question

For every similar-photo cluster:

&gt; Did the engine choose the same image that a human would choose?

This should be the first major quality metric.

It is more actionable than trying to assess whether an entire collection is “good.”

---

# 94. Best-of-Cluster Agreement

Measure:

```text
human best choice
vs.
engine best choice
```

Conceptually:

```text
Agreement =
clusters where engine top choice
matches human top choice
/
clusters reviewed
```

Exact-match agreement is strict.

Also record whether the engine's choice is:

```text
acceptable
```

even when it is not the reviewer's first choice.

---

# 95. Serious Selection Errors

Not all mistakes are equally important.

Example:

```text
Engine chooses second-best portrait
instead of best portrait
```

may be minor.

But:

```text
Engine chooses obviously blurred photo
while a sharp equivalent exists
```

is serious.

Manual validation should classify errors by severity.

---

# 96. Global Collection Evaluation

After cluster ranking is acceptable, evaluate the complete collection.

Ask:

```text
Are important portions of the trip missing?

Are there too many photos of the same thing?

Are there obvious bad photos?

Did the engine remove too much?

Would I rather review this collection
than the original?
```

This is the actual product-level evaluation.

---

# 97. Override Rate

When the review UI exists, monitor manual behavior locally during development.

Useful measures:

```text
photos manually removed

photos manually added back

cluster primary replacements
```

A high primary-replacement rate indicates problems with within-cluster ranking.

A high add-back rate may indicate over-aggressive global selection.

A high removal rate may indicate insufficient filtering.

---

# 98. Selection Engine Development Phases

Implement the engine incrementally.

### Phase 1 — Similarity only

```text
Feature extraction
Moment clustering
Select one arbitrary representative
```

Goal:

Verify clustering.

### Phase 2 — Technical ranking

Add:

```text
sharpness
exposure
```

Goal:

Choose technically stronger representatives.

### Phase 3 — Portrait ranking

Add:

```text
face detection
face capture quality
```

Goal:

Improve portraits and group photos.

### Phase 4 — Global curation

Add:

```text
target count
temporal segments
visual novelty
temporal novelty
```

Goal:

Produce complete curated collections.

### Phase 5 — Tune

Adjust:

```text
thresholds
weights
cluster behavior
target behavior
```

using manual validation.

---

# 99. Do Not Add ML Until a Failure Is Identified

Every additional model should solve a documented failure mode.

Examples:

```text
Problem:
Engine repeatedly selects blinking portraits.

Possible addition:
Eye-state model.
```

```text
Problem:
Among technically perfect landscape photos,
ranking appears random.

Possible addition:
Aesthetic model.
```

Do not add models simply because they are available.

---

# 100. Future Aesthetic Model

If later introduced, an aesthetic model should remain one signal among several.

Conceptually:

```text
quality =
technicalQuality
+
faceQuality
+
aestheticQuality
```

It must not override:

```text
similarity
diversity
user intent
```

---

# 101. Future Semantic Understanding

Later versions may classify broad semantic content such as:

```text
food
landscape
portrait
architecture
pet
document
screenshot
```

This could improve collection diversity.

However, MVP should first determine whether visual feature novelty already provides sufficient diversity.

---

# 102. Future Personalization

Eventually the engine could learn from manual overrides.

Example:

```text
User repeatedly prefers:
wider compositions
```

or:

```text
User frequently restores:
food photographs
```

This is explicitly outside MVP.

Personalization introduces additional privacy, persistence, and model-design concerns.

---

# 103. Failure Handling

A single failed analysis should not abort the session.

Each asset should have an analysis state.

Conceptually:

```swift
enum PhotoAnalysisStatus {
    case pending
    case analyzing
    case completed
    case unavailable
    case failed
}
```

The engine should produce a partial result when enough assets were successfully analyzed.

---

# 104. Analysis Failure Policy

If feature extraction fails:

```text
asset cannot participate normally
in similarity selection
```

Possible MVP behavior:

- mark unavailable for automatic selection;
- surface separately in review.

Do not silently classify it as a poor photo.

Failure to analyze is not evidence of poor quality.

---

# 105. Orientation

All analysis stages must use a consistent correctly oriented representation.

Feature extraction and quality metrics should not accidentally compare:

```text
rotated pixel buffers
```

against:

```text
visually upright images
```

Orientation bugs can materially damage similarity and face detection.

Treat orientation handling as part of asset preparation.

---

# 106. Edited Photos

The engine should generally evaluate the current user-visible rendition of an edited Photos asset.

If the user:

- cropped;
- rotated;
- adjusted exposure;

the curation decision should reflect what they currently see in Photos.

Original photo data should remain untouched.

---

# 107. Live Photos

For MVP, analyze the still representation.

The selected result should retain the original `PHAsset`.

Do not create a flattened JPEG merely because the engine analyzed a still frame.

Thus:

```text
analysis representation
≠
output asset
```

---

# 108. Asset Identity

All results should reference the original Photos asset through its stable local identifier.

Never rely on:

```text
array index
filename
temporary UIImage identity
```

as the long-lived identifier for a photo during the session.

---

# 109. Engine Independence from UI

The selection engine should not import SwiftUI.

It should operate on domain inputs and produce domain outputs.

Conceptually:

```text
UI
↓
Curation service
↓
Selection engine
↓
Vision / Photos helpers
```

This allows selection logic to evolve without coupling it to screens.

This does not require an elaborate clean-architecture framework.

Simple module/file boundaries are sufficient.

---

# 110. Recommended Internal Components

Keep the engine small.

A reasonable initial decomposition is:

```text
PhotoSelectionEngine

PhotoAnalyzer

SimilarityAnalyzer

MomentClusterer

ClusterRanker

GlobalSelector
```

Supporting helpers may include:

```text
ImageLoader
SharpnessAnalyzer
ExposureAnalyzer
FaceAnalyzer
```

Avoid creating a protocol for every class unless substitution is actually needed.

---

# 111. Suggested Source Layout

Conceptually:

```text
photos-curator/
├── Features/
│   └── Curation/
│
├── SelectionEngine/
│   ├── PhotoSelectionEngine.swift
│   ├── PhotoAnalyzer.swift
│   ├── MomentClusterer.swift
│   ├── ClusterRanker.swift
│   ├── GlobalSelector.swift
│   ├── SelectionEngineConfiguration.swift
│   │
│   ├── Analysis/
│   │   ├── SharpnessAnalyzer.swift
│   │   ├── ExposureAnalyzer.swift
│   │   ├── FaceAnalyzer.swift
│   │   └── FeaturePrintAnalyzer.swift
│   │
│   └── Models/
│       ├── PhotoAnalysis.swift
│       ├── PhotoCluster.swift
│       └── CurationResult.swift
│
└── Photos/
    └── PhotoImageLoader.swift
```

This structure is a guideline.

Do not create empty files purely to match the diagram.

---

# 112. No Test Targets

The repository intentionally does not require:

```text
photos-curatorTests

photos-curatorUITests
```

Do not create:

- unit-test targets;
- UI-test targets;
- snapshot-test infrastructure;
- mocks solely for automated tests;
- test fixtures solely for automated tests.

Selection behavior will be evaluated through structured manual validation.

---

# 113. Manual Validation Support Is Required

Although automated test targets are intentionally omitted, development builds should make manual algorithm evaluation easy.

Useful capabilities include:

```text
show cluster membership

show cluster ranking

show quality signals

show selected/unselected status

show selection reason

export compact debug JSON
```

These directly accelerate engine improvement.

They are more valuable to the MVP than maintaining a large automated test architecture.

---

# 114. Privacy Constraints

The selection engine must not require sending photo pixels to a `photos-curator` backend.

All primary analysis should remain local.

Transient analysis images should be released after use.

Do not log:

```text
image contents
face crops
raw photographs
```

Debug logs should use identifiers and numerical metrics only.

---

# 115. Performance Priorities

Optimize in this order:

```text
1. Correct selection behavior

2. Memory safety

3. UI responsiveness

4. Analysis latency

5. Energy/thermal behavior
```

Do not sacrifice selection quality for premature micro-optimizations.

At the same time, avoid architectural decisions that obviously load the entire library into memory.

---

# 116. MVP Algorithm Summary

The complete recommended MVP algorithm is:

```text
INPUT:
N selected PHAssets
targetCount

↓

Fetch lightweight metadata

↓

Sort by capture date

↓

For each asset:

    request ~512–768 px analysis image

    compute Vision feature print

    calculate sharpness

    calculate exposure

    detect significant faces

    calculate face capture quality when applicable

    create PhotoAnalysis

    release analysis image

↓

Build time-aware visual moment clusters

↓

For every cluster:

    rank photos using relative quality

    identify primary candidate

    retain ranked secondaries

↓

Split cluster primaries into coarse
temporal segments

↓

Allocate approximate target budget
across segments

↓

Within each segment:

    greedily select candidates using

    quality
    +
    visual novelty
    +
    temporal novelty
    -
    redundancy

↓

If additional target capacity exists:

    consider ranked secondary photos

↓

Produce:

    selectedAssetIDs
    unselectedAssetIDs
    clusters
    selection reasons
    analysis summary

↓

USER REVIEWS RESULT
```

---

# 117. MVP Decision Rules

The following rules summarize the intended behavior.

### Rule 1

If multiple photos are extremely similar and close in time:

```text
prefer one strong representative
```

### Rule 2

If a similar photo is noticeably blurrier:

```text
prefer the sharper photo
```

### Rule 3

If similar portrait photos differ in face capture quality:

```text
prefer better face capture quality
```

### Rule 4

If two photos are visually similar but far apart in time:

```text
do not automatically treat them
as the same moment
```

### Rule 5

If one scene has many excellent photos:

```text
do not allow it to dominate
the complete collection
```

### Rule 6

If the target cannot be reached without obvious redundancy:

```text
prefer a slightly smaller result
```

### Rule 7

If analysis fails:

```text
do not interpret failure as poor quality
```

### Rule 8

If uncertain:

```text
prefer conservative curation
over aggressive irreversible filtering
```

The originals remain untouched regardless.

---

# 118. Configuration Tuning Priorities

Tune parameters in this order:

```text
1. Moment clustering threshold

2. Moment temporal window

3. Sharpness normalization

4. Face-quality influence

5. Within-cluster quality weights

6. Global quality weight

7. Visual novelty weight

8. Temporal novelty weight

9. Secondary-photo penalty

10. Target tolerance
```

Clustering should be tuned first because ranking errors are impossible to interpret when clusters themselves are incorrect.

---

# 119. What Not to Tune Simultaneously

Avoid changing:

```text
clustering threshold
+
quality weights
+
global diversity weights
```

at the same time.

Otherwise it becomes difficult to determine which change improved or degraded the result.

Manual development should follow:

```text
change one conceptual component
↓
review known datasets
↓
record observations
↓
continue
```

---

# 120. Primary Engineering Risk

The main engineering risk is not:

```text
Can the iPhone process 1,000 images?
```

The main risk is:

```text
Can the engine distinguish redundancy
without removing meaningful diversity?
```

A successful engine must be aggressive against redundant images while conservative about unique moments.

---

# 121. Primary Algorithmic Risk

The most dangerous failure is incorrect clustering.

### Under-clustering

```text
8 similar images
→ 8 separate clusters
```

Result:

Too many redundant photos survive.

### Over-clustering

```text
8 meaningfully different images
→ 1 cluster
```

Result:

Important photos disappear from the recommendation.

Over-clustering is generally the more harmful error.

Therefore initial thresholds should favor slightly conservative clustering.

---

# 122. Product Bias

When uncertain between:

```text
keep
```

and:

```text
exclude
```

the initial MVP should lean slightly toward:

```text
keep
```

because the application is curating memories, not cleaning temporary files.

Users can remove extra photos more easily than they can discover an important photo that the system hid too aggressively.

---

# 123. Definition of Done — Selection Engine v1

Selection Engine v1 is ready for integration when it can:

1. Analyze approximately 1,000 selected photos without loading all full-resolution images into memory.
2. Produce compact visual feature representations on-device.
3. Group clear repeated-photo sequences into useful moment clusters.
4. Rank technically stronger images above obvious failures inside those clusters.
5. Improve portrait selection using face-aware quality where applicable.
6. Produce an approximate requested collection size.
7. Preserve reasonable temporal and visual diversity.
8. Return all cluster information required by the review UI.
9. Continue when a minority of assets cannot be analyzed.
10. Run without a `photos-curator` backend.
11. Run without user accounts.
12. Run without automated test targets.
13. Preserve all original Photos assets.

---

# 124. MVP North-Star Example

Input:

```text
1,024 trip photos
```

The engine discovers:

```text
147 strong repeated-photo clusters

543 mostly unique moment candidates

334 redundant alternatives
```

The user requests:

```text
~200 photos
```

The engine:

```text
chooses strong representatives
from repeated moments

removes obvious redundant alternatives

preserves coverage across the trip

selects approximately 180–210 photos
```

The user then reviews the recommendation and makes a small number of changes.

The ideal outcome is:

&gt; The user feels that reviewing the curated 200 photos is dramatically easier than manually reviewing all 1,024, while still trusting that the original library remains untouched.

---

# 125. Final Design Principle

The selection engine should remain understandable enough that when it makes a bad decision, the developer can answer:

&gt; “Why did this photo get selected?”

If the answer requires debugging an opaque stack of unnecessary models, abstractions, and infrastructure, the MVP has become too complicated.

The preferred engine is:

```text
simple enough to understand
+
strong enough to be useful
+
modular enough to improve
```

That is the standard for `photos-curator` v1.