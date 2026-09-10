# Photos Curator — Product & Engineering Roadmap

**Document:** `12_Roadmap.md`  
**Project:** Photos Curator  
**Status:** Implementation Guide  
**Priority:** Required  
**Target Platform:** iOS / iPhone  
**Primary Technology:** SwiftUI, PhotoKit, Vision  
**Processing Model:** On-device first

---

## 1. Purpose

This document defines the recommended implementation order for Photos Curator.

The roadmap is designed to answer one practical question:

> What should be built first, what should be delayed, and what conditions must be satisfied before moving to the next stage?

Photos Curator should not begin as a fully featured AI photo-management product.

The first objective is much narrower:

> Prove that an iPhone can take a large set of approximately 1,000 travel photos and automatically produce a smaller album that a human considers meaningfully better than random or purely chronological selection.

Everything else is secondary until that behavior works reliably.

The development sequence is therefore:

**Technical Prototype → Selection Engine Prototype → Functional MVP → Quality Hardening → Beta → Personalization**

The roadmap intentionally avoids premature infrastructure, backend services, automated test suites, complex machine-learning systems, social features, cloud synchronization, or other work that does not directly validate the core product.

---

# 2. Guiding Principles

## 2.1 Selection quality is the product

Photos Curator is not primarily a photo browser.

Its core value is the quality of its decisions.

A technically polished application that consistently selects mediocre photos is not a successful product.

Development priority should therefore generally follow:

```text
Selection quality
    ↓
Reliability
    ↓
Performance
    ↓
Review experience
    ↓
Polish
    ↓
Advanced features
```

---

## 2.2 Build the smallest complete pipeline first

Do not attempt to perfect individual components before an end-to-end pipeline exists.

The earliest useful system should already be capable of:

```text
Photo Library
    ↓
Asset loading
    ↓
Image analysis
    ↓
Moment grouping
    ↓
Duplicate / similarity grouping
    ↓
Candidate scoring
    ↓
Shortlist
    ↓
Final album
    ↓
Human review
```

Individual algorithms may initially be simple.

A complete imperfect pipeline is more valuable than an isolated sophisticated ranking model.

---

## 2.3 Prefer deterministic heuristics before sophisticated AI

The first versions of the selection engine should rely heavily on understandable signals such as:

- sharpness
- exposure
- face presence
- face quality
- eyes open when detectable
- duplicate similarity
- temporal proximity
- burst membership
- image orientation
- photo type
- screenshot detection
- scene diversity
- moment representation

These signals are easier to debug and evaluate than opaque ranking systems.

More complex learned ranking or personalization should only be introduced after sufficient real-world evidence shows where deterministic scoring fails.

---

## 2.4 Avoid infrastructure before it is necessary

The MVP should not require a backend.

Prefer:

```text
Photo Library → On-device processing → Local state → User review
```

over:

```text
Photo Library
    ↓
Upload
    ↓
Backend
    ↓
Cloud AI
    ↓
Database
    ↓
Synchronization
    ↓
Result
```

A backend should only be introduced later if a product requirement cannot reasonably be implemented on-device.

---

## 2.5 Optimize for iteration speed

During early development, architectural decisions should make it easy to change:

- scoring weights
- similarity thresholds
- moment boundaries
- album size rules
- quality thresholds
- diversity constraints
- exclusion rules

These should preferably be represented by configuration rather than scattered constants.

The selection engine should be easy to rerun against the same photo set after changing parameters.

---

# 3. Roadmap Overview

| Phase | Goal | Product State |
|---|---|---|
| Phase 0 | Establish minimum project foundation | Empty but runnable app |
| Phase 1 | Prove photo access and analysis | Technical prototype |
| Phase 2 | Build first complete selection engine | Algorithm prototype |
| Phase 3 | Build usable end-to-end application | MVP |
| Phase 4 | Improve selection quality | MVP quality pass |
| Phase 5 | Harden performance and reliability | Beta-ready |
| Phase 6 | Validate with real users | Beta |
| Phase 7 | Introduce personalization | Post-MVP |
| Phase 8 | Evaluate advanced intelligence | Future product |

