# Manual QA and Selection Evaluation

**Document:** `10_Manual_QA_and_Selection_Evaluation.md`  
**Product:** Photos Curator  
**Status:** MVP Specification  
**Priority:** Required

---

## 1. Purpose

Photos Curator is not a conventional application where correctness can be evaluated only by checking whether buttons work or screens render correctly.

The core product value depends on two independent dimensions:

1. **Application correctness**
   - The app launches and navigates correctly.
   - Photo permissions behave correctly.
   - Photos are loaded without corruption.
   - Processing can complete, fail, retry, or resume safely.
   - The user can review and save the selected photos.
   - The app behaves correctly under interruption, memory pressure, iCloud downloads, and permission changes.

2. **Selection quality**
   - The app selects the photos a human would actually want to keep.
   - Important moments are not accidentally removed.
   - Near-duplicates are reduced.
   - The best photo from a sequence is preferred.
   - Group photos are evaluated appropriately.
   - Landscapes and contextual photos are preserved.
   - The final album is visually diverse rather than consisting of many nearly identical photos.

This document defines the manual QA process for both dimensions.

The goal is to provide a lightweight but repeatable validation process suitable for fast MVP development without introducing automated test infrastructure.

---

# 2. QA Philosophy

## 2.1 Manual-first testing

The MVP intentionally does not include:

- Unit test targets
- UI test targets
- Snapshot tests
- Automated integration tests
- Test-only dependency injection
- Mock services created exclusively for tests
- `Tests/` directories
- XCTest files
- CI pipelines dedicated to automated tests

The developer manually validates the application on real photo libraries and controlled benchmark datasets.

This is an intentional product-development decision intended to reduce engineering overhead during the early development phase.

It does **not** mean that correctness is optional.

Instead, quality is maintained through:

- Small, understandable modules
- Defensive runtime checks
- Structured manual test scenarios
- Stable benchmark photo sets
- Repeatable selection evaluation
- Regression checks before meaningful releases
- Logging sufficient to diagnose failures

Automated testing may be introduced later if the product grows sufficiently complex.

---

# 3. What Must Be Tested

Manual QA is divided into four areas.

| Area | Primary Question |
|---|---|
| Functional QA | Does the application behave correctly? |
| Selection QA | Does the engine choose good photos? |
| Performance QA | Can realistic libraries be processed reliably? |
| Privacy QA | Does the application respect its privacy guarantees? |

Performance-specific limits and implementation details are defined in:

`08_Performance_Spec.md`

Privacy requirements are defined in:

`09_Privacy_and_Permissions.md`.

This document validates those requirements from the user's perspective.

---

# 4. MVP Quality Priorities

Not all defects have equal importance.

For Photos Curator, the priority order is:

```text
1. Never damage or unexpectedly delete the user's original photos.

2. Avoid losing important photos from the recommended album.

3. Avoid obviously bad selections.

4. Remove unnecessary duplicates.

5. Preserve meaningful moment and subject diversity.

6. Maintain acceptable processing reliability.

7. Maintain acceptable processing speed.

8. Polish minor UI details.
```

A slightly imperfect recommendation is acceptable.

Accidentally deleting an original photo is not.

Missing one of the most important photos from a trip is substantially worse than including one extra mediocre photo.

Therefore, when selection confidence is uncertain, the engine should generally prefer **false inclusion over false exclusion** during shortlist generation.

The final selection stage may be more aggressive, but important moments must still be protected.

---

# 5. Test Environments

## 5.1 Primary environment

Most meaningful validation should be performed on a physical iPhone.

A physical device is particularly important for:

- PhotoKit behavior
- Limited Photos access
- iCloud Photos
- Large libraries
- Image decoding
- Memory pressure
- Backgrounding
- Device thermal behavior
- Real Vision framework performance

The simulator may still be used for basic UI development.

It should not be treated as the primary validation environment for the selection pipeline.

---

## 5.2 Recommended device coverage

During MVP development, testing every supported iPhone model is unnecessary.

Maintain at least:

### Primary development device

The developer's normal iPhone.

Used for:

- Daily testing
- Selection tuning
- UI validation
- Performance sanity checks

### Older supported device when available

Used occasionally to identify:

- Excessive memory usage
- Slow image analysis
- Thermal problems
- Poor concurrency behavior

### Current high-performance device when available

Used to ensure that concurrency and processing remain efficient on newer hardware.

The goal is representative coverage, not exhaustive hardware certification.

---

# 6. Standard QA Datasets

Random testing against the developer's entire photo library is useful but not sufficient.

Selection quality must also be evaluated using several stable datasets.

These datasets should remain mostly unchanged so results can be compared after algorithm changes.

---

## 6.1 Dataset A — Basic Mixed Album

**Recommended size:** 50–100 photos.

Should contain:

- People
- Landscapes
- Buildings
- Food
- Indoor photos
- Outdoor photos
- A few duplicates
- A few low-quality photos
- Different orientations

Purpose:

Validate basic end-to-end functionality quickly.

This should be the default smoke-test dataset.

---

## 6.2 Dataset B — Duplicate Stress Set

**Recommended size:** 50–150 photos.

Contains repeated photographs of the same scene.

Include examples such as:

- 10 photos of the same building
- 15 similar selfies
- Multiple crops of nearly the same image
- Slight camera movement
- Exposure changes
- Small expression differences
- Repeated screenshots when screenshots are supported
- Photos captured seconds apart

Purpose:

Validate:

- Similarity clustering
- Duplicate suppression
- Best-shot selection
- Duplicate leakage into the final album

---

## 6.3 Dataset C — Moment Sequence Set

**Recommended size:** 100–300 photos.

Contains sequences representing distinct moments.

Example:

```text
Airport
↓
Hotel
↓
Street walk
↓
Lunch
↓
Museum
↓
Sunset
↓
Dinner
↓
Night street
```

Each moment should contain several candidate photos.

Purpose:

Validate whether the final album preserves temporal and narrative coverage.

---

## 6.4 Dataset D — People and Group Photos

**Recommended size:** 100–200 photos.

Contains:

- Single-person portraits
- Couples
- Small groups
- Large groups
- Closed eyes
- Motion blur
- Different expressions
- Partial faces
- Back-facing subjects
- Multiple versions of the same group shot

Purpose:

Validate:

- Face-aware scoring
- Group-photo handling
- Best-shot selection
- Protection of socially important images

---

## 6.5 Dataset E — Landscape and Context

**Recommended size:** 100–200 photos.

Contains:

- Landscapes
- Architecture
- Streets
- Signs
- Food
- Hotel rooms
- Transportation
- Wide contextual images
- Photos without faces

Purpose:

Ensure that face-heavy scoring does not cause the system to produce an album containing almost exclusively people.

---

## 6.6 Dataset F — Bad Photo Stress Set

Contains intentionally poor images.

Examples:

- Heavy blur
- Accidental pocket photos
- Severe underexposure
- Severe overexposure
- Obstructed camera
- Near-black images
- Extreme motion blur
- Accidental floor or ceiling photos
- Unusable framing

Purpose:

Validate quality rejection.

---

## 6.7 Dataset G — Real Trip

**Recommended size:** 500–1,500 photos.

A complete real-world trip or event.

This is the most important qualitative benchmark.

It should include naturally occurring:

- Duplicates
- Burst-like sequences
- People
- Landscapes
- Food
- Transportation
- Night photos
- Screenshots
- Mistakes
- Important emotional moments

Purpose:

Answer the most important product question:

> Would the developer genuinely use the resulting album?

---

## 6.8 Dataset H — Large Library Stress Test

Recommended sizes:

```text
1,000 photos
3,000 photos
5,000 photos
```

Purpose:

Evaluate:

- Processing stability
- Memory use
- Cancellation
- Interruption
- Progress reporting
- iCloud behavior
- Thermal behavior
- Long-running task reliability

Selection quality does not need to be manually scored for all 5,000 images every time.

This dataset primarily validates system behavior.

---

# 7. Golden Evaluation Dataset

At least one dataset should eventually become a **Golden Dataset**.

A Golden Dataset is a fixed album manually annotated with expected selection behavior.

Recommended size:

```text
200–500 photos
```

It should be complex enough to include realistic edge cases but small enough to review manually.

For every photo, the reviewer may assign:

```text
MUST_KEEP
ACCEPTABLE
REJECT
```

Additional optional annotations:

```text
Moment ID
Duplicate cluster ID
Best photo in cluster
Group photo
Landscape
Portrait
Context photo
Known technical defect
```

The Golden Dataset provides a stable reference for algorithm changes.

---

# 8. Human Ground-Truth Labels

## 8.1 MUST_KEEP

A photo that should almost certainly appear in a good curated album.

Examples:

- Best family/group photo
- Unique important event
- Excellent portrait
- Only photo from a significant location
- Strong landscape
- Emotionally meaningful moment
- Important contextual image

Missing these photos is considered a significant selection failure.

---

## 8.2 ACCEPTABLE

A reasonable photo that may or may not be selected depending on album size and diversity constraints.

Examples:

- Good secondary portrait
- Alternative landscape
- Additional contextual image
- Good but redundant scene
- Second-best version of an important moment

---

## 8.3 REJECT

A photo that should generally not appear in the final album.

Examples:

- Severe blur
- Accidental photo
- Clearly inferior duplicate
- Poor expression when better alternatives exist
- Meaningless repeated frame
- Technically unusable image

---

# 9. Ground-Truth Annotation Procedure

When creating or updating a Golden Dataset:

1. Review the original album without looking at the algorithm's output.

2. Identify natural moments.

3. Identify duplicate or near-duplicate groups.

4. Mark the strongest image in important groups.

5. Assign each image:

```text
MUST_KEEP
ACCEPTABLE
REJECT
```

