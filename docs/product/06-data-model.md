# Photos Curator — Data Model

**Document:** `06_Data_Model.md`  
**Status:** MVP Specification  
**Product:** Photos Curator  
**Platform:** iOS  
**Primary technologies:** Swift, SwiftUI, PhotoKit, Vision  
**Related documents:**

- `01_PRD.md`
- `02_UX_Flows.md`
- `03_Photo_Selection_Rules.md`
- `04_Selection_Engine_Design.md`
- `05_iOS_Architecture.md`
- `07_Apple_Framework_Integration.md`
- `08_Performance_Spec.md`
- `09_Privacy_and_Permissions.md`
- `10_Manual_QA_and_Selection_Evaluation.md`
- `11_Analytics_and_Metrics.md`

---

# 1. Purpose

This document defines the core data model used by Photos Curator.

The model must support the complete pipeline:

```text
PhotoKit Assets
    ↓
Asset Metadata
    ↓
Photo Analysis
    ↓
Moments
    ↓
Similarity / Duplicate Clusters
    ↓
Selection Decisions
    ↓
Shortlist
    ↓
Final Album
    ↓
User Review / Feedback
```

The data model must allow the application to process approximately **1,000–5,000 photos per session** without loading full-resolution images into application state.

The model should remain simple enough for the MVP while preserving enough structure to support future improvements such as:

- better ranking algorithms;
- personalized photo selection;
- improved duplicate detection;
- semantic scene understanding;
- user preference learning;
- re-ranking without re-running expensive image analysis.

The data model intentionally does **not** attempt to reproduce or replace the Photos library database.

PhotoKit remains the source of truth for the user's photos.

---

# 2. Design Principles

## 2.1 PhotoKit is the source of truth

Photos Curator must never duplicate the user's entire Photos library.

The application stores only:

- PhotoKit asset identifiers;
- lightweight metadata required by the selection engine;
- derived analysis;
- clustering information;
- selection decisions;
- user feedback;
- session state.

Actual images remain managed by PhotoKit and iCloud Photos.

---

## 2.2 Never use `PHAsset` as a persistent model

`PHAsset` is a framework object and must not become part of the app's persistent data schema.

Store:

```swift
PHAsset.localIdentifier
```

instead.

Example:

```swift
struct AssetID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}
```

The identifier is used to resolve the corresponding `PHAsset` when needed.

---

## 2.3 Separate facts from decisions

The application distinguishes between:

### Objective or semi-objective analysis

Examples:

- image dimensions;
- blur;
- exposure;
- face count;
- eyes closed;
- perceptual similarity;
- scene classification.

These belong to:

```text
PhotoAnalysis
```

### Selection decisions

Examples:

- selected;
- rejected;
- duplicate rejected;
- best group-photo candidate;
- diversity replacement.

These belong to:

```text
SelectionDecision
```

This separation allows the ranking algorithm to change without re-running Vision analysis.

---

## 2.4 Derived data must be reproducible

Most analysis information is derived data.

If necessary, it should be possible to delete it and regenerate it from the user's Photos library.

Derived data must therefore not become the application's only record of something important to the user.

---

## 2.5 Models should support concurrency

Analysis will happen concurrently.

Core value types should therefore prefer:

```swift
Sendable
```

where practical.

Typical domain models should also use:

```swift
Codable
Hashable
Identifiable
```

when appropriate.

---

## 2.6 Avoid storing images inside models

Models must never contain:

```swift
UIImage
CGImage
CIImage
CVPixelBuffer
PHAsset
```

as persistent properties.

Image objects are temporary processing resources managed by image-loading and caching services.

---

# 3. High-Level Entity Model

The MVP contains the following main domain entities:

```text
SelectionSession
│
├── PhotoAsset
│   └── PhotoAnalysis
│
├── Moment
│   └── [AssetID]
│
├── PhotoCluster
│   └── [AssetID]
│
├── SelectionDecision
│
├── SelectionResult
│
└── UserFeedback
```

Conceptually:

```text
PHAsset
   │
   │ localIdentifier
   ▼
PhotoAsset
   │
   ├──────────────► PhotoAnalysis
   │
   ├──────────────► Moment
   │
   ├──────────────► PhotoCluster
   │
   └──────────────► SelectionDecision
                            │
                            ▼
                     SelectionResult
                            │
                            ▼
                      UserFeedback
```

---

# 4. Core Identifier Types

The application should avoid passing untyped `String` identifiers throughout the selection engine.

Lightweight typed identifiers reduce accidental misuse.

```swift
struct AssetID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String
}

struct SessionID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}

struct MomentID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}

struct ClusterID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID
}
```

For convenience:

```swift
extension SessionID {
    static func new() -> Self {
        .init(rawValue: UUID())
    }
}
```

Do not create typed identifiers for every minor object unless there is a real risk of identifier confusion.

---

# 5. PhotoAsset

`PhotoAsset` represents the application's lightweight view of one photo in PhotoKit.

It contains metadata that is cheap to retrieve and useful to the selection pipeline.

It does **not** contain actual image pixels.

```swift
struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {

    let id: AssetID

    let creationDate: Date?

    let pixelWidth: Int
    let pixelHeight: Int

    let mediaSubtype: PhotoMediaSubtype

    let isFavorite: Bool

    let location: GeoCoordinate?

    let source: AssetSource

    var aspectRatio: Double {
        guard pixelHeight > 0 else { return 1 }
        return Double(pixelWidth) / Double(pixelHeight)
    }

    var orientation: PhotoOrientation {
        if pixelWidth > pixelHeight {
            return .landscape
        }

        if pixelHeight > pixelWidth {
            return .portrait
        }

        return .square
    }
}
```

---

# 6. PhotoMediaSubtype

The selection engine may treat some image types differently.

