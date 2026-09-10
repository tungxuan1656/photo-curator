# Apple Framework Integration

**File:** `07_Apple_Framework_Integration.md`  
**Project:** photos-curator  
**Status:** Required  
**Primary frameworks:** PhotoKit, Vision  
**Related documents:**

- `01_PRD.md`
- `02_UX_Flows.md`
- `03_Photo_Selection_Rules.md`
- `04_Selection_Engine_Design.md`
- `05_iOS_Architecture.md`
- `06_Data_Model.md`
- `08_Performance_Spec.md`
- `09_Privacy_and_Permissions.md`

---

# 1. Purpose

This document defines how `photos-curator` integrates with Apple frameworks required to:

1. access the user's photo library;
2. enumerate and load photo assets;
3. handle photos stored in iCloud Photos;
4. generate appropriately sized images for analysis;
5. analyze images with Vision;
6. detect visually similar or duplicate photos;
7. analyze faces and group photos;
8. cache thumbnails and analysis images efficiently;
9. handle Photos permission states;
10. react safely to photo-library changes;
11. optionally create a curated Photos album.

The goal is to establish a small, predictable integration layer between Apple's APIs and the application's selection engine.

The application should not duplicate functionality already provided by PhotoKit or Vision.

---

# 2. Core Integration Principles

The Apple-framework layer follows these principles.

## 2.1 PhotoKit is the source of truth for photo assets

The app must not maintain its own copy of the user's photo library.

`PHAsset.localIdentifier` is stored as the reference to the original Photos asset.

PhotoKit manages both device-local assets and assets backed by iCloud Photos.

---

## 2.2 Analysis uses derived images, not originals

The selection engine usually does not require full-resolution images.

For most analysis operations:

```text
PHAsset
  ↓
PhotoKit request
  ↓
Downscaled working image
  ↓
Vision / quality analysis
  ↓
AnalysisResult
```

The original asset should only be requested when a feature specifically requires original image data.

This reduces:

- memory usage;
- image decoding cost;
- iCloud downloads;
- Vision processing time;
- thermal pressure.

---

## 2.3 Processing stays on-device

PhotoKit provides image data to the app.

Vision performs analysis locally.

The MVP must not upload photo pixels, face data, or Vision embeddings to a server.

Detailed privacy requirements are defined in:

```text
09_Privacy_and_Permissions.md
```

---

## 2.4 Apple APIs remain behind narrow service boundaries

Do not allow `PHAsset`, Vision requests, or Photos authorization APIs to leak throughout the SwiftUI application.

Use a small set of integration services:

```text
PhotoLibraryService
ImageLoadingService
VisionAnalysisService
AlbumExportService
```

Avoid creating dozens of one-method wrappers.

---

# 3. Framework Overview

| Framework | Purpose | MVP |
|---|---|---|
| Photos / PhotoKit | Library access and asset metadata | Required |
| PHCachingImageManager | Thumbnail and analysis image loading | Required |
| Vision | Face analysis and image similarity | Required |
| PhotosUI | Limited-library management / optional picker UI | As needed |
| CoreGraphics / ImageIO | Image orientation and lightweight image processing | Supporting |
| CoreLocation | Not required directly for PhotoKit metadata | No |
| Core ML | Custom model execution | Not required for MVP |
| CloudKit | Application cloud storage | Not required |
| AVFoundation | Video analysis | Not required for photo-only MVP |

---

# 4. High-Level Architecture

```text
                  SwiftUI
                     │
                     ▼
             Selection Workflow
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
PhotoLibraryService  │     AlbumExportService
        │            │
        ▼            │
    PhotoKit         │
        │            │
        ▼            ▼
    PHAsset     Selection Engine
        │            ▲
        ▼            │
ImageLoadingService  │
        │            │
        ▼            │
PHCachingImageManager
        │
        ▼
  Analysis Image
        │
        ▼
VisionAnalysisService
        │
        ▼
   Vision Framework
        │
        ▼
 PhotoAnalysis
```

The selection engine must consume application models rather than directly calling PhotoKit or Vision.

---

# 5. Photo Library Authorization

## 5.1 Required access level

The application should request:

```swift
PHPhotoLibrary.requestAuthorization(for: .readWrite)
```

rather than using the older authorization APIs.

The access-level-specific API is required to correctly distinguish limited photo-library access from full access. Apple specifically recommends `authorizationStatus(for:)` and `requestAuthorization(for:handler:)` for this purpose.

The app requires read access because it must analyze existing photos.

Write access is useful for creating a final curated album.

---

# 6. Supported Authorization States

The integration must explicitly handle every `PHAuthorizationStatus`.

```text
.notDetermined
.authorized
.limited
.denied
.restricted
```

Apple exposes limited access as a distinct authorization state.

Expected behavior:

| Status | Behavior |
|---|---|
| `.notDetermined` | Explain the need for access and request permission |
| `.authorized` | Continue normally |
| `.limited` | Process only accessible assets and expose "Manage Photos Access" |
| `.denied` | Show Settings guidance |
| `.restricted` | Explain that Photos access is unavailable |

---

# 7. When Permission Should Be Requested

Do not request Photos permission immediately on application launch.

Recommended flow:

```text
Launch
  ↓
Welcome / explanation
  ↓
User taps "Choose Photos" or "Start"
  ↓
Request Photos access
```

The app should explain why access is necessary before triggering the system permission dialog.

Example purpose:

> photos-curator needs access to your photos to analyze and select the best images. Photo analysis stays on this device.

Exact UX copy belongs in `02_UX_Flows.md` and privacy wording in `09_Privacy_and_Permissions.md`.

---

# 8. Info.plist Configuration

At minimum, provide:

```text
NSPhotoLibraryUsageDescription
```

If the application modifies the Photos library or creates albums, the configuration must also satisfy Apple's photo-library write-access requirements for the supported deployment target.

Permission descriptions must clearly describe the application's actual behavior.

Do not use generic wording such as:

```text
"We need Photos permission."
```

Prefer:

```text
"photos-curator analyzes your photos on this device to help you choose the best images from a trip or event."
```

---

# 9. Limited Photos Access

Limited Photos access must be considered a supported state, not an error.

When access is limited:

```text
Library
 ├── accessible asset
 ├── accessible asset
 ├── inaccessible asset
 └── inaccessible asset
```

The app sees only the assets the user has authorized.

The application must:

- analyze the available assets normally;
- indicate that access is limited;
- allow the user to continue without granting full access;
- provide a way to manage the selected set if the user wants to analyze more photos.

PhotoKit provides a limited-library management interface for updating the user's selected assets.

Full library access must never be presented as mandatory unless the requested workflow genuinely requires it.

---

# 10. PhotosPicker vs Direct PhotoKit Access

`photos-curator` should use direct PhotoKit access as its primary library integration.

A generic `PhotosPicker` is not the main ingestion mechanism.

The product needs to work with sets such as:

```text
Trip
Event
Date range
Album
Large batch of 1,000–5,000 photos
```

The selection engine also benefits from metadata and relationships between nearby assets.

Therefore:

```text
Primary:
PhotoKit → PHAsset

Optional:
PhotosPicker / PhotosUI → explicit user-selected subset
```

PhotosUI may still be useful for:

- managing limited-library access;
- manually selecting a specific subset;
- future lightweight workflows.

---

# 11. Fetching Photo Assets

The MVP should fetch image assets using PhotoKit.

Conceptually:

```swift
let options = PHFetchOptions()

let result = PHAsset.fetchAssets(
    with: .image,
    options: options
)
```

Filters should be applied as early as possible when the user specifies:

- an album;
- a date range;
- a trip;
- another constrained photo set.

PhotoKit supports filtering through `PHFetchOptions`, including predicates and sort descriptors.

---

# 12. Asset Metadata

Extract inexpensive metadata before requesting image pixels.

Useful fields include:

```text
localIdentifier
creationDate
pixelWidth
pixelHeight
mediaType
mediaSubtypes
favorite
hidden
location
burstIdentifier
```

PhotoKit exposes metadata such as creation date, dimensions, media type, subtype, favorite state, hidden state, and location directly on `PHAsset`.

This metadata should populate the application's asset model defined in:

```text
06_Data_Model.md
```

---

# 13. Asset Identifier

Use:

```swift
PHAsset.localIdentifier
```

as the reference connecting an application record to PhotoKit.

Conceptually:

```swift
struct PhotoAsset {
    let assetIdentifier: String
}
```

Later:

```swift
PHAsset.fetchAssets(
    withLocalIdentifiers: [assetIdentifier],
    options: nil
)
```

Do not persist the `PHAsset` object itself.

Do not copy full photo files into application storage merely to preserve asset references.

---

# 14. Missing Assets

A stored asset identifier may stop resolving because the user can:

- delete the photo;
- revoke access;
- change limited-library permissions;
- modify the Photos library from another device.

Therefore:

```text
Asset identifier exists in app database
        +
PhotoKit fetch returns nothing
        =
Asset unavailable
```

This is a normal state.

It must not crash the selection workflow.

Mark the application asset as unavailable or remove stale analysis data according to the persistence rules in `06_Data_Model.md`.

---

# 15. Hidden Photos

Hidden assets should not normally participate in automatic curation.

Recommended default:

```text
hidden == true
→ exclude from automatic selection
```

This avoids unexpectedly resurfacing photos that the user intentionally hid.

If future product requirements differ, this behavior may become configurable.

---

# 16. Screenshots

Screenshots can be identified using PhotoKit media subtype metadata.

Default selection behavior should usually exclude screenshots from travel/event curation unless explicitly included by the user.

This filtering belongs logically to the selection rules rather than PhotoKit itself.

PhotoKit's responsibility is only to expose the subtype.

---

# 17. Live Photos

A Live Photo is still represented as a Photos image asset with an appropriate subtype.

For the MVP:

```text
Live Photo
    ↓
Use still-image representation
    ↓
Run normal photo analysis
```

Do not process the motion component.

Do not request `PHLivePhoto` unless the UI explicitly needs Live Photo playback.

This avoids unnecessary memory and processing overhead.

---

# 18. RAW and Large Images

RAW images and high-resolution photographs must not automatically be decoded at full resolution.

For analysis:

```text
Original 48 MP image
        ↓
PhotoKit resize
        ↓
~1024–1600 px analysis representation
        ↓
Vision
```

Exact target sizes are performance tuning parameters and are defined in:

```text
08_Performance_Spec.md
```

---

# 19. Image Loading Service

Photo loading should be centralized.

Recommended interface:

```swift
protocol ImageLoadingService {
    func requestThumbnail(
        assetIdentifier: String,
        targetSize: CGSize
    ) async throws -> UIImage

    func requestAnalysisImage(
        assetIdentifier: String
    ) async throws -> CGImage
}
```

The exact return types can be adjusted during implementation.

The important architectural constraint is:

```text
Selection Engine
must not directly call
PHImageManager
```

---

# 20. PHCachingImageManager

Use one long-lived:

```swift
PHCachingImageManager
```

for thumbnail and analysis-image requests.

Apple specifically provides `PHCachingImageManager` for efficiently preloading image representations when many assets are being displayed or accessed.

Do not instantiate a new image manager for every photo.

Recommended ownership:

```text
ImageLoadingService
       │
       └── PHCachingImageManager
```

