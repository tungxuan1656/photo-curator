# Analytics and Metrics

## 1. Purpose

This document defines the analytics events, product metrics, and selection-quality metrics for **photos-curator**.

The primary purpose of analytics is not to maximize engagement or screen time. The purpose is to answer a much more important question:

> **Does photos-curator reliably turn a large photo collection into a smaller album that users consider worth keeping?**

Analytics should help the team:

- measure the quality of the photo-selection engine;
- identify failure modes in automatic selection;
- understand how much users modify generated albums;
- measure processing reliability and performance;
- compare selection-engine versions;
- determine whether future personalization improves results;
- detect regressions after algorithm changes;
- understand where users abandon the workflow.

Analytics should remain deliberately lightweight for the MVP.

This application processes highly personal photo libraries. Therefore, analytics must be designed according to the principle:

> **Measure user decisions and system behavior, not photo content.**

The analytics system must never require uploading users' photos, image embeddings, detected faces, face identities, or raw Vision framework outputs.

---

# 2. Goals

The analytics system must answer five primary questions.

## 2.1 Is the selection engine useful?

We need to determine whether users accept the automatically generated album.

Useful signals include:

- how many selected photos users keep;
- how many selected photos users remove;
- how many rejected photos users restore;
- whether users save/export the final album;
- whether users regenerate the selection;
- whether users abandon the result.

---

## 2.2 Is the selection engine improving?

Algorithm versions should be comparable.

For example:

```text
Selection Engine v1.0

Acceptance rate: 82%
Restore rate: 6%
Regeneration rate: 14%

Selection Engine v1.1

Acceptance rate: 88%
Restore rate: 4%
Regeneration rate: 9%
```

A newer algorithm should not be considered better simply because its internal scores look better.

User decisions are the strongest practical signal available.

---

## 2.3 Where does the selection engine fail?

Analytics should identify classes of failure such as:

```text
Too many similar photos selected

Important group photo excluded

Poor facial expression selected

Landscape variety too low

Album contains too many photos from one moment

Album size feels too large

Album size feels too small
```

These failures should primarily be inferred from user actions and optional structured feedback.

---

## 2.4 Is processing reliable?

The system must measure:

- processing completion rate;
- processing duration;
- interruption frequency;
- resume success;
- memory-related failures;
- PhotoKit access failures;
- unavailable iCloud assets;
- unsupported or corrupted assets.

---

## 2.5 Is the product delivering its core value?

The ideal workflow is:

```text
Select trip/photos
      ↓
Run analysis
      ↓
Generate album
      ↓
Minimal review
      ↓
Save album
```

The fewer corrections required before saving the album, the better the selection system is performing.

---

# 3. Non-Goals

The MVP analytics implementation is **not** intended to provide:

- advertising analytics;
- cross-app tracking;
- behavioral profiling;
- social graph analysis;
- face identity analytics;
- detailed user segmentation;
- attribution marketing infrastructure;
- session replay;
- heatmaps;
- photo-content analytics in the cloud;
- large-scale experimentation infrastructure;
- real-time analytics pipelines.

Do not introduce complex analytics infrastructure until there is a demonstrated product need.

---

# 4. Core Analytics Principles

## 4.1 Privacy First

The analytics layer must never transmit:

- original photos;
- thumbnails;
- image hashes that could reconstruct or identify content;
- Vision feature prints;
- embeddings;
- face crops;
- face landmarks;
- face identities;
- EXIF GPS coordinates;
- filenames;
- `PHAsset.localIdentifier`;
- album names entered by users;
- free-text user feedback unless explicitly designed and reviewed later.

Analytics should contain aggregated values and categorical information only.

Example:

```json
{
  "input_photo_count": 1248,
  "selected_photo_count": 94,
  "processing_duration_seconds": 41.3
}
```

This is acceptable.

The following is not:

```json
{
  "asset_id": "...",
  "latitude": 21.028,
  "longitude": 105.834,
  "face_embedding": [...]
}
```