```swift
enum PhotoMediaSubtype: String, Codable, Sendable {
    case standard
    case livePhoto
    case screenshot
    case panorama
    case hdr
    case portrait
    case unknown
}
```

For the MVP, this enum should contain only values that affect product behavior.

It should not attempt to mirror every possible PhotoKit media subtype.

---

# 7. AssetSource

Some assets may exist locally while others require iCloud download.

```swift
enum AssetSource: String, Codable, Sendable {
    case local
    case iCloud
    case unknown
}
```

This value primarily helps with:

- processing strategy;
- progress reporting;
- error handling;
- performance diagnostics.

It should not be interpreted as permanent state because iCloud availability can change.

---

# 8. PhotoOrientation

```swift
enum PhotoOrientation: String, Codable, Sendable {
    case portrait
    case landscape
    case square
}
```

Orientation is derived from dimensions and normally does not need separate persistence.

---

# 9. GeoCoordinate

Location is optional.

```swift
struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}
```

Location data should only be stored when required for grouping or selection.

The MVP should not create a separate geographic database.

---

# 10. PhotoAnalysis

`PhotoAnalysis` contains all derived information produced during image analysis.

It should be independent from selection decisions.

```swift
struct PhotoAnalysis: Identifiable, Codable, Sendable {

    var id: AssetID {
        assetID
    }

    let assetID: AssetID

    let technical: TechnicalAnalysis

    let people: PeopleAnalysis

    let composition: CompositionAnalysis

    let content: ContentAnalysis

    let qualityScore: Double

    let analyzedAt: Date

    let analysisVersion: Int
}
```

The `analysisVersion` is critical.

When analysis logic changes significantly, cached results can be invalidated without complex migrations.

Example:

```swift
static let currentAnalysisVersion = 1
```

---

# 11. TechnicalAnalysis

Technical analysis represents defects or quality characteristics that can generally be measured independently from subjective preference.

```swift
struct TechnicalAnalysis: Codable, Sendable {

    let sharpnessScore: Double

    let exposureScore: Double

    let blurProbability: Double

    let underexposureProbability: Double

    let overexposureProbability: Double

    let resolutionScore: Double
}
```

All normalized values should use the range:

```text
0.0 ... 1.0
```

unless explicitly documented otherwise.

Example interpretation:

```text
sharpnessScore = 1.0
→ very sharp

blurProbability = 1.0
→ highly likely blurred
```

Do not mix opposite score semantics without clear property naming.

---

# 12. PeopleAnalysis

People and group-photo quality are important selection signals.

```swift
struct PeopleAnalysis: Codable, Sendable {

    let faceCount: Int

    let faces: [FaceAnalysis]

    let groupPhotoScore: Double?

    var containsPeople: Bool {
        faceCount > 0
    }
}
```

The application should store only derived face information required for selection.

It should not attempt to build a persistent biometric identity database.

---

# 13. FaceAnalysis

```swift
struct FaceAnalysis: Codable, Sendable {

    let boundingBox: NormalizedRect

    let qualityScore: Double

    let eyesOpenScore: Double?

    let smileScore: Double?

    let frontalScore: Double?
}
```

The model represents anonymous faces inside a photo.

It does **not** contain:

```text
personName
personID
identityEmbedding
contactIdentifier
```

for the MVP.

The selection engine cares about questions such as:

- Is the face visible?
- Is it sharp?
- Are the eyes open?
- Are multiple people captured well?

It does not need to know who the person is.

---

# 14. NormalizedRect

Bounding boxes should use normalized coordinates rather than image pixels.

```swift
struct NormalizedRect: Codable, Hashable, Sendable {

    let x: Double
    let y: Double

    let width: Double
    let height: Double
}
```

Expected range:

```text
0.0 ... 1.0
```

This keeps analysis independent from thumbnail resolution.

---

# 15. CompositionAnalysis

```swift
struct CompositionAnalysis: Codable, Sendable {

    let aestheticScore: Double?

    let subjectPlacementScore: Double?

    let horizonScore: Double?

    let visualBalanceScore: Double?
}
```

Not every composition metric must exist in the initial implementation.

Unavailable signals should generally be represented by `nil`, rather than fake neutral values.

For example:

```swift
aestheticScore: nil
```

means:

> This analysis was not performed.

This is different from:

```swift
aestheticScore: 0.5
```

which means:

> The analysis was performed and produced a moderate score.

---

# 16. ContentAnalysis

Content analysis contains lightweight semantic information useful for album diversity.

```swift
struct ContentAnalysis: Codable, Sendable {

    let sceneType: SceneType

    let tags: [SemanticTag]

    let hasText: Bool?

    let screenshotProbability: Double?
}
```

The MVP should avoid generating hundreds of labels per image.

Only labels useful to selection behavior should be retained.

---

# 17. SceneType

```swift
enum SceneType: String, Codable, Sendable {

    case people
    case group
    case landscape
    case architecture
    case food
    case animal
    case indoor
    case outdoor
    case document
    case screenshot
    case other
    case unknown
}
```

Scene classification exists primarily to improve diversity.

Example:

Without diversity logic:

```text
Top 20 technically best photos
→ 15 nearly identical portraits
→ 3 landscapes
→ 2 food photos
```

With scene awareness:

```text
Final album
→ portraits
→ group photos
→ landscapes
→ architecture
→ food
→ environmental/context photos
```

---

# 18. SemanticTag

Semantic tags should remain lightweight.

```swift
struct SemanticTag: Codable, Hashable, Sendable {

    let name: String

    let confidence: Double
}
```

Example:

```swift
SemanticTag(
    name: "beach",
    confidence: 0.93
)
```

Do not create a complicated ontology during MVP development.

---

# 19. Quality Score

`qualityScore` is a normalized summary of intrinsic photo quality.

```text
0.0 = extremely poor
1.0 = excellent
```

Conceptually:

```text
qualityScore =
    sharpness
    + exposure
    + face quality
    + composition
    + other intrinsic signals
```

The exact calculation belongs to:

`04_Selection_Engine_Design.md`

The data model stores the result but does not define the ranking algorithm.

---

# 20. QualityScoreBreakdown

For debugging and explainability, the selection engine should optionally retain its score components.

```swift
struct QualityScoreBreakdown: Codable, Sendable {

    let technical: Double

    let people: Double?

    let composition: Double?

    let content: Double?

    let total: Double
}
```

This is particularly useful during manual selection-engine evaluation.

For example:

```text
Photo A

technical      0.91
people         0.86
composition    0.72
content        0.80

total          0.84
```

This allows developers to understand why one image outranked another.

---

# 21. Moment

A `Moment` represents a temporally coherent event containing several related photos.

Examples:

```text
08:14–08:22 → breakfast
10:35–10:51 → beach
14:12–14:20 → temple
18:02–18:13 → sunset
```

Model:

```swift
struct PhotoMoment: Identifiable, Codable, Sendable {

    let id: MomentID

    let assetIDs: [AssetID]

    let startDate: Date?

    let endDate: Date?

    let representativeAssetID: AssetID?

    let locationCenter: GeoCoordinate?

    let sceneDistribution: [SceneType: Double]
}
```

A moment contains references to photos, not copies of `PhotoAsset`.

---

# 22. Moment Membership

An asset normally belongs to one primary moment.

For the MVP:

```text
PhotoAsset → 0 or 1 Moment
Moment → many PhotoAssets
```

A many-to-many moment system is unnecessary.

---

# 23. PhotoCluster

A cluster represents visually related photos inside a moment.

Typical examples:

```text
burst-like sequence
same pose
same landscape framing
multiple attempts at one group photo
near duplicates
```

Model:

```swift
struct PhotoCluster: Identifiable, Codable, Sendable {

    let id: ClusterID

    let momentID: MomentID?

    let type: ClusterType

    let assetIDs: [AssetID]

    let representativeAssetID: AssetID?

    let similarityScore: Double?
}
```

---

# 24. ClusterType

```swift
enum ClusterType: String, Codable, Sendable {

    case nearDuplicate
    case burstLike
    case sameScene
    case samePose
    case groupPhotoSequence
}
```

Not all cluster types need separate detection algorithms initially.

The enum describes why the selection engine considers the photos related.

---

# 25. Similarity Data

Pairwise similarity for thousands of photos can become expensive.

The application must **not** persist an NxN similarity matrix.

For 5,000 images:

```text
5,000 × 5,000
= 25,000,000 potential comparisons
```

Instead, retain only meaningful clustering results.

If pairwise similarity must be represented temporarily:

```swift
struct SimilarityEdge: Sendable {

    let first: AssetID

    let second: AssetID

    let similarity: Double
}
```

This should normally remain transient processing data.

---

# 26. Feature Representations

Vision feature prints or equivalent image representations may be required for similarity detection.

They should be treated as implementation-level cache data, not core domain entities.

The conceptual relationship is:

```text
AssetID
    ↓
Feature Representation Cache
    ↓
Similarity Engine
    ↓
PhotoCluster
```

The data model used by the UI should not depend directly on Vision-specific feature objects.

This allows a future similarity implementation to change without changing the rest of the application.

---

# 27. SelectionDecision

`SelectionDecision` represents what the selection engine decided about one photo.

```swift
struct SelectionDecision: Identifiable, Codable, Sendable {

    var id: AssetID {
        assetID
    }

    let assetID: AssetID

    let status: SelectionStatus

    let score: Double

    let scoreBreakdown: SelectionScoreBreakdown

    let reasons: [SelectionReason]

    let competingAssetIDs: [AssetID]

    let engineVersion: Int
}
```

---

# 28. SelectionStatus

```swift
enum SelectionStatus: String, Codable, Sendable {

    case selected
    case rejected
    case undecided
}
```

Do not create a different state for every rejection reason.

The reason belongs in:

```swift
SelectionReason
```

This avoids state explosion.

---

# 29. SelectionScoreBreakdown

Final selection is different from intrinsic image quality.

A high-quality photo may still be rejected because it is redundant.

Therefore:

```swift
struct SelectionScoreBreakdown: Codable, Sendable {

    let quality: Double

    let uniqueness: Double

    let momentImportance: Double

    let people: Double

    let diversity: Double

    let redundancyPenalty: Double

    let finalScore: Double
}
```

Conceptually:

```text
Final Selection Score
=
Quality
+ Uniqueness
+ Moment Importance
+ People Value
+ Diversity Value
- Redundancy Penalty
```

The actual weighting belongs to the selection-engine specification.

---

# 30. SelectionReason

Selection decisions should be explainable.

```swift
enum SelectionReason: String, Codable, Sendable {

    case highOverallQuality

    case sharpImage
    case goodExposure
    case strongComposition

    case bestInCluster
    case duplicateOfBetterPhoto

    case goodGroupPhoto
    case eyesOpen
    case poorFaceQuality

    case blurry
    case badlyExposed

    case addsMomentCoverage
    case addsSceneDiversity

    case redundantScene
    case lowRelativeQuality

    case userForcedKeep
    case userForcedRemove
}
```

A decision may contain multiple reasons.

Example:

```swift
reasons = [
    .bestInCluster,
    .goodGroupPhoto,
    .eyesOpen
]
```

Another:

```swift
reasons = [
    .duplicateOfBetterPhoto,
    .lowRelativeQuality
]
```

---

# 31. competingAssetIDs

When a photo loses to another photo, retaining the competing asset IDs greatly improves debugging.

Example:

```text
Photo B rejected

Reason:
duplicateOfBetterPhoto

Competing asset:
Photo A
```

The UI does not have to expose this relationship immediately, but it is valuable for manual engine evaluation.

---

# 32. SelectionResult

