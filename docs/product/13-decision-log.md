# Photos Curator — Decision Log

**Document:** `13_Decision_Log.md`  
**Product:** Photos Curator  
**Status:** Living document  
**Last updated:** 2026-09-10

---

## 1. Purpose

This document records important product and engineering decisions made during the development of Photos Curator.

Its purpose is not to document every implementation detail.

Instead, it captures decisions that:

- materially affect the product behavior;
- significantly constrain the architecture;
- would be expensive or confusing to reverse later;
- explain why one approach was chosen over another;
- may otherwise be questioned or accidentally changed in the future.

The Decision Log is intentionally lightweight.

Photos Curator is a small product and should not introduce a heavyweight Architecture Decision Record process unless the project eventually grows enough to justify one.

---

# 2. How to Use This Document

Each important decision receives a stable ID:

```text
DEC-001
DEC-002
DEC-003
...
```

A decision should normally include:

- status;
- date;
- context;
- decision;
- rationale;
- consequences;
- conditions under which the decision should be reconsidered.

Decisions are append-only whenever practical.

Do not silently rewrite historical decisions.

If a decision changes:

1. keep the old decision;
2. mark it as `Superseded`;
3. create a new decision;
4. reference the new decision from the old one.

---

# 3. Decision Status

The following statuses are used.

| Status | Meaning |
|---|---|
| `Proposed` | Under consideration |
| `Accepted` | Current project decision |
| `Rejected` | Evaluated but intentionally not chosen |
| `Superseded` | Replaced by a newer decision |
| `Deferred` | Intentionally postponed |
| `Revisit` | Still valid but should be reevaluated soon |

---

# 4. Decision Summary

| ID | Decision | Status |
|---|---|---|
| DEC-001 | Build Photos Curator as a native iOS application | Accepted |
| DEC-002 | Use SwiftUI as the primary UI framework | Accepted |
| DEC-003 | Prefer Apple-native frameworks before third-party dependencies | Accepted |
| DEC-004 | Perform photo analysis on-device by default | Accepted |
| DEC-005 | Keep original user photos untouched | Accepted |
| DEC-006 | Build a multi-stage selection engine rather than a single global score | Accepted |
| DEC-007 | Organize selection around moments and similarity groups | Accepted |
| DEC-008 | Remove near-duplicates before higher-level album selection | Accepted |
| DEC-009 | Optimize for album quality rather than selecting only the highest-scoring photos | Accepted |
| DEC-010 | Diversity is an explicit selection constraint | Accepted |
| DEC-011 | Typical processing target is approximately 1,000 photos | Accepted |
| DEC-012 | Design the processing pipeline to remain usable with up to approximately 5,000 photos | Accepted |
| DEC-013 | Use incremental and cancellable processing | Accepted |
| DEC-014 | Cache reusable photo-analysis results | Accepted |
| DEC-015 | Keep the architecture intentionally simple | Accepted |
| DEC-016 | Do not include unit tests, UI tests, or test targets in the repository | Accepted |
| DEC-017 | Validate selection quality primarily through manual QA and curated datasets | Accepted |
| DEC-018 | Analytics must not contain image contents or biometric data | Accepted |
| DEC-019 | Store enough decision metadata to explain why a photo was selected or rejected | Accepted |
| DEC-020 | Personalization is not required for the initial MVP | Accepted |
| DEC-021 | User feedback should be represented in the data model for future personalization | Accepted |
| DEC-022 | Selection processing should tolerate app interruption | Accepted |
| DEC-023 | iCloud-backed assets should be handled explicitly rather than assumed to be local | Accepted |
| DEC-024 | Do not require a cloud AI backend for core photo selection | Accepted |
| DEC-025 | Prefer deterministic rules around model outputs | Accepted |
| DEC-026 | Do not automatically delete rejected photos | Accepted |
| DEC-027 | Optimize implementation speed over theoretical architectural purity | Accepted |

---

# 5. Accepted Decisions

## DEC-001 — Native iOS Application

**Status:** Accepted  
**Date:** 2026-09-10

### Context

Photos Curator requires deep integration with the user's photo library, image metadata, local image processing, PhotoKit, Vision, memory management, and iOS lifecycle behavior.