---

## 4.2 User Actions Are Ground Truth

Internal quality scores are useful for debugging, but they are not the primary success metric.

For example:

```text
Technical sharpness score = 0.91
```

does not necessarily mean the user prefers the photo.

A technically imperfect photograph may have high emotional value.

Therefore:

```text
User Keep / Remove / Restore decisions

          >

Internal aesthetic scores
```

when evaluating real-world usefulness.

---

## 4.3 Analytics Must Not Affect Selection

Analytics must remain downstream from the selection engine.

The engine should not depend on the analytics service to function.

```text
PhotoKit
   ↓
Analysis
   ↓
Selection Engine
   ↓
Final Selection
   ↓
Analytics Event
```

Never:

```text
PhotoKit
   ↓
Analytics Service
   ↓
Selection Engine
```

Loss of network connectivity or analytics availability must never prevent album generation.

---

## 4.4 Prefer Aggregates Over Asset-Level Events

Do not emit one analytics event for every photo.

Bad:

```text
photo_analyzed
photo_analyzed
photo_analyzed
photo_analyzed
...
1,000 times
```

Prefer:

```text
analysis_completed
{
    photo_count: 1000,
    duplicate_cluster_count: 143,
    moment_count: 52,
    duration_seconds: 31
}
```

This reduces:

- privacy risk;
- storage requirements;
- network usage;
- analytics complexity;
- implementation complexity.

---

# 5. Analytics Architecture

Analytics should be implemented through a small application-level abstraction.

Example:

```swift
protocol AnalyticsService {
    func track(
        _ event: AnalyticsEvent
    )
}
```

Application code should not depend directly on a third-party analytics SDK.

Recommended structure:

```text
AnalyticsService
│
├── AnalyticsEvent
├── AnalyticsProperties
│
└── AnalyticsProvider
```

For development:

```text
DebugAnalyticsProvider
```

may simply log events.

For production:

```text
ProductionAnalyticsProvider
```

may forward approved events to the selected analytics backend.

This abstraction makes it possible to:

- change analytics providers;
- disable analytics;
- test locally;
- inspect events during development;
- maintain centralized privacy rules.

---

# 6. Event Naming Convention

Events should use:

```text
snake_case
```

and represent completed user/system actions.

Examples:

```text
selection_started
selection_completed
photo_removed_from_selection
photo_restored_to_selection
album_saved
processing_failed
```

Avoid names such as:

```text
button1_clicked
screen2_opened
thing_happened
```

Events should describe product meaning rather than implementation details.

---

# 7. Core Event Model

Every event may include a minimal common context.

```text
app_version
selection_engine_version
device_class
os_version_major
session_id
```

Optional:

```text
processing_mode
input_size_bucket
```

Do not include persistent device identifiers unless there is a clear product requirement.

---

# 8. Selection Session

The most important analytics unit is a **selection session**.

A selection session represents one attempt to transform a source photo set into a curated result.

Conceptually:

```text
User chooses photos
        ↓
selection_started
        ↓
analysis
        ↓
selection_completed
        ↓
review
        ↓
album_saved
```

A session should use an ephemeral random identifier:

```text
selection_session_id
```

Example:

```text
A782E1C9...
```

The identifier exists only to associate events from the same selection workflow.

It must not encode:

- photo identifiers;
- user identity;
- album identity;
- timestamps;
- device identifiers.

---

# 9. Essential MVP Events

Only a relatively small number of events are required for the MVP.

## 9.1 `selection_started`

Triggered when the user starts processing a photo collection.

Properties:

| Property | Description |
|---|---|
| `input_photo_count` | Number of input assets |
| `input_size_bucket` | Size category |
| `target_selection_count` | Requested approximate output size |
| `engine_version` | Selection engine version |

Recommended size buckets:

```text
1_100
101_500
501_1000
1001_2500
2501_5000
5000_plus
```

---

## 9.2 `analysis_completed`

Triggered when photo analysis is completed.