---

# 21. Two Image Sizes

Maintain two conceptual image classes.

## 21.1 UI thumbnails

Used for:

- grid;
- shortlist;
- review screen.

Example:

```text
200–500 px range
```

depending on display scale and UI layout.

---

## 21.2 Analysis image

Used for:

- Vision feature prints;
- face detection;
- sharpness heuristics;
- exposure heuristics;
- image-content analysis.

Recommended initial target:

```text
long edge ≈ 1024–1600 px
```

Exact values should be benchmarked.

Do not create separate cached versions for every algorithm unless measurements show a need.

---

# 22. Avoid Full-Resolution Requests

Do not normally use:

```swift
PHImageManagerMaximumSize
```

for the selection pipeline.

Apple defines this as a way to request the original or largest available image representation.

That behavior is unnecessary for most ranking operations.

Full-resolution decoding across 1,000–5,000 assets would cause excessive:

- memory pressure;
- decoding;
- iCloud transfer;
- processing time.

---

# 23. PHImageRequestOptions

Image requests should be asynchronous.

Conceptually:

```swift
let options = PHImageRequestOptions()
options.isSynchronous = false
```

`PHImageRequestOptions` controls delivery mode, resize mode, version, network access, and progress behavior.

Avoid synchronous image requests in production batch pipelines.

---

# 24. Delivery Modes

Different workloads can use different delivery behavior.

## Grid

Optimize for responsiveness:

```text
fast / opportunistic delivery
```

A low-resolution image arriving first is acceptable.

## Analysis

Prefer a deterministic final image representation.

The analysis pipeline must avoid accidentally analyzing an early degraded result returned by an opportunistic request.

The loader should only resume the analysis continuation when the requested usable representation is available.

---

# 25. Image Orientation

Vision analysis must receive the correct image orientation.

Orientation errors can cause:

- failed face detection;
- incorrect face rectangles;
- inconsistent feature prints;
- incorrect geometry calculations.

The image-loading layer should normalize the representation or explicitly provide the corresponding:

```swift
CGImagePropertyOrientation
```

to Vision.

Do not scatter orientation conversions across analysis algorithms.

---

# 26. iCloud Photos

PhotoKit represents local and iCloud-backed assets through the same `PHAsset` abstraction.

An asset can therefore exist in the user's library while its image data is not currently stored on the device.

The application must never assume:

```text
PHAsset exists
→ pixels are already local
```

---

# 27. Network Access for iCloud Assets

`PHImageRequestOptions.isNetworkAccessAllowed` controls whether PhotoKit can download required image data from iCloud.

When network access is disabled and the image is only in iCloud, PhotoKit reports that the requested content requires network access.

When network access is enabled, PhotoKit can download the asset and provide progress updates.

---

# 28. Recommended iCloud Strategy

Use a two-stage strategy.

## Stage A — discover assets

Fetching `PHAsset` metadata should remain lightweight.

Do not immediately download thousands of originals.

## Stage B — request analysis representation

When an asset enters the analysis queue:

```text
Request analysis-size image
    ↓
Available locally?
 ┌──┴──┐
Yes    No
 │      │
Analyze iCloud download if allowed
        │
        ▼
     Analyze
```

This means iCloud data is downloaded only as needed.

---

# 29. User Visibility During iCloud Downloads

If a meaningful number of assets requires iCloud downloads, the UI should expose that state.

Example:

```text
Preparing photos…

Analyzed 421 / 1,247
Downloading 18 photos from iCloud
```

Do not make an iCloud-backed photo appear to be an analysis failure merely because it is not currently downloaded.

---

# 30. iCloud Download Progress

For network-backed requests, use PhotoKit's progress callbacks where useful.

Apple exposes a `progressHandler` for image and asset-resource downloads from iCloud.

Do not produce a progress event for every individual byte.

Aggregate progress into the overall analysis workflow.

---

# 31. Network Failure

Possible outcomes include:

```text
asset available
asset unavailable
iCloud download pending
network unavailable
download failed
request cancelled
```

A single failed asset must not terminate the complete selection run.

Preferred behavior:

```text
1 asset fails
→ mark asset analysis unavailable
→ continue processing remaining assets
```

After the batch completes, the UI may report:

```text
1,238 analyzed
9 unavailable
```

---

# 32. Vision Integration

Vision provides the primary on-device computer-vision capabilities.

The MVP can use Vision for:

```text
image feature representations
face detection
face capture quality
optional face landmarks
optional image aesthetics
```

Do not introduce a custom Core ML model unless the native pipeline is shown to be insufficient during evaluation.

---

# 33. Stable Vision API Strategy

For the initial implementation, prefer Apple's established `VN*` request APIs where they satisfy the requirements.

Examples:

```swift
VNGenerateImageFeaturePrintRequest
VNDetectFaceRectanglesRequest
VNDetectFaceCaptureQualityRequest
VNDetectFaceLandmarksRequest
```

Newer Vision APIs may provide Swift-native request types, but adopting them is not required merely because they exist.

This keeps the minimum supported OS flexible and avoids coupling the MVP to beta or newly introduced APIs.

---

# 34. Vision Analysis Pipeline

One photo should conceptually produce:

```text
Analysis Image
      │
      ├── Feature Print
      ├── Face Detection
      ├── Face Quality
      ├── Optional Landmarks
      └── Quality Metrics
              │
              ▼
        PhotoAnalysis
```

Not every algorithm must run on every photo.

The selection engine can use staged analysis to reduce cost.

---

# 35. Feature Prints

Use:

```swift
VNGenerateImageFeaturePrintRequest
```

to produce a:

```swift
VNFeaturePrintObservation
```

