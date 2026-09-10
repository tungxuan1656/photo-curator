# 08 — Performance Specification

**Product:** photos-curator  
**Document:** `08_Performance_Spec.md`  
**Status:** Required for MVP  
**Scope:** On-device photo analysis and selection performance for approximately 1,000–5,000 photos per selection job

---

## 1. Purpose

This document defines the performance requirements and execution strategy for photos-curator.

The app may need to process thousands of photos in a single selection job. The primary performance challenge is therefore not individual image analysis, but controlling:

- image decoding,
- Vision requests,
- memory usage,
- concurrent work,
- PhotoKit access,
- caching,
- intermediate result persistence,
- thermal load,
- battery usage,
- interruption and resume behavior,
- UI responsiveness during long-running analysis.

The implementation must remain predictable when processing 5,000 photos and must not rely on loading the complete photo set into memory.

Performance optimization must not materially reduce selection quality.

The design favors simple bounded pipelines over complex scheduling infrastructure.

---

# 2. Goals

The performance architecture must satisfy the following goals:

1. Support selection jobs containing approximately **1,000–5,000 photos**.
2. Keep the SwiftUI interface responsive during analysis.
3. Avoid memory spikes caused by image decoding.
4. Avoid unbounded Vision concurrency.
5. Reuse previously computed analysis whenever possible.
6. Allow analysis to stop safely at any point.
7. Resume interrupted jobs without starting from zero.
8. Handle memory pressure and thermal pressure gracefully.
9. Avoid unnecessary access to full-resolution images.
10. Avoid unnecessary iCloud downloads.
11. Avoid O(N²) algorithms across the entire photo set.
12. Make performance measurable using manual profiling.
13. Keep the architecture simple enough for a small MVP codebase.

---

# 3. Non-Goals

This specification does not require:

- a distributed processing system,
- a server-side image-processing pipeline,
- background servers,
- GPU-specific scheduling,
- custom thread pools,
- custom memory allocators,
- complex job orchestration frameworks,
- a dedicated performance test target,
- unit tests,
- UI tests,
- XCTest performance benchmarks,
- permanent thumbnail duplication on disk.

Performance validation will be performed manually using real photo libraries, Instruments, signposts, application diagnostics, and the procedures defined in `10_Manual_QA_and_Selection_Evaluation.md`.

---

# 4. Expected Workloads

The implementation should be designed around four practical workload sizes.

| Workload | Number of Assets | Usage |
|---|---:|---|
| Small | 100–300 | Short event or manually selected range |
| Normal | ~1,000 | Primary MVP workload |
| Large | ~2,500 | Long trip or large event |
| Maximum MVP target | ~5,000 | Stress workload |

The application should remain functional beyond these values where possible, but optimization beyond approximately 5,000 assets is not an MVP requirement.

A single analysis job must never assume that all assets can be decoded simultaneously.

---

# 5. Performance Philosophy

The core rule is:

> **Bound the amount of expensive work in progress at every stage.**

The system should optimize throughput by processing continuously rather than maximizing concurrency.

For example:

```text
Bad

5,000 assets
    ↓
request 5,000 images
    ↓
create 5,000 Vision tasks
    ↓
large memory spike
    ↓
thermal throttling / memory termination


Good

5,000 assets
    ↓
metadata scan
    ↓
small bounded batches
    ↓
limited image requests
    ↓
limited Vision workers
    ↓
persist results
    ↓
release decoded images
    ↓
next batch
```

The implementation should prefer stable throughput for twenty minutes over extremely high throughput for thirty seconds followed by thermal throttling.

---

# 6. Performance Layers

Performance should be considered at five layers:

```text
PhotoKit
    ↓
Image loading / decoding
    ↓
Vision analysis
    ↓
Selection-engine computation
    ↓
SwiftUI presentation
```

Every layer must have an explicit upper bound on active work.

---

# 7. Pipeline Overview

The processing pipeline should conceptually follow:

```text
PHAsset identifiers
       │
       ▼
Metadata collection
       │
       ▼
Cheap analysis
       │
       ├── capture time
       ├── dimensions
       ├── media subtype
       ├── orientation
       ├── basic quality signals
       └── low-cost Vision information
       │
       ▼
Moment / candidate generation
       │
       ▼
Candidate shortlist
       │
       ▼
Expensive analysis
       │
       ├── face/group analysis
       ├── detailed quality signals
       ├── similarity representation
       └── other required Vision features
       │
       ▼
Duplicate / moment clustering
       │
       ▼
Scoring + diversity
       │
       ▼
Final album
```

Not every analysis operation needs to run on every photo.

Expensive analysis should be restricted whenever the selection-engine design allows it.

The exact selection semantics remain defined by:

- `03_Photo_Selection_Rules.md`
- `04_Selection_Engine_Design.md`

This document defines how those operations should execute efficiently.

---

# 8. Metadata-First Processing

The pipeline must begin with cheap metadata operations.

Do not immediately request image pixel data.

Useful metadata may include:

```text
localIdentifier
creationDate
modificationDate
pixelWidth
pixelHeight
mediaType
mediaSubtypes
favorite status
location when available
burst information when available
```

Metadata should be used to eliminate unnecessary work before image decoding begins.

Examples include:

- grouping nearby timestamps into candidate moments,
- excluding unsupported media,
- identifying likely burst sequences,
- determining aspect ratio,
- identifying obviously invalid assets,
- deciding which analysis operations are required.