Properties:

| Property | Description |
|---|---|
| `input_photo_count` | Number of analyzed photos |
| `analyzed_photo_count` | Successfully analyzed photos |
| `skipped_photo_count` | Assets that could not be analyzed |
| `duplicate_cluster_count` | Duplicate/similarity clusters |
| `moment_count` | Detected moments |
| `group_photo_count` | Group-photo candidates |
| `analysis_duration_seconds` | Analysis duration |

These values are aggregate statistics only.

---

## 9.3 `selection_completed`

Triggered when the engine produces its initial result.

Properties:

| Property | Description |
|---|---|
| `input_photo_count` | Source collection size |
| `candidate_count` | Photos surviving initial filtering |
| `selected_photo_count` | Final automatic selection |
| `duplicate_removed_count` | Removed because of duplicate/similarity logic |
| `quality_rejected_count` | Removed because of quality rules |
| `engine_version` | Algorithm version |
| `processing_duration_seconds` | Total processing time |

This is one of the most important events.

---

## 9.4 `review_started`

Triggered when the user opens the generated selection.

Properties:

```text
selected_photo_count
```

This separates successful processing from actual user review.

---

## 9.5 `photo_removed_from_selection`

Triggered when the user removes an automatically selected photo.

Properties should remain minimal.

Recommended:

```text
reason_category
```

Only include a reason when one is available from structured UI or engine metadata.

Potential categories:

```text
unknown
duplicate
poor_quality
bad_expression
unwanted_person
not_important
too_similar
other
```

The MVP does not need to require a reason.

User removal itself is already a meaningful signal.

---

## 9.6 `photo_restored_to_selection`

Triggered when the user restores a photo rejected by the engine.

This event is especially important because it represents a likely **false negative**.

Possible properties:

```text
original_rejection_category
```

Examples:

```text
duplicate
quality
moment_limit
diversity
ranking
unknown
```

Again, no image identifier should be transmitted.

---

## 9.7 `selection_regenerated`

Triggered when the user asks the app to generate another selection.

Properties:

```text
previous_selected_count
requested_selected_count
```

Optional:

```text
reason
```

Possible structured reasons:

```text
too_many_photos
too_few_photos
bad_selection
too_similar
missing_important_photos
other
```

---

## 9.8 `album_saved`

Triggered when the user confirms the final result.

Properties:

| Property | Description |
|---|---|
| `initial_selected_count` | Automatic result size |
| `final_selected_count` | Final user-approved size |
| `removed_count` | Selected photos removed |
| `restored_count` | Rejected photos restored |
| `review_duration_seconds` | Review duration |
| `regeneration_count` | Number of regenerations |

This event provides the strongest signal that the workflow delivered value.

---

## 9.9 `selection_abandoned`

Triggered when a started workflow does not result in an accepted album.

It should distinguish broad stages:

```text
analysis
selection
review
```

Do not overinterpret this event.

The user may simply close the app or become busy.

---

# 10. Processing and Reliability Events

## 10.1 `processing_interrupted`

Triggered when processing stops because of:

```text
app_backgrounded
system_termination
user_cancelled
photo_access_changed
unknown
```

Properties:

```text
processed_photo_count
input_photo_count
stage
```

---

## 10.2 `processing_resumed`

Triggered when an interrupted operation successfully resumes.

Properties:

```text
stage
remaining_photo_count
```

---

## 10.3 `processing_failed`

Triggered for non-recoverable processing failures.

Error values must be categorical.

Example:

```text
photo_access_error
icloud_asset_unavailable
image_decode_error
memory_pressure
analysis_error
selection_error
unknown
```

Never upload raw exception messages that could accidentally contain private information.

---

# 11. Primary Product Metrics

The number of events is less important than deriving the right metrics.

The following metrics should be considered the primary product metrics.

---

# 12. Selection Acceptance Rate

This measures how many automatically selected photographs survive user review.

```text
Selection Acceptance Rate
=
Automatically selected photos kept by user
÷
Automatically selected photos
```