`SelectionResult` represents the output of the engine after processing one session.

```swift
struct SelectionResult: Codable, Sendable {

    let sessionID: SessionID

    let selectedAssetIDs: [AssetID]

    let rejectedAssetIDs: [AssetID]

    let decisions: [SelectionDecision]

    let generatedAt: Date

    let engineVersion: Int
}
```

Ordering of:

```swift
selectedAssetIDs
```

should be meaningful.

Unless another ordering is explicitly requested, final selected photos should normally remain in chronological order for review.

Ranking order should be stored separately if required.

---

# 33. RankedCandidate

During selection, it can be useful to represent a ranked candidate.

```swift
struct RankedCandidate: Identifiable, Sendable {

    var id: AssetID {
        assetID
    }

    let assetID: AssetID

    let score: Double

    let rank: Int
}
```

This can remain transient unless needed for debugging.

---

# 34. SelectionSession

A `SelectionSession` represents one complete curation operation.

Examples:

```text
User selects 1,284 photos from a trip
→ one SelectionSession

User later selects 640 photos from another event
→ another SelectionSession
```

Model:

```swift
struct SelectionSession: Identifiable, Codable, Sendable {

    let id: SessionID

    let createdAt: Date

    var updatedAt: Date

    var status: SessionStatus

    let sourceAssetIDs: [AssetID]

    let targetPhotoCount: Int?

    var progress: SessionProgress

    var result: SelectionResult?

    let configuration: SelectionConfiguration
}
```

---

# 35. SessionStatus

```swift
enum SessionStatus: String, Codable, Sendable {

    case created

    case loadingAssets

    case analyzing

    case groupingMoments

    case clustering

    case ranking

    case generatingAlbum

    case readyForReview

    case completed

    case interrupted

    case failed
}
```

This represents the major pipeline phase.

Do not encode every processing detail as a separate state.

---

# 36. SessionProgress

```swift
struct SessionProgress: Codable, Sendable {

    let stage: ProcessingStage

    let processedCount: Int

    let totalCount: Int

    let message: String?
}
```

Derived progress:

```swift
extension SessionProgress {

    var fractionCompleted: Double {

        guard totalCount > 0 else {
            return 0
        }

        return Double(processedCount)
            / Double(totalCount)
    }
}
```

---

# 37. ProcessingStage

```swift
enum ProcessingStage: String, Codable, Sendable {

    case loading

    case analysis

    case momentDetection

    case clustering

    case ranking

    case finalSelection
}
```

The UI can map these stages to user-friendly labels.

The domain model should not contain localized strings.

---

# 38. SelectionConfiguration

A selection session should retain the important parameters under which it was generated.

```swift
struct SelectionConfiguration: Codable, Sendable {

    let targetPhotoCount: Int?

    let minimumPhotoCount: Int?

    let maximumPhotoCount: Int?

    let duplicateSensitivity: Double

    let qualityPreference: Double

    let diversityPreference: Double

    let peoplePreference: Double
}
```

For MVP, most values may use internal defaults rather than user-facing controls.

The configuration exists primarily for:

- reproducibility;
- debugging;
- future experimentation;
- analytics.

Do not expose every engine parameter to the user.

---

# 39. UserFeedback

User behavior during review provides the strongest signal about whether the automatic selection was correct.

```swift
struct UserFeedback: Identifiable, Codable, Sendable {

    let id: UUID

    let sessionID: SessionID

    let assetID: AssetID

    let action: FeedbackAction

    let previousState: SelectionStatus?

    let newState: SelectionStatus?

    let timestamp: Date
}
```

---

# 40. FeedbackAction

```swift
enum FeedbackAction: String, Codable, Sendable {

    case keepRejectedPhoto

    case removeSelectedPhoto

    case restorePhoto

    case undo

    case acceptSelection
}
```

Examples:

### AI selected a photo, user removes it

```text
removeSelectedPhoto
```

### AI rejected a photo, user restores it

```text
keepRejectedPhoto
```

These events are highly valuable for evaluating the selection engine.

---

# 41. User Override State

The final state of a photo should distinguish engine output from user override.

A simple model is:

```swift
enum UserOverride: String, Codable, Sendable {

    case none

    case forceKeep

    case forceRemove
}
```

The effective state can then be derived:

```text
Engine Decision
+
User Override
=
Final User-visible Decision
```

For example:

```text
Engine:
rejected

User Override:
forceKeep

Final:
selected
```

This is preferable to mutating the original engine decision.

The original AI decision remains available for evaluation.

---

# 42. FinalPhotoDecision

A convenience model may combine engine output and user override:

```swift
struct FinalPhotoDecision: Sendable {

    let assetID: AssetID

    let engineDecision: SelectionDecision

    let userOverride: UserOverride

    var isSelected: Bool {

        switch userOverride {

        case .forceKeep:
            return true

        case .forceRemove:
            return false

        case .none:
            return engineDecision.status == .selected
        }
    }
}
```

This model may remain computed rather than persisted.

---

# 43. Review State

UI-specific review state should not be mixed into analysis models.

For example:

```swift
struct ReviewState: Sendable {

    var currentAssetID: AssetID?

    var selectedAssetIDs: Set<AssetID>

    var rejectedAssetIDs: Set<AssetID>
}
```

Properties such as:

```text
isExpanded
isSheetPresented
scrollPosition
currentZoom
```

belong to SwiftUI presentation state, not the persistent domain model.

---

# 44. ProcessingFailure

Failures should be associated with assets without invalidating the entire session.

```swift
struct AssetProcessingFailure: Codable, Sendable {

    let assetID: AssetID

    let stage: ProcessingStage

    let reason: ProcessingFailureReason
}
```

```swift
enum ProcessingFailureReason: String, Codable, Sendable {

    case assetUnavailable

    case iCloudDownloadFailed

    case imageRequestFailed

    case visionAnalysisFailed

    case unsupportedFormat

    case cancelled

    case unknown
}
```

