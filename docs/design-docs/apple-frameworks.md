# Apple Framework Integration (PhotoKit/Vision use only)

**Doc:** `apple-frameworks.md` (native filename kept)
**Status:** MVP specification
**Role:** Single owner of how the app calls PhotoKit and Vision. Other docs link here. This doc does not copy them.

**Ownership:**
This doc owns auth API states, fetch and metadata mapping, `localIdentifier` plus missing-asset handling, `PHCachingImageManager` sizes and caching, iCloud 2-stage fetch plus progress, Vision `VN*` pipeline, memory and preheat, cancellation and async, change observer, export `performChanges`, error mapping and retry.

This doc does not own selection policy, duplicate strategy, face buckets, aesthetics scoring (03), UX permission copy (02), privacy policy (09), or perf budgets (08). Where those topics appear below, this file states the API fact; the linked file states the rule.

**Incoming links:** 04, 05, 06 link here for API use. They do not restate it.
**Outgoing links:** This doc links to 02, 03, 04, 06, 08, 09, 10. It does not copy their content.

Related docs:

- `ux-flows.md` — permission screens and copy
- `selection-rules.md` — duplicate strategy, face buckets, scoring policy
- `selection-engine.md` — analysis size, pipeline order, concurrency numbers
- `data-model.md` — stored asset and analysis shape
- `performance.md` — budgets, concurrency, resume
- `privacy.md` — privacy rules, retention, redaction
- `manual-qa.md` — QA procedure

---

## 1. Invariants

Only this section uses requirement keywords. All other sections use plain verbs.

- The app MUST keep `PHAsset` objects behind services; SwiftUI and scoring code MUST NOT call PhotoKit or Vision directly.
- The app treats limited library access as a valid state, not an error.
- The app treats a missing asset identifier as a normal state; it does not crash.
- The app MUST NOT analyze full-resolution originals unless a feature needs original pixels.
- The app supports cancellation of image requests and analysis tasks.
- The app MUST NOT upload photo pixels, face data, or embeddings to app servers.
- The app MUST NOT delete, edit, hide, or favorite originals; the only write is a user-approved album.
- The app MUST release decoded images after analysis; it MUST NOT hold large batches in memory.
- The app MUST NOT persist face boxes, precise location, or feature-print blobs beyond bounded temp working memory.

---

## 2. Framework map

| Framework | Use | MVP |
|---|---|---|
| Photos / PhotoKit | Library access, asset fetch, metadata, album export | Required |
| `PHCachingImageManager` | Thumbs and analysis-image delivery, preheat | Required |
| Vision | Feature prints, face rects, face quality, optional landmarks/aesthetics | Required |
| PhotosUI | Limited-library manager, optional picker for small subsets | As needed |
| CoreGraphics / ImageIO | Orientation, light decode work | Supporting |
| Core ML | Custom models | Not for MVP |
| CloudKit | App cloud storage | Not for MVP |
| AVFoundation | Video work | Not for MVP (photo-only) |

Primary path is direct PhotoKit access. `PhotosPicker` is optional for small explicit subsets only. Large sets (trip, event, date range, album, 100–2,000 photos) need `PHAsset` fetch plus metadata, which a picker alone does not give.

Minimum deployment target is iOS 26 (see [decision-log DEC-TBD-001](decision-log.md)).

Service boundary:

```text
SwiftUI -> Selection Workflow -> Services -> PhotoKit / Vision
```

| Service | Owns | Must not own |
|---|---|---|
| `PhotoLibraryService` | Auth state, fetch, metadata map, limited-access handling, change observer | Vision, scoring, clustering |
| `ImageLoadingService` | `PHCachingImageManager`, thumbs, analysis images, iCloud load, cancel, orientation | Ranking, duplicates, moments |
| `VisionAnalysisService` | Feature prints, face rects, face quality, optional landmarks/aesthetics, map to app data | Albums, SwiftUI, final picks |
| `AlbumExportService` | Create/find album, add assets, map write errors | Image copies |