Example:

```text
Engine selected: 100

User removed: 12

Kept: 88
```

Therefore:

```text
Acceptance Rate = 88 / 100 = 88%
```

Higher is generally better.

However, this metric must be interpreted together with restoration rate.

---

# 13. Selection Removal Rate

```text
Removal Rate
=
Removed automatically selected photos
÷
Automatically selected photos
```

Therefore:

```text
Removal Rate
=
1 - Acceptance Rate
```

This metric approximates the engine's false-positive behavior.

In product terms:

> How frequently does the engine select something the user does not want?

---

# 14. Restore Rate

Restore Rate is one of the most important metrics.

```text
Restore Rate
=
User-restored photos
÷
Automatically rejected photos exposed to the user
```

Conceptually, it measures false negatives.

A high restore rate suggests that the engine is rejecting photos users consider important.

This may be more damaging than selecting a few mediocre photographs.

For a curator application:

```text
Missing an important memory
```

may be worse than:

```text
Including one extra mediocre image.
```

Therefore, selection tuning should generally be conservative about aggressively discarding uncertain photos.

---

# 15. Edit Rate

The overall album edit rate measures how much work remains after automatic curation.

```text
Edit Rate
=
Removed + Restored
÷
Initial selection size
```

Example:

```text
Initial selection: 100

Removed: 8
Restored: 4

Edit Rate = 12%
```

Lower is better.

This can serve as one of the clearest measures of selection-engine usefulness.

---

# 16. Album Save Rate

```text
Album Save Rate
=
Saved selection sessions
÷
Completed selection sessions
```

A generated album that is never saved is weaker evidence of successful curation.

This should therefore be considered a high-level product success metric.

---

# 17. Regeneration Rate

```text
Regeneration Rate
=
Sessions containing regeneration
÷
Reviewed sessions
```

High regeneration may indicate:

- poor selection quality;
- wrong album size;
- lack of diversity;
- excessive duplicate images;
- important moments missing.

A decreasing regeneration rate is usually a positive signal.

---

# 18. Review Effort

The application is intended to reduce work.

Therefore, review effort matters.

Useful measurements include:

```text
review_duration_seconds

photos_removed

photos_restored

regeneration_count
```

A simple derived metric:

```text
Review Actions per 100 Selected Photos
=
(Removals + Restores)
÷
Initial selected count
× 100
```

This allows sessions with different album sizes to be compared.

---

# 19. Time to Curated Album

Measure:

```text
selection_started
        ↓
album_saved
```

Derived metric:

```text
Time to Curated Album
```

This includes:

- processing time;
- review time;
- regeneration time.

The purpose of photos-curator is to reduce the time and cognitive effort required to curate large photo collections.

Therefore, this metric reflects the product's end-to-end value.

---

# 20. Processing Metrics

Performance should be measured separately from selection quality.

Important metrics:

```text
analysis_duration
selection_duration
total_processing_duration
photos_processed_per_second
processing_completion_rate
processing_failure_rate
resume_success_rate
```

Segment these metrics by broad input-size buckets.

For example:

| Input Size | Median Processing Time |
|---|---:|
| 1–100 | — |
| 101–500 | — |
| 501–1,000 | — |
| 1,001–2,500 | — |
| 2,501–5,000 | — |

Exact targets belong in `08_Performance_Spec.md`.

This document only defines measurement.

---

# 21. Selection Engine Quality Scorecard

No single metric can adequately describe selection quality.

Use a small scorecard.

Recommended primary scorecard:

| Metric | Desired Direction |
|---|---|
| Selection Acceptance Rate | ↑ |
| Restore Rate | ↓ |
| Edit Rate | ↓ |
| Album Save Rate | ↑ |
| Regeneration Rate | ↓ |
| Median Review Time | ↓ |
| Processing Completion Rate | ↑ |

This scorecard should be used when comparing engine versions.

---

# 22. Engine Versioning