The selection engine should generally continue processing remaining photos.

---

# 45. Session-Level Failure

A session-level failure is reserved for conditions where processing cannot reasonably continue.

```swift
struct SessionFailure: Codable, Sendable {

    let stage: ProcessingStage?

    let message: String

    let recoverable: Bool
}
```

Avoid persisting raw framework error objects.

Store stable app-level failure categories instead.

---

# 46. Analysis Cache Record

Derived analysis should be cacheable so interrupted sessions do not require complete re-analysis.

Conceptually:

```swift
struct AnalysisCacheRecord: Codable, Sendable {

    let assetID: AssetID

    let analysis: PhotoAnalysis

    let fingerprint: AssetFingerprint

    let analysisVersion: Int
}
```

---

# 47. AssetFingerprint

An asset fingerprint helps determine whether cached analysis is still valid.

```swift
struct AssetFingerprint: Codable, Hashable, Sendable {

    let pixelWidth: Int

    let pixelHeight: Int

    let creationDate: Date?

    let modificationDate: Date?
}
```

The exact available PhotoKit metadata will determine the final implementation.

The goal is not cryptographic verification.

The goal is simply:

> Can we reasonably reuse this cached analysis?

---

# 48. Cache Validity

Cached analysis should be valid only when:

```text
asset still exists
AND
asset fingerprint is compatible
AND
analysisVersion matches
```

Conceptually:

```swift
func isCacheValid(
    record: AnalysisCacheRecord,
    asset: PhotoAsset,
    currentVersion: Int
) -> Bool
```

returns `true` only when the cached analysis can safely be reused.

---

# 49. Engine Versioning

Two independent versions should exist.

## Analysis version

```text
analysisVersion
```

Changes when image interpretation changes.

Examples:

- new blur detection;
- different face analysis;
- different Vision request;
- new semantic analysis.

## Selection engine version

```text
engineVersion
```

Changes when ranking or selection behavior changes.

Examples:

- different quality weights;
- different duplicate threshold;
- new diversity rules;
- different moment balancing.

This separation is important.

Changing ranking weights should not force thousands of photos to be analyzed again.

---

# 50. Re-ranking Without Re-analysis

The model should support:

```text
existing PhotoAnalysis
    ↓
new ranking algorithm
    ↓
new SelectionDecision
```

without:

```text
loading all photos
    ↓
running Vision again
```

This is one of the primary reasons `PhotoAnalysis` and `SelectionDecision` are separate entities.

---

# 51. Processing Workspace

Some data should exist only while a session is being processed.

Example:

```swift
struct ProcessingWorkspace {

    var assets: [PhotoAsset]

    var analyses: [AssetID: PhotoAnalysis]

    var moments: [PhotoMoment]

    var clusters: [PhotoCluster]

    var decisions: [AssetID: SelectionDecision]
}
```

This is an implementation concept rather than a required persisted entity.

For performance-sensitive code, dictionaries keyed by `AssetID` are preferred when repeated random lookup is required.

Example:

```swift
[AssetID: PhotoAnalysis]
```

instead of repeatedly searching:

```swift
[PhotoAnalysis]
```

---

# 52. Recommended Runtime Indexes

For a session containing thousands of assets, commonly used indexes include:

```swift
let assetByID: [AssetID: PhotoAsset]

let analysisByAssetID: [AssetID: PhotoAnalysis]

let decisionByAssetID: [AssetID: SelectionDecision]

let clusterByAssetID: [AssetID: ClusterID]

let momentByAssetID: [AssetID: MomentID]
```

These can be rebuilt when loading a session and do not necessarily need separate persistence.

---

# 53. Persistence Strategy

The application should persist only what provides meaningful value between launches.

Recommended persistent information:

```text
SelectionSession

PhotoAnalysis / analysis cache

SelectionResult

SelectionDecision

UserOverride

UserFeedback

minimum metadata necessary for cache validation
```

Information that normally does not need permanent persistence:

```text
UIImage thumbnails

full-resolution photos

temporary Vision request objects

CGImage objects

pairwise similarity matrices

temporary ranking arrays

temporary progress UI state
```

---

# 54. Domain Models vs Persistence Models

The selection engine should operate on Swift domain models rather than directly depending on a specific persistence framework.

Conceptually:

```text
Persistence
    ↓
Domain Models
    ↓
Selection Engine
    ↓
Domain Result
    ↓
Persistence
```

The domain models defined in this document are intentionally persistence-agnostic.

The storage implementation may use the mechanism selected by the architecture document without requiring the selection engine itself to understand database details.

For the MVP, avoid introducing separate DTO/domain/database objects unless the persistence framework actually requires them.

One model representation is preferable when it remains practical.

---

# 55. Data Loading Strategy

Never materialize full images for every `PhotoAsset`.

Loading 5,000 assets should initially mean loading approximately:

```text
IDs
dates
dimensions
favorite state
media subtype
location metadata
```

not:

```text
5,000 × image pixels
```

Image pixels should be requested only when a processing stage requires them.

---

# 56. Image Analysis Input

The processing layer may use an ephemeral structure:

```swift
struct AnalysisInput {

    let assetID: AssetID

    let image: CGImage
}
```

This object must never be persisted.

Its lifetime should be limited to the current processing operation.

After analysis:

```text
CGImage released
        ↓
PhotoAnalysis retained
```

---

# 57. Memory Ownership

The data model should make the expected lifecycle clear:

```text
PhotoAsset
→ lightweight
→ retained throughout session

PhotoAnalysis
→ lightweight
→ retained / cached

Thumbnail
→ temporary
→ NSCache / image cache

Full image
→ temporary
→ process and release

Vision request objects
→ temporary
→ release after analysis
```

This separation is required to make processing thousands of assets feasible.

