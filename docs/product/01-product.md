# Photos Curator — Product Requirements Document

**Document:** `01_[PRD.md](http://PRD.md)`  
**Product:** Photos Curator  
**Platform:** iPhone / iOS  
**Status:** Draft for MVP  
**Version:** 1.0

---

# 1. Purpose of This Document

This document defines the product vision, user problem, target users, MVP scope, product requirements, non-goals, and success criteria for **Photos Curator**.

It is intended to serve as the primary product-level source of truth for the MVP.

Detailed implementation decisions are intentionally excluded from this document and belong in the corresponding technical specifications:

- `02_UX_[Flows.md](http://Flows.md)`
- `03_Photo_Selection_[Rules.md](http://Rules.md)`
- `04_Selection_Engine_[Design.md](http://Design.md)`
- `05_iOS_[Architecture.md](http://Architecture.md)`
- `06_Data_[Model.md](http://Model.md)`
- `07_Apple_Framework_[Integration.md](http://Integration.md)`
- `08_Performance_[Spec.md](http://Spec.md)`
- `09_Privacy_and_[Permissions.md](http://Permissions.md)`
- `10_Manual_QA_and_Selection_[Evaluation.md](http://Evaluation.md)`

The PRD defines **what the product should accomplish and why**, rather than exactly how it should be implemented.

---

# 2. Product Summary

Photos Curator is an iPhone application that helps users turn a large collection of photos into a much smaller, high-quality, representative album.

A typical use case is:

> A user returns from a trip with 1,000 photos. Instead of manually reviewing all 1,000 images, Photos Curator analyzes them and proposes a curated album containing the best and most representative photos.

The application should automatically identify:

- near-duplicate photos,
- multiple photos of the same moment,
- blurry or technically poor photos,
- photos where people have closed eyes or poor expressions,
- strong portraits,
- strong group photos,
- strong landscape or location photos,
- important moments,
- visually diverse photos,
- redundant photos,
- and images that contribute meaningful variety to the final album.

The user remains in control of the final result.

Photos Curator **recommends and organizes**. It does not automatically delete the user's original photos.

---

# 3. Product Vision

## 3.1 Vision

Make reviewing thousands of personal photos feel like reviewing only a few dozen.

Photos Curator should become the user's trusted first pass after a trip, event, holiday, family gathering, or other photo-heavy experience.

Instead of asking:

> "Which of these 1,000 photos should I keep?"

the user should be able to ask:

> "Show me the 80 photos that best tell the story."

---

# 4. User Problem

Modern smartphone users take significantly more photos than they ultimately need.

A single trip can easily produce:

- hundreds of photos,
- repeated shots of the same scene,
- burst sequences,
- multiple attempts at the same group photo,
- screenshots,
- accidental photos,
- blurred photos,
- similar portraits,
- and many slightly different versions of the same moment.

The user's problem is not photo capture.

The problem is **photo selection**.

Manually reviewing a large photo library creates several forms of friction.

## 4.1 Too Many Decisions

The user must repeatedly decide:

- Is this photo good?
- Is the next one better?
- Are these two essentially the same?
- Should I keep both?
- Did I already select a similar photo?
- Does my album contain enough photos of each person?
- Did I keep enough landscape photos?
- Am I missing an important moment?

The decision cost grows quickly as the number of photos increases.

---

## 4.2 Duplicate and Near-Duplicate Photos

Users frequently take several photos within a few seconds to increase the probability of getting one good shot.

For example:

- 8 photos of the same group,
- 6 versions of the same sunset,
- 12 photos from a burst,
- 5 selfies with slightly different expressions.

Most users ultimately want only one or a few of these photos.

Finding the best version manually is repetitive and time-consuming.

---

## 4.3 Good Photos Are Not Enough

Simply ranking photos by technical quality does not create a good album.

For example, an algorithm could select ten excellent portraits of the same person while ignoring:

- the destination,
- other people,
- meals,
- activities,
- architecture,
- landscapes,
- or important moments.

A useful photo curator must optimize both:

1. **individual photo quality**, and
2. **album-level diversity and storytelling**.

---

## 4.4 Manual Curation Takes Too Long

For many users, the effort required to curate a trip means the task is postponed indefinitely.

Photos accumulate in the library but are never:

- organized,
- shared,
- printed,
- added to albums,
- or revisited.

Photos Curator should substantially reduce this effort.

---

# 5. Product Goal

The primary product goal is:

> Given a large set of personal photos, automatically generate a substantially smaller collection that preserves the best images, important moments, people, locations, and visual diversity.