6. Run Photos Curator.

7. Compare the generated album against the annotations.

This order reduces reviewer bias.

If the reviewer sees the algorithm's choices first, there is a risk of unconsciously adjusting the expected result to match the algorithm.

---

# 10. Core Selection Metrics

Selection quality should not be reduced to one number.

Several metrics should be reviewed together.

---

## 10.1 Must-Keep Recall

Measures whether important photos survive selection.

```text
Must-Keep Recall
=
Number of selected MUST_KEEP photos
/
Total MUST_KEEP photos
```

Example:

```text
MUST_KEEP photos: 20
Selected: 19

Recall = 19 / 20 = 95%
```

This is one of the most important metrics.

A curation system that removes important memories is not useful even if its other selections look attractive.

---

## 10.2 Good Selection Rate

Measures how many final selections are reasonable.

```text
Good Selection Rate
=
Selected MUST_KEEP + ACCEPTABLE photos
/
Total selected photos
```

Example:

```text
Final album: 100 photos

MUST_KEEP: 18
ACCEPTABLE: 77
REJECT: 5

Good Selection Rate = 95%
```

---

## 10.3 Bad Pick Rate

The inverse practical metric:

```text
Bad Pick Rate
=
Selected REJECT photos
/
Total selected photos
```

Lower is better.

A few questionable photos are acceptable.

A visually obvious concentration of bad photos is not.

---

## 10.4 Duplicate Leakage Rate

Measures unnecessary repetition in the final album.

A leaked duplicate occurs when multiple photographs from the same near-identical cluster are selected without a meaningful reason.

```text
Duplicate Leakage Rate
=
Unnecessary duplicate selections
/
Total selected photos
```

Not every similar photo is a duplicate error.

Two photos may both deserve inclusion when:

- Facial expressions are meaningfully different.
- Different people are looking at the camera.
- They communicate different parts of an action.
- The moment is particularly important.
- The framing or composition differs significantly.

Manual judgment is therefore required.

---

## 10.5 Best-Shot Accuracy

For duplicate or moment clusters where one image has been manually identified as clearly best:

```text
Best-Shot Accuracy
=
Clusters where engine selected the expected best shot
/
Evaluated clusters
```

Example:

```text
40 clusters evaluated
Engine chose preferred image in 35

Accuracy = 87.5%
```

This metric is especially useful for:

- Group photos
- Portrait sequences
- Repeated landscapes
- Burst-like sequences

---

# 11. Moment Coverage

A good travel album should tell the story of the experience rather than simply select the highest-scoring individual images.

For the Golden Dataset, assign moment identifiers such as:

```text
M01 Airport
M02 Hotel
M03 Old Town Walk
M04 Lunch
M05 Museum
M06 Sunset
M07 Dinner
```

Then measure whether important moments are represented.

```text
Moment Coverage
=
Important moments represented in final album
/
Total important moments
```

The system does not need to select photos from every trivial moment.

However, it should not accidentally eliminate an entire important part of the trip because those photos scored slightly lower than another scene.

---

# 12. Diversity Evaluation

Diversity is partly subjective and should primarily be inspected visually.

Review the final album for excessive concentration in:

- One person
- One location
- One time period
- One scene
- One photo type
- One orientation
- One duplicate cluster

A healthy travel album often contains a mixture of:

```text
People
Group photos
Portraits
Landscapes
Architecture
Food
Details
Context
Transportation
Day scenes
Night scenes
```

The engine should not enforce artificial quotas.

Instead, diversity should prevent one repeated visual theme from dominating the album when other meaningful content exists.

---

# 13. Compression Ratio

Track the relationship between source size and final album size.

```text
Compression Ratio
=
Final selected photos
/
Input photos
```

Example:

```text
Input: 1,000
Final: 120

Compression ratio = 12%
```

The ideal ratio depends on the source album.

Therefore, compression ratio should **not** be treated as a quality score.

It is useful primarily for detecting major behavioral changes after algorithm tuning.

Example:

```text
Version A: 1,000 → 130 photos
Version B: 1,000 → 420 photos
```

A sudden change may indicate that duplicate filtering or threshold logic has broken.

---

# 14. Human Edit Rate

When a generated album is reviewed manually, record how many changes are needed before it feels acceptable.

Two useful values are:

```text
Removed by user
Added back by user
```

Then:

```text
Human Edit Rate
=
Photos manually changed
/
Final album size
```

More importantly, distinguish between:

### Removal edits

The engine included something unnecessary.

### Add-back edits

The engine failed to include something important.

Add-back edits are generally more serious because they indicate false exclusion.

---

# 15. MVP Selection Quality Targets

The following values are **initial engineering targets**, not scientifically established thresholds.

They should be adjusted after evaluating real datasets and user behavior.

For the Golden Dataset, aim approximately for:

| Metric | Initial MVP Target |
|---|---:|
| Must-Keep Recall | ≥ 95% |
| Good Selection Rate | ≥ 90% |
| Bad Pick Rate | ≤ 10% |
| Important Moment Coverage | ≥ 90% |
| Best-Shot Accuracy | ≥ 80–85% |
| Obvious Duplicate Leakage | ≤ 5% |

These thresholds should not be interpreted mechanically.

For example:

```text
Must-Keep Recall = 94%
```

could still be acceptable if the missing photo was borderline.

Conversely:

```text
Must-Keep Recall = 98%
```

could still represent a major failure if the missing 2% contained the single most important photograph in the album.

Manual review remains the final authority during MVP development.

---

# 16. Functional Smoke Test

Run this test after any significant change affecting:

- Photo loading
- Selection pipeline
- Review screen
- Permissions
- Data models
- Concurrency
- Saving

Use Dataset A.

Expected workflow:

```text
Launch app
↓
Select or grant photo access
↓
Choose photos
↓
Start curation
↓
Observe progress
↓
Processing completes
↓
Review selected album
↓
Open individual photos
↓
Adjust selection
↓
Save/export result
↓
Return to app
```

Confirm:

- No crash
- No permanently frozen UI
- Progress changes during processing
- Input photo count is correct
- Selected images display correctly
- User modifications are preserved
- Final save operation succeeds
- Original photos remain unchanged

---

# 17. Photo Permission QA

Test all important permission states.

## First launch

Verify:

- Permission explanation is understandable.
- iOS Photos permission appears at the appropriate time.
- The app does not crash when permission is denied.

## Full access

Verify:

- Accessible photos appear correctly.
- Album selection works.
- Processing works normally.

## Limited access

Verify:

- Only authorized photos are available.
- The app does not assume the entire library is accessible.
- Processing completes using accessible assets.
- The UI does not misleadingly report inaccessible photos as missing or corrupted.

## Denied

Verify:

- The app explains why photo access is required.
- The user is given a clear recovery path.
- No processing attempt begins without accessible assets.

## Permission changed in Settings

Test:

```text
Full → Limited
Full → Denied
Limited → Full
Denied → Full
```

Relaunch the app and verify state recovery.

---

# 18. Photo Loading QA

Validate:

- Portrait photos
- Landscape photos
- Square photos
- HEIC
- JPEG
- Large-resolution photos
- Edited Photos-library assets
- iCloud-backed assets
- Photos with unavailable metadata
- Assets that fail to load

One failed photo must not normally abort the entire curation session.

The engine should skip or record the failed asset and continue when possible.

---

# 19. iCloud Photo QA

Test with a library where some original assets are not stored locally.

Verify:

- The app does not assume immediate local availability.
- Loading states remain understandable.
- Slow iCloud retrieval does not appear as an application freeze.
- Failed downloads are handled.
- Cancellation remains possible where supported.
- Partial failures do not corrupt the entire session.

Test both:

```text
Good network
Poor network / temporarily offline
```

The exact iCloud loading strategy is defined in `07_Apple_Framework_Integration.md`.

---

# 20. Processing State QA

Validate each major state.

## Idle

No processing is running.

## Preparing

Photo metadata and required resources are being prepared.

## Analyzing

Assets are being evaluated.

## Clustering

Duplicates and/or moments are being organized.

## Selecting

Shortlist and final decisions are produced.

## Completed

Results can be reviewed.

## Failed

A recoverable explanation is shown.

## Cancelled

Temporary state is cleaned up safely.

The UI must never become stuck indefinitely in a processing state after the underlying operation has terminated.

---

# 21. Cancellation QA

Start processing and cancel at several points:

```text
Immediately after starting
~25% complete
~50% complete
~90% complete
```

Verify:

- The app remains responsive.
- Processing actually stops.
- Memory is eventually released.
- No invalid final album is presented as completed.
- A new session can be started afterward.
- Previous source photos remain untouched.

---

# 22. Backgrounding and Interruption QA

During processing:

1. Put the app in the background.
2. Return after a short period.
3. Lock and unlock the phone.
4. Open another memory-intensive application.
5. Trigger common interruptions when convenient.

Depending on the architecture defined elsewhere, Photos Curator may:

- Continue processing,
- Pause,
- Resume,
- Or restart safely.

Any of these strategies can be acceptable if intentional.

The unacceptable outcomes are:

- Silent data corruption
- Invalid selections
- Permanent loading state
- Crash loop
- Inability to restart the workflow

---

# 23. Review Screen QA

Validate:

- Correct number of selected photos
- Smooth scrolling
- Correct thumbnails
- Full-screen preview
- Selection/deselection
- Changes reflected immediately
- No duplicate UI items caused by identifier bugs
- Returning from full-screen view preserves state
- Review state does not unexpectedly reset

For large result sets, confirm that scrolling does not cause excessive memory growth.

---

# 24. Saving and Finalization QA

Verify that the user can complete the workflow successfully.

Depending on final product behavior, test:

- Creating a Photos album
- Adding selected photos to an album
- Preserving original assets
- Retry after save failure
- Partial PhotoKit failure
- App backgrounding during save