---

# 58. User Feedback and Future Personalization

The MVP does not need an ML personalization model.

However, feedback should be stored in a way that makes future personalization possible.

Useful future signals include:

```text
AI selected → user removed

AI rejected → user restored

portrait frequently kept

landscape frequently removed

group photos frequently restored

specific technical imperfections tolerated
```

The MVP only records the raw actions.

Interpretation and personalization belong to future versions.

---

# 59. Do Not Store User Preference Conclusions Yet

Avoid models such as:

```swift
struct UserPreferenceProfile {
    let likesLandscapes: Double
    let likesSelfies: Double
    let likesFoodPhotos: Double
}
```

during the MVP.

There will initially be insufficient data to make these values reliable.

Store feedback events first.

Derive preference models later when enough behavior exists.

---

# 60. Deletion Behavior

When a photo disappears from PhotoKit:

```text
AssetID can no longer resolve
```

The app should:

```text
remove or invalidate derived analysis
remove cluster membership
remove associated decisions when appropriate
ignore the asset during resumed processing
```

The application must never assume that a stored `AssetID` will remain resolvable forever.

---

# 61. Photo Library Changes

Because users may:

- edit photos;
- delete photos;
- restore photos;
- download originals from iCloud;
- modify favorites;
- add new photos;

PhotoKit should always be treated as authoritative.

Stored metadata is a processing snapshot, not a replacement for PhotoKit.

---

# 62. Session Resume Model

Processing must be resumable after interruption.

A resumable session should know:

```text
session ID

source asset IDs

current processing stage

already completed analyses

processing configuration

selection result if generated
```

The application should not require perfect instruction-level continuation.

For example, after interruption during analysis:

```text
1,000 total photos

620 cached analyses available

app restarts

→ reuse 620

→ analyze remaining 380

→ continue pipeline
```

This is sufficient.

There is no need to persist every internal operation.

---

# 63. Session Lifecycle

Expected lifecycle:

```text
created
   ↓
loadingAssets
   ↓
analyzing
   ↓
groupingMoments
   ↓
clustering
   ↓
ranking
   ↓
generatingAlbum
   ↓
readyForReview
   ↓
completed
```

Possible interruption:

```text
analyzing
   ↓
interrupted
   ↓
resume
   ↓
analyzing
```

Possible failure:

```text
any stage
   ↓
failed
```

Asset-level processing failures should not automatically cause session-level failure.

---

# 64. Final Album

The final curated album can be represented simply as:

```swift
struct CuratedAlbum: Identifiable, Codable, Sendable {

    let id: UUID

    let sessionID: SessionID

    let assetIDs: [AssetID]

    let createdAt: Date
}
```

For MVP, an album does not need complicated metadata.

The source PhotoKit assets remain the actual photos.

---

# 65. Album Ordering

`assetIDs` should normally use chronological order.

Example:

```text
Day 1 breakfast
Day 1 beach
Day 1 sunset
Day 2 museum
Day 2 dinner
```

rather than ranking order:

```text
best score
second-best score
third-best score
...
```

Ranking is used to determine inclusion.

Chronology is used to tell the story.

---

# 66. Optional Debug Information

Development builds may attach additional information to selections.

```swift
struct SelectionDebugInfo: Codable, Sendable {

    let candidateRank: Int?

    let clusterRank: Int?

    let momentRank: Int?

    let rawScores: [String: Double]
}
```

Debug information should not become necessary for normal application behavior.

It may be omitted from production persistence.

---

# 67. Example Complete Asset State

A photo moving through the pipeline might eventually have:

```text
PhotoAsset
    id: A123
    creationDate: 2026-06-18 10:32
    orientation: portrait

PhotoAnalysis
    sharpness: 0.91
    exposure: 0.86
    faces: 2
    quality: 0.88
    scene: people

Moment
    M14 — Temple Visit

Cluster
    C27 — Group Photo Sequence

SelectionDecision
    selected
    score: 0.92

Reasons
    bestInCluster
    goodGroupPhoto
    eyesOpen
    addsMomentCoverage

UserOverride
    none

Final State
    selected
```

Another image:

```text
PhotoAsset
    id: A124

PhotoAnalysis
    sharpness: 0.82
    faces: 2
    quality: 0.79

Moment
    M14

Cluster
    C27

SelectionDecision
    rejected

Reasons
    duplicateOfBetterPhoto
    lowRelativeQuality

CompetingAsset
    A123

Final State
    rejected
```

---

# 68. Example User Correction

Suppose the engine rejects:

```text
A130
```

but the user restores it.

The original engine record remains:

```text
SelectionDecision

assetID:
A130

status:
rejected
```

The user action creates:

```text
UserOverride

assetID:
A130

forceKeep
```

and:

```text
UserFeedback

action:
keepRejectedPhoto
```

Effective final state:

```text
selected
```

This preserves both:

```text
what the AI decided
```

and:

```text
what the user wanted
```

That distinction is essential for evaluating future selection quality.

---

# 69. Suggested Swift Domain Definitions

A minimal core set for the MVP is:

```swift
struct PhotoAsset
struct PhotoAnalysis
struct TechnicalAnalysis
struct PeopleAnalysis
struct FaceAnalysis
struct ContentAnalysis

struct PhotoMoment
struct PhotoCluster

struct SelectionDecision
struct SelectionScoreBreakdown
struct SelectionResult

struct SelectionSession
struct SelectionConfiguration
struct SessionProgress

struct UserFeedback
struct CuratedAlbum
```

Core enums:

```swift
enum PhotoMediaSubtype
enum PhotoOrientation
enum AssetSource
enum SceneType
enum ClusterType

enum SelectionStatus
enum SelectionReason

enum SessionStatus
enum ProcessingStage

enum UserOverride
enum FeedbackAction
```

This should be sufficient for MVP development.

Do not create additional models without a concrete use case.