The resulting collection should be good enough that the user mainly performs **review and correction**, rather than starting the selection process from zero.

---

# 6. Core Product Principles

## 6.1 Reduce Decisions, Do Not Create More Decisions

Every major product decision should reduce the amount of manual review required.

The app should not expose unnecessary AI scores, technical metrics, cluster IDs, or complicated tuning controls to normal users.

---

## 6.2 User Has Final Control

The selection engine proposes.

The user decides.

Users must be able to:

- review selected photos,
- remove selected photos,
- restore alternatives,
- and approve the final album.

The app must never silently delete original photos.

---

## 6.3 Album Quality Matters More Than Individual Ranking

The highest-scoring individual photos do not necessarily produce the best album.

The final selection should consider:

- moments,
- people,
- scenes,
- time,
- locations where available,
- photo similarity,
- image quality,
- and album diversity.

---

## 6.4 Privacy by Default

Personal photo libraries may contain highly sensitive information.

The product should be designed around local/on-device analysis whenever technically practical.

Photo contents should not be uploaded to a remote server merely for selection unless this becomes an explicit future feature with clear user consent.

The detailed policy is defined in `09_Privacy_and_[Permissions.md](http://Permissions.md)`.

---

## 6.5 Fast Enough to Be Useful

The application is intended for large collections.

A workflow that works well for 50 photos but becomes unusable for 1,000 photos does not solve the primary problem.

The MVP should be designed around approximately:

**1,000 photos per curation session**

while maintaining an architecture that does not prevent future support for larger collections.

Detailed performance requirements are defined in `08_Performance_[Spec.md](http://Spec.md)`.

---

## 6.6 Prefer Simple Product Behavior

The MVP should avoid unnecessary configuration.

The app should make reasonable decisions automatically instead of requiring the user to configure dozens of preferences before starting.

Advanced personalization may be introduced later after real user behavior demonstrates a need.

---

# 7. Target Users

## 7.1 Primary User

The primary user is an iPhone user who frequently takes many photos during:

- travel,
- holidays,
- family events,
- celebrations,
- outings,
- concerts,
- weddings,
- social gatherings,
- or everyday life.

They typically have hundreds or thousands of photos but do not want to spend significant time organizing them.

---

## 7.2 Primary User Characteristics

The target user:

- takes many photos,
- often takes multiple versions of the same scene,
- values memories,
- wants good photos rather than photographic perfection,
- does not want to manually inspect every image,
- expects the application to make useful automatic decisions,
- and wants control before the final result is saved.

The target user does **not** need to understand photography terminology.

---

# 8. Secondary Users

Potential secondary users include:

### Enthusiast photographers

Users who take large numbers of photos and want an initial shortlist before doing their own final selection.

### Parents

Users with large numbers of family and child photos who regularly capture multiple versions of similar moments.

### Content creators

Users who need to quickly reduce a large shoot into a smaller candidate set.

These users may eventually require more sophisticated controls, but they are not the primary design target for the MVP.

---

# 9. Jobs to Be Done

## Primary Job

> When I have taken hundreds or thousands of photos, help me quickly find a small set of photos worth keeping, sharing, or putting into an album.

## Supporting Jobs

The user wants the application to help answer:

> Which photo is the best version of this moment?

> Which photos are basically duplicates?

> Which photos are technically poor?

> Which photos represent the important parts of my trip?

> Do I have too many similar photos?

> Did I include everyone?

> Did I include enough scenery and context?

> Can I reduce 1,000 photos to a manageable album without manually reviewing all 1,000?

---

# 10. Core User Scenario

A representative MVP scenario:

1. The user returns from a five-day trip.
2. The Photos library contains approximately 1,000 photos from the trip.
3. The user opens Photos Curator.
4. The user selects the photos or the relevant date range.
5. The user chooses approximately how many photos they want in the final album.
6. Photos Curator analyzes the selected photos.
7. Similar photos are grouped into moments.
8. Poor-quality and redundant photos are deprioritized.
9. Strong representatives from each meaningful moment are identified.
10. Album-level diversity is considered.
11. Photos Curator proposes a curated selection.
12. The user reviews the result.
13. The user removes or replaces individual selections when necessary.
14. The user approves the selection.
15. Photos Curator creates or exports the curated album into the user's Photos library.

The user should spend most of their time reviewing the final shortlist rather than reviewing the original 1,000 photos.

---

# 11. MVP Definition

The MVP must answer one question extremely well:

> Can Photos Curator reliably transform a large photo set into a substantially smaller, useful album?

The MVP does not need to solve every photo-management problem.