The phases are sequential in terms of dependency, not necessarily calendar time.

A phase should be considered complete when its exit criteria are satisfied rather than after a fixed number of development days.

---

# 4. Phase 0 — Minimum Project Foundation

## Objective

Create only enough application structure to support rapid development of the selection pipeline.

Do not build a full production architecture at this stage.

---

## Deliverables

Create the SwiftUI application shell and the minimum services required by the architecture defined in `05_iOS_Architecture.md`.

Suggested initial modules:

```text
App
Features/
    PhotoImport/
    Processing/
    Results/
Core/
    Models/
    Services/
    SelectionEngine/
```

The exact folder structure may evolve.

Avoid creating empty abstraction layers merely because they may theoretically be useful later.

---

## Initial screens

Only basic placeholders are necessary:

```text
Home
  ↓
Photo Source / Selection
  ↓
Processing
  ↓
Results
```

Settings, onboarding, personalization, analytics dashboards, detailed explanations, and advanced album controls are not required yet.

---

## Configuration

Create a central location for selection-engine parameters.

Example conceptual structure:

```swift
SelectionConfiguration
```

It may contain values such as:

```text
duplicateSimilarityThreshold
momentTimeGap
minimumQualityScore
targetAlbumRatio
maximumPhotosPerMoment
landscapeQuota
groupPhotoPreference
diversityWeight
```

The purpose is not to create a complex configuration system.

The purpose is to allow fast experiments without rewriting algorithm logic.

---

## Exit criteria

Phase 0 is complete when:

- the app builds and runs on a physical iPhone;
- Photo Library authorization can be requested;
- the basic navigation flow works;
- core data models can represent a photo and its analysis state;
- the project structure does not block implementation of the analysis pipeline.

Do not spend significant time polishing this phase.

---

# 5. Phase 1 — Technical Photo Analysis Prototype

## Objective

Prove that the application can efficiently inspect a real photo library using Apple frameworks.

No intelligent album generation is required yet.

The main question is:

> Can Photos Curator reliably extract the information required by the future selection engine?

---

## 5.1 PhotoKit integration

Implement:

```text
PHPhotoLibrary authorization
PHAsset fetching
thumbnail requests
metadata extraction
iCloud-backed asset handling
cancellation
```

The application should work with both locally stored and iCloud Photos assets.

The implementation must follow the behaviors defined in:

`07_Apple_Framework_Integration.md`

and:

`09_Privacy_and_Permissions.md`.

---

## 5.2 Create the analysis pipeline

For each candidate photo, generate an `AssetAnalysis`.

The first analysis version should prioritize inexpensive signals.

Example:

```text
Asset
 ├─ dimensions
 ├─ timestamp
 ├─ orientation
 ├─ media subtype
 ├─ favorite state
 ├─ screenshot status
 ├─ burst information
 ├─ perceptual similarity representation
 ├─ visual quality signals
 ├─ face count
 └─ scene / composition signals
```

Not every possible Vision feature needs to be implemented.

Only implement signals that are expected to influence selection.

---

## 5.3 Build a developer inspection view

During development, create a simple internal view capable of showing:

```text
Thumbnail
Asset ID
Timestamp
Quality score
Face count
Similarity group
Moment
Selection score
Selection state
```

This is significantly more valuable at this stage than visual polish.

The developer must be able to answer:

> Why did the engine choose this image?

and:

> Why did the engine reject that image?

without inspecting raw memory structures.

---

## 5.4 Run against real libraries

Do not validate the pipeline using only ten or twenty carefully chosen sample photos.

Test with realistic sets such as:

```text
100 photos
500 photos
1,000 photos
2,000+ photos
```

The objective is not yet performance optimization.

The objective is discovering incorrect assumptions.

---

## Exit criteria

Phase 1 is complete when:

- real PhotoKit assets can be processed;
- iCloud-backed photos fail gracefully or download when appropriate;
- analysis does not require loading full-resolution images unnecessarily;
- several hundred photos can be analyzed without obvious memory problems;
- each analyzed asset produces enough signals for the first selection engine.