---

# 9. Image Resolution Policy

The analysis pipeline should use the **smallest image representation that provides sufficient information for the requested Vision operation**.

Full-resolution images should not be the default analysis input.

Typical analysis input should use a bounded long edge approximately within:

```text
512–1024 px
```

The exact size may differ by feature.

Example policy:

| Analysis | Preferred Input |
|---|---|
| Basic image quality | ~512 px |
| Duplicate similarity | ~512–768 px |
| Scene representation | ~512–768 px |
| Face detection | ~768–1024 px |
| Review grid thumbnail | Screen-dependent thumbnail |
| Final full-screen preview | Higher-resolution request on demand |

Do not request a 12–48 MP source image simply to determine whether an image contains faces or resembles another image.

Full-resolution assets should normally be requested only for features that explicitly require them or for high-resolution user review/export behavior.

---

# 10. PhotoKit Caching Strategy

`PHCachingImageManager` should be used primarily for user-visible thumbnail preheating and predictable repeated PhotoKit image requests.

Preheating should cover a bounded range surrounding the currently visible review-grid assets rather than the entire album. PhotoKit supports preparing image representations in advance using the same target size and request configuration subsequently used to request the image.

Example:

```text
Visible assets:
    150–180

Cache window:
    100–230

NOT:
    0–5,000
```

As scrolling progresses:

```text
start caching assets entering preheat window
stop caching assets leaving preheat window
```

The analysis engine should not treat `PHCachingImageManager` as permission to keep thousands of decoded images alive.

---

# 11. No Custom Thumbnail Disk Cache for MVP

The MVP should not maintain another permanent copy of all PhotoKit thumbnails.

Reasons:

- Photos already performs image caching internally.
- Persistent thumbnail duplication consumes unnecessary disk space.
- Cache invalidation becomes more complex.
- Additional files increase privacy and deletion responsibilities.
- It does not materially improve the core selection engine.

Persistent storage should focus on **derived analysis**, not copies of the original photo.

---

# 12. Derived Analysis Cache

Expensive analysis results should be reusable.

Examples:

```text
faceCount
faceQuality
sharpnessScore
exposureScore
feature representation
duplicate signature
scene information
group-photo information
quality score components
```

These results should be persisted through the persistence layer defined by `06_Data_Model.md`.

A cached result must only be reused when its analysis key remains valid.

Conceptually:

```text
AnalysisCacheKey =
    assetIdentifier
    + assetModificationState
    + analysisPipelineVersion
    + analysisConfigurationVersion
```

The implementation does not need to hash complete image bytes.

Doing so would require unnecessarily reading every source asset.

---

# 13. Analysis Versioning

Every persisted expensive analysis result must belong to an analysis version.

For example:

```text
analysisVersion = 3
```

If the Vision configuration or interpretation changes incompatibly:

```text
analysisVersion = 4
```

Old analysis can then be invalidated lazily.

Do not immediately reprocess the entire photo library when the app updates.

Instead:

```text
asset requested
    ↓
cache version valid?
    │
    ├── yes → reuse
    │
    └── no  → recompute
```

This keeps migrations simple.

---

# 14. Re-Selection Must Not Re-Analyze Photos

Changing album preferences should normally rerun the **selection stage**, not the Vision stage.

Examples:

```text
User changes:
100 selected photos → 50 selected photos

Expected:
recalculate ranking/diversity

Not expected:
rerun Vision on 1,000 photos
```

The same applies when users modify preferences such as:

- more landscapes,
- fewer similar photos,
- more group photos,
- stronger diversity,
- smaller final album.

If the underlying visual analysis has not changed, reuse it.

This is one of the largest performance optimizations available to the product.

---

# 15. Batch Processing

Assets must be processed in finite batches.

Recommended initial configuration:

```text
analysisBatchSize = 32
```

This is a starting value, not a hard architectural constant.

Depending on profiling, useful values may fall approximately within:

```text
16–64 assets
```

A batch should follow roughly:

```text
load identifiers
    ↓
request bounded images
    ↓
analyze
    ↓
persist derived results
    ↓
release temporary image memory
    ↓
checkpoint progress
    ↓
next batch
```

No later stage should require retaining the decoded image from an earlier completed batch.

---

# 16. Concurrency Model

Swift structured concurrency should be used.

Do not create one active expensive task for every asset.

Avoid:

```swift
for asset in 5_000_assets {
    Task {
        analyze(asset)
    }
}
```

This creates effectively unbounded concurrency.

Instead, use a bounded producer/consumer model.

Conceptually:

```text
Asset stream
     ↓
┌─────────────┐
│ Worker 1    │
│ Worker 2    │
│ Worker 3    │
└─────────────┘
     ↓
Result store
```

The exact implementation can use:

- structured `TaskGroup`,
- an actor-owned queue,
- or another small bounded asynchronous pipeline.

Do not introduce a custom thread-pool abstraction unless profiling demonstrates a real need.

---

# 17. Initial Concurrency Limits

Recommended MVP starting values:

| Operation | Initial Concurrency |
|---|---:|
| Heavy Vision analysis | 2 |
| Light image analysis | 2–4 |
| Large PhotoKit image requests | 2 |
| Persistence writes | Serialized or small batches |
| Selection/ranking stage | 1 task with internal efficient loops |

A maximum Vision concurrency around:

```text
4
```

should be considered a ceiling for initial profiling rather than the default.

More concurrent Vision requests do not automatically mean better total throughput.

Image decoding, CPU load, memory bandwidth, thermal state, and the underlying Vision execution path may become bottlenecks.

---

# 18. Adaptive Concurrency

The pipeline should be capable of reducing concurrency during adverse device conditions.

Example policy:

```text
Normal
    Vision workers = 2–3

Low Power Mode
    Vision workers = 1–2

Thermal serious
    Vision workers = 1

Thermal critical
    pause expensive analysis
```

`ProcessInfo` exposes the device thermal state and Low Power Mode status, allowing the app to adjust expensive processing accordingly.

The implementation does not need an advanced predictive scheduler.

A few explicit operating modes are sufficient.

---

# 19. Suggested Performance Modes

Internally, processing can use three simple modes.

### Normal

```text
normal concurrency
normal batch size
normal prefetching
```

### Constrained

Triggered by:

```text
Low Power Mode
thermal pressure
memory warning
```

Behavior:

```text
reduce concurrency
reduce image prefetch window
clear unnecessary caches
avoid speculative processing
```

### Critical

Triggered by severe memory or thermal conditions.

Behavior:

```text
finish or cancel current safe unit of work
persist checkpoint
clear decoded images
pause analysis
inform UI
resume when appropriate
```

Do not continue aggressively until iOS terminates the process.

---

# 20. Main-Thread Policy

The main actor is reserved for UI-related state.

The following work must not execute synchronously on the main actor:

- image decoding,
- Vision requests,
- feature-distance calculations,
- duplicate detection,
- clustering,
- database migrations,
- large persistence writes,
- thousands-of-assets sorting when expensive,
- filesystem operations,
- cache cleanup.

SwiftUI should receive compact progress updates rather than thousands of per-photo mutations.

---

# 21. UI Responsiveness Target

While processing is active:

- scrolling must remain responsive,
- navigation must remain responsive,
- Cancel must respond immediately,
- leaving the screen must not freeze the app,
- progress updates must not overwhelm SwiftUI.

Target UI refresh rate:

```text
60 fps where practical
```

The app should avoid synchronous main-thread operations exceeding approximately:

```text
16 ms
```

during interactive scrolling.

Occasional longer system-controlled work may occur, but application-owned analysis should not intentionally block the main actor.

---

# 22. Progress Update Throttling

Do not publish progress after every small internal operation.

With thousands of assets, this can create excessive SwiftUI invalidation.

Recommended maximum:

```text
progressUpdateFrequency <= 4 Hz
```

For example:

```text
0%
1%
1%
1%
2%
2%
...
```

should not generate six UI updates within milliseconds.

Instead aggregate worker progress and periodically publish:

```swift
ProcessingProgress(
    stage: .visualAnalysis,
    completed: 732,
    total: 1000
)
```

The progress actor may update internally more frequently than SwiftUI receives updates.

---

# 23. Progress Must Be Stage-Aware

A simple asset count can be misleading because pipeline stages have different costs.

Prefer stage-aware progress:

```text
Preparing photos
Analyzing quality
Finding moments
Finding similar photos
Building shortlist
Creating final album
```

Internally, approximate stage weights may be used.

Example:

```text
Metadata                 5%
Cheap analysis          35%
Expensive analysis      40%
Clustering              10%
Final ranking           10%
```

These weights are estimates and should be calibrated through profiling.

Exact percentage accuracy is less important than:

- monotonic progress,
- no apparent freezing,
- correct completion state.

---

# 24. Memory Strategy

The app must assume that decoded images are expensive.

For example, an image decoded to:

```text
4000 × 3000 × 4 bytes
```

requires approximately:

```text
48 MB
```

of raw pixel memory before considering additional framework overhead.

Therefore only a few full-size decoded images can create hundreds of megabytes of memory pressure.

The app must not keep original-resolution decoded images in collections.

---

# 25. Memory Targets

Exact iOS termination thresholds vary by device and operating conditions, so the app must not depend on a known system memory limit.

Initial engineering targets on the oldest supported device should be:

```text
Preferred steady-state RSS:
    <= ~350 MB

Preferred temporary peak:
    <= ~500 MB
```

These are profiling targets, not guarantees from iOS.

The more important acceptance condition is:

> Processing 5,000 photos must not exhibit continuously increasing memory consumption.

After multiple batches, memory usage should stabilize around a bounded operating range.

---

# 26. Memory Growth Acceptance Rule

For a long job:

```text
Batch 1
Batch 10
Batch 50
Batch 100
```

memory should fluctuate but not rise monotonically because completed decoded images remain referenced.

Example healthy pattern:

```text
220 MB
280 MB
250 MB
290 MB
260 MB
```

Example unhealthy pattern:

```text
220 MB
310 MB
410 MB
520 MB
650 MB
...
```

The second pattern indicates retained objects, cache misuse, or excessively long object lifetimes.

---

# 27. Temporary Image Lifetime

Temporary image objects must have the smallest practical lifetime.

Ideal lifecycle:

```text
request image
    ↓
decode
    ↓
Vision
    ↓
extract compact result
    ↓
release image
```

Do not attach `UIImage`, `CGImage`, or pixel buffers to long-lived analysis models.

Analysis models should contain compact derived values only.

---

# 28. Memory Warnings

When a memory warning occurs:

1. stop speculative prefetching,
2. clear nonessential in-memory image caches,
3. reduce processing concurrency,
4. reduce the next batch size when necessary,
5. preserve persisted analysis,
6. preserve job checkpoint,
7. continue cautiously when safe.

Do not delete useful persisted analysis merely because RAM is constrained.

RAM cache and persistent analysis cache are different concepts.

---

# 29. Algorithmic Complexity

Processing 5,000 assets makes algorithmic complexity important.

The engine must avoid global all-pairs comparison where possible.

For `N = 5,000`:

```text
N × N = 25,000,000
```

and the number of unique pair comparisons is approximately:

```text
12,497,500
```

Running an expensive visual-distance calculation for every possible pair is unnecessary.

---

# 30. Duplicate Candidate Generation

Duplicate detection should first generate plausible candidate pairs using cheap signals.

Possible candidate constraints include:

```text
capture-time proximity
moment membership
burst membership
basic visual signature
dimensions
coarse feature bucketing
```

Only those candidates should receive expensive similarity comparison.

Conceptually:

```text
All 5,000 photos
       ↓
cheap candidate buckets
       ↓
small candidate neighborhoods
       ↓
detailed similarity
```

Not:

```text
5,000
  ×
4,999
```

---

# 31. Moment Grouping Complexity

Photos should first be sorted chronologically.

Expected cost:

```text
sorting:
O(N log N)

moment scan after sorting:
O(N)
```

Moment formation should generally use sequential or near-sequential comparisons.

Moment grouping must not require every asset to be compared with every other asset.

---

# 32. Similarity Clustering

Similarity clustering must operate on bounded candidate neighborhoods.

A practical model:

```text
photo
    ↓
moment / temporal neighborhood
    ↓
candidate similar photos
    ↓
feature distance
    ↓
duplicate/similar cluster
```

If global similarity becomes a future feature, use an approximate nearest-neighbor strategy rather than introducing global O(N²) comparison into the MVP.

---

# 33. Expensive Analysis Candidate Reduction

When the selection-engine rules permit, expensive analysis should execute only on candidates that survived earlier filters.

For example:

```text
5,000 source assets
       ↓
5,000 cheap analyses
       ↓
candidate reduction
       ↓
~500–1,500 expensive analyses
       ↓
final selection
```

The exact number must be determined by selection quality.

Performance optimization must not remove essential candidates such as:

- moment representatives,
- important group photos,
- rare scene categories,
- strong landscape candidates,
- diversity-preserving photos.

Candidate reduction belongs to the selection-engine policy; this specification only requires that such reduction be exploited when available.

---

# 34. Persistence Frequency

Persisting after every tiny intermediate operation can create unnecessary I/O.

Conversely, persisting only at job completion makes interruption expensive.

Use small batch persistence.

Recommended initial checkpoint policy:

```text
after every ~25 completed assets

OR

approximately every ~10 seconds

whichever occurs first
```

The exact values should be tuned after profiling.

Persisting at natural batch boundaries is preferred.

---

# 35. Job Checkpoint

A selection job should store enough information to recover after interruption.

Conceptual state:

```text
SelectionJob

jobID
createdAt
configuration
assetIdentifiers
pipelineVersion
currentStage
completedAnalysisCount
status
```

Per-photo analysis persistence should remain the primary source of truth for determining whether a particular asset requires recomputation.

Avoid creating a second complex task database purely for checkpoints.

---

# 36. Idempotent Processing

Analysis should be idempotent.

Running:

```text
analyze(asset A)
```

twice with the same:

```text
asset state
analysis version
analysis configuration
```

should produce equivalent stored analysis.

Therefore recovery becomes simple:

```text
for each asset:
    valid analysis exists?
        yes → skip
        no  → analyze
```

This is preferable to trying to serialize the complete internal execution state of every worker.

---

# 37. Interruption Types

The application must tolerate:

- user pressing Cancel,
- user navigating away,
- app entering background,
- incoming call / system interruption,
- app suspension,
- process termination,
- memory pressure,
- thermal pressure,
- device locking,
- iCloud asset unavailability,
- individual Vision failures.

The pipeline must assume interruption can occur between any two batches.

---

# 38. User Cancellation

Cancellation must propagate through the analysis hierarchy.

Conceptually:

```text
SelectionJob Task
    ├── batch task
    │     ├── asset worker
    │     ├── asset worker
    │     └── asset worker
    └── progress aggregation
```

Cancelling the root job should stop children.

Workers should check cancellation:

- before requesting an asset,
- after receiving an asset,
- before expensive Vision requests,
- between independent Vision operations,
- before persistence where appropriate.

Do not start another asset after cancellation is known.

---

# 39. Cancellation Responsiveness

Target:

```text
UI acknowledgement:
< 250 ms

No new expensive work:
< 1 second where practical
```

Some framework operations already in progress may take longer to return.

The UI should still immediately show:

```text
Cancelling…
```

rather than appearing frozen.

Once the current safe unit of work finishes:

```text
persist checkpoint
release temporary resources
transition job state
```

---

# 40. Pause Versus Cancel

MVP behavior should remain simple.

Recommended semantics:

### Cancel

Stop processing and retain reusable analysis already completed.

The user can restart the selection later without losing existing valid analysis.

### App background / interruption

Treat as a resumable interruption, not destructive cancellation.

Do not delete completed analysis.