Critical rule:

> Photos Curator must not destructively remove original photos as part of the normal MVP curation flow.

If destructive cleanup is ever added in the future, it requires a separate safety specification.

---

# 25. Duplicate Selection Evaluation

For each duplicate cluster, manually check:

### Cluster correctness

Do the grouped images actually represent the same visual event?

Bad clustering example:

```text
Photo A: Eiffel Tower during daytime
Photo B: Eiffel Tower at night

Incorrectly treated as disposable duplicates.
```

### Representative quality

Did the selected image have:

- Better sharpness?
- Better expression?
- Better exposure?
- Better composition?
- Fewer closed eyes?
- Fewer obstructions?

### Leakage

Did unnecessary variants still enter the final album?

### Over-aggressive removal

Did clustering eliminate meaningful alternatives?

---

# 26. Group Photo Evaluation

Group photos require additional caution because image-quality metrics alone are insufficient.

For sequences of group photographs, inspect:

- Number of visible faces
- Closed eyes
- Face sharpness
- Facial expression
- Occlusion
- Whether important individuals are visible
- Whether someone is looking away
- Overall framing
- Whether multiple variants deserve preservation

Example:

```text
Photo A:
Excellent sharpness, one person has closed eyes.

Photo B:
Slightly lower technical score, everyone looks good.
```

A human may strongly prefer Photo B.

The selection engine should increasingly approximate this behavior.

---

# 27. Landscape Evaluation

Ensure that landscape photos are not systematically disadvantaged by face-related scoring.

Inspect whether the engine preserves:

- Strong establishing shots
- Unique locations
- Wide vistas
- Architectural scenes
- Sunset/sunrise
- Night city scenes
- Environmental context

A travel album containing only portraits usually fails the curation goal even if every individual portrait is technically excellent.

---

# 28. Low-Quality Photo Evaluation

For technically weak photos, ask two separate questions.

### Is the image technically poor?

Examples:

- Blur
- Underexposure
- Bad framing

### Is the image still important?

A technically imperfect image may be the only record of an important moment.

Therefore:

```text
Low technical quality
≠
Automatically reject
```

Technical quality should influence ranking but should not always override uniqueness or moment importance.

---

# 29. Temporal Diversity QA

View the final album chronologically.

Look for suspicious gaps.

Example input:

```text
Day 1: 250 photos
Day 2: 300 photos
Day 3: 200 photos
Day 4: 250 photos
```

Unexpected output:

```text
Day 1: 40 selected
Day 2: 50 selected
Day 3: 2 selected
Day 4: 45 selected
```

This should trigger investigation.

It may be legitimate, but it may indicate:

- Moment clustering failure
- Threshold bias
- Incorrect timestamps
- Duplicate over-clustering
- Category imbalance

---

# 30. Selection Review Questions

For every significant evaluation run, answer these questions:

```text
Did the album preserve the most important memories?

Did anything obviously bad survive?

Did obvious duplicates survive?

Was the best image usually chosen from repeated sequences?

Were group photos handled sensibly?

Were landscapes preserved?

Were different parts of the event represented?

Did one person or scene dominate unnecessarily?

Does the album feel substantially easier to review than the original library?

Would I personally accept this album with only minor edits?
```

The final question is particularly valuable during MVP development.

---

# 31. Real-World Blind Review

Periodically evaluate a new photo set that was **not** used while tuning the algorithm.

Recommended process:

```text
New trip
↓
Do not manually pre-curate it
↓
Run Photos Curator
↓
Review generated album
↓
Record obvious removals
↓
Record missing important photos
↓
Record duplicate failures
↓
Record moment failures
```

This helps detect overfitting to the Golden Dataset.

The selection engine should generalize to unfamiliar albums.

---

# 32. Regression Evaluation

After meaningful changes to:

- Scoring weights
- Duplicate thresholds
- Moment clustering
- Diversity logic
- Face analysis
- Final album size logic

run at minimum:

```text
Dataset A — Basic Mixed Album
Dataset B — Duplicate Stress
Golden Dataset
One real-world trip
```

Compare against the previous version.

Record:

```text
Must-Keep Recall
Bad Pick Rate
Duplicate Leakage
Best-Shot Accuracy
Moment Coverage
Final album size
Notable qualitative differences
```

Do not accept a change merely because one metric improves.

Example:

```text
Duplicate leakage:
5% → 1%

Must-Keep recall:
96% → 82%
```

This is almost certainly a regression.

The engine became more aggressive but substantially less safe.

---

# 33. Performance Smoke QA

Detailed performance requirements belong in `08_Performance_Spec.md`.

For manual QA, validate at least:

```text
100 photos
500 photos
1,000 photos
5,000 photos
```

Observe:

- Does processing begin?
- Does progress continue?
- Does memory appear bounded?
- Does the UI stay responsive?
- Does the device become excessively hot?
- Does the app crash?
- Can processing be cancelled?
- Does the result appear complete?