---

# 6. Phase 2 — Selection Engine Prototype

## Objective

Build the first end-to-end algorithm capable of converting a large photo set into a smaller album.

This phase is the first major product validation point.

UI quality remains secondary.

---

# 6.1 Stage A — Hard exclusions

Remove items that should almost never compete with normal photography.

Possible exclusions include:

```text
screenshots
obviously corrupted assets
unsupported assets
extremely low-quality images
accidental captures
exact duplicates
```

Hard exclusions should remain conservative.

When uncertain, prefer ranking an image lower rather than permanently eliminating it.

---

# 6.2 Stage B — Moment detection

Partition the input library into meaningful temporal groups.

Example:

```text
Trip
 ├─ Moment A — airport
 ├─ Moment B — hotel arrival
 ├─ Moment C — beach
 ├─ Moment D — dinner
 └─ Moment E — night market
```

Initially, moment detection may rely largely on capture time gaps.

Geographic or semantic information can later improve boundaries if necessary.

The objective is not perfect event recognition.

The objective is preventing the final album from being dominated by one short photographic burst.

---

# 6.3 Stage C — Similarity and duplicate grouping

Identify visually similar photos.

Typical cases:

```text
same pose photographed five times
burst sequences
slightly different framing
multiple shots of the same landscape
repeated selfies
near-identical group photos
```

Photos should be grouped into similarity clusters.

The engine should normally choose only the strongest representative from highly redundant clusters.

---

# 6.4 Stage D — Individual quality scoring

Calculate a base quality score for each surviving candidate.

Conceptually:

```text
qualityScore =
    technicalQuality
  + faceQuality
  + compositionSignal
  + userSignal
  - defectPenalty
```

Exact weights should remain configurable.

Do not spend excessive time finding theoretically perfect weights.

The initial goal is producing obviously reasonable rankings.

---

# 6.5 Stage E — Contextual scoring

An image should not be evaluated completely independently.

Adjust ranking according to its role within the entire album.

For example:

```text
excellent 17th photo of the same landmark
```

may be less useful than:

```text
good first photo of an important different moment
```

This introduces:

```text
moment representation
subject diversity
orientation diversity
scene diversity
people diversity
redundancy penalty
```

---

# 6.6 Stage F — Shortlist generation

Generate an intermediate candidate set significantly larger than the final album.

Example for 1,000 source photos:

```text
1,000 source assets
        ↓
600 valid candidates
        ↓
250 non-redundant candidates
        ↓
100–150 shortlist
```

The exact numbers are not requirements.

The shortlist exists so that expensive or contextual ranking can operate on a much smaller candidate set.

---

# 6.7 Stage G — Final album construction

Construct the requested album while enforcing diversity.

Example:

```text
100 shortlisted photos
        ↓
30–50 final photos
```

Selection should not simply take the highest-scoring N images.

Album construction should consider:

```text
quality
redundancy
moments
people
group photos
landscapes
story coverage
orientation
visual diversity
```

Detailed rules are defined in `03_Photo_Selection_Rules.md`.

---

# 6.8 Add selection reasons

Each decision should produce machine-readable reasons.

Example:

```text
selected:
- strongest image in duplicate cluster
- high face quality
- represents unique moment

rejected:
- near duplicate of selected image
- lower sharpness
- redundant scene
```

These reasons are primarily for development diagnostics.

They may later support user-facing explanations.

---

## Exit criteria

Phase 2 is complete when a developer can provide approximately 1,000 real photos and receive a plausible curated album without manually intervening.

The result does not need to be consistently excellent yet.

However, it must clearly outperform:

```text
random selection
```

and should generally outperform:

```text
take every Nth photo
```

or:

```text
take the highest technical-quality scores only
```

If the generated album still feels obviously random, development should remain focused on Phase 2.

Do not move to UI polish.

---

# 7. Phase 3 — Functional MVP

## Objective

Transform the selection-engine prototype into an application that a real user can operate without developer assistance.

The product flow should become:

```text
Open Photos Curator
        ↓
Grant Photos access
        ↓
Choose photos / trip
        ↓
Choose approximate album size
        ↓
Start curation
        ↓
Processing
        ↓
Review result
        ↓
Adjust selection
        ↓
Save result
```

---

## 7.1 Home experience

The home screen should clearly communicate the core action.

Avoid introducing multiple unrelated entry points.

The primary CTA should be equivalent to:

> Curate Photos

The user should immediately understand that the app selects the best images from a larger set.

---

## 7.2 Input selection

Support the minimum input method necessary for the intended MVP.

Depending on the final UX decision, this may be:

```text
manual photo selection
```

or:

```text
date-range / trip selection
```

Do not implement a sophisticated event-management system unless required.

---

## 7.3 Album size

Give users a simple level of control.

For example:

```text
Highlights
Balanced
More Photos
```

Internally these may correspond to target ratios or photo counts.

Avoid requiring users to configure technical selection parameters.

---

## 7.4 Processing screen

Processing should expose meaningful progress.

Example:

```text
Preparing photos
Analyzing photos
Finding similar shots
Choosing highlights
Building your album
```

The application should remain resilient to interruption.

Detailed performance behavior belongs to `08_Performance_Spec.md`.

---

## 7.5 Results screen

The user must be able to inspect the complete generated album.

At minimum, support:

```text
view selected images
remove a selected image
restore / add an omitted image
review the source set when necessary
```

The app should not treat AI selection as irreversible.

Human override is part of the product.

---

## 7.6 Save / export

The selected result should be saved using the behavior defined elsewhere in the product specification.

Avoid destructive operations.

Photos Curator should not delete source photos during MVP.

---

## 7.7 Basic error states

Handle at least:

```text
Photos permission denied
Limited Photos access
No photos selected
Asset unavailable
iCloud download failure
Insufficient memory / processing failure
Processing interruption
Selection engine returns too few candidates
```

Errors should provide a recovery action whenever possible.

---

## MVP exit criteria

The product reaches functional MVP when a new user can:

```text
install
→ grant permission
→ provide a large photo set
→ generate a curated album
→ review the result
→ modify mistakes
→ save the result
```

without requiring developer assistance.

At this point, selection quality may still require tuning.

---

# 8. Phase 4 — Selection Quality Hardening

## Objective

Improve the album from "technically reasonable" to "something users would actually trust."

This phase should be driven primarily by real examples rather than theoretical algorithm improvements.

---

## 8.1 Create evaluation datasets

Maintain several representative photo collections.

Examples:

| Dataset | Primary challenge |
|---|---|
| Travel city | landmarks, streets, food, people |
| Beach trip | repeated landscapes and portraits |
| Family trip | group photos and children |
| Event | bursts and repeated people |
| Scenic trip | landscapes and viewpoint duplicates |
| Mixed library | screenshots, food, documents, people, scenery |

These datasets do not need to be stored as formal automated test fixtures inside the repository.

They serve as manual evaluation material.

---

## 8.2 Perform side-by-side evaluation

For each significant engine change, compare:

```text
Previous engine
vs.
New engine
```

Do not evaluate the new output in isolation.

This makes regressions much easier to notice.

---

## 8.3 Focus on high-impact failure modes

Prioritize errors such as:

```text
bad face selected instead of good face
blurred image selected
duplicate photos retained
important moment completely missing
album dominated by selfies
album dominated by landscapes
group photo omitted
only one person repeatedly represented
chronological story becomes incoherent
```

Minor ranking disagreements should not receive the same engineering effort.

---

## 8.4 Tune album-level diversity

Individual quality scores are insufficient.

Improve constraints for:

```text
moment coverage
duplicate suppression
people coverage
scene diversity
landscape / portrait balance
group photo representation
visual repetition
```

The final album should feel intentionally curated rather than merely filtered.

---

## 8.5 Collect decision-level diagnostics

When reviewing a poor output, developers should be able to inspect:

```text
asset score
cluster
moment
penalties
bonuses
final rank
selection reason
rejection reason
```

Without this visibility, parameter tuning becomes guesswork.