Vision feature prints provide an image representation that can be compared with another feature print.

This is useful for:

- near-duplicate detection;
- burst similarity;
- visually similar photo clustering;
- moment-level candidate reduction.

---

# 36. Comparing Feature Prints

Vision provides:

```swift
computeDistance(...)
```

between feature-print observations.

Smaller distances indicate greater similarity.

Conceptually:

```text
Photo A feature print
        │
        ├── distance(A, B)
        │
Photo B feature print
```

The application must determine similarity thresholds empirically.

Do not hard-code an arbitrary threshold and assume it is universally correct.

Threshold tuning belongs to:

```text
03_Photo_Selection_Rules.md
10_Manual_QA_and_Selection_Evaluation.md
```

---

# 37. Duplicate Detection Strategy

Feature-print comparisons should not be performed against every photo in the entire library.

Naive comparison:

```text
5,000 × 5,000
```

is unnecessary.

First narrow candidates using inexpensive context:

```text
creation time
moment grouping
burst metadata
basic image dimensions
```

Then perform feature-print comparisons within candidate groups.

Example:

```text
Time-nearby photos
       ↓
Moment
       ↓
Feature-print distances
       ↓
Near-duplicate cluster
```

This belongs to the selection-engine implementation rather than the PhotoKit integration itself.

---

# 38. Face Detection

Use:

```swift
VNDetectFaceRectanglesRequest
```

for basic face detection.

Vision returns face observations containing detected face regions.

Store derived values such as:

```text
faceCount
faceBoundingBoxes
largestFaceAreaRatio
```

rather than storing source images.

---

# 39. Why Face Count Matters

Face detection enables rules such as:

```text
0 faces
→ landscape / object candidate

1 face
→ portrait candidate

2–4 faces
→ small group

5+ faces
→ group photo
```

These categories are heuristic inputs.

They are not semantic guarantees.

---

# 40. Face Capture Quality

Use:

```swift
VNDetectFaceCaptureQualityRequest
```

when ranking multiple similar photos containing faces.

Vision produces a face-quality value from `0` to `1`; higher values generally correspond to better-lit, sharper, and more centrally positioned face captures.

This is particularly useful for:

```text
same moment
+
same people
+
multiple shots
```

where the engine must select one or two representative images.

---

# 41. Group Photo Scoring

For group photos, do not simply maximize the highest individual face score.

Consider:

```text
number of expected faces
minimum face quality
average face quality
face size
face visibility
overall photo quality
```

Example conceptual score:

```text
groupFaceQuality =
    average(faceCaptureQuality)
    - severeLowQualityFacePenalty
```

Exact scoring belongs to the selection rules.

---

# 42. Face Landmarks

`VNDetectFaceLandmarksRequest` can detect facial features such as eyes and mouth.

Landmarks may eventually support:

- eye-state heuristics;
- face orientation;
- more advanced group-photo ranking.

However:

```text
Face landmarks are NOT required in the first implementation
unless they materially improve selection quality.
```

Start with:

```text
face rectangles
+
face capture quality
```

Add landmarks only after manual QA identifies a concrete failure mode.

---

# 43. Face Recognition

The MVP must not attempt to identify who a person is.

Do not implement:

```text
"This is Alice"
"This is Bob"
```

Do not create a persistent identity database.

Face detection is sufficient for initial selection rules.

This greatly reduces:

- privacy complexity;
- product complexity;
- persistence requirements.

Person-identity clustering may be considered in a later roadmap only if clearly justified.

---

# 44. Image Aesthetics

Recent Vision APIs include image-aesthetics scoring functionality. Apple documents an image-aesthetics request that produces an aesthetics-score observation.

Treat this as an optional accelerator rather than a hard dependency.

Architecture:

```text
if aesthetics API supported:
    use native aesthetics score

else:
    use existing quality heuristics
```

The selection engine must not fail on devices where the optional API is unavailable.

---

# 45. Do Not Let Aesthetic Score Become the Final Decision

Even when available:

```text
Aesthetic score ≠ final photo score
```

A technically beautiful photo may still be redundant.

A less aesthetic photo may be essential because it contains:

- an important person;
- a unique moment;
- a unique place;
- the only group photo;
- needed narrative diversity.

Therefore:

```text
FinalSelectionScore =
    quality
    + moment relevance
    + uniqueness
    + people value
    + diversity
    - duplicate penalty
```

Aesthetic quality is only one input.

---

# 46. Custom Image Quality Heuristics

Some quality metrics can be calculated without additional Apple ML models.

Examples:

```text
blur / sharpness
brightness
extreme underexposure
extreme overexposure
contrast
image dimensions
```

These should use the already decoded analysis image.

Avoid repeatedly decoding the same `PHAsset` for separate metrics.

---

# 47. One Decode, Multiple Analyses

Preferred:

```text
PHAsset
  ↓
decode once
  ↓
CGImage
  ├── Vision feature print
  ├── face analysis
  ├── sharpness
  └── exposure
```

Avoid:

```text
PHAsset → decode → feature print
PHAsset → decode → faces
PHAsset → decode → sharpness
PHAsset → decode → exposure
```

The analysis pipeline should reuse the working image while that asset is being processed.

---

# 48. Memory Lifetime

The analysis image should have a short lifetime.

Conceptually:

```swift
for asset in batch {
    autoreleasepool {
        let image = loadAnalysisImage(asset)

        analyze(image)

        persistSmallAnalysisResult()

        // image released
    }
}
```

Exact concurrency and memory limits are defined in:

```text
08_Performance_Spec.md
```

Do not keep hundreds of decoded `UIImage` or `CGImage` objects alive.

---

# 49. Persisted Analysis

Persist small derived results where useful.

Examples:

```text
assetIdentifier
analysisVersion
faceCount
faceQualitySummary
featurePrint
sharpnessScore
exposureScore
aestheticScore?
analysisTimestamp
```

Do not persist:

```text
full decoded images
face crops
full-resolution copies
```

unless explicitly required by a future feature.

---

# 50. Analysis Versioning

Vision algorithms and application scoring logic may change.

Cached analysis therefore requires a version.

Example:

```text
analysisVersion = 1
```

When an incompatible algorithm change occurs:

```text
analysisVersion = 2
```

Old analysis can then be invalidated and recomputed.

Do not attempt field-by-field migration of ephemeral AI analysis when recomputation is cheaper and safer.

---

# 51. Vision Request Revision

Where reproducibility matters, avoid silently mixing incompatible Vision behavior within one analysis run.

If a specific Vision request revision is explicitly selected, store enough analysis version information to identify that decision.

However, do not build a complex Vision-revision management framework in the MVP.

Application-level `analysisVersion` is sufficient initially.

---

# 52. Caching Strategy

The application has three distinct cache concepts.

```text
1. PhotoKit image cache
2. decoded-image lifetime
3. persisted analysis cache
```

They must not be confused.

---

# 53. PhotoKit Cache

Managed through:

```swift
PHCachingImageManager
```

Useful primarily for:

- photo grid;
- shortlist grid;
- review UI;
- near-future batch assets.

Apple recommends preheating images likely to be needed soon with `startCachingImages`.

---

# 54. UI Cache Preheating

When the user scrolls through a photo grid:

```text
Visible assets
       +
Assets slightly ahead
       ↓
startCachingImages
```

When assets are far behind the viewport:

```text
stopCachingImages
```

Do not preheat thousands of thumbnails at once.

---

# 55. Analysis Cache

Persist analysis outputs so repeatedly opening the same trip does not necessarily rerun Vision for every unchanged photo.

Cache key concept:

```text
assetIdentifier
+
analysisVersion
+
relevant asset state
```

If no meaningful input changed:

```text
reuse analysis
```

Otherwise:

```text
reanalyze
```

---

# 56. Do Not Build a Custom Disk Image Cache

The MVP should not implement its own general-purpose image disk cache.

PhotoKit already owns the image source.

Persisting another image cache would add:

- storage usage;
- invalidation complexity;
- privacy concerns;
- duplicate data.

Persist compact analysis results instead.

---

# 57. Cancellation

All long-running image requests and analysis tasks must support cancellation.

`PHImageManager` returns request identifiers that can be passed to `cancelImageRequest(_:)`.

Swift task cancellation should propagate into the PhotoKit request layer where possible.

Conceptually:

```text
Swift Task cancelled
        ↓
cancel PHImageRequestID
        ↓
discard image result
        ↓
stop Vision work
```

---

# 58. Async PhotoKit Wrapper

PhotoKit callback APIs may be wrapped with Swift concurrency.

Conceptual example:

```swift
func requestImage(
    for asset: PHAsset,
    targetSize: CGSize
) async throws -> UIImage
```

Internally:

```text
withCheckedThrowingContinuation
        +
withTaskCancellationHandler
```

Care must be taken because some PhotoKit delivery modes can invoke a result handler more than once.

The continuation must resume exactly once.

---

# 59. Avoid Synchronous PhotoKit Requests

Do not use:

```swift
options.isSynchronous = true
```

inside the main analysis pipeline.

Synchronous image loading can unnecessarily block executors or threads, particularly when iCloud access is involved.

The app should treat image delivery as asynchronous.

---

# 60. Batch Concurrency

Do not launch one unrestricted task per photo.

Bad:

```swift
for photo in 5000Photos {
    Task {
        analyze(photo)
    }
}
```

This can create:

- memory spikes;
- concurrent iCloud downloads;
- thermal pressure;
- excessive Vision workloads.

Use bounded concurrency.

The exact number of concurrent analysis operations is specified and benchmarked in:

```text
08_Performance_Spec.md
```

---

# 61. Photo Library Changes

The user may modify Photos while `photos-curator` is running.

PhotoKit provides:

```swift
PHPhotoLibraryChangeObserver
```

and can notify registered observers when fetched assets or collections change.

The MVP should respond conservatively.

---

# 62. Change Observer Scope

Register one centralized Photos-library observer rather than an observer for every screen.

Recommended:

```text
PhotoLibraryService
        │
implements
PHPhotoLibraryChangeObserver
```

On relevant changes:

```text
invalidate affected fetch
        ↓
refresh asset references
        ↓
notify current workflow
```

Do not immediately rerun the complete selection pipeline after every minor Photos change.

---

# 63. Changes During Analysis

If a photo disappears during analysis:

```text
request fails
→ mark asset unavailable
→ continue
```

If many library changes occur:

```text
finish or cancel current job according to workflow state
→ refresh asset set
```

The selection engine must tolerate stale identifiers.

---

# 64. Creating the Final Curated Album

The MVP may create a Photos album after the user approves the final selection.

Example:

```text
photos-curator — Japan 2026
```

Use PhotoKit change requests.

PhotoKit exposes `PHAssetCollectionChangeRequest` for creating and modifying user albums and `PHPhotoLibrary.performChanges` for applying changes.

---

# 65. Album Export Flow

Recommended workflow:

```text
Final selection
      ↓
User taps "Create Album"
      ↓
Check Photos authorization
      ↓
Create or resolve album
      ↓
Add selected PHAssets
      ↓
PhotoKit completion
      ↓
Show success/error
```

Do not automatically modify the Photos library before explicit user action.

---

# 66. Non-Destructive Behavior

The application must not automatically:

```text
delete rejected photos
hide rejected photos
edit originals
change favorites
change metadata
```