Exact timings should be recorded only when investigating performance regressions.

There is no need to benchmark every development build.

---

# 34. Memory Pressure QA

Large libraries should be tested on a physical device.

Watch for symptoms such as:

- OS termination
- UI becoming unresponsive
- Thumbnail disappearance
- Long pauses
- Processing slowdown over time
- Repeated re-decoding of the same images

If memory behavior becomes suspicious, use Xcode Instruments for targeted investigation.

Profiling is encouraged when diagnosing a problem.

Continuous performance instrumentation is not required for the MVP.

---

# 35. Privacy QA Checklist

Validate manually that:

- No photo is uploaded unexpectedly.
- No image-analysis API sends source images externally unless explicitly designed and documented.
- Face-analysis data remains on-device according to the privacy specification.
- Temporary images are not left indefinitely in app storage.
- Logs do not contain raw image data.
- Logs do not unnecessarily expose sensitive PhotoKit identifiers.
- Reset/deletion behavior removes app-owned analysis data as documented.
- Permission denial is respected immediately.

The privacy behavior must match `09_Privacy_and_Permissions.md`.

---

# 36. Error-State QA

Simulate or reproduce realistic errors where practical.

Examples:

```text
Photo unavailable
iCloud network failure
Permission revoked
Asset disappears during processing
Insufficient storage
Processing cancellation
App backgrounded
Unexpected analysis error
Save failure
```

For each failure verify:

1. The app does not corrupt state.
2. The user gets understandable feedback when action is required.
3. Retrying is possible when appropriate.
4. Other valid photos can continue processing when possible.

---

# 37. Edge Cases

The following cases should eventually be tested manually:

### Very small selection

```text
1 photo
2 photos
5 photos
```

### All photos nearly identical

Example:

```text
100 photos from one burst-like sequence
```

### No duplicates

The engine should not invent duplicates simply to reduce album size.

### Mostly poor photos

The system should still preserve the relatively strongest meaningful images.

### Mostly excellent photos

The system should avoid unnecessarily destructive filtering.

### No faces

Landscape-only trip.

### Almost all faces

Party or family event.

### Mixed portrait and landscape orientation

### Multiple days

### Incorrect or missing timestamps

### Photos edited in Apple Photos

### Photos stored only in iCloud

### Limited library access

### Large panoramic images

### Screenshots, if present in supported input

### Extremely dark night scenes

### Strong HDR or unusual exposure

---

# 38. Bug Severity

Use four severity levels.

## P0 — Critical

Examples:

- User originals are deleted or modified unexpectedly.
- App causes data corruption.
- Privacy guarantee is violated.
- Normal workflow consistently crashes.
- Final save operation corrupts user data.

P0 blocks release immediately.

---

## P1 — Major

Examples:

- Processing cannot complete for common albums.
- Major permission flow broken.
- Large numbers of important images are removed.
- Severe duplicate clustering errors.
- Review workflow unusable.
- Common iCloud assets cannot be processed.

P1 normally blocks release.

---

## P2 — Moderate

Examples:

- Some mediocre selections.
- Occasional missed duplicate.
- Specific edge-case failure.
- Moderate performance regression.
- Recoverable UI-state issue.

P2 may ship if understood and acceptable for the current milestone.

---

## P3 — Minor

Examples:

- Cosmetic issues
- Small spacing problems
- Minor wording inconsistency
- Rare low-impact recommendation disagreement

P3 should not normally block MVP progress.

---

# 39. Selection Failure Categories

Selection bugs should be categorized rather than reported only as "AI result is bad."

Use one or more of:

```text
IMPORTANT_PHOTO_MISSED

BAD_PHOTO_SELECTED

DUPLICATE_LEAKAGE

WRONG_BEST_SHOT

OVER_CLUSTERING

UNDER_CLUSTERING

MOMENT_MISSING

PEOPLE_BIAS

LANDSCAPE_BIAS

DIVERSITY_FAILURE

GROUP_PHOTO_FAILURE

QUALITY_SCORING_FAILURE

ALBUM_TOO_LARGE

ALBUM_TOO_SMALL

UNKNOWN_SELECTION_FAILURE
```

This makes patterns easier to identify during tuning.

---

# 40. Manual Selection Issue Template

When a selection problem is worth investigating, record:

```text
Dataset:
Build/version:
Input photo count:
Final photo count:

Failure category:

Expected behavior:

Actual behavior:

Relevant photo IDs:

Moment/cluster:

Why the human preference differs:

Suspected subsystem:
- quality scoring
- duplicate clustering
- face scoring
- moment clustering
- diversity
- final ranking
- unknown

Severity:

Screenshot or screen recording if useful:
```

Do not create heavyweight issue documentation for every subjective disagreement.

Record issues that:

- Recur,
- Are severe,
- Reveal systematic bias,
- Or materially reduce album usefulness.

---

# 41. Evaluation Run Template

Use the following structure for significant algorithm comparisons.