---

# 12. MVP Scope

## 12.1 Photo Source

The application must allow the user to select photos from the iOS Photos library.

The user must be able to curate a reasonably large collection in one session.

Primary MVP target:

**up to approximately 1,000 photos per normal curation session**

The system should not make assumptions that prevent later optimization for 5,000-photo sessions.

---

# 13. Starting a Curation Session

The user must be able to create a curation session from selected photos.

At minimum, the product should support a simple workflow where the user chooses:

- the source photos,
- and a desired output size.

The interface may provide sensible presets such as:

- Small album
- Medium album
- Large album

or allow the user to specify a target number of photos.

The exact interaction is defined in `02_UX_[Flows.md](http://Flows.md)`.

---

# 14. Photo Analysis

For each photo, the system may analyze signals relevant to selection.

These may include:

- sharpness,
- blur,
- exposure,
- face presence,
- eye state,
- facial quality,
- image composition,
- visual similarity,
- timestamps,
- capture sequence,
- semantic content,
- and other locally available signals.

These signals are internal implementation details.

Users should normally see the result of the analysis rather than raw scores.

Detailed scoring logic belongs in:

`03_Photo_Selection_[Rules.md](http://Rules.md)`

and:

`04_Selection_Engine_[Design.md](http://Design.md)`.

---

# 15. Duplicate and Near-Duplicate Detection

The MVP must identify groups of images that are effectively alternative versions of the same photograph or moment.

Examples include:

- burst photos,
- multiple group-photo attempts,
- repeated selfies,
- several photos of the same landmark,
- nearly identical camera angles,
- and shots taken seconds apart with minimal visual change.

The engine should avoid filling the final album with redundant photos.

When several photos represent the same moment, the system should generally select the strongest representative.

Multiple photos from the same moment may still be selected when they provide meaningfully different value.

---

# 16. Moment Detection

Photos should not be treated as independent objects.

The system should attempt to identify meaningful groups or moments using available signals such as:

- capture time,
- visual similarity,
- subjects,
- people,
- scene changes,
- and contextual continuity.

Examples:

**Moment A**

Arrival at the airport.

**Moment B**

First view of the hotel.

**Moment C**

Lunch.

**Moment D**

Temple visit.

**Moment E**

Sunset.

The selection algorithm can then evaluate both:

- the best image within each moment,
- and the importance of the moment within the album.

---

# 17. Technical Quality Filtering

The selection engine should reduce the probability of choosing obviously poor images.

Examples include:

- severe motion blur,
- accidental images,
- unusably dark images,
- unusably overexposed images,
- obvious camera failures,
- poorly captured faces,
- and images that are clearly inferior to another near-duplicate.

Technical quality should not operate as an absolute rule.

A technically imperfect photo may still be valuable if it represents a unique or important memory.

---

# 18. People and Faces

People are often central to personal photo collections.

The product should avoid creating albums that accidentally exclude important people simply because another category of image received higher technical scores.

Where possible, the selection engine should consider:

- strong portraits,
- group photos,
- facial quality,
- closed eyes,
- repeated expressions,
- and representation across people.

The MVP does not need to identify people by real-world identity or name.

Face-related data must be handled according to the privacy requirements in `09_Privacy_and_[Permissions.md](http://Permissions.md)`.

---

# 19. Group Photos

When multiple versions of a group photo exist, Photos Curator should attempt to select the strongest version.

Relevant signals may include:

- number of visible faces,
- eyes open,
- face visibility,
- blur,
- expression quality where technically feasible,
- and overall image quality.

The system should avoid selecting multiple nearly identical group photos unless they provide meaningful differences.

---

# 20. Landscapes and Context Photos

A good travel album should not consist only of portraits.

Photos Curator should preserve contextual images such as:

- landscapes,
- architecture,
- streets,
- food,
- interiors,
- landmarks,
- transportation,
- and environmental details.

These photos help the final collection represent the experience rather than only the people present.

---

# 21. Diversity

The final album must consider diversity across multiple dimensions.

Potential dimensions include:

- time,
- moment,
- scene,
- people,
- visual appearance,
- orientation,
- subject,
- and photo type.

Diversity does not mean every category receives equal representation.

The objective is to reduce unnecessary repetition while preserving the story of the source collection.

---

# 22. Album Size

The user should be able to influence approximately how aggressive the curation is.

For example:

**1,000 source photos → 50 photos**

represents aggressive curation.

**1,000 source photos → 150 photos**

represents broader coverage.

The selection engine should adapt intelligently to the requested album size rather than merely returning the top N individual image scores.