Every generated selection must internally record:

```text
engine_version
```

Example:

```text
1.0
1.1
1.2
```

More detailed internal versions are also acceptable:

```text
2026.09.1
```

The important requirement is reproducibility.

When algorithm behavior changes meaningfully, increment the engine version.

Examples of meaningful changes:

- duplicate clustering threshold changed;
- quality scoring changed;
- moment clustering changed;
- group-photo prioritization changed;
- diversity weighting changed;
- ranking formula changed;
- final selection allocation changed.

Do not change the engine version for unrelated UI changes.

---

# 23. Comparing Selection Engine Versions

Suppose:

| Metric | v1.0 | v1.1 |
|---|---:|---:|
| Acceptance Rate | 83% | 89% |
| Restore Rate | 8% | 5% |
| Regeneration Rate | 16% | 10% |
| Median Review Time | 4.2 min | 3.1 min |

This provides strong evidence that v1.1 produces more useful selections.

However, also check performance:

| Metric | v1.0 | v1.1 |
|---|---:|---:|
| 1,000-photo processing | 35 s | 72 s |

The selection improvement may not justify doubling processing time.

Algorithm evaluation must therefore consider both:

```text
Selection Quality
+
Performance Cost
```

---

# 24. Quality Metrics by Input Size

Selection performance may vary significantly depending on input collection size.

Metrics should therefore be segmented by:

```text
1–100
101–500
501–1,000
1,001–2,500
2,501–5,000
5,000+
```

For example:

```text
Acceptance Rate

1–100 photos       92%
101–500            90%
501–1,000          88%
1,001–2,500        81%
2,501–5,000        74%
```

This would reveal that large collections require algorithm improvements.

---

# 25. Quality Metrics by Selection Ratio

The difficulty of curation depends on the requested compression ratio.

Example:

```text
1,000 photos → 300 photos

vs.

1,000 photos → 50 photos
```

The second task requires much more aggressive rejection.

Therefore record:

```text
input_photo_count
selected_photo_count
```

and derive:

```text
Selection Ratio
=
selected_photo_count
÷
input_photo_count
```

Quality metrics can then be compared across ranges such as:

```text
< 5%
5–10%
10–20%
20–40%
> 40%
```

---

# 26. Selection Reason Analytics

The selection engine should internally classify why photos were kept or rejected.

Possible categories:

```text
quality
duplicate
moment_representative
group_photo
portrait
landscape
diversity
ranking
selection_limit
```

Do not upload per-photo decisions.

Instead aggregate them.

Example:

```json
{
  "duplicate_rejected_count": 187,
  "quality_rejected_count": 42,
  "moment_limit_rejected_count": 93,
  "diversity_selected_count": 11
}
```

These aggregate numbers allow algorithm debugging without transmitting photo-level data.

---

# 27. False-Positive Analysis

A false positive occurs when:

```text
Engine selects photo
        ↓
User removes photo
```

Useful aggregate questions:

```text
What proportion of removed photos were selected because of:

quality score?
group-photo priority?
moment representation?
diversity?
ranking?
```

This can reveal rules that are too aggressive.

Example:

```text
35% of user-removed photos were selected through
group-photo prioritization.
```

This suggests the group-photo rule may need adjustment.

---

# 28. False-Negative Analysis

A false negative occurs when:

```text
Engine rejects photo
        ↓
User restores photo
```

This is particularly important.

Aggregate restoration by original rejection reason:

```text
duplicate
quality
moment_limit
ranking
selection_limit
```

Example:

```text
Restored photos by rejection reason:

Duplicate        8%
Quality         12%
Moment limit    41%
Ranking         29%
Other           10%
```

This would strongly suggest that moment-level selection is eliminating photos users care about.

---

# 29. Optional Structured Feedback

The MVP should not require users to fill out surveys.

However, lightweight optional feedback can be valuable.

Example prompt after saving:

```text
How was this selection?

Great
Okay
Poor
```

Optional secondary reasons for poor results:

```text
Missing important photos
Too many similar photos
Poor photo choices
Too many photos
Too few photos
Not enough variety
```

Avoid free-text feedback in the initial implementation.

Structured feedback is easier to analyze and carries less privacy risk.

---

# 30. Feedback Metrics

If structured feedback exists, track:

```text
selection_feedback_submitted
```

Properties:

```text
rating
reason
engine_version
```

Example:

```json
{
  "rating": "poor",
  "reason": "missing_important_photos",
  "engine_version": "1.1"
}
```

No photo or personal content should accompany this event.

---

# 31. Funnel Metrics

The primary product funnel is:

```text
App opened
     ↓
Photos selected
     ↓
Selection started
     ↓
Selection completed
     ↓
Review started
     ↓
Album saved
```

Important funnel conversions:

```text
Selection Start Rate

Processing Completion Rate

Review Start Rate

Album Save Rate
```

The most important transition is:

```text
selection_completed
        ↓
album_saved
```

because it represents whether a generated result becomes useful output.

---

# 32. Recommended MVP Dashboard

Avoid building many dashboards.

One dashboard is sufficient initially.

## Section A — Usage

```text
Selection sessions
Average input photo count
Average output photo count
Saved albums
```

## Section B — Selection Quality

```text
Acceptance Rate
Restore Rate
Edit Rate
Regeneration Rate
Album Save Rate
```

## Section C — Performance

```text
Median processing time
P90 processing time
Processing failure rate
Interruption rate
Resume success rate
```

## Section D — Engine Versions

Compare:

```text
Acceptance
Restore
Regeneration
Review time
Processing time
```

by:

```text
engine_version
```

This is enough for the MVP.

---

# 33. Recommended Statistical Aggregation

For latency and review duration, report:

```text
median
P90
```

rather than only averages.

A small number of extremely slow operations can make the mean misleading.

For selection quality metrics, use:

```text
count
percentage
sample size
```

Example:

```text
Acceptance Rate
88.1%

Sessions: 382
Selected photos evaluated: 31,420
```

Never interpret percentages without considering sample size.

---

# 34. Minimum Sample Size for Product Decisions

Do not change selection rules because of a few isolated sessions.

During early development, manual inspection remains important.

Once real users exist, compare algorithm changes across enough sessions to avoid reacting to noise.

There is intentionally no rigid statistical threshold in the MVP.

The practical rule is:

> Use analytics to detect patterns, then verify those patterns through manual selection evaluation.

`10_Manual_QA_and_Selection_Evaluation.md` remains the primary tool for controlled qualitative evaluation.

Analytics complements manual QA; it does not replace it.

---

# 35. Internal Development Metrics

During development, richer local-only diagnostics may be useful.

Examples:

```text
average_quality_score
duplicate_cluster_distribution
moment_size_distribution
face_count_distribution
candidate_score_distribution
selection_reason_distribution
```

These may appear in:

```text
debug logs
developer UI
local JSON exports
```

They do not need to be uploaded to production analytics.

This separation is important.

```text
Local debugging metrics
        ≠
Production analytics
```

---

# 36. Debug Session Summary

A useful development feature is a locally generated summary.

Example:

```text
Selection Session

Input:
1,247 photos

Analysis:
63 moments
172 similarity clusters
208 photos removed as near-duplicates
39 photos removed for low quality

Candidates:
416

Final selection:
96

Selection reasons:
Moment representative: 53
Portrait: 14
Group photo: 8
Landscape: 9
Diversity: 12

Processing:
Analysis: 31.2 s
Selection: 1.8 s
Total: 33.0 s
```

This diagnostic output should remain on-device unless explicitly exported by the developer/user.

It can be extremely useful during manual QA.

---

# 37. Privacy-Safe Device Segmentation

Performance may depend on device capability.

Avoid transmitting exact device information unless necessary.

Prefer broad categories such as:

```text
device_performance_class
```

Example:

```text
low
medium
high
```

