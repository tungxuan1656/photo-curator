# photos-curator — Product Specification

**Document:** `docs/product/01-product-spec.md`  
**Product:** `photos-curator`  
**Platform:** iOS / iPhone  
**Status:** Draft  
**Version:** 0.1  
**Stage:** MVP

---

# 1. Product Overview

`photos-curator` is an iPhone application that helps users turn a large collection of photos into a smaller, higher-quality, and more meaningful curated collection.

The primary use case is simple:

> After a trip, event, or day of heavy photography, a user may have 500–2,000 photos. Instead of manually reviewing every image, photos-curator analyzes the collection, identifies similar photos, evaluates photo quality, and recommends a smaller set of the best images.

Example:

```text
Input:
1,024 photos

Output:
187 recommended photos

```

The application does not aim to replace Apple Photos.

It solves one focused problem:

> “Which photos from this large collection are actually worth keeping in my final album?”

---

# 2. Product Vision

The ideal experience should feel like having a personal photo editor on the iPhone.

The user selects a large collection of photos and receives a curated result with minimal effort.

The core interaction should remain:

```text
Select
  ↓
Analyze
  ↓
Review
  ↓
Save

```

The application should be able to:

- recognize near-duplicate photos;
- identify multiple photos of the same moment;
- select the strongest image from a similar group;
- detect obviously poor-quality photos;
- preserve meaningful moments;
- avoid selecting too many visually redundant photos;
- maintain variety across the final collection.

The product should prioritize:

1. Selection quality
2. User trust
3. Privacy
4. Simplicity
5. Performance

---

# 3. Problem Statement

Modern smartphones make it extremely easy to take many photos.

A user may take several photos of the same subject because:

- someone blinked;
- the subject moved;
- framing changed slightly;
- exposure changed;
- the user wanted multiple attempts;
- burst photography was used;
- the user simply pressed the shutter repeatedly.

A typical travel collection may therefore contain:

- near-duplicates;
- burst sequences;
- blurred photos;
- accidental photos;
- poorly exposed photos;
- screenshots;
- multiple versions of the same composition;
- dozens of technically acceptable but redundant images.

The difficult problem is usually not:

> “Is this image good?”

The more useful question is:

> “Among these seven nearly identical photos, which one should I keep?”

This comparison problem is the core opportunity for `photos-curator`.

---

# 4. Target Users

## 4.1 Primary User

The primary user is an everyday iPhone user who takes many photos during:

- travel;
- family events;
- social gatherings;
- holidays;
- meals;
- sightseeing;
- concerts;
- celebrations;
- outings with friends;
- photography of children or pets.

The target user is not necessarily a professional photographer.

They primarily want to:

- reduce photo overload;
- quickly find their best shots;
- remove visual redundancy;
- create albums worth revisiting;
- spend less time manually reviewing photos.

---

# 5. Core User Story

> As a user who has taken approximately 1,000 photos during a trip, I want photos-curator to recommend approximately 100–200 of the best photos so that I can review a manageable selection instead of manually reviewing all 1,000 images.

---

# 6. MVP Objective

The MVP must validate one central hypothesis:

> Reviewing a curated collection of approximately 100–200 photos is significantly easier and more useful than manually reviewing the original collection of approximately 1,000 photos.

The MVP does not need to become a complete photo-management application.

The product succeeds if users consistently feel that:

```text
Curated review
is better than
full-library review

```

---

# 7. Product Principles

## 7.1 Never Destroy User Data

`photos-curator` must never automatically delete original photos.

The application recommends photos.

The user remains in control.

Any destructive photo-library functionality should remain outside the MVP unless explicitly designed later.

---

## 7.2 Prefer Ranking Over Hard Rejection

Photo quality is subjective.

The engine should generally rank photos rather than classify them as simply:

```text
Good
Bad

```

A technically imperfect photo can still be emotionally important.

---

## 7.3 Compare Similar Photos First

The most reliable AI decision is often relative rather than absolute.

Instead of asking:

> “Is IMG_1045 a great photo?”

the engine should often ask:

> “Is IMG_1045 better than IMG_1044, IMG_1046, and IMG_1047?”