---

# 23. Selection Result

After analysis, Photos Curator must present a proposed curated set.

The user should immediately understand:

- which photos were selected,
- approximately how many photos were selected,
- and that the selection remains editable.

The result should behave like a recommendation rather than an irreversible action.

---

# 24. Review Experience

The review experience is a core part of the MVP.

The user must be able to inspect the proposed album and make corrections before saving it.

At minimum, users should be able to:

- view selected photos,
- remove a selected photo,
- restore or choose an alternative photo when relevant,
- inspect similar photos from the same moment,
- and confirm the final album.

The app should make corrections easy without requiring the user to return to the complete original library.

---

# 25. Explainability

The MVP does not need a sophisticated AI explanation interface.

However, where useful, the UI may communicate simple reasons such as:

- Better shot
- Similar photo
- Blurry
- Eyes closed
- Best of this moment
- Similar composition

The product should avoid exposing opaque technical values such as:

> Quality score: 0.8731

unless needed for internal development or debugging.

---

# 26. Saving the Result

After review, the user must be able to save the curated result.

For the MVP, the preferred outcome is the creation of a regular album in the user's Photos library containing the selected photos.

The original photos remain unchanged.

Photos Curator must not require users to move or duplicate original images unnecessarily.

---

# 27. Originals Must Be Preserved

The MVP is a **selection product**, not a photo deletion product.

Photos Curator must not automatically delete photos that were not selected.

A rejected photo means:

> "Not selected for this curated album."

It does not mean:

> "This photo should be permanently deleted."

Any future cleanup or deletion feature must be designed separately with stronger safeguards.

---

# 28. Processing State

Large photo collections require noticeable processing time.

The application must provide a clear processing state.

The user should understand:

- that analysis is running,
- that the application has not frozen,
- approximately what stage is occurring where useful,
- and whether processing successfully completed.

Detailed UI behavior is defined in `02_UX_[Flows.md](http://Flows.md)`.

Interruption and recovery behavior is defined in `08_Performance_[Spec.md](http://Spec.md)`.

---

# 29. Error Handling

The product must fail safely.

Possible failure conditions include:

- Photos permission denied,
- Photos permission partially granted,
- inaccessible iCloud assets,
- unavailable local photo data,
- insufficient device resources,
- interrupted processing,
- application termination,
- Photos library changes during processing,
- and album creation failure.

Errors should never result in loss or modification of the user's source photos.

---

# 30. Privacy Requirement

Personal photos are highly sensitive data.

The MVP should follow these principles:

1. Analyze photos on-device whenever technically practical.
2. Do not upload photos to a Photos Curator server for normal curation.
3. Do not require account creation for the core MVP workflow.
4. Do not store unnecessary face-derived data.
5. Do not use user photos for external model training.
6. Clearly explain why Photos access is required.
7. Respect Limited Photos access when granted by the user.
8. Delete temporary analysis artifacts when they are no longer required.

Full requirements are defined in `09_Privacy_and_[Permissions.md](http://Permissions.md)`.

---

# 31. Offline Behavior

The core selection pipeline should work without requiring a Photos Curator backend.

Some original photos may still require iCloud download if the full-resolution or required local representation is not currently stored on the device.

The product should distinguish between:

- application processing requirements,
- and Apple's iCloud Photos asset availability.

---

# 32. Account Requirement

The MVP should not require the user to create a Photos Curator account.

There is no clear MVP need for:

- username,
- password,
- profile,
- cloud synchronization,
- or authentication infrastructure.

Avoiding accounts reduces:

- onboarding friction,
- privacy complexity,
- backend development,
- and maintenance burden.

An account system should only be introduced later if a concrete product requirement justifies it.

---

# 33. Backend Requirement

The MVP should not depend on a custom backend for its core photo-selection workflow.

A backend may eventually be useful for:

- optional cloud features,
- cross-device preferences,
- subscription infrastructure,
- remote configuration,
- or analytics.

However, the core ability to curate photos should not require server availability.

---

# 34. Personalization

The initial MVP selection engine should work reasonably well without prior user training.

The user should not need to:

- label hundreds of photos,
- train a personal model,
- configure detailed photographic preferences,
- or complete a preference questionnaire.

The architecture may preserve signals from user corrections for future personalization, but sophisticated personalization is outside the initial MVP.

---

# 35. User Feedback Signals

User corrections provide valuable information about selection quality.

Examples include:

- user removes an AI-selected photo,
- user replaces the selected representative,
- user restores a rejected photo,
- user consistently prefers certain categories,
- user changes album size.