---

## Exit criteria

Phase 4 is complete when manual evaluation repeatedly shows that most generated albums require only limited user correction rather than extensive rebuilding.

The specific thresholds should follow the metrics defined in:

`11_Analytics_and_Metrics.md`

and the manual evaluation methodology defined in:

`10_Manual_QA_and_Selection_Evaluation.md`.

---

# 9. Phase 5 — Performance and Reliability Hardening

## Objective

Make the application reliable on realistic libraries before wider distribution.

Selection quality remains important, but the focus shifts toward execution behavior.

---

## 9.1 Test realistic scale

Validate at least:

```text
~1,000 photos — normal expected workload
~2,500 photos — heavy workload
~5,000 photos — stress workload
```

The system does not necessarily need identical latency across all datasets.

It must remain stable.

---

## 9.2 Control memory

Full-resolution images should not remain in memory unnecessarily.

Prefer:

```text
PHAsset
    ↓
appropriately sized image request
    ↓
analysis
    ↓
store compact result
    ↓
release image
```

Avoid:

```text
5,000 full-resolution UIImages
```

being retained simultaneously.

---

## 9.3 Improve batching

Tune:

```text
batch sizes
concurrent Vision operations
thumbnail dimensions
PhotoKit request behavior
cache limits
```

Performance optimization should be based on measurements from physical devices.

---

## 9.4 Support interruption

The application must behave correctly when:

```text
the user backgrounds the app
the device locks
an image request is cancelled
iCloud retrieval stalls
processing is interrupted
memory pressure occurs
```

The application should either resume safely or restart processing without corrupting user state.

---

## 9.5 Cache expensive analysis

Where useful, cache stable results such as:

```text
quality signals
face analysis
similarity representation
asset metadata
```

Do not implement complex cache invalidation unless it is genuinely necessary.

The cache should be an optimization, not a second source of truth.

---

## Exit criteria

Phase 5 is complete when the application can repeatedly curate realistically large libraries on supported devices without:

```text
crashes
runaway memory growth
corrupted state
incorrect progress
duplicate results caused by retry
unrecoverable interruption
```

The performance requirements defined in `08_Performance_Spec.md` should be satisfied.

---

# 10. Phase 6 — Beta Validation

## Objective

Determine whether Photos Curator solves the intended problem for people other than its developer.

At this point, further engineering should increasingly be driven by observed behavior.

---

## 10.1 First beta population

Start with a small number of users who regularly take many photos.

Ideal use cases include:

```text
travel
family events
vacations
day trips
celebrations
photography-heavy outings
```

The goal is not demographic representativeness.

The goal is collecting difficult real-world photo sets.

---

## 10.2 Observe corrections

The most important behavioral signal is not whether users say:

> The result is good.

More useful information is:

```text
Which selected photos do they remove?
Which rejected photos do they restore?
How many changes do they make?
Do they regenerate the album?
Do they abandon the result?
Do they save the album?
```

These interactions reveal systematic engine errors.

---

## 10.3 Add analytics

At this stage, implement the minimum analytics defined in:

`11_Analytics_and_Metrics.md`.

Important metrics should include concepts such as:

```text
curation completion rate
processing failure rate
selected-photo removal rate
rejected-photo restoration rate
final acceptance rate
regeneration rate
processing duration
input photo count
output photo count
```

Do not collect image content or face identity information merely for analytics.

---

## 10.4 Maintain privacy guarantees

Analytics must remain compatible with:

`09_Privacy_and_Permissions.md`.

The selection engine should not require uploading the user's private photo library merely to measure product quality.

---

## Beta exit criteria

The product is ready to leave early beta when:

- curation reliably completes;
- users understand the workflow;
- most albums require relatively few corrections;
- major algorithm failure patterns are understood;
- large libraries do not commonly crash the app;
- analytics confirm that users actually save or keep the generated result.

At this point, the project has validated its core premise.

---

# 11. Phase 7 — Personalization

## Objective

Make the engine adapt to the user's preferences after the generic selection engine is already good.

Personalization must not be used to compensate for a weak base model.