Similarity clustering is therefore a first-class part of the product.

---

## 7.4 Optimize for Trust

Users must understand that the application is recommending a selection rather than deciding what should permanently exist.

Whenever practical, users should be able to inspect:

- which photos were selected;
- which photos were not selected;
- groups of similar images;
- the recommended best image in a group.

---

## 7.5 Privacy First

Photo analysis should run on-device whenever technically reasonable.

The MVP should not require uploading a user's full photo library to a server.

Cloud infrastructure should only be introduced if a clear product requirement cannot reasonably be implemented on-device.

---

## 7.6 Avoid Over-Engineering

The application should use the simplest architecture that reliably supports the MVP.

Do not introduce infrastructure solely for hypothetical future requirements.

Examples of things that should not exist without a concrete need:

- microservices;
- complex backend systems;
- distributed queues;
- premature abstraction layers;
- elaborate dependency injection frameworks;
- unnecessary database layers;
- plugin architectures;
- remote inference infrastructure.

The MVP should favor native iOS frameworks and local processing.

---

# 8. Primary User Flow

## 8.1 Launch

The application opens to a simple home screen.

Primary action:

**Select Photos**

Optional supporting text:

> Turn hundreds of photos into a collection worth keeping.

---

# 9. Select Photos

The user chooses a collection of photos from the Photos Library.

Possible sources include:

- manually selected photos;
- an existing Photos album;
- photos from a date range.

The MVP does not need every selection mechanism immediately.

The simplest reliable selection flow should be implemented first.

Example:

```text
Japan Trip
1,024 photos selected

```

Recommended MVP working range:

```text
100–2,000 photos per curation session

```

The application may work beyond this range, but optimization for extremely large libraries is not an MVP requirement.

---

# 10. Choose Curation Size

After selecting photos, the user chooses approximately how many photos they want to keep.

Example interface:

```text
Keep approximately

10%    20%    30%

```

Example:

```text
1,024 photos selected

20%
≈ 205 photos

```

The default should initially be:

```text
20%

```

A continuous slider may be introduced if it provides a better UX.

The engine should treat the target as approximate rather than mathematically exact.

For example:

```text
Requested:
200 photos

Acceptable result:
187 photos

```

may be preferable to artificially selecting 13 redundant photos simply to reach exactly 200.

---

# 11. Analysis

After confirmation, the application analyzes the selected photos.

Example UI:

```text
Analyzing your photos

423 / 1,024

```

The application may communicate understandable processing stages such as:

```text
Finding similar photos

Checking image quality

Comparing similar shots

Building your collection

```

Internal model names, algorithms, confidence values, and implementation details should not normally appear in the consumer UI.

---

# 12. Curated Result

After processing:

```text
Your collection is ready

1,024 photos
↓
187 selected

```

The result screen should primarily show:

### Selected

Photos recommended for the curated collection.

### Not Selected

Photos that were analyzed but not included.

The wording should avoid implying that unselected photos are objectively bad.

Prefer:

**Not Selected**

over:

**Bad Photos**

or:

**Rejected Photos**

---

# 13. Review

The user should be able to review the recommendation before saving it.

Required interactions:

- view selected photos in a grid;
- open a photo fullscreen;
- remove a selected photo;
- restore an unselected photo;
- inspect similar-photo groups when available.

Example:

```text
Best of 7 similar photos

```

The user may open the group and manually choose another image.

---

# 14. Save Curated Collection

The main output should be an album in Apple Photos.

Example:

```text
Japan — Curated

```

The application adds the selected assets to the new album.

Original photos remain unchanged.

The application should not duplicate original image data if Photos can reference the existing assets in an album.

---

# 15. Core Functional Requirements

## FR-01 — Photos Library Access

The application must request the minimum Photos permission required for the intended functionality.

The application should correctly support Apple's limited photo-library permission model where applicable.

---

## FR-02 — Photo Selection

The application must allow the user to select a large set of photos for analysis.

Expected MVP range:

```text
100–2,000 photos

```

---

## FR-03 — Asset Loading

The application must process Photos assets without loading all original-resolution images into memory simultaneously.