A separate explicit user-facing Pause control is not required for MVP unless UX testing shows a need.

---

# 41. Foreground and Background Execution

Checkpoint/resume is the primary reliability mechanism.

The application must not assume that arbitrary foreground work will continue forever after the app becomes backgrounded.

On supported deployment targets, Apple also provides `BGContinuedProcessingTask` for user-initiated, long-running processing that begins in the foreground and may continue after backgrounding; Apple specifically describes intensive CPU image work including Vision as a supported example.

This capability should be treated as an enhancement rather than a prerequisite for correctness.

Fallback behavior must always remain:

```text
persist progress
    ↓
suspension / termination
    ↓
app reopened
    ↓
load job
    ↓
reuse completed analysis
    ↓
continue missing work
```

Traditional `BGProcessingTask` execution is system scheduled and can itself be interrupted, so it must not be considered a guarantee that a selection job will finish.

---

# 42. Resume Behavior

On launch, detect unfinished jobs.

Example:

```text
Job status:
interrupted

842 / 1,000 assets analyzed
```

The app can offer:

```text
Continue selection
```

When resumed:

```text
load job
    ↓
validate cached analysis
    ↓
skip 842 valid assets
    ↓
process remaining 158
    ↓
continue selection pipeline
```

The progress bar should not return to zero simply because the process restarted.

---

# 43. Individual Asset Failures

One problematic asset must not terminate an entire 5,000-photo job.

Examples:

- PhotoKit request failure,
- corrupted image,
- unsupported representation,
- iCloud retrieval failure,
- Vision request failure.

Desired behavior:

```text
record asset failure
continue pipeline
```

At job completion:

```text
4,997 analyzed
3 unavailable
```

The engine should produce an album if enough valid assets remain.

---

# 44. Retry Policy

Do not implement aggressive automatic retries.

Recommended MVP behavior:

```text
local transient failure:
    retry once

persistent failure:
    mark unavailable
    continue
```

For iCloud/network-dependent retrieval, behavior should follow `07_Apple_Framework_Integration.md` and `09_Privacy_and_Permissions.md`.

Avoid infinite retry loops.

---

# 45. iCloud Photos Performance

Network transfer time must be separated from compute performance.

For performance benchmarking, distinguish:

```text
Locally available assets
```

from:

```text
Assets requiring iCloud download
```

A job that takes fifteen minutes because hundreds of originals are downloading from iCloud should not be interpreted as a fifteen-minute Vision regression.

UI progress should expose the difference where practical:

```text
Downloading photo 214…
```

versus:

```text
Analyzing photo 214…
```

---

# 46. Avoid Unnecessary iCloud Downloads

Do not download a full-resolution iCloud original if a lower-resolution representation is sufficient for analysis.

Network access should occur only when required by the analysis or review operation.

This reduces:

- waiting time,
- bandwidth,
- energy consumption,
- device heat.

---

# 47. Thermal Management

Photo analysis is sustained compute work.

A 5,000-image job may run long enough for thermal conditions to change substantially.

The app should observe thermal changes and adapt.

Suggested policy:

| Thermal State | Behavior |
|---|---|
| Nominal | Normal processing |
| Fair | Continue normally or slightly reduce concurrency |
| Serious | Reduce Vision concurrency to 1 |
| Critical | Pause expensive processing and checkpoint |

Do not attempt to maintain maximum throughput while the device reports critical thermal pressure.

---

# 48. Low Power Mode

When Low Power Mode is active:

```text
reduce concurrency
disable speculative work
reduce aggressive preheating
favor checkpoint-safe batches
```

Do not block the user from running a selection job.

Low Power Mode should influence performance strategy, not feature availability.

---

# 49. Battery Policy

For the MVP, the app should not require the device to be charging.

However, expensive speculative operations should be avoided.

Examples of prohibited behavior:

```text
pre-analyze entire Photos library without user intent
recompute valid cached results
preload thousands of thumbnails
rerun selection analysis after every small UI change
```

Only perform work that contributes to a user-requested selection or reusable analysis that naturally results from that selection.

---

# 50. Review Grid Performance

The review grid may display hundreds of selected candidates.

Use lazy SwiftUI containers such as:

```swift
LazyVGrid
```

where appropriate.

Review-cell models should contain:

```text
asset identifier
selection state
small score/result fields
```

not decoded images.

Images should be requested based on visible cells.

---

# 51. Review Thumbnail Preheating

For scrolling:

```text
visible region
    ↓
expand by bounded preheat distance
    ↓
PHCachingImageManager
```

The preheat region should move with the viewport.

Do not cache all 5,000 thumbnails simply because the review grid has 5,000 backing assets.

---

# 52. SwiftUI State Granularity

Avoid one massive observable object containing continuously mutating state for all 5,000 assets.

Prefer:

```text
job-level observable state
visible review models
persistent data source
```

Only values that affect currently displayed UI need immediate publication.

For example:

```text
completedAnalysisCount
currentStage
isCancelled
currentAlbum
```

can be job-level state.

Detailed analysis results can remain outside frequently published UI state.

---

# 53. Selection Algorithm Memory

Selection logic should work primarily with compact representations.

Example structure:

```swift
CandidateSummary {
    assetID
    momentID
    qualityScore
    duplicateClusterID
    faceSummary
    categoryFlags
    diversityEmbeddingReference
}
```

It must not require:

```swift
Candidate {
    UIImage
}
```