The selection result is advisory.

For the MVP, the only Photos write operation should normally be:

```text
create curated album
and/or
add selected assets to that album
```

Original assets remain untouched.

---

# 67. Duplicate Assets in Albums

Creating a curated album does not require copying image files.

Albums contain references to assets already in the Photos library.

This is the desired behavior.

Do not export and reimport images merely to create a curated album.

---

# 68. Error Model

Apple-framework errors should be translated into application-level errors.

Example:

```swift
enum PhotoLibraryError: Error {
    case permissionDenied
    case permissionRestricted
    case assetUnavailable
    case iCloudDownloadFailed
    case requestCancelled
    case imageDecodeFailed
    case albumCreationFailed
}
```

Avoid exposing raw `NSError` messages directly to users.

Raw errors may still be recorded in local diagnostic logs.

---

# 69. Retry Strategy

Retry only errors that have a reasonable chance of succeeding.

Examples:

```text
temporary iCloud/network failure
→ may retry

permission denied
→ do not retry automatically

asset deleted
→ do not retry

task cancelled
→ do not retry
```

Do not build a generalized exponential-backoff framework for the MVP.

A small retry policy around iCloud-backed loading is sufficient.

---

# 70. Analysis Failure Policy

A photo-analysis failure should not normally fail the entire job.

Example:

```text
Photo 421
Vision face request fails
```

Possible response:

```text
faceCount = unknown
other metrics remain available
continue selection
```

The engine should distinguish:

```text
zero faces
```

from:

```text
face analysis unavailable
```

These are not equivalent.

---

# 71. Dependency Direction

The architecture must preserve:

```text
SwiftUI
   ↓
Application / Selection Engine
   ↓
Protocols / Services
   ↓
Apple Framework Integration
   ↓
PhotoKit / Vision
```

Never:

```text
Selection scoring rule
↓
direct PHImageManager call
```

and never:

```text
SwiftUI view
↓
VNDetectFaceRectanglesRequest
```

This keeps product logic testable manually and understandable even though the project intentionally does not include automated test targets.

---

# 72. Recommended Integration Types

Keep the concrete implementation small.

Suggested structure:

```text
Services/
├── PhotoLibraryService.swift
├── ImageLoadingService.swift
├── VisionAnalysisService.swift
└── AlbumExportService.swift
```

Possible supporting files:

```text
AppleIntegration/
├── PhotoKitAsync.swift
├── ImageOrientation.swift
└── VisionResultMapper.swift
```

Only create supporting files when they remove real duplication.

Do not create:

```text
PhotoKitManagerFactory
VisionRequestFactory
VisionRequestRepository
PhotoFrameworkCoordinatorFactory
```

unless future requirements genuinely justify them.

---

# 73. PhotoLibraryService Responsibilities

`PhotoLibraryService` should own:

```text
authorization state
authorization request
PHAsset fetching
asset metadata mapping
limited-access handling
Photos change observation
```

It should not own:

```text
Vision analysis
selection scoring
duplicate clustering
```

---

# 74. ImageLoadingService Responsibilities

`ImageLoadingService` should own:

```text
PHCachingImageManager
thumbnail requests
analysis image requests
iCloud-backed loading
request cancellation
orientation normalization
```

It should not own:

```text
photo ranking
duplicate decisions
moment grouping
```

---

# 75. VisionAnalysisService Responsibilities

`VisionAnalysisService` should own:

```text
feature print generation
face rectangle detection
face quality
optional landmarks
optional aesthetics request
mapping Vision observations to application data
```

It should not know about:

```text
Photos albums
SwiftUI
final photo selection
```

---

# 76. AlbumExportService Responsibilities

`AlbumExportService` should own:

```text
creating an album
finding an existing target album when appropriate
adding PHAssets to an album
mapping PhotoKit write errors
```

It should not create duplicate copies of images.

---

# 77. Suggested Analysis Interface

Conceptually:

```swift
protocol VisionAnalysisService {
    func analyze(
        image: CGImage,
        orientation: CGImagePropertyOrientation
    ) async throws -> PhotoAnalysis
}
```

`PhotoAnalysis` should be an application model defined in:

```text
06_Data_Model.md
```

It must not contain raw Vision request objects.

---

# 78. Partial Analysis

Where useful, the service may expose staged methods:

```swift
generateFeaturePrint(...)
detectFaces(...)
calculateFaceQuality(...)
calculateImageQuality(...)
```

However, avoid exposing excessive internal implementation detail merely for architectural purity.

Prefer one main analysis entry point unless the selection engine has a concrete need for staged execution.

---

# 79. Data That May Be Persisted

Acceptable:

```text
PHAsset local identifier
metadata
scalar quality scores
face count
normalized face rectangles
Vision feature-print representation
selection decisions
analysis version
```

---

# 80. Data That Should Not Be Persisted by Default

Avoid:

```text
full-resolution photos
decoded UIImage objects
CGImage objects
face crop images
temporary iCloud download files
Photos authentication state snapshots
```

PhotoKit remains responsible for the original media.

---

# 81. Feature Print Persistence

Feature prints may be persisted if measurements show that regeneration significantly affects performance.

Benefits:

```text
faster reopening
faster reclustering
faster threshold tuning
```

Cost:

```text
additional database size
Vision revision compatibility concerns
```

MVP decision:

```text
Persist feature prints if required by the selection-engine cache design.
Do not create a separate vector database.
```

The dataset size does not justify specialized vector infrastructure.

---

# 82. Request Priorities

The system should conceptually distinguish:

```text
User-visible request
Background analysis request
Prefetch request
```

Priority order:

```text
visible UI
>
currently analyzed photo
>
near-future analysis
>
speculative prefetch
```