Image requests should use appropriately sized representations whenever full resolution is unnecessary.

---

## FR-04 — Metadata Extraction

The application may use available asset metadata such as:

- capture timestamp;
- image dimensions;
- media type;
- location;
- burst identifiers;
- favorite status;
- screenshot subtype;
- creation date.

Metadata should supplement image analysis rather than replace it.

---

## FR-05 — Technical Quality Analysis

The system should derive quality signals where useful.

Potential signals include:

- blur;
- sharpness;
- exposure;
- face quality;
- subject visibility;
- image aesthetics.

Not every signal must be implemented in the first MVP.

---

## FR-06 — Similarity Detection

The application must estimate visual similarity between photos.

Similarity detection should support identification of:

- near-duplicates;
- burst sequences;
- repeated compositions;
- multiple attempts of the same moment.

This is a core MVP capability.

---

## FR-07 — Photo Clustering

Similar photos should be grouped into clusters representing approximately the same photographic moment.

Example:

```text
Cluster 23

IMG_1001
IMG_1002
IMG_1003
IMG_1004
IMG_1005
IMG_1006

```

The engine can then compare photos within the cluster.

---

## FR-08 — Photo Scoring

Each candidate may receive an internal score derived from multiple signals.

Conceptually:

```text
photoScore =
    technicalQuality
  + faceQuality
  + aestheticQuality
  + contextualValue

```

The exact formula is an implementation detail and should evolve based on real-world validation.

---

## FR-09 — Best-of-Cluster Selection

For each cluster, the system should identify one or more preferred images.

Example:

```text
Cluster size:
7

Primary recommendation:
IMG_1045

Secondary candidate:
IMG_1047

```

Large or diverse clusters may contribute more than one selected photo.

---

## FR-10 — Global Selection

The final collection must not simply consist of the highest-scoring individual photos.

The engine should consider:

- similarity;
- temporal coverage;
- scene diversity;
- subject diversity;
- cluster redundancy;
- requested target size.

The goal is a good collection, not merely a list of high-scoring images.

---

# 16. Selection Engine Concept

The high-level pipeline is:

```text
Selected Photos
      │
      ▼
Asset Metadata
      │
      ▼
Image Preprocessing
      │
      ├──────────────┐
      ▼              ▼
Quality Signals   Visual Features
      │              │
      └──────┬───────┘
             ▼
     Similarity Analysis
             │
             ▼
         Clustering
             │
             ▼
     Intra-Cluster Ranking
             │
             ▼
      Global Selection
             │
             ▼
     Curated Collection

```

Detailed implementation belongs in:

```text
docs/selection-engine.md

```

---

# 17. Technical Quality Signals

Technical signals should influence ranking but generally should not independently eliminate a photo.

---

## 17.1 Blur and Sharpness

Potentially detect:

- camera shake;
- strong motion blur;
- severe defocus.

Minor softness should not automatically cause rejection.

---

## 17.2 Exposure

Potentially detect:

- severe underexposure;
- severe overexposure;
- excessive highlight clipping;
- extremely low usable contrast.

The engine should avoid trying to enforce professional photography standards.

It only needs to recognize obvious failures well enough to improve relative ranking.

---

## 17.3 Face Quality

For photos containing people, potentially evaluate:

- visible faces;
- closed eyes;
- face sharpness;
- face obstruction;
- facial orientation;
- expression quality where reliably available.

Face quality is especially useful when comparing several photos from the same moment.

---

## 17.4 Aesthetic Quality

A model may estimate overall aesthetic preference.

Possible characteristics include:

- composition;
- balance;
- subject prominence;
- visual clarity;
- overall appeal.

Aesthetic scoring must not become the sole basis of selection.

---

# 18. Similarity and Moment Detection

Similarity is central to the product.

Consider six images taken within several seconds:

```text
10:31:04 IMG_1001
10:31:05 IMG_1002
10:31:06 IMG_1003
10:31:07 IMG_1004
10:31:09 IMG_1005
10:31:11 IMG_1006

```

If all six represent the same person standing in front of the same landmark, they should usually be treated as:

```text
One moment

```

rather than:

```text
Six independent candidate moments

```

Possible similarity inputs include:

- timestamps;
- image embeddings;
- perceptual similarity;
- scene similarity;
- face similarity;
- camera burst metadata.

The exact implementation will be defined separately.

---

# 19. Temporal Context

Capture time can provide a strong clustering signal.

However, time alone is insufficient.

Example:

```text
IMG_A — 10:31:04
IMG_B — 10:31:07

```

may represent the same moment.

But:

```text
IMG_C — 10:31:08

```

could point in a completely different direction.

Therefore:

```text
Temporal proximity
+
Visual similarity

```

should generally be more useful than either signal alone.

---

# 20. Global Diversity

A common failure mode of naive ranking systems is selecting many photos from one visually strong scene.

Example:

```text
30 excellent sunset photos

```

could dominate the top scores.

A useful vacation album should instead preserve coverage of the overall experience.

Therefore the final selection should discourage excessive redundancy.

Conceptually:

```text
Final utility =
    quality
  + importance
  + diversity
  - redundancy

```

This is a conceptual model, not a required literal formula.

---

# 21. Potentially Important Photos

Some images may deserve protection from aggressive filtering.

Examples may include:

- Favorites;
- highly unique photos;
- photos representing isolated moments;
- photos unlike any other selected image.

A unique photo should often receive different treatment than one of ten nearly identical photos.

---

# 22. Screenshots and Non-Camera Assets

Screenshots may exist in a user's selected range.

MVP behavior should be predictable.

Recommended initial rule:

If the user explicitly selected the photo, the application may analyze it, but screenshots should generally receive low priority in travel-style curation unless they represent unique content.

More advanced semantic handling can be added later.

---

# 23. Videos

Videos are outside the primary MVP scope.

Initial MVP options:

```text
Option A:
Ignore videos.

Option B:
Display them but exclude them from automatic curation.

```

Recommended MVP:

**Exclude videos from the selection engine.**

Video curation can become a later feature.

---

# 24. Live Photos

Live Photos should initially be treated primarily through their still-image representation.

The application should preserve the underlying original asset when adding the result to an album.

The MVP does not need to independently rank Live Photo motion segments.

---

# 25. RAW Photos

RAW-specific processing is not an MVP priority.

If RAW assets appear, the system may use the Photos-provided preview representation for analysis.

The application should not modify the RAW asset.

---

# 26. Editing State

If an asset has been edited in Apple Photos, the application should normally evaluate the user's current visible version where possible rather than attempting to reinterpret the original.

The app should not overwrite existing edits.

---

# 27. Privacy Requirements

User photos are highly sensitive data.

The MVP should follow these principles:

- prefer on-device processing;
- avoid uploading images;
- do not maintain unnecessary copies;
- do not create a user account unless needed;
- do not collect photo content for analytics;
- minimize persistent intermediate data.

If temporary files are necessary, they should be removed when no longer needed.

---

# 28. Offline Behavior

The core curation workflow should ideally function without internet access.

Expected:

```text
Select
Analyze
Review
Save

```

should not require a remote server.

External network access may be used later for optional functionality but should not become a hidden requirement for core selection.

---

# 29. Performance Requirements

Exact performance targets should be established through testing on real devices rather than prematurely specified.

The important MVP constraints are:

- UI must remain responsive;
- processing must not cause uncontrolled memory growth;
- assets should be processed incrementally;
- intermediate results should be released when possible;
- progress should be visible;
- cancellation should be supported if practical.

The application should initially optimize for recent iPhones rather than attempt perfect performance across every legacy device.

---

# 30. Memory Requirements

The application must not decode hundreds or thousands of full-resolution photos simultaneously.

Preferred pattern:

```text
PHAsset
   ↓
request appropriate thumbnail/input size
   ↓
analyze
   ↓
store compact features/results
   ↓
release image

```

Persistent analysis data should generally contain compact values such as:

- identifiers;
- scores;
- embeddings;
- metadata;
- cluster membership.

Not full-size image buffers.

---

# 31. Analysis Progress

Long-running analysis should expose progress.

Minimum UI state:

```text
Analyzing

432 / 1,024 photos

```

The progress estimate does not have to be perfectly linear.

The UI should avoid appearing frozen.

---

# 32. Cancellation

The user should be able to leave or cancel an analysis operation without corrupting app state.

The first version may discard the incomplete analysis entirely.

Sophisticated resume support is not required for MVP.

---

# 33. Error Handling

The application must gracefully handle common failures such as:

- Photos permission denied;
- assets no longer available;
- iCloud asset unavailable;
- image request failure;
- insufficient storage;
- application interruption;
- memory pressure.

Errors should be user-readable.

Avoid exposing internal implementation details.

Example:

```text
Some photos couldn't be analyzed.

1,018 of 1,024 photos were processed.

```

rather than:

```text
PHImageManager request error -1100

```

---

# 34. UX Requirements

The UI should emphasize photos rather than controls.

Design characteristics:

- minimal;
- native iOS;
- image-first;
- low visual clutter;
- clear actions;
- understandable language.

Avoid dashboards filled with AI metrics.

The user does not need to see:

```text
Aesthetic score: 0.842
Blur score: 0.294
Embedding similarity: 0.931

```

unless such information later proves useful.

---

# 35. Explainability

Explainability should focus on simple human concepts.

Useful:

```text
Best of 8 similar photos

```

Useful:

```text
Similar photos

```

Possibly useful:

```text
Sharper photo

```

Not useful for normal users:

```text
Cosine distance = 0.067

```

---

# 36. Manual Override

Every recommendation must be reversible before the final album is created.

The user should be able to:

```text
Selected → remove

Not Selected → add

```

The final result is therefore:

```text
AI recommendation
+
human confirmation

```

rather than fully autonomous decision-making.

---

# 37. Persistence

MVP should persist enough information to prevent accidental loss of useful work when practical.

Possible session data:

```text
CurationSession
- id
- creationDate
- sourceAssetIDs
- targetRatio
- analysisStatus
- selectedAssetIDs
- clusters

```

Whether full sessions need long-term persistence should be decided based on UX needs.

Avoid building a complex persistence layer before it becomes necessary.

---

# 38. Suggested Domain Model

Conceptually:

```text
CurationSession

PhotoCandidate

PhotoFeatures

PhotoScore

PhotoCluster

SelectionResult

```

Example:

```swift
struct PhotoCandidate {
    let assetIdentifier: String
    let captureDate: Date?
}

```

Detailed Swift models belong in technical documentation rather than this product specification.

---

# 39. MVP Scope

The MVP includes:

- Photos Library integration;
- multi-photo input;
- on-device photo analysis;
- similarity detection;
- similarity clustering;
- basic quality scoring;
- best-photo selection within clusters;
- global curated selection;
- target selection size;
- selected-photo review;
- manual override;
- curated album creation.

---

# 40. Explicitly Out of Scope for MVP

The following should not delay the MVP:

- Android;
- macOS app;
- web application;
- cloud photo storage;
- social network;
- photo sharing platform;
- collaborative albums;
- professional photo editing;
- automatic image enhancement;
- RAW development;
- video curation;
- generative photo editing;
- automatic photo deletion;
- cross-device synchronization;
- user accounts;
- subscription backend;
- recommendation feeds;
- facial identity databases;
- complex cloud infrastructure.

---

# 41. Testing Strategy

The project intentionally prioritizes rapid iteration.

The repository does not require:

- unit-test targets;
- UI-test targets;
- generated test boilerplate;
- test-only architecture;
- mock frameworks created solely for tests.

The developer will perform manual validation.

However, selection quality must still be evaluated systematically.

A separate document should define:

```text
docs/manual-validation.md

```

This should contain repeatable manual test datasets and scenarios such as:

- burst sequences;
- portraits;
- landscapes;
- low-light images;
- motion blur;
- near-duplicates;
- mixed scenes;
- 1,000-photo travel collections.

The absence of automated tests must not imply the absence of validation.

---

# 42. Selection Quality Evaluation

The most important metric is whether the recommended photos match human preference.

Useful manual metrics may include:

### Best-of-cluster accuracy