---

# 70. Recommended Folder Mapping

The exact folder structure is defined in `05_iOS_Architecture.md`, but conceptually models can remain organized by domain:

```text
Models/
├── Asset/
│   ├── PhotoAsset.swift
│   └── AssetID.swift
│
├── Analysis/
│   ├── PhotoAnalysis.swift
│   ├── TechnicalAnalysis.swift
│   ├── PeopleAnalysis.swift
│   └── ContentAnalysis.swift
│
├── Grouping/
│   ├── PhotoMoment.swift
│   └── PhotoCluster.swift
│
├── Selection/
│   ├── SelectionDecision.swift
│   ├── SelectionReason.swift
│   └── SelectionResult.swift
│
├── Session/
│   ├── SelectionSession.swift
│   └── SessionProgress.swift
│
└── Feedback/
    ├── UserFeedback.swift
    └── UserOverride.swift
```

However, if the number of files remains small during the first implementation, a flatter structure is acceptable.

Do not create directories merely to satisfy architectural symmetry.

---

# 71. Data Model Invariants

The following invariants should hold.

### Asset identity

```text
One PhotoKit localIdentifier
→ one AssetID
```

### Analysis

```text
At most one active PhotoAnalysis
per AssetID
per analysisVersion
```

### Moment

```text
An asset belongs to at most one primary moment.
```

### Cluster

An asset may technically participate in different conceptual clustering passes, but within one cluster type/pass it should have one clear primary cluster.

### Selection

```text
One active engine decision
per asset
per engine version/session
```

### User override

```text
At most one effective override
per asset/session
```

Historical feedback events may contain multiple actions.

---

# 72. Numeric Score Conventions

All normalized scores should follow:

```text
0.0 ... 1.0
```

unless explicitly stated otherwise.

Prefer:

```swift
Double
```

for scoring.

Examples:

```text
0.0 = weakest
1.0 = strongest
```

For probability properties:

```text
0.0 = unlikely
1.0 = highly likely
```

Property names must communicate whether higher means better or worse.

Good:

```swift
sharpnessScore
blurProbability
```

Bad:

```swift
blurScore
```

because it is unclear whether a high value represents more blur or better blur performance.

---

# 73. Missing Values

Use `nil` when analysis was unavailable.

Example:

```swift
smileScore: nil
```

Possible meaning:

```text
No reliable smile analysis was available.
```

Do not substitute arbitrary values such as:

```swift
0
0.5
```

because doing so makes unavailable measurements indistinguishable from real measurements.

---

# 74. Collections

Use arrays when ordering matters.

Examples:

```swift
[AssetID]
```

for album chronology.

Use sets for membership.

Examples:

```swift
Set<AssetID>
```

for selected assets during review.

Use dictionaries for repeated key lookup.

Examples:

```swift
[AssetID: PhotoAnalysis]
```

for analysis lookup.

---

# 75. Avoid Premature Database Relationships

The persistence model does not need a complex graph of bidirectional object relationships.

For example, prefer:

```swift
PhotoCluster {
    let assetIDs: [AssetID]
}
```

over requiring every `PhotoAsset` database object to maintain a bidirectional relationship with every cluster.

Identifiers keep the processing model simpler and reduce persistence coupling.

---

# 76. Avoid Premature Generic Abstractions

Do not introduce abstractions such as:

```swift
protocol AnalyzableEntity
protocol Scorable
protocol Clusterable
protocol PersistableDomainObject
```

unless multiple real implementations require them.

Concrete types are preferred during MVP development.

---

# 77. Avoid Model Explosion

Do not create separate models for concepts that can be represented as properties or enums.

For example, avoid:

```text
BlurResult
ExposureResult
SharpnessResult
FaceCountResult
LandscapeResult
```

when:

```swift
TechnicalAnalysis
PeopleAnalysis
ContentAnalysis
```

provide sufficient structure.

---

# 78. No Testing-Specific Data Models

The production repository does not require model objects created exclusively for unit tests or UI tests.

Manual QA and selection-engine evaluation are covered by:

`10_Manual_QA_and_Selection_Evaluation.md`

Debugging metadata may still be retained when it directly helps understand selection quality.

---

# 79. Privacy Constraints

Data models must follow several privacy principles.

Do not persist:

```text
raw photos

unnecessary thumbnails

biometric identity profiles

person names derived from faces

persistent face embeddings unless absolutely required

unnecessary precise location history
```

Prefer retaining only derived signals required for curation.

Detailed privacy behavior is defined in:

`09_Privacy_and_Permissions.md`

---

# 80. MVP Persistence Summary

For the first production-capable MVP:

| Entity | Persistent | Reason |
|---|---:|---|
| `AssetID` | Yes | Reconnect to PhotoKit |
| `PhotoAsset` metadata | Partial | Resume/cache validation |
| `PhotoAnalysis` | Yes | Avoid expensive re-analysis |
| Vision image objects | No | Temporary processing |
| Feature representations | Cache only | Duplicate detection performance |
| `PhotoMoment` | Optional | Cheap to recompute |
| `PhotoCluster` | Optional | Cheap/moderate to recompute |
| `SelectionDecision` | Yes | Review and evaluation |
| `SelectionResult` | Yes | Restore curated result |
| `SelectionSession` | Yes | Resume interrupted work |
| `UserOverride` | Yes | Preserve user choices |
| `UserFeedback` | Yes | Engine evaluation |
| thumbnails | Cache only | UI performance |
| full images | No | PhotoKit owns them |

The exact persistence/caching boundary may be adjusted after measuring processing cost.

---

# 81. Minimum MVP Schema

If implementation needs to begin with the smallest viable schema, start with:

```text
PhotoAsset
PhotoAnalysis
PhotoMoment
PhotoCluster
SelectionDecision
SelectionSession
UserFeedback
```

These seven concepts provide enough structure for the complete MVP pipeline.