Keeping 5,000 compact candidate structs is acceptable.

Keeping 5,000 decoded photos is not.

---

# 54. Sorting Performance

Sorting 5,000 compact values is inexpensive compared with image analysis.

Do not prematurely optimize ordinary operations such as:

```text
sorting by timestamp
sorting by score
sorting moment representatives
```

Focus performance work on:

- image requests,
- decoding,
- Vision,
- similarity computation,
- unnecessary repeated analysis,
- memory lifetime.

---

# 55. Database / Persistence Performance

Persistence operations should favor batches.

Avoid:

```text
analyze asset
save transaction
analyze asset
save transaction
...
5,000 times
```

Prefer:

```text
analyze batch
save batch results
checkpoint
```

However, batches must remain small enough that interruption loses very little work.

The recommended 16–64 item processing range provides a reasonable initial tradeoff.

---

# 56. Write Amplification

Progress values that change several times per second should generally remain in memory.

Do not persist:

```text
34.1%
34.2%
34.3%
```

Persist semantic checkpoints such as:

```text
asset analysis completed
batch completed
pipeline stage completed
job state changed
```

This minimizes unnecessary storage writes.

---

# 57. Logging

Performance logging should be concise and structured.

Useful measurements:

```text
job duration
stage duration
assets processed
cache hits
cache misses
average image load time
average Vision time
candidate count
failed assets
peak observed memory during manual profiling
thermal state changes
cancellation latency
resume count
```

Do not log sensitive image content.

Do not log facial embeddings or other image-derived private payloads merely for performance diagnostics.

---

# 58. Signposts

Use `OSSignposter` / signpost intervals around major stages where useful.

Examples:

```text
SelectionJob
MetadataScan
PhotoLoad
VisionAnalysis
DuplicateClustering
MomentClustering
FinalRanking
PersistenceBatch
```

Do not create a signpost for every trivial arithmetic operation.

Signposts should help Instruments explain where total processing time goes.

---

# 59. Performance Metrics

At minimum, manually capture:

```text
totalJobDuration
metadataDuration
cheapAnalysisDuration
expensiveAnalysisDuration
clusteringDuration
rankingDuration
cacheHitRate
averageAssetAnalysisTime
p95AssetAnalysisTime
peakMemory
failedAssetCount
```

These metrics should make regressions visible between development builds.

---

# 60. Benchmark Conditions

Performance measurements must record the environment.

At minimum:

```text
iPhone model
iOS version
app build
number of assets
local vs iCloud assets
battery state
Low Power Mode state
thermal state at start
analysis version
```

Without these variables, raw duration comparisons are unreliable.

---

# 61. Primary Benchmark Device

The most important release benchmark is:

> **The oldest iPhone model officially supported by the application.**

A high-end current device may be used for development, but it must not be the only performance reference.

The actual deployment-device matrix should be defined by the product/deployment configuration rather than duplicated here.

---

# 62. Initial Completion-Time Targets

These targets are engineering starting points, not user-facing SLAs.

Assumptions:

```text
assets locally available
normal thermal state
Low Power Mode disabled
oldest supported device
normal selection configuration
warm application state not required
```

Initial targets:

| Assets | Target | Investigate Regression Above |
|---|---:|---:|
| 300 | ≤ 2 min | > 3 min |
| 1,000 | ≤ 5 min | > 8 min |
| 2,500 | ≤ 12 min | > 20 min |
| 5,000 | ≤ 25 min | > 40 min |

These values must be recalibrated using the working prototype.

The main purpose of these thresholds is to detect regressions.

If the first real implementation requires different absolute values but produces acceptable UX, update this document rather than distorting the selection engine to satisfy arbitrary numbers.

---

# 63. Relative Performance Regression Rule

Once a stable baseline exists, relative regression becomes more useful than the initial absolute targets.

A build should be investigated when representative job duration increases approximately:

```text
> 20%
```

without an intentional quality improvement or algorithmic change explaining the increase.

Example:

```text
Previous:
1,000 photos = 4m 10s

New:
1,000 photos = 5m 20s

Regression:
~28%
```

Investigate before release.

---

# 64. Cache Performance Target

When all expensive analysis is already valid:

```text
Selection rerun
```

should be dramatically faster than:

```text
Initial photo analysis
```

For a 1,000-photo already-analyzed set, a change to final album size should ideally require seconds rather than minutes.

This is a required architecture property even if the exact target evolves during implementation.

---

# 65. Startup Performance

The app must not scan or analyze thousands of photos during launch.

Startup should perform only what is needed to show the initial UI.

Heavy operations must begin after explicit user intent.

Target:

```text
app becomes interactable:
approximately <= 1–2 seconds
```

on the oldest supported device under normal conditions.

Opening the application must not trigger:

```text
full Photos library scan
Vision analysis
global cache validation
large database migration on main actor
```

---

# 66. Time to First Progress

After the user starts a selection:

```text
Start Selection
```

the application should provide visible feedback quickly.

Target:

```text
processing state visible:
< 500 ms
```

The first expensive analysis result does not need to exist by then.

The user simply needs confirmation that the operation began.

---

# 67. Time to Cancel Feedback

After pressing Cancel:

```text
visual state change:
< 250 ms
```

The app may still be cleaning up an in-flight framework request.

UI feedback must not wait for all workers to completely terminate.

---

# 68. Performance Degradation Strategy