```text
In what percentage of similar-photo groups
does the engine choose the same best image
as the human reviewer?

```

### Recall of important photos

```text
How often does the engine preserve photos
that the human reviewer considers essential?

```

### Redundancy

```text
How many unnecessarily similar images
remain in the final result?

```

### User override rate

```text
How frequently does the user replace
the engine's recommendation?

```

These metrics are more meaningful than traditional code-level testing for validating the selection algorithm itself.

---

# 43. Initial Success Criteria

A successful MVP should demonstrate that:

1. A user can select approximately 1,000 photos without the application becoming unusable.
2. The app can analyze the collection entirely or primarily on-device.
3. Similar photos are grouped reliably enough to be useful.
4. The preferred photo from a similar group is usually reasonable.
5. The final collection contains significantly less redundancy than the input.
6. Users can easily override incorrect recommendations.
7. The app never modifies or deletes original assets unexpectedly.
8. The resulting curated album is meaningfully easier to review than the original photo collection.

---

# 44. Product Metrics

Early development should prioritize quality metrics over growth metrics.

Useful initial metrics:

```text
Input photo count

Selected photo count

Curation ratio

Number of clusters

Average cluster size

Manual add-back rate

Manual removal rate

Best-photo replacement rate

Analysis duration

```

User photo content must not be collected for analytics.

Metrics should use non-sensitive numerical information where possible.

---

# 45. Architecture Direction

The expected MVP architecture is:

```text
iOS App
   │
   ├── SwiftUI
   │
   ├── Photos / PhotoKit
   │
   ├── Vision
   │
   ├── Core ML
   │
   └── Local Selection Engine

```

A backend is not required by default.

The architecture should remain modular enough that individual selection components can evolve without creating unnecessary abstraction.

---

# 46. Development Priority

Implementation should proceed in approximately this order:

```text
1. Import/select photos
2. Display selected assets
3. Extract lightweight image representations
4. Build similarity features
5. Cluster similar photos
6. Rank photos inside clusters
7. Generate a global selection
8. Review results
9. Manual override
10. Create Photos album
11. Improve selection quality
12. Improve performance

```

The selection engine should become useful before significant time is spent polishing secondary UI.

---

# 47. Key Technical Risk

The primary product risk is not whether iOS can process 1,000 images.

It can.

The primary risk is:

> Can the selection engine consistently make choices that users consider reasonable?

Therefore engineering effort should concentrate on:

```text
Similarity
+
Clustering
+
Ranking
+
Diversity

```

rather than infrastructure.

---

# 48. Key UX Risk

Users may distrust the application if they believe it is deciding which memories should be deleted.

The UX must continuously reinforce the actual model:

```text
photos-curator recommends.

The user decides.

```

This is why the MVP should create a curated album rather than automatically delete unselected photos.

---

# 49. Future Possibilities

These features may be considered only after the core curation experience works well:

- smart trip detection;
- automatic album suggestions;
- person-aware selection;
- pet-aware selection;
- event detection;
- story generation;
- highlight reels;
- video selection;
- automatic cleanup suggestions;
- duplicate cleanup;
- personalized aesthetic preference;
- learning from manual overrides;
- macOS companion app;
- optional cloud-assisted models.

They are not requirements for MVP.

---

# 50. Definition of Done for MVP

The MVP is ready for real-world evaluation when a user can:

```text
Open photos-curator
        ↓
Select ~1,000 photos
        ↓
Choose desired collection size
        ↓
Run analysis
        ↓
Receive a curated recommendation
        ↓
Inspect similar-photo groups
        ↓
Override recommendations
        ↓
Create a curated Photos album

```

without:

- uploading the photo collection to a server;
- modifying original photos;
- requiring an account;
- requiring a backend;
- requiring automated test infrastructure.

At this point, development should shift from adding features to improving:

```text
selection quality
performance
trust
UX

```

---

# 51. Product North Star

The core product question should remain:

> If the user has 1,000 photos, can photos-curator reduce them to approximately 150 photos that the user is genuinely happy to revisit?

Every major feature should be evaluated against that question.

If a feature does not materially improve that outcome, it probably does not belong in the MVP.