Do not let background analysis make the review grid unresponsive.

---

# 83. Thermal and Memory Pressure

The Apple-framework integration must allow the higher-level processing pipeline to reduce work when needed.

Potential actions:

```text
reduce analysis concurrency
stop preheating
release decoded images
pause optional analysis
```

Do not permanently retain PhotoKit image results.

Detailed thresholds belong in `08_Performance_Spec.md`.

---

# 84. App Interruption

The pipeline must tolerate:

```text
app moves to background
screen locks
incoming call
task cancellation
memory warning
app termination
```

The system must not depend on all 1,000 photos remaining decoded or all intermediate state remaining in memory.

Completed analysis should be persisted incrementally.

Example:

```text
0–99 analyzed
→ persisted

100–199 analyzed
→ persisted

app terminated

relaunch
→ reuse completed analysis
→ continue remaining assets
```

Exact resume behavior belongs in the performance specification.

---

# 85. Do Not Assume Background Execution

The application must not assume iOS will allow several minutes of uninterrupted Vision processing after entering the background.

The primary execution model should be:

```text
user starts curation
+
app remains active
+
progress is visible
```

Resumability is more important than attempting to keep the process permanently alive in the background.

---

# 86. Privacy Boundary for Face Data

Vision face detection results are application-derived data.

The MVP must use them strictly for local photo selection.

Do not:

```text
upload face observations
store identity labels
share face embeddings
use them for advertising
```

Detailed policy is defined in:

```text
09_Privacy_and_Permissions.md
```

---

# 87. Logging

Do not log:

```text
photo binary data
face images
full filesystem image paths
raw feature-print contents
precise location metadata
```

Diagnostic logs may contain:

```text
asset hash / redacted identifier
request type
duration
success/failure
image target size
iCloud-required state
Vision error category
```

The logger must not become another photo-data store.

---

# 88. Performance Instrumentation

Measure Apple-framework operations separately.

Useful measurements:

```text
PhotoKit fetch duration
thumbnail request duration
analysis image request duration
iCloud wait duration
Vision feature-print duration
face-analysis duration
cache hit/miss
analysis failure count
```

These metrics can later inform:

```text
08_Performance_Spec.md
11_Analytics_and_Metrics.md
```

User analytics must not contain photo contents.

---

# 89. Recommended Processing Flow

Complete asset integration:

```text
1. User selects source
        ↓
2. Check Photos authorization
        ↓
3. Fetch PHAssets
        ↓
4. Map metadata → PhotoAsset
        ↓
5. Create moment candidates
        ↓
6. Request analysis-size image
        ↓
7. Download from iCloud if necessary
        ↓
8. Run Vision / quality analysis
        ↓
9. Persist PhotoAnalysis
        ↓
10. Release decoded image
        ↓
11. Selection engine ranks candidates
        ↓
12. UI requests thumbnails for finalists
        ↓
13. User reviews result
        ↓
14. Optional Photos album creation
```

---

# 90. Example Per-Asset Flow

```text
PHAsset
  │
  ├── localIdentifier
  ├── creationDate
  ├── dimensions
  └── metadata
       │
       ▼
PhotoAsset
       │
       ▼
requestImage(
    target ≈ analysis size
)
       │
       ├──── local image
       │
       └──── iCloud → download
                    │
                    ▼
                  CGImage
                    │
       ┌────────────┼─────────────┐
       ▼            ▼             ▼
 Feature Print   Face Analysis   Quality
       │            │             │
       └────────────┼─────────────┘
                    ▼
              PhotoAnalysis
                    │
                    ▼
               Persist
                    │
                    ▼
             Release CGImage
```

---

# 91. MVP Framework Decisions

The MVP intentionally chooses:

```text
PhotoKit
    instead of custom photo-file import

PHCachingImageManager
    instead of custom image caching

Vision
    instead of custom ML models

VNFeaturePrintObservation
    instead of custom embedding infrastructure

Vision face detection
    instead of custom face models

Local persistence
    instead of cloud AI processing
```

These choices significantly reduce implementation complexity while preserving the core product value.

---

# 92. Explicit Non-Goals

The Apple-framework layer does not implement:

```text
photo backup
cloud photo storage
custom Photos replacement
photo editing
RAW development
video curation
face identity recognition
person naming
custom neural-network training
server-side image analysis
custom photo synchronization
automatic deletion of rejected photos
custom general-purpose image cache
```

---

# 93. Implementation Order

Recommended order:

## Phase 1 — PhotoKit foundation

Implement:

```text
authorization
asset fetching
metadata mapping
thumbnail loading
```

Exit criterion:

> The app can show a user-selected set of Photos assets reliably.

---

## Phase 2 — Analysis image loading

Implement:

```text
analysis-size image requests
orientation handling
iCloud download support
cancellation
```

Exit criterion:

> The app can obtain a usable analysis image for local and iCloud-backed assets.

---

## Phase 3 — Core Vision

Implement:

```text
feature print
face rectangles
face capture quality
basic quality heuristics
```

Exit criterion:

> Each photo can generate the minimum `PhotoAnalysis` required by the selection engine.

---

## Phase 4 — Batch integration

Connect:

```text
PhotoKit
→ bounded analysis queue
→ Vision
→ persisted analysis
→ selection engine
```

Exit criterion:

> A large photo set can be processed without uncontrolled memory growth.

---

## Phase 5 — Review caching

Implement:

```text
PHCachingImageManager preheating
thumbnail cancellation
review-grid optimization
```

Exit criterion:

> Review and shortlist UI scroll smoothly.

---

## Phase 6 — Album export

Implement:

```text
create album
add selected PHAssets
handle write errors
```

Exit criterion:

> User can explicitly save the approved curation as a Photos album.

---

# 94. Acceptance Criteria

The Apple framework integration is MVP-ready when all of the following are true.

### Permissions

- App correctly handles `.authorized`.
- App correctly handles `.limited`.
- App correctly handles `.denied`.
- App correctly handles `.restricted`.
- Permission is requested in context rather than automatically at launch.

### PhotoKit

- Image assets can be fetched.
- `PHAsset.localIdentifier` maps reliably to application assets.
- Missing/deleted assets do not crash the application.
- Live Photos can be treated as still images.
- Hidden assets follow product filtering rules.

### iCloud

- iCloud-only photos can be detected through request behavior.
- Required analysis representations can be downloaded.
- Progress can be surfaced to the processing UI.
- Network failure does not terminate the complete batch.

### Loading

- Thumbnails use `PHCachingImageManager`.
- Analysis does not routinely request full-resolution originals.
- Requests can be cancelled.
- Decoded images are released after analysis.

### Vision

- Feature prints can be generated.
- Feature-print distances can be compared.
- Faces can be detected.
- Face capture quality can be extracted when available.
- Vision failures can degrade gracefully.
- Vision objects do not leak into UI or selection-domain models.

### Persistence

- Completed analysis can be reused.
- Analysis results have a version.
- Full photo pixels are not persisted by the app.

### Output

- User can review selected assets.
- User can optionally create a curated Photos album.
- Original photos remain unchanged.

---

# 95. Manual Validation Scenarios

These scenarios must later be included in detail in:

```text
10_Manual_QA_and_Selection_Evaluation.md
```

At minimum test:

```text
100 local photos
1,000 local photos
5,000 photos

library with iCloud Optimize Storage enabled
offline device
slow network

full Photos access
limited Photos access
permission denied

Live Photos
screenshots
RAW photos
bursts
large group photos
duplicate shots

photo deleted during processing
permission changed during processing
app interrupted during processing
```

No automated unit-test or UI-test targets are required for this project.

---

# 96. Key Engineering Rules

These rules should be treated as implementation constraints.

```text
RULE 1
Never analyze full-resolution images unless specifically required.

RULE 2
Never keep large batches of decoded images in memory.

RULE 3
Never assume every PHAsset is stored locally.

RULE 4
Never assume a stored PHAsset identifier will remain valid forever.

RULE 5
Never treat limited Photos permission as an application error.

RULE 6
Never upload photo or face data in the MVP.

RULE 7
Never let Vision objects become domain models.

RULE 8
Never compare every feature print against every other photo
when moment-based candidate reduction is possible.

RULE 9
Never automatically modify or delete original photos.

RULE 10
Prefer Apple's existing PhotoKit and Vision capabilities
before introducing custom infrastructure.
```

---

# 97. Final Integration Boundary

The intended boundary is:

```text
                photos-curator
                     │
                     ▼
              Domain Models
                     │
                     ▼
              App Services
          ┌──────────┴──────────┐
          ▼                     ▼
      PhotoKit                Vision
          │                     │
          ▼                     ▼
 User Photo Library      On-device Analysis
```

PhotoKit answers:

> "What photos are available, and how can I obtain their image representations?"

Vision answers:

> "What useful visual information can I derive from this image?"

The selection engine answers:

> "Given all of this information, which photos should the user keep?"

These responsibilities must remain separate.

---

# 98. Summary of MVP APIs

Primary PhotoKit APIs:

```swift
PHPhotoLibrary
PHAuthorizationStatus
PHAccessLevel

PHAsset
PHFetchOptions

PHImageManager
PHCachingImageManager
PHImageRequestOptions

PHPhotoLibraryChangeObserver

PHAssetCollection
PHAssetCollectionChangeRequest
```

Primary Vision APIs:

```swift
VNGenerateImageFeaturePrintRequest
VNFeaturePrintObservation

VNDetectFaceRectanglesRequest
VNFaceObservation

VNDetectFaceCaptureQualityRequest

VNDetectFaceLandmarksRequest // optional
```

Optional newer capability:

```text
Vision image aesthetics scoring
```

Supporting system types:

```swift
CGImage
CGImagePropertyOrientation
UIImage
```

No additional third-party image or AI framework is required for the MVP.

---

# 99. References

Implementation should be checked against the current Apple Developer Documentation for:

- PhotoKit
- `PHPhotoLibrary`
- `PHAuthorizationStatus`
- `PHCachingImageManager`
- `PHImageManager`
- `PHImageRequestOptions`
- `PHPhotoLibraryChangeObserver`
- `PHAssetCollectionChangeRequest`
- Vision
- `VNGenerateImageFeaturePrintRequest`
- `VNFeaturePrintObservation`
- `VNDetectFaceRectanglesRequest`
- `VNDetectFaceCaptureQualityRequest`
- `VNDetectFaceLandmarksRequest`

The API assumptions in this specification were validated against Apple's current documentation. PhotoKit supports local and iCloud-backed Photos assets, limited authorization, caching image managers, cancellable image requests, Photos-library change observation, and album modifications. Vision provides feature-print similarity and face-analysis requests used by the proposed selection pipeline.

---

# 100. Final Decision

For the `photos-curator` MVP:

```text
PhotoKit
    = asset source and library integration

PHCachingImageManager
    = image delivery and transient caching

Vision
    = on-device visual analysis

Application database
    = metadata + compact derived analysis

Selection Engine
    = ranking, clustering, diversity, and final decisions
```

No third-party photo SDK, cloud-image pipeline, custom face model, custom embedding model, or custom image-cache infrastructure is required.

This is sufficient to build the initial 1,000–5,000-photo curation pipeline while keeping the architecture small and compatible with later improvements.