When resources are insufficient, degrade in this order:

```text
1. stop speculative prefetch
2. reduce analysis concurrency
3. reduce batch size
4. clear memory caches
5. delay nonessential work
6. checkpoint
7. pause expensive processing
```

Do not immediately reduce selection-quality algorithms unless the product specification explicitly permits it.

Performance pressure should first affect **speed**, not **correctness**.

---

# 69. No Silent Quality Reduction

The app must not silently disable important selection features because a job contains 5,000 photos.

For example:

```text
5,000 photos
```

must not automatically mean:

```text
skip face analysis entirely
skip duplicate detection entirely
skip diversity entirely
```

Instead, optimize:

```text
candidate generation
batch execution
analysis reuse
input resolution
concurrency
```

If a lower-quality fast mode is introduced later, it must be an explicit product decision.

---

# 70. Configuration Constants

Performance-sensitive values should be centralized.

Conceptually:

```swift
struct PerformancePolicy {
    let analysisBatchSize: Int
    let normalVisionConcurrency: Int
    let constrainedVisionConcurrency: Int
    let analysisImageLongEdge: Int
    let checkpointAssetInterval: Int
    let checkpointTimeInterval: Duration
    let progressUpdateFrequency: Double
}
```

Recommended initial values:

```text
analysisBatchSize             = 32

normalVisionConcurrency       = 2
constrainedVisionConcurrency  = 1
maximumVisionConcurrency      = 4

analysisImageLongEdge         = 768 px default

checkpointAssetInterval       = 25
checkpointTimeInterval        = 10 seconds

progressUpdateFrequency       = 4 Hz
```

These values should not be scattered throughout the codebase.

---

# 71. Performance Configuration Is Not User Settings

The values above are implementation details.

Do not expose controls such as:

```text
Vision worker count
batch size
cache size
analysis resolution
```

to normal users.

The application should choose safe defaults.

Developer-only diagnostics may expose them temporarily during profiling.

---

# 72. Processing State Machine

The performance pipeline should align with a small job state machine.

Example:

```text
created
   ↓
preparing
   ↓
analyzing
   ↓
clustering
   ↓
selecting
   ↓
completed
```

Interruption paths:

```text
analyzing ───────→ interrupted
clustering ──────→ interrupted
selecting ───────→ interrupted
```

Terminal states:

```text
completed
cancelled
failed
```

An interrupted state is resumable.

---

# 73. Partial Results

Where practical, completed analysis should become reusable immediately.

Do not wait until photo 5,000 before persisting the first 4,999 analyses.

This allows:

- safe interruption,
- later resume,
- future jobs to reuse already analyzed assets.

The final album itself should normally be presented only after selection consistency is achieved.

---

# 74. Future Jobs

If the same photo appears in a later selection job:

```text
previous valid analysis exists
        ↓
reuse
```

Example:

```text
Trip selection:
photo A analyzed

Later:
Favorites selection also includes photo A

Expected:
reuse photo A analysis
```

This means performance naturally improves over time without requiring background pre-analysis.

---

# 75. Cache Invalidation Events

Recompute an asset when relevant inputs have changed.

Typical causes:

```text
photo edited
asset replaced
analysis pipeline version changed
analysis configuration changed incompatibly
cached data corrupted
```

Do not invalidate analysis because of unrelated application changes.

For example:

```text
UI color changed
```

must not invalidate photo analysis.

---

# 76. Deletion Handling

When PhotoKit assets disappear:

```text
asset no longer exists
```

the application may lazily delete associated analysis records.

Immediate global cleanup after every Photos library change is unnecessary.

Cache cleanup should not block normal selection.

Detailed deletion/privacy behavior belongs to:

`09_Privacy_and_Permissions.md`.

---

# 77. Large Cache Cleanup

If derived analysis eventually becomes large, cleanup may use:

```text
last-used date
asset existence
analysis version
```

The MVP does not require a sophisticated LRU database.

Priority should be:

```text
remove orphaned analysis
remove obsolete versions
retain currently useful analysis
```

---

# 78. Performance Failure Definitions

The following are considered performance bugs:

### P0 / Critical

- reproducible memory termination during normal 1,000-photo workload,
- data corruption after interruption,
- app deadlock,
- analysis cannot be cancelled,
- main UI becomes permanently unresponsive.

### P1 / High

- reproducible memory termination around 5,000 photos,
- interrupted job cannot resume,
- analysis unnecessarily restarts from zero,
- severe memory growth across batches,
- thermal state ignored until app becomes unusable.

### P2 / Medium

- processing is materially slower than baseline,
- review scrolling visibly stutters,
- cache reuse fails,
- too-frequent progress updates cause UI overhead.

### P3 / Low

- minor progress-estimation inaccuracies,
- small optimization opportunities without UX impact.

---

# 79. Manual Performance Validation

No XCTest performance suite is required.

Before MVP release, manually evaluate at minimum:

```text
300 local photos
1,000 local photos
2,500 local photos
5,000 local photos
```

For at least the 1,000- and 5,000-photo cases:

```text
record duration
observe memory
observe CPU
observe thermal behavior
test cancellation
test background interruption
test process termination
test resume
test cached rerun
```

Detailed QA procedures belong in:

`10_Manual_QA_and_Selection_Evaluation.md`.

---

# 80. Required Instruments Checks

During development, periodically inspect:

### Time Profiler