Suggested files: `Services/` with the four services above, plus small helpers (`PhotoKitAsync.swift`, `ImageOrientation.swift`, `VisionResultMapper.swift`) only when they remove real duplication.

---

## 3. Authorization API

Request read-write access. Read is needed to analyze. Write is needed to save the final album.

```swift
PHPhotoLibrary.requestAuthorization(for: .readWrite)
```

Use the access-level APIs (`authorizationStatus(for:)`, `requestAuthorization(for:handler:)`). They separate limited from full access. Older level-blind calls hide that difference.

`Info.plist` key: `NSPhotoLibraryUsageDescription`. Text must state true behavior. Exact wording policy and timing rules: [09](../ship-gates/privacy.md). Screen copy and pre-prompt flow: [02](../product-specs/ux-flows.md).

Ask in context (user taps Start or Select Photos), never at launch. Show a short true note first, then the system prompt.

### 3.1 Auth states

Canonical state meanings live in [09](../ship-gates/privacy.md). This table states API handling only.

| Status | API handling |
|---|---|
| `.notDetermined` | Explain, then call `requestAuthorization(for: .readWrite)` once |
| `.authorized` | Run normally |
| `.limited` | Run on the fetchable set; expose the system manage-access sheet (`PhotosUI`) |
| `.denied` | Stop; point to Settings; do not loop prompts |
| `.restricted` | Stop; plain note; no retry loop |
| Future value | Fail safe; keep app stable |

Re-check status on each run. Users can change it in Settings.

---

## 4. Fetch and metadata

Fetch image assets with `PHFetchOptions`. Apply user filters (album, date range, trip) in the fetch, not after decoding.

```swift
let options = PHFetchOptions()
let result = PHAsset.fetchAssets(with: .image, options: options)
```

### 4.1 Metadata map

Read cheap `PHAsset` fields before asking for pixels. Map them to the app model in [06](data-model.md).

| `PHAsset` field | Use |
|---|---|
| `localIdentifier` | App key to the asset (§5) |
| `creationDate` | Time grouping input for 03/04 |
| `pixelWidth`, `pixelHeight` | Size checks, request sizing |
| `mediaType`, `mediaSubtypes` | Filter video, screenshot, Live, RAW paths (§4.2) |
| `isFavorite` | Soft bonus input owned by 03 |
| `isHidden` | Excluded by default (§4.2) |
| `location` | Optional context only; never required; privacy limit in 09 |
| `burstIdentifier` | Burst group input for 03 |

### 4.2 Subtype handling (API facts only)

Policy (exclude or keep) is owned by [03](../product-specs/selection-rules.md). This doc states only what PhotoKit exposes.

| Class | PhotoKit fact | Loader action |
|---|---|---|
| Hidden | `isHidden == true` | Excluded from auto fetch by default |
| Screenshot | Media subtype flag | Exposed to 03; no special decode |
| Live Photo | Image asset with Live subtype | Use still image; do not request `PHLivePhoto` unless UI needs playback |
| RAW / large | Large pixel dims, RAW subtype | Never auto-decode full resolution; request analysis size (§6) |
| Video | `mediaType != .image` | Out of scope for photo-only MVP |

---

## 5. Identifiers and missing assets

Store `localIdentifier`. Do not store `PHAsset` objects. Do not copy full files to keep a reference.

```swift
struct PhotoAsset { let assetIdentifier: String }
PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
```

A stored ID can stop resolving. Causes: user deleted the photo, revoked access, changed limited set, or edited the library on another device.

```text
stored ID + empty fetch = unavailable (normal, not a crash)
```

On miss: mark unavailable per [06](data-model.md), drop or skip its analysis, and continue the batch. If it disappears mid-analysis, fail that asset only and continue. Full change handling: §10.

---

## 6. Image loading

Central rule: the selection engine never calls `PHImageManager` directly. All loads go through `ImageLoadingService`.