The MVP may record appropriate non-sensitive decision metadata locally for evaluation or future personalization.

Any analytics behavior must follow `11_Analytics_and_[Metrics.md](http://Metrics.md)`.

---

# 36. Functional Requirements

The MVP must support the following capabilities.


| ID    | Requirement                                                                       | Priority |
| ----- | --------------------------------------------------------------------------------- | -------- |
| FR-01 | Access user-selected Photos library content                                       | Must     |
| FR-02 | Create a curation session from a large set of photos                              | Must     |
| FR-03 | Support approximately 1,000 photos in a normal session                            | Must     |
| FR-04 | Analyze individual photo quality                                                  | Must     |
| FR-05 | Detect duplicate and near-duplicate photos                                        | Must     |
| FR-06 | Group photos into meaningful moments or clusters                                  | Must     |
| FR-07 | Identify stronger representatives within similar groups                           | Must     |
| FR-08 | Consider faces and people-related quality signals                                 | Must     |
| FR-09 | Preserve meaningful landscape/context photos                                      | Must     |
| FR-10 | Produce an album-level diverse selection                                          | Must     |
| FR-11 | Allow user to choose or influence output size                                     | Must     |
| FR-12 | Present the proposed album for review                                             | Must     |
| FR-13 | Allow users to remove selected photos                                             | Must     |
| FR-14 | Allow users to inspect or choose alternatives                                     | Must     |
| FR-15 | Preserve all original photos                                                      | Must     |
| FR-16 | Save the final selection to a Photos album                                        | Must     |
| FR-17 | Display processing progress/state                                                 | Must     |
| FR-18 | Handle inaccessible/iCloud assets safely                                          | Must     |
| FR-19 | Handle interruptions without damaging source data                                 | Must     |
| FR-20 | Perform core analysis locally where practical                                     | Must     |
| FR-21 | Work without a Photos Curator user account                                        | Must     |
| FR-22 | Core functionality should not require a custom backend                            | Must     |
| FR-23 | Record enough internal selection information to support manual quality evaluation | Should   |
| FR-24 | Capture appropriate selection feedback for future engine improvement              | Should   |


---

# 37. MVP User Experience Requirements

The MVP experience should prioritize simplicity.

A first-time user should conceptually understand the product from the main workflow:

**Choose Photos → Curate → Review → Save**

Users should not need to understand:

- clustering,
- embeddings,
- computer vision,
- image similarity models,
- confidence thresholds,
- ranking functions,
- or other implementation concepts.

---

# 38. Expected User Interaction Cost

For a collection of approximately 1,000 photos, the app should significantly reduce the number of photos the user must manually evaluate.

The desired interaction pattern is:

**Before Photos Curator**

Review approximately 1,000 photos manually.

**With Photos Curator**

Review approximately 50–150 selected photos plus a small number of alternatives.

This reduction in manual review is one of the most important measures of product value.

---

# 39. Non-Goals for MVP

The following features are explicitly outside the initial MVP unless later promoted through the decision log.

## 39.1 Automatic Photo Deletion

The app will not automatically delete rejected photos.

---

## 39.2 Full Photos App Replacement

Photos Curator is not intended to replace Apple Photos.

It focuses specifically on selection and curation.

---

## 39.3 Professional RAW Workflow

The MVP is not intended to replace professional tools such as Lightroom, Capture One, or dedicated photography culling applications.

Advanced RAW management is not required.

---

## 39.4 Photo Editing

The MVP does not need:

- exposure correction,
- cropping,
- filters,
- retouching,
- color grading,
- object removal,
- or generative editing.

Photos Curator selects photos. It does not edit them.

---

## 39.5 Video Curation

Videos are outside the initial MVP.

The first version should focus on still photos.

Video support may be evaluated later.

---

## 39.6 AI-Generated Albums or Content

The MVP will not generate synthetic images or modify memories using generative AI.

---

## 39.7 Social Network

The MVP does not include:

- profiles,
- followers,
- comments,
- likes,
- public galleries,
- or social feeds.

---

## 39.8 Cloud Photo Storage

Photos Curator will not operate as a replacement cloud photo-storage provider.

---

## 39.9 Cross-Platform Support

Android, macOS, Windows, and web versions are not part of the initial MVP.

The initial product targets iPhone.

---

## 39.10 Complex Personalization

The MVP does not require personalized AI models trained for each user.

---

## 39.11 Manual AI Parameter Controls

The MVP should not expose controls such as:

- similarity threshold,
- blur threshold,
- face confidence threshold,
- diversity coefficient,
- cluster size,
- ranking weights.