```text
# Selection Evaluation

Date:
Build:
Algorithm/configuration:
Dataset:

Input photos:
Final selected photos:
Compression ratio:

Must-Keep photos:
Must-Keep selected:
Must-Keep recall:

Selected MUST_KEEP:
Selected ACCEPTABLE:
Selected REJECT:

Good selection rate:
Bad pick rate:

Duplicate clusters evaluated:
Duplicate leakage:
Best-shot accuracy:

Important moments:
Moments represented:
Moment coverage:

User removals:
User add-backs:

Major failures:

Qualitative observations:

Regression versus previous version:

Decision:
[ ] Better
[ ] Approximately neutral
[ ] Worse

Notes:
```

This report may live outside the production code if desired.

There is no requirement to store every evaluation run permanently.

---

# 42. Visual Side-by-Side Comparison

When tuning selection algorithms, comparing entire albums is often more useful than examining scalar scores.

Recommended workflow:

```text
Algorithm A
↓
Generate album A

Algorithm B
↓
Generate album B

Review side by side
```

Focus on:

- Photos only in A
- Photos only in B
- Different representatives from the same cluster
- Lost moments
- Duplicate differences
- Changes in album balance

A numeric score can hide obvious qualitative regressions.

---

# 43. Avoid Optimizing a Single Metric

Selection quality is multi-objective.

For example, aggressively increasing the duplicate threshold may improve:

```text
Duplicate Leakage
```

while damaging:

```text
Moment Coverage
Must-Keep Recall
Group Photo Diversity
```

Likewise, heavily weighting face quality may improve portraits while causing landscapes to disappear.

Therefore algorithm changes must be evaluated across several dimensions.

The desired result is not mathematically optimal according to one score.

The desired result is an album that a person considers meaningfully better than manually reviewing the full source set.

---

# 44. Subjective Quality Scale

For real-world albums, assign one overall qualitative score.

## 5 — Excellent

The album feels ready to use.

Only trivial manual edits are desirable.

## 4 — Good

The album is clearly useful.

A few edits improve it, but important memories are preserved.

## 3 — Acceptable

The app saves time, but several obvious mistakes remain.

## 2 — Poor

Significant manual work is still required.

Important photos or moments may be missing.

## 1 — Unusable

The user would prefer curating the original library manually.

For the MVP, repeated scores of **4 or higher** on unseen real-world trip datasets are a strong signal that the selection engine is becoming useful.

---

# 45. Release Validation

Before an internal or external MVP build is considered acceptable, perform:

### Functional smoke test

Dataset A completes successfully.

### Selection regression test

Golden Dataset has no major unexplained regression.

### Real-world validation

At least one realistic trip produces a useful album.

### Permission validation

At minimum:

```text
Full access
Limited access
Denied access
```

### Large input validation

At least 1,000 photos complete without a critical failure.

### Cancellation validation

A processing session can be cancelled safely.

### Review validation

Photos can be added/removed correctly.

### Save validation

Final result can be persisted successfully.

### Privacy validation

No unexpected external photo transfer or sensitive logging is observed.

---

# 46. MVP Release Blockers

Do not release a build when any of the following is known to occur under normal usage:

```text
Original photo loss

Original photo modification without explicit user action

Repeatable normal-workflow crash

Processing permanently hangs

Generated album cannot be saved

Photos from another selection session appear incorrectly

Permission state causes invalid or misleading behavior

Major privacy violation

Common 1,000-photo album cannot complete

Systematically missing important moments

Selection quality obviously worse than the previous accepted build
```

---

# 47. Non-Blockers During Early MVP

The following issues may be acceptable temporarily:

```text
Occasional mediocre photo selected

Occasional duplicate survives

Minor ranking disagreement

Minor UI animation issue

Small visual inconsistency

Rare unsupported metadata case

Slight differences in final album size

Subjective disagreement between two similarly good photos
```

Development should not stop to perfect every subjective case.

The goal is to eliminate systematic failures first.

---

# 48. Algorithm Change Discipline

Whenever selection logic changes significantly:

1. Record what changed.

Example:

```text
Increase duplicate similarity threshold.

Add stronger closed-eye penalty.

Add moment diversity bonus.
```

2. State the expected effect.

Example:

```text
Expected:
fewer repeated shots in final album.

Risk:
important similar portraits could be collapsed.
```

3. Run representative datasets.

4. Compare against the last accepted behavior.

5. Keep or revert the change based on overall result.

This approach avoids random tuning without understanding why results changed.

Major decisions should be summarized in:

`13_Decision_Log.md`.

---

# 49. When to Use Xcode Diagnostics

Manual QA does not mean debugging only by visual inspection.

Use Xcode tools when there is evidence of a real problem.

Examples:

### Instruments

Use when investigating:

- Memory growth
- CPU hotspots
- Excessive allocations
- Thermal problems

### Memory Graph

Use when investigating suspected retained image buffers or service objects.

### Console / OSLog