```swift
protocol ImageLoadingService {
    func requestThumbnail(assetIdentifier: String, targetSize: CGSize) async throws -> UIImage
    func requestAnalysisImage(assetIdentifier: String) async throws -> CGImage
}
```

### 6.1 Manager and sizes

Use one long-lived `PHCachingImageManager` owned by `ImageLoadingService`. Do not create one per photo. It handles grid display, shortlist, review UI, and near-future batch preheat.

| Image class | Size | Notes |
|---|---|---|
| UI thumb | 200–500 px | Grid, shortlist, review; depends on layout and scale |
| Analysis image | Default 512 px long edge | Owned by 04; 07 states API limits only |
| Full resolution (`PHImageManagerMaximumSize`) | Original pixels | Not for the selection path; only when a feature needs original data |

Why the split: thumbs serve the screen; analysis images serve Vision. One cached variant per class is enough unless benchmarks prove otherwise. Exact analysis size, batch counts, and time budgets: [04](selection-engine.md) and [08](../ship-gates/performance.md).

### 6.2 Request options

| Setting | Rule |
|---|---|
| `isSynchronous = false` | Always async in batch paths |
| Grid delivery | Fast/opportunistic is fine; low-res first is acceptable |
| Analysis delivery | Deterministic final image only; never analyze an early degraded frame |
| `resizeMode` | Fast for thumbs; exact-ish for analysis per 04 |
| Orientation | Loader normalizes or passes `CGImagePropertyOrientation` to Vision; no scattered conversions |

### 6.3 Memory and preheat

Decode once per asset, fan out to all analyses, then release:

```text
PHAsset -> decode once -> CGImage -> feature print + faces + sharpness + exposure -> persist small result -> release
```

| Cache | Owner | Rule |
|---|---|---|
| PhotoKit image cache | `PHCachingImageManager` | Preheat visible plus slightly-ahead assets with `startCachingImages`; `stopCachingImages` for far-behind; never preheat thousands at once |
| Decoded image | Per-asset scope (`autoreleasepool`) | Short life; never hold hundreds of `UIImage`/`CGImage` |
| Persisted analysis | App store per 06 | Small fields plus version; reuse when inputs unchanged; face boxes, precise location, and feature-print blobs stay in bounded temp working memory only, see 09; never full images, crops, or blobs |

Priority order: visible UI, then current asset, then near-future analysis, then speculative prefetch. Background work never starves the review grid. On pressure: cut concurrency, stop preheat, release images, pause optional Vision steps. Thresholds: [08](../ship-gates/performance.md). Do not build a custom disk image cache; PhotoKit owns the pixels.

---

## 7. iCloud Photos

Same `PHAsset` abstraction covers local and iCloud-backed assets. Never assume pixels are local.

`PHImageRequestOptions.isNetworkAccessAllowed` controls whether PhotoKit may download. When off and bytes are remote, the request reports network-needed. When on, PhotoKit downloads and reports progress.

### 7.1 Two-stage fetch

| Stage | Action |
|---|---|
| A — discover | Fetch `PHAsset` metadata only; do not download thousands of originals |
| B — analyze | When an asset enters the queue, request analysis size; download only if needed |

```text
request analysis image -> local? analyze : download if allowed -> analyze
```

### 7.2 Progress and failure

Surface aggregate state, not per-byte events. Use `progressHandler` and roll it into overall progress. Example UI state: `Analyzed 421 / 1,247 — Downloading 18 from iCloud`. Exact copy: 02. Never label a pending download as an analysis failure.

| Outcome | Handling |
|---|---|
| Available | Analyze |
| Pending download | Wait with progress |
| Network off / failed | Mark asset unavailable; continue batch; report counts (`1,238 analyzed, 9 unavailable`) |
| Cancelled | Drop result; stop Vision work |

Retry only transient network failures with a small retry around iCloud loads. No general backoff framework for MVP (§11).

---