A cross-platform application would introduce an abstraction layer around the parts of the application that are most platform-specific.

### Decision

Photos Curator will be implemented as a native iOS application.

### Rationale

Native development provides:

- direct PhotoKit access;
- direct Vision integration;
- better control over image loading;
- better memory management;
- easier handling of iCloud Photos;
- native Swift concurrency;
- simpler integration with iOS lifecycle events;
- fewer third-party dependencies.

### Consequences

The first version of Photos Curator targets Apple platforms only.

Android support is outside the current scope.

### Reconsider When

Reconsider only if:

- the iOS product becomes successful enough to justify Android development;
- a significant portion of the target audience requires Android.

---

# DEC-002 — SwiftUI as the Primary UI Framework

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Use SwiftUI for the application UI.

UIKit may be used only when a required behavior is unavailable or unnecessarily difficult in SwiftUI.

### Rationale

SwiftUI provides:

- fast development;
- concise UI code;
- strong integration with modern Swift;
- straightforward state-driven interfaces;
- good compatibility with async processing workflows.

The project prioritizes development speed and maintainability.

### Consequences

The application should avoid unnecessary UIKit wrappers.

---

# DEC-003 — Apple-Native Frameworks First

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Use Apple-native frameworks whenever they adequately solve the problem.

Primary frameworks include:

- SwiftUI;
- PhotoKit;
- Vision;
- Core Image where appropriate;
- ImageIO;
- Core Graphics where appropriate;
- Swift Concurrency;
- OSLog;
- Foundation.

Third-party dependencies should require a clear benefit.

### Rationale

This reduces:

- dependency maintenance;
- binary size;
- privacy risk;
- compatibility risk;
- dependency abandonment risk;
- unnecessary architectural complexity.

### Consequences

A third-party library should not be introduced merely to save a small amount of implementation code.

---

# DEC-004 — On-Device Processing by Default

**Status:** Accepted  
**Date:** 2026-09-10

### Context

The application analyzes highly personal user photos.

Uploading potentially thousands of images to a server would create:

- privacy concerns;
- upload latency;
- network dependency;
- server costs;
- additional security responsibilities.

### Decision

Core photo analysis and selection will run on the user's device.

### Rationale

On-device processing provides:

- stronger privacy;
- offline operation;
- predictable cost;
- no large photo uploads;
- lower infrastructure complexity.

### Consequences

Algorithms must operate within iPhone:

- CPU limits;
- GPU/Neural Engine availability;
- memory constraints;
- thermal constraints;
- battery constraints.

### Reconsider When

Cloud processing may be considered for an optional future feature only when it delivers functionality that cannot reasonably be implemented on-device.

Core album selection must not depend on it.

---

# DEC-005 — Original Photos Remain Untouched

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The selection workflow must not modify original photo assets.

The application should operate on:

- asset references;
- analysis metadata;
- derived thumbnails;
- selection decisions.

### Rationale

The primary purpose of Photos Curator is selection, not destructive photo management.

### Consequences

The user should be able to use the application without fear of losing original photos.

---

# DEC-006 — Multi-Stage Selection Pipeline

**Status:** Accepted  
**Date:** 2026-09-10

### Context

A simple approach would calculate one score for every photo and select the highest-scoring photos.

This performs poorly when many high-quality images represent the same scene.

### Decision

Use a multi-stage selection pipeline.

Conceptually:

```text
Photo Library
    ↓
Asset Discovery
    ↓
Lightweight Analysis
    ↓
Quality Filtering
    ↓
Duplicate / Similarity Grouping
    ↓
Moment Detection
    ↓
Best-of-Group Selection
    ↓
Candidate Shortlist
    ↓
Global Diversity Selection
    ↓
Final Album
```

### Rationale

Selection is not equivalent to ranking.

A good album requires both:

- photo quality;
- coverage of the experience.

### Consequences

Individual photo scores are inputs to the selection engine, not the final selection algorithm.

---

# DEC-007 — Moment-Centric Selection

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Photos should be grouped into meaningful moments before final selection whenever sufficient metadata or similarity signals are available.

Possible signals include:

- capture timestamp;
- temporal distance;
- visual similarity;
- burst behavior;
- location where available;
- detected subjects or scenes.

### Rationale

Users frequently take several photos of the same real-world event.

Treating each photo independently produces repetitive albums.

### Consequences

Moment detection becomes a core concept in the data model and selection engine.

---

# DEC-008 — Duplicate Reduction Before Final Selection

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Near-duplicate and highly similar photos should be grouped before global album selection.

### Example

Given:

```text
IMG_101
IMG_102
IMG_103
IMG_104
```

where all four images are effectively the same shot, the engine should first determine:

```text
SimilarityGroup
    winner: IMG_103
    alternatives:
        IMG_101
        IMG_102
        IMG_104
```

The global selector should usually reason about `IMG_103`, not four independent photographs.

### Rationale

Otherwise duplicate-heavy moments dominate the final album.

---

# DEC-009 — Optimize for Album Quality, Not Individual Scores

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The optimization target is:

> Produce the best collection of photos representing the user's experience.

It is not:

> Find the N photographs with the highest independent quality scores.

### Rationale

An album containing twenty excellent photographs of the same sunset is usually worse than a diverse album containing:

- people;
- environments;
- landmarks;
- activities;
- details;
- landscapes;
- transitions between moments.

### Consequences

Final selection must consider interactions between already-selected photos and new candidates.

---

# DEC-010 — Diversity Is an Explicit Constraint

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The selection engine must explicitly manage diversity.

Relevant dimensions may include:

- moment;
- visual similarity;
- people;
- scene type;
- landscape vs portrait;
- composition;
- subject;
- temporal distribution.

### Rationale

Diversity does not reliably emerge from photo-quality ranking alone.

### Consequences

A slightly lower-quality photo may be selected instead of a higher-scoring photo if it significantly improves album coverage.

---

# DEC-011 — Approximately 1,000 Photos as the Primary Workload

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The primary optimization target is a selection session containing approximately:

```text
1,000 photos
```

### Rationale

This represents a realistic large trip, event, or accumulated photo session while remaining suitable for on-device processing.

### Consequences

Performance decisions should be evaluated against this workload first.

---

# DEC-012 — Support Larger Collections Without Redesign

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The architecture should remain operational with approximately:

```text
1,000–5,000 photos
```

without requiring a fundamentally different processing system.

### Important Clarification

This does not mean every operation must analyze 5,000 full-resolution images simultaneously.

The system should instead rely on:

- staged processing;
- thumbnails;
- batching;
- caching;
- early filtering;
- lazy loading.

### Consequences

Algorithms with unnecessary O(N²) behavior should be avoided on the full library.

Pairwise comparisons should normally occur only after candidate reduction or within bounded clusters.

---

# DEC-013 — Incremental and Cancellable Processing

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Long-running analysis should be implemented as incremental work rather than one monolithic operation.

Processing should support:

- cancellation;
- progress reporting;
- bounded batches;
- graceful interruption.

### Rationale

Users may:

- leave the screen;
- background the app;
- cancel the operation;
- receive memory pressure;
- lose access to an iCloud asset.

### Consequences

Processing services should expose cancellation-aware asynchronous APIs.

---

# DEC-014 — Cache Reusable Analysis

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Expensive analysis that remains valid should be cached.

Possible cached results include:

- image dimensions;
- timestamps;
- lightweight quality metrics;
- Vision observations;
- fingerprints;
- similarity features;
- duplicate-group membership;
- derived thumbnails.

### Rationale

Repeatedly analyzing the same photo wastes:

- CPU;
- battery;
- time.

### Consequences

The cache requires an invalidation strategy.

A cache entry should be associated with sufficient asset identity/version information to prevent stale results from being treated as current.

---

# DEC-015 — Intentionally Simple Architecture

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Photos Curator should use the simplest architecture that keeps major responsibilities separated.

Avoid creating layers merely because they are common in large enterprise applications.

### Preferred Shape

Conceptually:

```text
App
 ├── Features
 │    ├── PhotoImport
 │    ├── Processing
 │    ├── AlbumReview
 │    └── Settings
 │
 ├── SelectionEngine
 │
 ├── Services
 │    ├── PhotoLibraryService
 │    ├── ImageAnalysisService
 │    ├── CacheService
 │    └── AnalyticsService
 │
 ├── Models
 │
 └── Infrastructure
```

The exact folder names may evolve.

### Avoid

Unless clearly required, do not introduce:

- excessive protocol abstraction;
- separate package for every feature;
- repository classes around trivial storage;
- dependency injection frameworks;
- service locator frameworks;
- event buses;
- microservices;
- unnecessary networking layers;
- premature plugin systems.

### Rationale

The project is optimized for fast development by a small team.

---

# DEC-016 — No Automated Test Targets in the Repository

**Status:** Accepted  
**Date:** 2026-09-10

### Context

Development speed is currently more important than maintaining a comprehensive automated test suite.

The developer will perform manual validation.

### Decision

The repository will not include:

- unit test targets;
- UI test targets;
- XCTest files;
- snapshot test infrastructure;
- test-only dependency frameworks;
- generated test boilerplate.

### Rationale

For the current project stage, maintaining test infrastructure would increase implementation overhead without being a product requirement.

### Consequences

Quality must instead be protected through:

- clear selection rules;
- deterministic behavior where practical;
- manual QA;
- curated photo datasets;
- debugging tools;
- observable selection reasoning;
- performance testing on real devices.

### Important Boundary

This decision does **not** mean quality validation is optional.

It means validation is performed manually rather than through repository-based automated test suites.

### Related Document

`10_Manual_QA_and_Selection_Evaluation.md`

---

# DEC-017 — Manual Evaluation for Selection Quality

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Selection-engine quality should be evaluated using real photo collections and human review.

Important dimensions include:

- duplicate suppression;
- moment coverage;
- group-photo quality;
- face quality;
- blur rejection;
- landscape representation;
- diversity;
- overall album usefulness.

### Rationale

There is no single objective metric that fully represents whether a curated personal album feels good.

Human evaluation remains necessary.

### Consequences

The QA process should include several representative datasets, such as:

```text
Trip
Family gathering
Group event
Landscape-heavy trip
Portrait-heavy session
Low-light event
Burst-heavy collection
Mixed screenshots + camera photos
iCloud-heavy library
```

---

# DEC-018 — Analytics Must Not Contain Photo Content

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Analytics must never transmit:

- original images;
- thumbnails;
- face crops;
- Vision feature vectors that could reasonably represent biometric/image content;
- names inferred from Photos;
- precise user photo contents.

### Allowed Examples

Aggregate events may include values such as:

```text
processing_started
photo_count = 1240

processing_completed
duration_seconds = 78

album_reviewed
selected_count = 84
removed_by_user = 6
added_by_user = 4
```

### Rationale

Product analytics should measure system effectiveness without creating a second source of sensitive photo data.

### Related Document

`11_Analytics_and_Metrics.md`

---

# DEC-019 — Preserve Selection Reasoning

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The selection engine should retain structured information explaining important selection decisions.

Example:

```swift
SelectionDecision(
    assetID: assetID,
    state: .rejected,
    reasons: [
        .nearDuplicate,
        .lowerQualityThanGroupWinner
    ],
    competingAssetID: winnerID
)
```

### Rationale

Selection reasoning is useful for:

- debugging;
- manual QA;
- engine tuning;
- review UI;
- future explainability.

Without this information, developers may know that an image was rejected but not understand why.

### Consequences

The engine should not return only:

```swift
[SelectedAsset]
```

It should maintain enough intermediate decision metadata to explain meaningful outcomes.

---

# DEC-020 — No Personalization Requirement for MVP

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The first production-quality selection engine should work without requiring a learned profile for each user.

### Rationale

Cold-start personalization introduces significant complexity.

The application must first prove that generic selection rules create useful albums.

### Consequences

MVP selection should rely primarily on:

- image quality;
- duplicate suppression;
- moment structure;
- faces;
- composition;
- scene diversity;
- global album rules.

---

# DEC-021 — Preserve User Feedback for Future Personalization

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Although personalization is not required for MVP, the data model should be able to represent user feedback.

Examples:

```text
User removed AI-selected photo
User restored rejected photo
User marked favorite
User replaced suggested group winner
```

### Rationale

These interactions may eventually reveal user preferences such as:

- preference for people vs scenery;
- favorite individuals;
- preference for candid photos;
- preferred framing;
- willingness to keep similar shots.

### Consequences

Feedback should be represented in a simple structured model without building a personalization engine prematurely.

---

# DEC-022 — Processing Must Tolerate Interruption

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

Selection processing should be designed so that interruption does not corrupt application state.

Potential interruptions include:

- app entering background;
- task cancellation;
- iOS termination;
- memory pressure;
- iCloud download failure;
- temporary PhotoKit error.

### Rationale

Processing thousands of photos cannot assume uninterrupted execution.

### Consequences

Persist only meaningful checkpoints where useful.

Do not build a complex distributed job system.

A reasonable implementation may simply restart incomplete stages when that is cheaper and safer than implementing fine-grained resume logic.

---

# DEC-023 — Explicit Handling of iCloud Assets

**Status:** Accepted  
**Date:** 2026-09-10

### Context

A `PHAsset` existing in the Photos library does not guarantee that its image data is currently available locally.

### Decision

The processing pipeline must explicitly account for assets stored in iCloud.

### Behavior

The application should distinguish between:

```text
Asset available locally
Asset requires network download
Asset download pending
Asset unavailable
Asset failed
```

### Rationale

Ignoring this distinction would make progress appear frozen or produce inconsistent selection results.

### Consequences

The UI should communicate when network-backed assets affect processing.

One unavailable photo must not necessarily fail the entire session.

---

# DEC-024 — No Cloud AI Dependency for Core Selection

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

The core selection engine will not require:

- OpenAI APIs;
- external vision APIs;
- cloud-hosted multimodal models;
- user photo uploads to proprietary AI services.

### Rationale

A cloud AI dependency would add:

- recurring cost;
- network requirements;
- privacy complexity;
- latency;
- vendor dependency.

The MVP problem can be approached effectively using local image analysis and deterministic selection rules.

### Consequences

Cloud AI may be explored later for optional features but must not become a prerequisite for normal curation.

---

# DEC-025 — Deterministic Rules Around Model Outputs

**Status:** Accepted  
**Date:** 2026-09-10

### Context

Vision and machine-learning outputs are useful signals but should not directly control every selection decision.

### Decision

Use model outputs as signals inside an explicit selection policy.

Example:

```text
Vision / image analysis
        ↓
Normalized signals
        ↓
Quality scoring
        ↓
Grouping
        ↓
Selection rules
        ↓
Final decision
```

Instead of:

```text
AI score
   ↓
Select top N
```

### Rationale

Explicit rules make the system:

- more predictable;
- easier to tune;
- easier to debug;
- easier to explain;
- less sensitive to individual model errors.

---

# DEC-026 — Never Automatically Delete Rejected Photos

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

A photo rejected from the curated album is only:

```text
not selected for this album
```

It does not mean:

```text
safe to delete from the user's photo library
```

### Rationale

Selection and deletion have very different risk profiles.

A technically poor photo may still have significant personal value.

### Consequences

Automatic photo-library cleanup is not part of the curation engine.

Any future deletion feature would require:

- a separate user flow;
- explicit confirmation;
- separate product requirements;
- additional safety review.

---

# DEC-027 — Optimize for Development Speed

**Status:** Accepted  
**Date:** 2026-09-10

### Decision

When two solutions provide similar product quality, prefer the one with:

- fewer abstractions;
- fewer dependencies;
- less code;
- easier debugging;
- faster iteration;
- lower maintenance burden.

### Example

Prefer:

```swift
final class PhotoLibraryService {
    ...
}
```

over introducing:

```text
PhotoLibraryRepositoryProtocol
DefaultPhotoLibraryRepository
PhotoLibraryUseCase
PhotoLibraryInteractor
PhotoLibraryDataSource
PhotoLibraryProvider
```

unless those abstractions solve an actual existing problem.

### Rationale

Photos Curator is not an enterprise framework.

The architecture exists to ship the product.

### Consequences