Use for:

- Pipeline stages
- Failed asset identifiers
- Timing
- Cancellation
- PhotoKit errors

### Thread Performance Checker

Use when the UI becomes blocked.

These are debugging tools, not automated test infrastructure.

---

# 50. Logging for Manual QA

Development builds should make the selection process reasonably observable.

Useful logs include:

```text
Session started

Number of input assets

Number successfully analyzed

Number skipped

Duplicate cluster count

Moment count

Shortlist count

Final selection count

Pipeline stage timing

Cancellation

Asset loading errors

Selection session completed
```

Avoid logging:

- Raw image bytes
- Face crops
- Sensitive facial data
- Unnecessary personal metadata

Detailed scoring logs may be enabled temporarily when debugging specific selection problems.

---

# 51. Selection Explainability for Development

The production UI does not need to expose detailed AI explanations.

However, development diagnostics should make it possible to inspect why an image was:

```text
Selected
Rejected
Grouped as duplicate
Preferred over another image
Protected by diversity
Protected by moment coverage
```

A useful internal decision record might conceptually contain:

```text
assetID
qualityScore
faceScore
duplicateClusterID
momentID
diversityAdjustment
finalScore
decision
decisionReasons
```

The exact model is defined in `06_Data_Model.md`.

This diagnostic information dramatically reduces the difficulty of tuning the engine.

---

# 52. Manual QA Cadence

During ordinary feature development:

### After small UI-only change

Run only the relevant UI flow.

### After selection-scoring change

Run:

```text
Basic dataset
Golden Dataset
```

### After duplicate or clustering change

Run:

```text
Duplicate Stress Set
Golden Dataset
```

### After major pipeline change

Run:

```text
Functional smoke test
Golden Dataset
Real trip
1,000-photo performance check
```

### Before milestone/release

Run the complete release validation checklist.

This keeps QA proportional to risk without slowing every code change.

---

# 53. Definition of Done — Selection Feature

A meaningful selection-engine feature is considered done when:

```text
The feature works on a real device.

The intended selection behavior is observable.

No critical functional regression is introduced.

The Golden Dataset does not show an unacceptable regression.

At least one realistic album has been reviewed.

Known limitations are understood.

Relevant technical/product decisions are documented when necessary.
```

It is not necessary to create automated tests solely to satisfy a formal coverage requirement.

---

# 54. Definition of Done — MVP

The Photos Curator MVP is manually QA-ready when:

- Photo access works for expected permission states.
- Users can choose a source set of photos.
- 1,000-photo sessions work reliably on the primary supported device.
- Processing progress is understandable.
- Processing can fail or cancel safely.
- Important photos are rarely omitted.
- Obviously poor photos are usually filtered.
- Near-duplicates are substantially reduced.
- Group photos behave reasonably.
- Landscapes and contextual photos remain represented.
- Important moments remain represented.
- Final results can be reviewed and edited.
- Final selections can be saved.
- Original photos remain safe.
- On-device/privacy guarantees are respected.
- The resulting album provides a meaningful reduction in manual photo-review effort.

---

# 55. What We Are Explicitly Not Building

For the MVP, this QA strategy does not require:

```text
XCTest unit test suite

XCUITest suite

Snapshot testing

Automated golden-image comparison

Automated computer-vision quality benchmarking

Automated CI test pipelines

Device farm testing

Formal statistical significance testing

Large annotation infrastructure

ML experiment tracking platform

Dedicated QA backend

Separate test application target
```

These systems may eventually become valuable.

They are not prerequisites for proving the MVP.

---

# 56. Future Evolution

If Photos Curator gains significant usage, the manual evaluation process can gradually evolve.

Potential later additions include:

### Automated regression datasets

Run known photo sets through the engine and compare decision outputs.

### Offline evaluation tooling

Calculate selection metrics automatically from human annotations.

### A/B experiments

Compare different ranking strategies using real user behavior.

### Personalization metrics

Evaluate whether the engine learns individual preferences.

### User-feedback signals

Examples:

```text
Photo removed from recommendation
Photo added back
Alternative duplicate selected
Album accepted without edits
```

### Automated performance benchmarks

Track processing time and memory across releases.

These should be introduced only when their engineering cost is justified by product scale.

---

# 57. Core Principle

Photos Curator should ultimately be judged by a simple practical test:

> Given hundreds or thousands of photos, does the generated album preserve the memories that matter while removing enough repetition and low-value images that the user saves meaningful time?

All QA metrics exist to help answer that question.

Metrics are diagnostic tools.

They are not substitutes for reviewing real albums.

For the MVP, the preferred development loop is therefore:

```text
Build
↓
Run real photos
↓
Review mistakes
↓
Classify the failure
↓
Adjust the smallest relevant part of the engine
↓
Re-run stable benchmark datasets
↓
Compare
↓
Keep or revert
```

This provides enough discipline to improve the selection engine systematically while preserving the project's goal of fast development without unnecessary testing infrastructure.