## 8. Vision pipeline

Vision runs on device on the analysis image. No custom Core ML model unless native requests prove insufficient.

| Request | Output | Use |
|---|---|---|
| `VNGenerateImageFeaturePrintRequest` | `VNFeaturePrintObservation` | Similarity input for duplicate logic owned by 03 |
| `VNDetectFaceRectanglesRequest` | `VNFaceObservation` list | Face count, boxes, largest-face ratio |
| `VNDetectFaceCaptureQualityRequest` | Score 0–1 per face | Best-frame choice among similar faces, owned by 03 |
| `VNDetectFaceLandmarksRequest` | Eyes, mouth points | Optional; add only after QA shows a concrete miss |
| Aesthetics request | Aesthetics score | Optional fallback chain: native score when present, else local heuristics; never fails the run when absent |

Prefer stable `VN*` requests. Do not adopt new Swift-native Vision types just because they exist.

Per-asset flow:

```text
CGImage + orientation -> feature print + face rects + face quality (+ optional landmarks/aesthetics) + light heuristics (blur, exposure, contrast) -> PhotoAnalysis (per 06) -> persist -> release image
```

Rules:

- Store derived values (counts, quality summaries, version, timestamp) per 06. Face boxes and feature-print blobs stay in bounded temp working memory only and are released after use; retention and redaction: [09](../ship-gates/privacy.md). Never store source images or face crops.
- Thresholds, group scoring, face buckets, and final-score mixing are owned by [03](../product-specs/selection-rules.md). Removed from this doc by design. Similarity-threshold tuning plus QA: 03 and [10](../ship-gates/manual-qa.md).
- No identity: detect faces, never name people, never keep an identity store. Privacy limits: [09](../ship-gates/privacy.md).
- Version cached analysis (`analysisVersion`). On algorithm change, bump and recompute; do not migrate ephemeral AI fields. Vision revision pinning beyond the app version is out of scope for MVP.
- Partial Vision failure degrades per asset: keep what succeeded, mark the missing field unknown, continue. Unknown face count differs from zero faces.

Conceptual service shape:

```swift
protocol VisionAnalysisService {
    func analyze(image: CGImage, orientation: CGImagePropertyOrientation) async throws -> PhotoAnalysis
}
```

Prefer one entry point. Add staged methods (`generateFeaturePrint`, `detectFaces`, …) only when the engine needs staged runs per 04. `PhotoAnalysis` is defined in 06 and holds no Vision request objects.

---

## 9. Async, cancellation, concurrency

Wrap PhotoKit callbacks with continuations and wire Swift task cancellation to `cancelImageRequest(_:)`:

```text
task cancelled -> cancel PHImageRequestID -> discard result -> stop Vision work
```

Resume the continuation exactly once. Some delivery modes call back more than once; only the usable final image resumes analysis.

Do not launch one unbounded task per photo. Use bounded concurrency owned and numbered by [08](../ship-gates/performance.md). Never use `isSynchronous = true` in the pipeline; it blocks executors, worse with iCloud waits.

---

## 10. Library changes

Register one observer on `PhotoLibraryService`:

```swift
PHPhotoLibraryChangeObserver
```

On change: invalidate the affected fetch, refresh references, notify the workflow. Never rerun the whole pipeline on every small change. If many changes arrive mid-run, finish or cancel per workflow state, then refresh. The engine tolerates stale IDs per §5.

---

## 11. Export

Creating a new album is references only (non-destructive, collision-safe per [decision-log DEC-TBD-005](decision-log.md)). No file copies, no reimport.

Flow:

```text
final picks -> user taps Create Album -> check auth -> create or resolve album -> add PHAssets -> show result
```

Use `PHAssetCollectionChangeRequest` inside `PHPhotoLibrary.performChanges`. Never write before explicit user action.

| API | Use |
|---|---|
| `PHAssetCollection` | Resolve target album |
| `PHAssetCollectionChangeRequest` | Create album, add assets |
| `PHPhotoLibrary.performChanges` | Apply the change block |