or a carefully reviewed hardware-family category.

Do not collect hardware identifiers for user tracking.

---

# 38. Offline Behavior

The app must remain fully functional when analytics cannot be sent.

Analytics failure must never cause:

```text
selection failure
album save failure
processing delay
user-visible error
```

The expected behavior is:

```text
Analytics unavailable
       ↓
Drop or queue approved event
       ↓
Continue normally
```

A bounded temporary queue may be used.

Do not build a complex synchronization system solely for analytics.

---

# 39. Event Queue Limits

If analytics events are temporarily queued locally:

- use a small bounded queue;
- remove successfully uploaded events;
- discard old events;
- do not store photo content;
- do not store sensitive identifiers;
- do not allow analytics storage to grow indefinitely.

Exact implementation is provider-dependent.

---

# 40. Analytics Consent and Configuration

Analytics behavior must remain consistent with:

`09_Privacy_and_Permissions.md`.

If analytics collection requires consent depending on implementation, provider, or distribution region, the app must respect that requirement.

The selection engine must remain fully functional regardless of analytics participation.

Conceptually:

```text
analyticsEnabled = false
```

must not change:

```text
analysis
selection
review
saving
```

behavior.

---

# 41. Data Retention

Analytics retention should follow the principle:

> Keep data only as long as it remains useful for product and engine evaluation.

Avoid indefinite retention by default.

No analytics retention policy should override the privacy guarantees defined in `09_Privacy_and_Permissions.md`.

---

# 42. Events Explicitly Not Allowed

The following events or properties should not be implemented:

```text
photo_viewed:
    photo_identifier

face_detected:
    face_embedding

location_seen:
    latitude
    longitude

person_selected:
    identity

photo_rejected:
    thumbnail

image_uploaded:
    image_bytes
```

Similarly, avoid event names that encourage asset-level tracking.

Production analytics should describe the **selection session**, not the contents of the user's photo library.

---

# 43. MVP Event Set

The recommended initial production event set is deliberately small.

```text
selection_started
analysis_completed
selection_completed
review_started

photo_removed_from_selection
photo_restored_to_selection
selection_regenerated

album_saved
selection_abandoned

processing_interrupted
processing_resumed
processing_failed

selection_feedback_submitted
```

`selection_feedback_submitted` is optional.

This event set should be sufficient to understand the MVP without introducing unnecessary analytics complexity.

---

# 44. Derived MVP Metrics

From the events above, calculate:

```text
Selection Acceptance Rate
Selection Removal Rate
Restore Rate
Edit Rate
Album Save Rate
Regeneration Rate

Median Review Duration
Median Time to Curated Album

Processing Completion Rate
Processing Failure Rate
Resume Success Rate

Median Processing Duration
P90 Processing Duration
```

These should be enough for early product decisions.

---

# 45. North-Star Quality Metric

For the early product, the closest practical quality metric is:

> **Percentage of automatically selected photos that survive user review in sessions where the album is saved.**

Formally:

```text
Accepted Selection Rate
=
Kept automatic selections
÷
Initial automatic selections
```

calculated for successfully saved albums.

However, this metric must always be considered together with:

```text
Restore Rate
```

because an algorithm could artificially improve acceptance by selecting very few photographs and excluding important memories.

Therefore the main quality pair is:

```text
High Acceptance Rate
+
Low Restore Rate
```

---

# 46. Long-Term Success Metric

As personalization is introduced later, the strongest signal becomes:

```text
How little does the user need to edit
before accepting the generated album?
```

A mature photos-curator engine should produce:

```text
Large source library
        ↓
Automatic selection
        ↓
Very few corrections
        ↓
Save
```

Therefore the long-term product objective should be:

> **Minimize user correction effort while preserving important memories and maintaining album diversity.**

---

# 47. Personalization Metrics — Future

Personalization is outside the initial MVP.

When introduced, compare:

```text
generic engine
```

against:

```text
personalized engine
```

using the same core metrics:

```text
Acceptance Rate
Restore Rate
Edit Rate
Regeneration Rate
Review Time
```

Do not create separate arbitrary "AI personalization scores".

The success criterion remains user behavior.

---

# 48. Possible Future Learning Signals

Future versions may use local feedback such as:

```text
frequently restored photo characteristics
frequently removed photo characteristics
preferred portrait/group-photo balance
preferred album size
preferred landscape frequency
preferred moment density
```

Any learning system should preferably remain on-device when practical.

The analytics backend does not need the underlying photo features.

At most, privacy-reviewed aggregate metrics may be uploaded.

---

# 49. What Not to Optimize

Do not optimize photos-curator primarily for:

```text
daily active usage
session duration
number of screens opened
number of photos viewed
time spent reviewing
```

For many consumer applications, longer engagement is desirable.

For photos-curator, it may indicate failure.

A user who processes:

```text
1,000 photos
```

and obtains an excellent album after:

```text
2 minutes
```

is more successful than a user who spends:

```text
30 minutes
```

correcting the selection.

Therefore:

> **Lower interaction time can represent higher product quality.**

---

# 50. Example Successful Session

```text
Input:
1,200 photos

Automatic selection:
100 photos

User review:
Removed 5
Restored 2

Final album:
97 photos

Regeneration:
0

Review time:
2.8 minutes

Album saved:
Yes
```

Metrics:

```text
Acceptance Rate:
95%

Edit Rate:
7%

Regeneration:
No

Album Save:
Yes
```

This is a strong successful session.

---

# 51. Example Poor Session

```text
Input:
1,200 photos

Automatic selection:
100 photos

User review:
Removed 31
Restored 18

Regeneration:
2

Review time:
14 minutes

Album saved:
No
```

This strongly suggests that the selection engine failed to produce useful output.

The session should be considered valuable diagnostic evidence even though no photo content is collected.

---

# 52. Implementation Priority

## MVP — Required

Implement:

```text
selection_started
analysis_completed
selection_completed
review_started

photo_removed_from_selection
photo_restored_to_selection

album_saved
processing_failed
```

Calculate:

```text
Acceptance Rate
Restore Rate
Edit Rate
Album Save Rate
Processing Completion Rate
Processing Duration
```

---

## MVP — Recommended

Add:

```text
selection_regenerated
selection_abandoned
processing_interrupted
processing_resumed
```

Calculate:

```text
Regeneration Rate
Review Duration
Resume Success Rate
```

---

## Post-MVP

Consider:

```text
structured selection feedback
engine experiment comparison
personalization effectiveness
longitudinal preference adaptation
```

Only implement these after the core selection workflow is stable.

---

# 53. Definition of Done

The analytics implementation is considered sufficient for the MVP when:

- every selection session can be associated with an engine version;
- input and output photo counts are measured;
- processing duration can be measured;
- processing failures can be categorized;
- user removals from automatic selections can be counted;
- user restorations can be counted;
- album saves can be measured;
- selection acceptance rate can be calculated;
- restore rate can be calculated;
- edit rate can be calculated;
- album save rate can be calculated;
- metrics can be segmented by engine version;
- metrics can be segmented by input-size bucket;
- analytics failure never affects the main photo-selection workflow;
- no photos or thumbnails are transmitted;
- no face embeddings or identity information are transmitted;
- no PhotoKit asset identifiers are transmitted;
- no precise location information is transmitted;
- production analytics remains significantly simpler than the selection engine itself.

---

# 54. Final Product Principle

The analytics system exists to answer:

> **Did photos-curator make the user's photo-selection job easier?**

The strongest evidence is not how frequently users open the app or how long they stay inside it.

The strongest evidence is:

```text
The engine selected good photos
        ↓
The user changed very little
        ↓
The user saved the album
```

For this product, good analytics should therefore optimize for:

```text
High selection acceptance
Low restore rate
Low correction effort
High album completion
Reliable processing
Strong privacy
```

Everything else is secondary.