---

## 11.1 Learn from explicit corrections

The first personalization source should be direct user behavior.

Examples:

```text
AI selects photo → user removes it
AI rejects photo → user restores it
AI chooses A from cluster → user replaces it with B
```

These decisions provide strong preference signals.

---

## 11.2 Maintain a lightweight preference profile

A local profile might gradually estimate preferences such as:

```text
more people photos
fewer selfies
more landscapes
more group photos
more food photos
stronger preference for favorites
preferred album density
preferred portrait / landscape mix
```

Do not begin by training a complex personalized neural network.

Simple adaptive weights may provide most of the useful benefit.

---

## 11.3 Separate universal quality from personal preference

The system should distinguish:

```text
Is this photo technically good?
```

from:

```text
Does this user tend to want this type of photo?
```

For example, personalization should not cause an obviously blurred image to outrank a sharp alternative merely because the category is preferred.

Conceptually:

```text
finalScore =
    universalQuality
  + contextualValue
  + personalPreference
```

with appropriate safeguards.

---

## 11.4 Make personalization reversible

Users should eventually be able to reset learned preferences.

The engine should also remain functional if no personalization data exists.

Cold-start quality therefore depends entirely on the generic selection engine.

---

## Exit criteria

Personalization is successful when repeated user corrections decrease across multiple curation sessions without causing clear regressions in basic image quality.

---

# 12. Phase 8 — Advanced Intelligence

This phase is intentionally outside the initial product requirement.

Implement only after sufficient product usage demonstrates a clear need.

Possible directions include the following.

---

## Semantic trip understanding

Instead of only detecting moments:

```text
Moment 1
Moment 2
Moment 3
```

the system might understand approximate roles such as:

```text
arrival
hotel
landmark
meal
activity
sunset
nightlife
departure
```

This could improve narrative coverage.

---

## Story-aware album generation

Future versions could optimize not merely for the best individual images but for photographic storytelling.

Example:

```text
Establishing shot
      ↓
People
      ↓
Activity
      ↓
Details
      ↓
Key landmark
      ↓
Closing moment
```

This should only be attempted after reliable lower-level selection exists.

---

## Natural-language preferences

A later version might allow instructions such as:

> Make a 30-photo album with more pictures of people.

or:

> Keep landscapes but remove repetitive food photos.

Natural-language controls should map to deterministic selection parameters where possible.

They should not require replacing the entire engine with a generative model.

---

## Cross-event learning

The app might eventually learn broader preferences across multiple albums.

Any such feature must remain consistent with the privacy model.

---

## Advanced face-aware selection

Potential improvements may include better evaluation of:

```text
eyes open
face orientation
expression
occlusion
group-photo quality
whether everyone is looking toward the camera
```

These capabilities should be introduced only when supported reliably by the selected Apple frameworks and device performance.

---

# 13. Features Explicitly Deferred

The following are not required for the initial MVP unless product evidence later justifies them.

| Feature | Initial decision |
|---|---|
| Backend server | Defer |
| User accounts | Defer |
| Cloud synchronization | Defer |
| Social network | Out of scope |
| Shared collaborative albums | Defer |
| Android app | Out of initial scope |
| macOS app | Defer |
| Web application | Defer |
| Generative photo editing | Out of scope |
| Automatic deletion of rejected photos | Out of scope |
| Full photo-library organizer | Out of scope |
| Custom ML training pipeline | Defer |
| Server-side image processing | Defer |
| Complex semantic search | Defer |
| Subscription infrastructure | Defer until monetization is validated |
| Unit-test target | Not required for current development strategy |
| UI-test target | Not required for current development strategy |

Deferral does not mean these features are permanently rejected.

It means they should not compete with core selection quality during early development.

---

# 14. Recommended Implementation Order

The following is the practical coding sequence.