---

## 12. Errors and retry

Map Apple errors to app errors. Never show raw `NSError` text to users. Raw detail may go to redacted local logs per 09.

| App error | Source | Retry |
|---|---|---|
| `permissionDenied` | Auth denied | No; show Settings path |
| `permissionRestricted` | System restriction | No |
| `assetUnavailable` | Deleted, revoked, unresolvable ID | No |
| `iCloudDownloadFailed` | Network or remote failure | Small retry only, then mark unavailable |
| `requestCancelled` | Task or request cancel | No |
| `imageDecodeFailed` | Bad or undecodable bytes | No; mark unavailable |
| `visionFailed` | Vision request error | Per-field degrade; continue |
| `albumCreationFailed` | `performChanges` error | Ask user; retry only on explicit action |

Batch rule: one failed asset never fails the job. Finish the batch, then report analyzed versus unavailable counts.

---

## 13. Logging and privacy pointers

Logging redaction and face-data handling: see [09](../ship-gates/privacy.md).

---

## 14. Build order

| Phase | Work | Done when |
|---|---|---|
| 1 — PhotoKit base | Auth, fetch, metadata map, thumbs | User set shows reliably |
| 2 — Analysis loads | Analysis-size requests, orientation, iCloud, cancel | Local and iCloud assets yield usable images |
| 3 — Core Vision | Feature print, face rects, face quality, light heuristics | Each photo yields minimum `PhotoAnalysis` per 06 |
| 4 — Batch wiring | Bounded queue PhotoKit → Vision → persist → engine | Large sets run without memory growth |
| 5 — Review cache | Preheat, thumb cancel, grid tuning | Review scrolls smoothly |
| 6 — Export | Create album, add assets, write-error map | User can save the approved album |

---

## 15. Acceptance

- Auth: `.authorized`, `.limited`, `.denied`, `.restricted` each behave per §3.1; ask happens in context, not at launch.
- PhotoKit: image fetch works; IDs map; missing assets do not crash; Live stills work; hidden follows 03 filter via §4.2 flags.
- iCloud: remote-only assets detected via request behavior; analysis-size downloads work; progress aggregates; network failure degrades per batch rule.
- Loading: `PHCachingImageManager` serves thumbs; no routine full-resolution loads; cancel works; decoded images released.
- Vision: prints generate and compare (thresholds per 03); faces and quality extract; failures degrade per asset; no Vision types leak into UI or domain models.
- Persist: results reused by ID plus version; no pixel persistence.
- Output: review works; album export is user-approved; originals unchanged.

Manual scenarios (detail in 10): 100 / 1,000 / 2,000 local photos; Optimize Storage on; offline; slow network; full, limited, denied; Live, screenshots, RAW, bursts, groups, retakes; delete-during-run; permission change mid-run; interruption. No automated test targets per project policy.

---

## 16. Uncertain

1. Exact Vision recall on small or angled faces at 512 px (default owned by 04); needs QA tuning per 10.
2. Feature-print version stability across OS releases; `analysisVersion` bump policy unproven.
3. iCloud progress granularity worth surfacing without noisy UI updates.
4. Landmark-request cost versus measurable selection gain.
5. Aesthetics-request availability across supported OS versions; fallback coverage.

---

## 17. Links and upkeep

- Selection policy, duplicates, faces, scoring: see `selection-rules.md`.
- Analysis size default (512 px) (default owned by 04), pipeline order: see `selection-engine.md`.
- Stored shapes: see `data-model.md`.
- Budgets, concurrency numbers, resume: see `performance.md`.
- Privacy, retention, redaction: see `privacy.md`.
- UX copy: see `ux-flows.md`. QA: see `manual-qa.md`.

Check Apple docs each release: PhotoKit auth, `PHCachingImageManager`, `PHImageRequestOptions`, change observer, album requests, Vision face and feature-print requests.