Future developers should resist "clean architecture" changes that substantially increase code volume without solving a demonstrated problem.

---

# 6. Deferred Decisions

The following decisions do not need to be finalized at the start of development.

They should be decided only when implementation reaches the relevant area.

---

## DEC-TBD-001 — Minimum Supported iOS Version

**Status:** Deferred

Determine based on:

- required Vision APIs;
- SwiftUI APIs;
- Photos framework behavior;
- current App Store device distribution.

Do not lower deployment targets solely to support very old devices unless there is a clear product reason.

---

# DEC-TBD-002 — Persistent Storage Technology

**Status:** Deferred

Possible options include:

- simple Codable files;
- SwiftData;
- Core Data;
- lightweight database.

Decision principle:

> Choose the simplest persistence mechanism that supports the actual data volume and lifecycle requirements.

Do not introduce a database merely because the application contains models.

---

# DEC-TBD-003 — Analytics Provider

**Status:** Deferred

Potential options:

```text
No analytics provider initially
App Store / Apple metrics
Custom lightweight analytics
Third-party product analytics
```

Provider selection must comply with:

`09_Privacy_and_Permissions.md`

and:

`11_Analytics_and_Metrics.md`

---

# DEC-TBD-004 — Monetization Model

**Status:** Deferred

Possible future models include:

- paid app;
- one-time unlock;
- subscription;
- freemium;
- limited free processing.

Monetization must not influence the initial architecture unless necessary.

---

# DEC-TBD-005 — Final Album Export Behavior

**Status:** Deferred

Possible approaches include:

- create a Photos album;
- maintain an internal curated collection;
- export selected assets;
- support multiple outputs.

The decision should be driven by the final MVP UX.

---

# DEC-TBD-006 — Advanced ML Models

**Status:** Deferred

Potential future capabilities may include:

- custom Core ML quality model;
- aesthetic ranking model;
- scene embeddings;
- semantic similarity;
- personalized ranking;
- advanced face-expression analysis.

Do not introduce them until baseline Apple-framework-based selection has been evaluated.

---

# DEC-TBD-007 — Personalization Strategy

**Status:** Deferred

Potential future approaches include:

```text
Simple preference weights
Per-user ranking adjustments
Implicit feedback
Explicit preference controls
On-device learning
```

This should follow actual observed user behavior rather than speculative architecture.

---

# 7. Explicit Non-Decisions

Some areas should intentionally remain flexible.

The following should not become architectural commitments prematurely.

---

## Exact Selection Weights

Values such as:

```text
sharpnessWeight = 0.25
faceWeight = 0.20
aestheticWeight = 0.30
diversityWeight = 0.25
```

are tuning parameters, not architectural decisions.

They belong in:

`03_Photo_Selection_Rules.md`

or engine configuration.

---

## Exact Folder Structure

Folder naming may evolve during implementation.

Changing:

```text
Services/
```

to:

```text
Infrastructure/
```

does not require a decision record unless it represents a meaningful architectural change.

---

## Naming of Internal Types

Renaming:

```swift
PhotoAnalysis
```

to:

```swift
AssetAnalysis
```

does not require a decision entry.

---

## UI Details

Button placement, spacing, colors, or icon choices normally belong to UX/design implementation rather than the Decision Log.

---

# 8. When a New Decision Should Be Added

Add a decision when the answer to at least one of these questions is **yes**:

### Product

- Does this significantly change what Photos Curator does?
- Does it alter user privacy expectations?
- Does it introduce destructive behavior?
- Does it change the core selection philosophy?

### Architecture

- Does this introduce a major dependency?
- Does this introduce a backend?
- Does this change local vs cloud processing?
- Does this change the persistence architecture?
- Does this create a new architectural layer?
- Would reversing it later require substantial work?

### Selection Engine

- Does this change the fundamental pipeline?
- Does this change the meaning of a moment or cluster?
- Does this change how final selections are optimized?
- Does it introduce a new machine-learning dependency?

### Performance

- Does this fundamentally change how thousands of assets are processed?
- Does this introduce full-resolution processing at scale?
- Does it materially change caching or concurrency?

### Privacy