These belong to internal engine configuration.

---

## 39.12 Unit Tests and UI Test Targets

Automated unit-test and UI-test targets are not required for this project at the current development stage.

The repository should not contain test targets or test files solely for the sake of conventional project structure.

Product validation will rely primarily on:

- manual application testing,
- repeatable photo datasets,
- selection-quality evaluation,
- regression datasets,
- and manual QA checklists.

The evaluation methodology is defined in:

`10_Manual_QA_and_Selection_[Evaluation.md](http://Evaluation.md)`.

---

# 40. Product Quality Definition

A technically functioning selection algorithm is not sufficient.

The product is considered useful only if users generally agree that its selection is a good starting point.

Selection quality therefore has several dimensions.

## 40.1 Individual Quality

Selected photos should generally be technically and visually preferable to rejected near-duplicates.

---

## 40.2 Moment Coverage

Important moments should appear in the final album.

---

## 40.3 Diversity

The result should avoid excessive repetition.

---

## 40.4 People Coverage

Important people should not disappear unintentionally from the result.

---

## 40.5 Context Coverage

The album should preserve enough environmental and scene information to represent the experience.

---

## 40.6 User Correction Cost

A good result should require relatively few manual changes.

This is particularly important.

An algorithm that produces a beautiful-looking result but requires 50 replacements is less useful than one requiring only 10.

---

# 41. MVP Success Criteria

The MVP should be considered successful when it demonstrates that automated curation provides substantial value compared with manual selection.

Success criteria are divided into product gates and quality targets.

---

# 42. Product Launch Gates

Before considering the MVP usable, all of the following should be true.

### Gate 1 — Large Session Completion

The app can successfully complete a representative curation session containing approximately 1,000 photos on supported devices.

---

### Gate 2 — Safe Photo Handling

No normal curation workflow modifies or deletes original photos.

---

### Gate 3 — Meaningful Reduction

A 1,000-photo collection can be reduced to a user-requested shortlist such as approximately 50–150 photos.

---

### Gate 4 — Duplicate Suppression

Obvious near-duplicate groups do not dominate the final result.

---

### Gate 5 — Reviewability

Users can understand and modify the proposed result without returning to a completely manual review of the entire source collection.

---

### Gate 6 — Recoverable Failure

Permission problems, inaccessible assets, and processing failures do not corrupt the session or source library.

---

# 43. Selection Quality Targets

The following are initial product targets rather than guarantees.

They should be validated using the methodology defined in `10_Manual_QA_and_Selection_[Evaluation.md](http://Evaluation.md)`.

## 43.1 Strong Representative Selection

When a cluster contains several obvious near-duplicates and one is clearly superior, the engine should select the superior candidate in the large majority of cases.

Initial target:

**≥ 85% agreement with human reviewer preference on clear duplicate/near-duplicate cases.**

Ambiguous cases should not be counted as hard failures.

---

## 43.2 Low Redundancy

The final album should contain few obviously unnecessary duplicate selections.

Initial target:

**&lt; 10% of the final album should be judged clearly redundant by a human reviewer.**

---

## 43.3 Important Moment Recall

Important moments identified by a human reviewer should usually be represented in the final result.

Initial target:

**≥ 90% of high-importance moments represented in a medium-sized curated album.**

This metric depends on the requested output size and should be evaluated accordingly.

---

## 43.4 Manual Correction Rate

The user should not need to replace a large portion of the proposed result.

Initial target for representative evaluation datasets:

**≥ 70% of AI-selected photos are acceptable without replacement.**

Longer-term target:

**≥ 80% acceptable without replacement.**

---

# 44. Product Efficiency Target

For a typical large session, Photos Curator should reduce manual decision-making substantially.

A practical success criterion is:

> The user should feel that reviewing the curated result is significantly easier than manually reviewing the entire original collection.

A measurable proxy is:

**At least 80% fewer photos requiring direct manual review than the original collection in common curation scenarios.**

Example:

1,000 source photos.

100-photo curated album.

Even if the user inspects another 50 alternatives during correction, only approximately 150 photos require close manual consideration instead of 1,000.

---

# 45. Performance Success Criteria

Performance details are defined in `08_Performance_[Spec.md](http://Spec.md)`, but the product-level expectation is:

- processing should complete reliably,
- the app should remain responsive where possible,
- memory pressure should not routinely terminate the workflow,
- interruptions should be recoverable,
- and the user should receive meaningful progress feedback.

A faster but substantially worse selection engine is not automatically preferable to a slower, more accurate engine.