Identify:

```text
Vision bottlenecks
image conversion overhead
unexpected main-thread work
clustering hotspots
```

### Allocations / Memory

Check:

```text
decoded-image lifetime
persistent memory growth
cache growth
large temporary allocations
```

### Swift Concurrency

Where useful, inspect:

```text
task explosion
unexpected actor contention
long-running main-actor tasks
```

Do not optimize purely from intuition when Instruments can identify the actual bottleneck.

---

# 81. Profiling Priority

Optimize in this order:

```text
1. crashes / memory termination
2. main-thread blocking
3. repeated unnecessary Vision work
4. image resolution and decoding
5. concurrency
6. similarity algorithm complexity
7. persistence overhead
8. minor Swift-level micro-optimizations
```

Do not spend significant engineering time optimizing a small array loop while full-resolution images are being unnecessarily decoded.

---

# 82. Implementation Checklist

Before considering the performance architecture complete:

- [ ] No full photo collection is decoded into memory.
- [ ] Analysis uses bounded image sizes.
- [ ] Vision concurrency is bounded.
- [ ] No task is created simultaneously for every photo.
- [ ] Expensive results are persisted.
- [ ] Analysis cache has version-based invalidation.
- [ ] Re-selection reuses valid analysis.
- [ ] Batch size is centralized.
- [ ] Concurrency limits are centralized.
- [ ] Progress publication is throttled.
- [ ] Main actor does not perform Vision/image decoding.
- [ ] Duplicate detection avoids global O(N²) comparisons.
- [ ] Moment grouping uses efficient chronological processing.
- [ ] Temporary image memory is released after analysis.
- [ ] Memory warnings reduce speculative work.
- [ ] Thermal state can reduce concurrency.
- [ ] Low Power Mode can reduce concurrency.
- [ ] User cancellation propagates through worker tasks.
- [ ] Completed analysis survives cancellation.
- [ ] Interrupted jobs can resume.
- [ ] Individual asset failures do not terminate the entire job.
- [ ] iCloud download time is distinguishable from analysis time.
- [ ] Review-grid thumbnail preheating is bounded.
- [ ] The app does not scan the complete library during launch.
- [ ] Major stages have measurable timing.
- [ ] A 5,000-photo manual stress run has been performed.

---

# 83. MVP Recommended Defaults

The initial implementation should begin with the following simple configuration:

```text
Maximum selection job:
~5,000 assets

Analysis batch:
32 assets

Heavy Vision concurrency:
2

Maximum Vision concurrency:
4

Constrained Vision concurrency:
1

Typical analysis image:
~768 px long edge

Progress publication:
<= 4 updates / second

Checkpoint:
25 assets or ~10 seconds

Custom persistent thumbnail cache:
None

Derived-analysis cache:
Enabled

Full-resolution analysis:
Only when specifically required

Background correctness:
Checkpoint + resume

Thermal handling:
Reduce concurrency

Low Power Mode:
Reduce concurrency

Global pairwise image comparison:
Forbidden
```

These defaults intentionally prioritize safety and predictable resource usage over theoretical maximum throughput.

---

# 84. Architecture Summary

The complete performance strategy is:

```text
Fetch metadata cheaply
        ↓
Process incrementally
        ↓
Request bounded-size images
        ↓
Limit concurrent Vision work
        ↓
Extract compact analysis
        ↓
Release decoded image memory
        ↓
Persist analysis in batches
        ↓
Checkpoint progress
        ↓
Use efficient candidate neighborhoods
        ↓
Avoid global O(N²)
        ↓
Reuse analysis across selections
        ↓
Adapt to memory / thermal pressure
        ↓
Resume safely after interruption
```

The central architectural invariant is:

> **At no point should the amount of active work scale linearly with the total number of photos in the selection job.**

A job containing 5,000 photos should take longer than a job containing 1,000 photos, but it should not require five times more peak memory or thousands of simultaneous asynchronous operations.

---

# 85. Definition of Done

`08_Performance_Spec.md` is considered implemented for MVP when:

1. A 1,000-photo job completes reliably on the oldest supported device.
2. A 5,000-photo job completes without unbounded memory growth.
3. The UI remains usable while analysis runs.
4. Vision and image loading use bounded concurrency.
5. Full-resolution assets are not unnecessarily decoded.
6. Analysis results are reused across repeated selections.
7. Changing final album parameters does not unnecessarily rerun Vision.
8. Cancellation stops new expensive work promptly.
9. Completed analysis survives cancellation or process interruption.
10. Interrupted jobs can resume without restarting from zero.
11. Duplicate/similarity processing does not perform global all-pairs expensive comparison.
12. Thermal and memory pressure produce graceful degradation.
13. Manual Instruments profiling shows no major memory leaks or main-thread analysis bottlenecks.
14. The implementation requires no unit-test target, UI-test target, or performance-test target.

---

# 86. Final Principle

When choosing between two implementations, prefer the one that:

```text
uses less decoded image memory,
performs less repeated analysis,
has bounded concurrency,
has predictable interruption behavior,
and remains easy to understand.
```

For photos-curator, reliable processing of thousands of photos is more important than maximizing short-lived benchmark throughput.

The MVP should be optimized through:

```text
bounded batches
+ bounded concurrency
+ smaller image inputs
+ analysis reuse
+ efficient candidate generation
+ checkpoint/resume
```

rather than through complex infrastructure.