```text
1. Create SwiftUI app shell
        ↓
2. Implement Photos permission
        ↓
3. Fetch PHAssets
        ↓
4. Display selected photo set
        ↓
5. Build batch image-analysis pipeline
        ↓
6. Add basic technical-quality analysis
        ↓
7. Add face analysis
        ↓
8. Add similarity / duplicate representation
        ↓
9. Implement moment grouping
        ↓
10. Implement duplicate clustering
        ↓
11. Implement base candidate scoring
        ↓
12. Generate shortlist
        ↓
13. Implement diversity-aware final selection
        ↓
14. Display generated album
        ↓
15. Allow remove / restore
        ↓
16. Save final album
        ↓
17. Add interruption / error handling
        ↓
18. Optimize memory and batching
        ↓
19. Run manual selection-quality evaluation
        ↓
20. Tune rules and thresholds
        ↓
21. Add essential analytics
        ↓
22. Run beta
        ↓
23. Analyze user corrections
        ↓
24. Add personalization
```

This sequence should be changed only when a concrete dependency requires it.

---

# 15. Milestone Definitions

## Milestone A — Pipeline Works

Input:

```text
1,000 photos
```

Output:

```text
structured analysis for each usable photo
```

No meaningful curation quality is required yet.

---

## Milestone B — Engine Works

Input:

```text
1,000 photos
```

Output:

```text
a 30–50 photo album
```

The result is visibly more coherent than random selection.

---

## Milestone C — MVP Works

A normal user can complete the entire workflow without developer intervention.

```text
select
→ process
→ review
→ adjust
→ save
```

---

## Milestone D — Curation Feels Useful

Most generated albums are good enough that users edit rather than rebuild them.

The distinction is important.

If users routinely replace a large proportion of selected images, the product is functioning technically but has not yet solved the curation problem.

---

## Milestone E — Beta Is Stable

The app can process realistic libraries consistently without major crashes, memory failures, or corrupted results.

---

## Milestone F — Personalization Adds Value

Users who curate multiple albums need progressively fewer corrections.

---

# 16. Development Decision Gates

Several decision gates should prevent unnecessary work.

---

## Gate 1 — Can on-device analysis handle the workload?

Evaluate after Phase 1.

If yes:

```text
continue on-device
```

If no:

First optimize:

```text
image resolution
batching
Vision requests
concurrency
caching
analysis scope
```

Do not immediately introduce a backend.

---

## Gate 2 — Does the algorithm produce useful albums?

Evaluate after Phase 2.

If no:

Improve:

```text
moment detection
duplicate clustering
quality scoring
diversity constraints
```

Do not compensate with UI polish.

---

## Gate 3 — Do users substantially edit every album?

Evaluate during beta.

If yes:

Analyze correction patterns.

Do not immediately add more AI.

First determine whether the problem is caused by:

```text
incorrect scoring
bad duplicate detection
poor moment segmentation
insufficient diversity
album-size mismatch
personal preferences
```

---

## Gate 4 — Is personalization actually necessary?

Only introduce personalized ranking if users show consistent individual preferences that cannot be handled adequately by universal selection rules.

---

## Gate 5 — Is a backend necessary?

A backend should require a specific justification such as:

```text
cross-device synchronization
account-based persistence
remote model requirements
collaboration
server-dependent product functionality
```

"Maybe useful later" is not sufficient justification.

---

# 17. Manual Validation Strategy Across the Roadmap

The project intentionally prioritizes rapid iteration and manual validation rather than maintaining automated unit-test and UI-test targets.

Quality assurance should therefore be integrated into each roadmap stage.

| Phase | Primary validation |
|---|---|
| PhotoKit prototype | Manually inspect asset access and metadata |
| Analysis prototype | Compare extracted signals against visible photos |
| Engine prototype | Inspect clusters, moments, scores, selections |
| MVP | Complete end-to-end manual flows |
| Quality hardening | Compare albums before/after algorithm changes |
| Performance | Stress-test large real libraries |
| Beta | Observe user corrections and failures |
| Personalization | Compare correction rates over repeated sessions |

Detailed procedures are maintained in:

`10_Manual_QA_and_Selection_Evaluation.md`.

---

# 18. What Not to Optimize Early

Before the MVP validates useful photo selection, avoid spending significant development effort on:

```text
complex animations
perfect onboarding
large design systems
custom networking layers
dependency injection frameworks
database abstraction layers
remote configuration platforms
feature-flag infrastructure
server architecture
complex logging systems
custom ML infrastructure
extensive settings screens
multiple export formats
subscription infrastructure
marketing SDKs
```

Some of these may eventually become useful.

Their timing matters more than whether they are inherently good or bad technologies.

---

# 19. Suggested MVP Boundary

The minimum product worth shipping to early testers should contain:

```text
Photos permission
        +
Photo input selection
        +
On-device analysis
        +
Moment grouping
        +
Duplicate / similarity handling
        +
Quality ranking
        +
Diversity-aware album generation
        +
Processing progress
        +
Results review
        +
Manual remove / restore
        +
Save result
        +
Basic failure recovery
```

Anything outside this set requires explicit justification before entering MVP scope.

---

# 20. Post-MVP Prioritization Framework

After MVP, new features should be evaluated against three questions.

### Question 1

Does this improve selection quality?

### Question 2

Does this significantly reduce user effort?

### Question 3

Does real usage data demonstrate that users need it?

A feature strongly satisfying at least one of these questions may deserve prioritization.

A feature satisfying none should normally remain deferred.

---

# 21. Recommended Product Evolution

The intended evolution of Photos Curator can be summarized as:

```text
Version 0
"Can we analyze 1,000 photos?"
        ↓
Version 0.1
"Can we remove obvious bad and duplicate photos?"
        ↓
Version 0.2
"Can we identify the strongest photo in each moment?"
        ↓
Version 0.3
"Can we create a balanced album?"
        ↓
MVP
"Can a user trust the result enough to save it?"
        ↓
Beta
"Does it work reliably across real photo libraries?"
        ↓
V1
"Can most users get a good album with minimal editing?"
        ↓
V1.x
"Can the app learn each user's preferences?"
        ↓
Future
"Can the app understand and curate photographic stories?"
```

Each stage answers a more difficult question.

Do not skip directly to the final question.

---

# 22. Definition of MVP Success

The MVP should not be judged primarily by:

```text
number of AI models
number of features
number of supported photo types
architecture complexity
animation quality
lines of code
```

It should be judged by the following behavior:

> A user gives Photos Curator a large, messy collection of photos and receives a smaller album that they would realistically keep, share, or use with only limited manual correction.

The strongest product signal is therefore:

```text
Input:
Large photo collection

↓ Photos Curator

Output:
Small, diverse, high-quality album

↓ Human review

Only minor corrections required
```

If this behavior is achieved, the product has validated its core value proposition.

If it is not achieved, development should continue improving the selection engine rather than expanding product scope.

---

# 23. Final Roadmap

```text
PHASE 0
Minimum Foundation
        │
        ▼
PHASE 1
PhotoKit + Vision Technical Prototype
        │
        ▼
PHASE 2
Selection Engine Prototype
        │
        │  Core question:
        │  "Can we curate?"
        ▼
PHASE 3
Functional MVP
        │
        │  Core question:
        │  "Can a normal user use it?"
        ▼
PHASE 4
Selection Quality Hardening
        │
        │  Core question:
        │  "Is the result actually good?"
        ▼
PHASE 5
Performance & Reliability
        │
        │  Core question:
        │  "Can it handle real libraries?"
        ▼
PHASE 6
Beta Validation
        │
        │  Core question:
        │  "Do users trust the result?"
        ▼
PHASE 7
Personalization
        │
        │  Core question:
        │  "Can it learn what this user likes?"
        ▼
PHASE 8
Advanced Intelligence
           Core question:
           "Can it curate stories, not just photos?"
```

---

# 24. Final Engineering Principle

When choosing what to build next, prefer the work that most directly answers:

> Why did Photos Curator choose the wrong photo?

over work that answers:

> What additional feature could Photos Curator have?

Until the selection engine is consistently useful, improving its decisions is the highest-leverage engineering work in the project.

Once that foundation is strong, personalization and more advanced intelligence can be added incrementally without requiring the application to be redesigned from scratch.