The product should optimize the overall user experience rather than raw benchmark speed alone.

---

# 46. Privacy Success Criteria

The MVP should meet all of the following:

- no Photos Curator account required,
- no normal photo upload to a custom backend,
- no original photo deletion,
- clear Photos permission messaging,
- support for Apple's permission model,
- temporary analysis data handled appropriately,
- and no hidden reuse of user photos for training.

---

# 47. Metrics to Observe After MVP

Detailed analytics are defined in `11_Analytics_and_[Metrics.md](http://Metrics.md)`.

At a product level, the most useful signals include:

### Session completion rate

How often users who start curation reach the review result.

### Save rate

How often users save the generated album.

### Selection acceptance rate

How many AI selections remain in the final approved album.

### Replacement rate

How often users replace AI-selected representatives.

### Removal rate

How often users remove selected photos without replacement.

### Restoration rate

How often users recover photos the system initially rejected.

### Album-size adjustment

Whether users frequently request substantially more or fewer photos after seeing the result.

### Repeat usage

Whether users return to curate additional collections.

These metrics should help answer:

> Is the selection engine actually reducing work for users?

not merely:

> Are users tapping buttons?

---

# 48. MVP Constraints

The MVP should optimize for development speed and learning.

Therefore:

- prefer built-in Apple frameworks where suitable,
- prefer on-device processing,
- avoid unnecessary backend infrastructure,
- avoid mandatory accounts,
- avoid premature abstraction,
- avoid architecture designed for hypothetical future platforms,
- avoid features that do not directly improve the core curation loop,
- and prioritize selection quality over feature count.

---

# 49. Product Trade-Off Principles

When product requirements conflict, use the following priorities.

## Priority 1 — Protect User Data

Never compromise source-photo safety for convenience.

---

## Priority 2 — Selection Quality

A curated album that users disagree with provides little value.

---

## Priority 3 — Reduce User Effort

The application exists to eliminate manual review work.

---

## Priority 4 — Reliability

Large sessions should finish predictably.

---

## Priority 5 — Speed

Processing should be reasonably fast, but not at the expense of substantially worse selections.

---

## Priority 6 — Advanced Features

Additional functionality comes only after the core curation workflow works well.

---

# 50. Key Product Risks

## 50.1 Selection Quality Is Too Generic

The application may technically select "good" photos but fail to understand which memories matter.

Mitigation:

Design the engine around moment coverage and diversity rather than simple global ranking.

---

## 50.2 Duplicate Detection Is Too Aggressive

Two visually similar photos may represent different meaningful moments.

Mitigation:

Combine visual similarity with timing and contextual signals rather than relying on image similarity alone.

---

## 50.3 Duplicate Detection Is Too Weak

The result may contain several almost identical photos.

Mitigation:

Evaluate redundancy explicitly during final album construction.

---

## 50.4 Face Quality Dominates Selection

The engine could over-prioritize portraits and under-represent the environment.

Mitigation:

Apply album-level diversity rules.

---

## 50.5 Processing Is Too Slow

Large collections could make the application feel impractical.

Mitigation:

Use staged processing, caching, batching, and progressive analysis as defined in the performance and selection-engine specifications.

---

## 50.6 Memory Pressure

Analyzing hundreds or thousands of full-resolution images simultaneously could exceed device resources.

Mitigation:

Never design the pipeline around loading the full dataset into memory at once.

Detailed handling belongs in `08_Performance_[Spec.md](http://Spec.md)`.

---

## 50.7 iCloud Assets Are Not Local

Some Photos assets may require downloading before analysis.

Mitigation:

Handle unavailable assets explicitly and expose understandable processing state.

---

## 50.8 Users Do Not Trust Automatic Selection

Users may worry that the app is hiding or deleting memories.

Mitigation:

Clearly separate:

**selected**

from:

**deleted**.

Nothing is deleted automatically.

---

# 51. Core Product Loop

The complete MVP can be summarized as:

```text
SOURCE PHOTOS
      ↓
ANALYZE
      ↓
GROUP INTO MOMENTS / SIMILAR SETS
      ↓
RANK CANDIDATES
      ↓
BUILD DIVERSE ALBUM
      ↓
USER REVIEW
      ↓
USER CORRECTIONS
      ↓
SAVE CURATED ALBUM

```

The success of Photos Curator depends primarily on the quality of this loop.

---

# 52. MVP Screen-Level Concept

The detailed UI specification belongs in `02_UX_[Flows.md](http://Flows.md)`.

At the PRD level, the minimum conceptual states are:

```text
Home
  ↓
Choose Photos
  ↓
Configure Curation
  ↓
Processing
  ↓
Curated Result
  ↓
Review / Alternatives
  ↓
Save Album
  ↓
Completed

```

Additional states must exist for:

- permission required,
- limited Photos permission,
- processing failure,
- unavailable iCloud asset,
- interrupted session,
- and save failure.

---

# 53. Example MVP Experience

A user selects:

**1,024 photos**

from a seven-day trip.

They request:

**80 final photos.**

Photos Curator analyzes the collection and discovers approximately:

- 220 moment/similarity clusters,
- many repeated photos,
- several poor-quality images,
- multiple versions of group photos,
- portraits,
- landscapes,
- food,
- architecture,
- and travel-context images.

The engine generates an 80-photo proposal.

The user reviews it and:

- removes 4 photos,
- replaces 6 photos with alternatives,
- restores 2 photos,
- and approves the final 78-photo album.

The user then saves:

**Japan Trip — Curated**

to Apple Photos.

The remaining 946 source images remain untouched.

This is a successful Photos Curator workflow.

---

# 54. What Would Make the MVP a Failure?

The MVP should be considered unsuccessful if one or more of the following is consistently true:

- users still need to inspect almost every source photo,
- the selected album contains many duplicates,
- important trip moments frequently disappear,
- the app consistently chooses weaker versions of obvious duplicate shots,
- users replace a large proportion of selected photos,
- processing frequently crashes on large collections,
- users cannot understand what the app is doing,
- users fear that rejected photos will be deleted,
- or the application requires so much configuration that manual selection becomes easier.

---

# 55. Definition of Done for Product MVP

The MVP is product-complete when a real user can perform the following workflow without developer assistance:

```text
Open Photos Curator
→ select a large photo collection
→ choose desired album size
→ start curation
→ wait for analysis
→ review the proposed selection
→ correct individual selections
→ save the curated album

```

and the resulting album demonstrates:

- reasonable image quality,
- strong duplicate suppression,
- good moment coverage,
- meaningful diversity,
- safe handling of originals,
- and substantial reduction in manual review effort.

---

# 56. Future Opportunities

The following ideas may be considered after the MVP proves the core selection experience.

They are not current requirements.

Potential future features include:

- personalized selection preferences,
- learning from previous selections,
- automatic trip detection,
- event detection,
- suggested album sizes,
- multiple curation styles,
- "Best 20" / "Best 50" / "Best 100" presets,
- family-member preference learning,
- smarter expression analysis,
- advanced semantic scene understanding,
- video selection,
- Live Photo selection,
- automatic highlight albums,
- photo cleanup,
- duplicate deletion workflows,
- shared album workflows,
- macOS support,
- iPad support,
- and optional generative album titles or descriptions.

Future features should not complicate the MVP architecture unless there is a clear and inexpensive reason to support them.

---

# 57. Open Product Questions

These questions should be resolved through prototyping and recorded in `13_Decision_[Log.md](http://Log.md)`.

1. Should the user select individual photos, a date range, or both in the MVP?
2. Should album size be selected as an exact number or through presets such as Small / Medium / Large?
3. Should Photos Curator automatically suggest an album size based on the source collection?
4. How much alternative-photo browsing should be exposed during review?
5. Should users be able to mark a photo as mandatory before curation?
6. Should screenshots be automatically excluded or simply deprioritized?
7. How should Live Photos be represented in the MVP?
8. Should edited versions in Apple Photos receive additional preference?
9. Should favorites in Apple Photos influence selection?
10. How much previous user feedback should persist between curation sessions?

None of these questions should block development of the core selection pipeline unless they directly affect its implementation.

---

# 58. MVP Product Priorities

When development resources are limited, implement in this order:

**1. Reliable access to a large Photos collection**

↓

**2. Duplicate / near-duplicate grouping**

↓

**3. Basic photo quality assessment**

↓

**4. Moment grouping**

↓

**5. Candidate ranking**

↓

**6. Album-level diversity selection**

↓

**7. Result review**

↓

**8. Alternative selection**

↓

**9. Save curated album**

↓

**10. Selection-quality refinement**

Polish and advanced personalization should follow only after the complete curation loop works.

---

# 59. One-Sentence Product Definition

> **Photos Curator is an on-device-first iPhone app that turns hundreds or thousands of personal photos into a smaller, diverse, high-quality album that the user can quickly review and approve.**

---

# 60. Product North Star

The long-term product should optimize for one outcome:

> **How much manual photo-review work can Photos Curator eliminate without making users feel that important memories were lost?**

Everything else is secondary.