- Does this cause any image-related data to leave the device?
- Does it change how face information is stored?
- Does it change Photo Library access behavior?

If none of these apply, the choice probably does not belong in this file.

---

# 9. Decision Entry Template

Use the following template for new decisions.

```markdown
# DEC-XXX — Decision Title

**Status:** Proposed | Accepted | Rejected | Superseded | Deferred | Revisit  
**Date:** YYYY-MM-DD

## Context

Describe the problem or tradeoff that required a decision.

## Options Considered

### Option A

Description.

Advantages:

- ...

Disadvantages:

- ...

### Option B

Description.

Advantages:

- ...

Disadvantages:

- ...

## Decision

Clearly state what was chosen.

## Rationale

Explain why this option was selected.

## Consequences

Describe important effects of the decision.

Positive:

- ...

Negative:

- ...

## Reconsider When

List conditions that would justify reevaluating the decision.

## Related Documents

- `XX_Document.md`
```

---

# 10. Superseding a Decision

Do not erase the original reasoning.

Example:

```markdown
# DEC-014 — Cache Analysis Results

**Status:** Superseded by DEC-041
```

Then:

```markdown
# DEC-041 — Replace Disk Cache with SwiftData Analysis Store

**Status:** Accepted
**Date:** YYYY-MM-DD

...
```

This preserves the project's architectural history.

---

# 11. Relationship to Other Documentation

The Decision Log explains **why** major choices were made.

Other documents explain **what** the system should do and **how** it should work.

| Document | Responsibility |
|---|---|
| `01_PRD.md` | Product goals and MVP definition |
| `02_UX_Flows.md` | User journeys and UI states |
| `03_Photo_Selection_Rules.md` | Selection behavior |
| `04_Selection_Engine_Design.md` | Selection pipeline implementation |
| `05_iOS_Architecture.md` | Application architecture |
| `06_Data_Model.md` | Persistent and runtime data structures |
| `07_Apple_Framework_Integration.md` | Apple APIs and framework integration |
| `08_Performance_Spec.md` | Performance constraints |
| `09_Privacy_and_Permissions.md` | Privacy policy and permissions |
| `10_Manual_QA_and_Selection_Evaluation.md` | Manual validation |
| `11_Analytics_and_Metrics.md` | Product and selection metrics |
| `12_Roadmap.md` | Implementation sequence |
| `13_Decision_Log.md` | Rationale behind important choices |

Avoid duplicating entire specifications inside this document.

Instead, reference the authoritative document.

---

# 12. Decision Principles

When a new architectural or product question appears, use the following principles before introducing additional complexity.

In priority order:

```text
1. Protect user photos
2. Protect user privacy
3. Produce a genuinely useful curated album
4. Keep selection behavior understandable
5. Maintain acceptable performance on real iPhones
6. Keep the implementation simple
7. Minimize dependencies
8. Optimize development speed
9. Preserve future extensibility where inexpensive
10. Avoid speculative infrastructure
```

A future capability should not impose significant complexity on today's MVP unless there is a concrete near-term requirement.

---

# 13. Current Architectural Philosophy

The current Photos Curator architecture can be summarized as:

```text
Native iOS
    +
SwiftUI
    +
PhotoKit
    +
Vision / Apple-native image analysis
    +
On-device processing
    +
Batching and caching
    +
Moment / similarity grouping
    +
Explicit selection rules
    +
Manual QA
    +
Minimal infrastructure
```

The project intentionally avoids:

```text
Cloud dependency
Unnecessary backend services
Heavy Clean Architecture
Premature personalization
Large third-party dependency graphs
Automated test targets
Destructive photo management
Opaque top-N AI ranking
```

---

# 14. Guiding Rule

When considering a new architectural component, ask:

> What concrete problem in the current version of Photos Curator does this solve?

If the answer is unclear, do not add it yet.

When considering a more sophisticated algorithm, ask:

> Does this materially improve the final album compared with a simpler solution?

If that improvement has not been demonstrated through manual evaluation, prefer the simpler approach.

The goal is not to build the most sophisticated photo-analysis architecture.

The goal is to build a fast, private, reliable iPhone application that turns a large photo collection into a small album the user actually wants to keep.