Everything else in this document either supports these models or can be introduced incrementally.

---

# 82. Data Flow Example

A 1,000-photo session should conceptually behave as follows:

```text
1. User selects 1,000 assets
        ↓
2. Create SelectionSession
        ↓
3. Resolve PhotoAsset metadata
        ↓
4. Check cached PhotoAnalysis
        ↓
5. Analyze uncached assets
        ↓
6. Build PhotoMoments
        ↓
7. Build PhotoClusters
        ↓
8. Generate SelectionDecision for each candidate
        ↓
9. Produce SelectionResult
        ↓
10. Display curated album
        ↓
11. Record UserFeedback during review
        ↓
12. Save final user overrides
```

At no point should the data model require all 1,000 full-resolution images to remain resident in memory.

---

# 83. Data Ownership Matrix

| Data | Owner |
|---|---|
| Original photo | PhotoKit |
| Photo identifier | Photos Curator |
| Basic metadata snapshot | Photos Curator |
| Thumbnail | Cache |
| Analysis | Selection engine / app storage |
| Moment assignment | Selection engine |
| Cluster assignment | Selection engine |
| AI selection | Selection engine |
| User override | User |
| Final curated result | Photos Curator |
| Actual album/photo library changes | PhotoKit integration layer |

This ownership distinction should remain explicit throughout the implementation.

---

# 84. Future Extensions

The schema should allow, but not currently implement, the following.

## Personalized preferences

```text
UserFeedback
    ↓
Preference Learning
    ↓
Personalized Selection Score
```

## Person-aware selection

Potential future capability:

```text
anonymous person clustering
```

to avoid selecting ten photos of one person while excluding everyone else.

This requires separate privacy review before implementation.

## Better semantic understanding

Future analysis may include:

```text
landmark recognition
activity detection
event classification
photo storytelling relevance
```

These signals can extend `ContentAnalysis`.

## Multiple album styles

Future configurations could generate:

```text
Best 20
Best 50
People-focused
Landscape-focused
Story-focused
```

The current `SelectionConfiguration` and analysis/decision separation already support this direction.

---

# 85. Non-Goals

The MVP data model will not implement:

- a replacement for the Photos database;
- cloud synchronization of Photos Curator state;
- collaborative albums;
- named-person recognition;
- biometric identity databases;
- complex graph relationships between photos;
- persistent pairwise similarity matrices;
- custom image file management;
- custom photo storage;
- full event/location ontology;
- ML-based personalization profiles;
- versioned event sourcing;
- generic repository abstractions for every model;
- unnecessary database normalization;
- testing-only domain models.

These capabilities can be added only if future requirements justify them.

---

# 86. Implementation Priority

Recommended implementation order:

```text
1. AssetID
2. PhotoAsset
3. PhotoAnalysis
4. PhotoMoment
5. PhotoCluster
6. SelectionDecision
7. SelectionResult
8. SelectionSession
9. UserOverride
10. UserFeedback
11. Persistence/cache records
```

This order mirrors the actual selection pipeline and minimizes unused code.

---

# 87. Final Recommended Model Graph

The final MVP relationship should remain approximately:

```text
SelectionSession
│
├── sourceAssetIDs
│
├── configuration
│
├── progress
│
└── SelectionResult
         │
         └── SelectionDecision[]
                  │
                  └── AssetID
                       │
                       ├── PhotoAsset
                       │
                       ├── PhotoAnalysis
                       │
                       ├── PhotoMoment
                       │
                       └── PhotoCluster

UserFeedback
│
├── SessionID
└── AssetID

UserOverride
│
├── SessionID
└── AssetID
```

The relationship between entities is primarily identifier-based rather than based on large interconnected object graphs.

---

# 88. Key Architectural Rule

The most important rule in this document is:

> **A photo, its analysis, and the decision about that photo are three different things.**

```text
PhotoAsset
=
What photo is this?

PhotoAnalysis
=
What properties does this photo have?

SelectionDecision
=
Should this photo be included in this specific curated album?
```

Keeping these concepts separate allows Photos Curator to:

- re-rank photos without re-running Vision;
- change selection algorithms safely;
- compare different selection strategies;
- explain why an image was selected;
- measure user disagreement;
- introduce personalization later;
- recover from interrupted sessions;
- scale to thousands of photos without storing image data in application models.

This separation should remain intact even as the selection engine becomes more sophisticated.

---

# 89. Definition of Done

`06_Data_Model.md` is considered implemented when the application can represent:

```text
PhotoKit asset reference
        ↓
photo metadata
        ↓
derived analysis
        ↓
moment membership
        ↓
similarity cluster
        ↓
selection decision
        ↓
final curated result
        ↓
user correction
```

while preserving the following properties:

- no full-resolution photos stored in domain models;
- PhotoKit remains the source of truth;
- analysis can be cached;
- sessions can resume after interruption;
- ranking can change without re-running image analysis;
- engine decisions remain distinguishable from user overrides;
- selection decisions are explainable;
- models remain usable with Swift concurrency;
- 1,000–5,000 photo sessions do not require large persistent object graphs;
- the MVP remains simple enough to implement and modify quickly.

---

# 90. Summary

The MVP data model is centered around six fundamental concepts:

```text
Asset
Analysis
Moment
Cluster
Decision
Feedback
```

with `SelectionSession` coordinating the processing lifecycle.

The most important relationships are:

```text
Asset
→ analyzed into Analysis

Assets
→ grouped into Moments

Similar Assets
→ grouped into Clusters

Analysis + Moment + Cluster
→ produce Decision

Decisions
→ produce SelectionResult

User changes
→ produce Feedback / Override
```

This model is intentionally lightweight.

It provides enough structure for a reliable photo-selection engine while avoiding premature abstractions, unnecessary database complexity, and duplication of responsibilities already handled by PhotoKit.