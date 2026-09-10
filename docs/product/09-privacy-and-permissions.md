# Photos Curator — Privacy and Permissions Specification

**Document:** `09_Privacy_and_Permissions.md`  
**Product:** Photos Curator  
**Status:** MVP Specification  
**Priority:** Required  
**Related documents:**

- `01_PRD.md`
- `02_UX_Flows.md`
- `03_Photo_Selection_Rules.md`
- `04_Selection_Engine_Design.md`
- `05_iOS_Architecture.md`
- `06_Data_Model.md`
- `07_Apple_Framework_Integration.md`
- `08_Performance_Spec.md`
- `10_Manual_QA_and_Selection_Evaluation.md`
- `11_Analytics_and_Metrics.md`

---

# 1. Purpose

This document defines the privacy, permission, data-handling, retention, and deletion requirements for Photos Curator.

Photos Curator processes a highly sensitive category of user content: the user's personal photo library.

The privacy architecture must therefore be treated as a core product requirement rather than an App Store compliance task added at the end of development.

The MVP is designed around a simple principle:

> The user's photos stay under the user's control.

The application should perform photo analysis and selection locally on the device whenever technically possible.

The MVP must not require:

- a user account;
- a Photos Curator cloud account;
- uploading the user's photos to an application server;
- uploading face data;
- uploading visual embeddings;
- advertising identifiers;
- cross-app tracking;
- cloud-based AI inference.

The application should remain useful without any Photos Curator backend.

---

# 2. Privacy Principles

The following principles are mandatory for the MVP.

## 2.1 Local-first processing

Photo analysis must run on the user's device.

This includes, where applicable:

- image quality analysis;
- blur detection;
- exposure analysis;
- duplicate detection;
- near-duplicate detection;
- scene analysis;
- face detection;
- face quality analysis;
- group-photo analysis;
- image similarity;
- moment clustering;
- landscape evaluation;
- aesthetic scoring;
- diversity scoring;
- shortlist generation;
- final photo selection.

Photo pixels must not be uploaded to a Photos Curator server for the MVP.

---

## 2.2 Data minimization

Store only information required to provide the product functionality.

Do not persist information simply because it may become useful later.

For example:

Allowed:

```text
assetIdentifier
captureDate
pixelWidth
pixelHeight
sharpnessScore
faceCount
faceQualityScore
selectionScore
selectionDecision
```

Avoid:

```text
full-resolution copied photo
persistent face crop
persistent facial landmarks
persistent facial embedding
person identity
person name
location history assembled across sessions
```

---

## 2.3 Purpose limitation

Data obtained from the Photos library must be used exclusively for features clearly related to photo curation.

For example:

- determining which images belong to the same moment;
- finding duplicates;
- selecting the clearest group photograph;
- maintaining visual diversity;
- creating the final curated selection.

The application must not reuse photo-library information for unrelated purposes.

---

## 2.4 User control

The user must remain able to:

- deny Photos access;
- grant limited Photos access;
- grant full Photos access;
- change Photos access later in iOS Settings;
- stop a curation session;
- delete locally stored analysis;
- remove Photos Curator from the device.

The app must continue behaving predictably after any permission change.

Apple explicitly requires applications to respect permission choices and request access only when necessary.

---

# 3. Privacy Architecture

The MVP privacy architecture should be:

```text
┌───────────────────────────────┐
│       Apple Photos Library    │
│      PhotoKit / iCloud Photos │
└───────────────┬───────────────┘
                │
                │ User-authorized access
                ▼
┌───────────────────────────────┐
│        Photos Curator App     │
│                               │
│ PhotoKit                      │
│ Vision                        │
│ Core ML / local heuristics    │
│ Selection Engine              │
│ Local Metadata Cache          │
│                               │
└───────────────┬───────────────┘
                │
                │ Optional anonymous
                │ product metrics only
                ▼
          Analytics service
          if introduced
```

There must be **no application-server path carrying photo pixels or face information** in the MVP.

---

# 4. Data Classification

Photos Curator should internally classify data according to sensitivity.

| Data | Sensitivity | Persistence | Network transmission |
|---|---|---:|---:|
| Original photo/video | Very high | No application copy | Never to Photos Curator servers |
| Thumbnail | High | Temporary cache | Never |
| Photo metadata | High | Local if required | Never by default |
| GPS metadata | Very high | Avoid persisting | Never |
| Face bounding boxes | Very high | Temporary | Never |
| Facial landmarks | Very high | Temporary | Never |
| Face embeddings | Very high | Not stored in MVP | Never |
| Face quality score | Sensitive derived data | Local if required | Never |
| Face count | Sensitive derived data | Local if required | Never |
| Image quality scores | Moderate | Local | Never |
| Image similarity features | High | Local | Never |
| Selection decision | Moderate | Local | Aggregate metrics only |
| Processing duration | Low | Optional analytics | Allowed if anonymous |
| Number of analyzed photos | Low | Optional analytics | Allowed if anonymous |
| App crash diagnostics | Low–moderate | External service if used | Must contain no photo data |

---

# 5. Photos Permission Model

## 5.1 Required permission

Photos Curator needs to inspect existing photos selected for curation.

For PhotoKit-based library access, the app should therefore request:

```swift
PHAccessLevel.readWrite
```

rather than:

```swift
PHAccessLevel.addOnly
```

`addOnly` access is insufficient for the application's primary workflow because the application needs to read existing photo assets.

Apple recommends using the access-level-specific PhotoKit authorization APIs, including `authorizationStatus(for:)` and `requestAuthorization(for:handler:)`.

---

# 6. Permission Request Timing

The application must **not request Photos permission immediately at launch**.

Instead, request permission when the user initiates an action that clearly requires the photo library.

Recommended flow:

```text
Launch App
    ↓
Welcome / Home
    ↓
User taps "Select Photos" / "Start Curating"
    ↓
Explain why access is needed
    ↓
Request Photos permission
```

This makes the system permission dialog understandable in context.

---

# 7. Pre-Permission Explanation

Before invoking the system permission dialog, Photos Curator may show a short explanation.

Example:

> Photos Curator needs access to your photos to analyze duplicates, image quality, moments, and group photos.
>
> Photo analysis happens on your iPhone. Your photos are not uploaded to Photos Curator.

The explanation must not pressure the user into granting full access.

Avoid language such as:

> You must allow all photos.

or:

> The app cannot work unless you give us complete access.

Limited access must remain a supported state.

---

# 8. Info.plist Permission String

The application must provide a clear `NSPhotoLibraryUsageDescription`.

Recommended English text:

```text
Photos Curator needs access to your photo library to analyze and select your best photos. Photo analysis is performed on your device.
```

A shorter alternative:

```text
Allow access so Photos Curator can analyze and select your best photos on this device.
```

The text must accurately describe the actual behavior of the application.

Attempting protected Photos access without the appropriate usage description can cause the application to fail, and Apple requires the purpose string to explain how Photos access is used.

---

# 9. Authorization States

The application must explicitly handle every `PHAuthorizationStatus`.

```swift
.notDetermined
.restricted
.denied
.authorized
.limited
```

Apple currently defines both `.authorized` and `.limited` as valid user-controlled Photos authorization states.

Expected behavior:

| Status | Application behavior |
|---|---|
| `.notDetermined` | Explain access, then request permission |
| `.authorized` | Continue normally |
| `.limited` | Continue using only accessible assets |
| `.denied` | Show permission explanation and Settings option |
| `.restricted` | Explain that system restrictions prevent access |
| unknown future value | Fail gracefully |

Do not treat `.limited` as an error.

---

# 10. Limited Photos Access

Limited Photos access is a first-class supported state.

When the user grants limited access, Photos Curator may analyze only assets exposed by iOS.

The application must not repeatedly ask the user to grant full access.

Instead, the UI may display a non-blocking message such as:

> Photos Curator currently has access to selected photos only. You can add more photos if you want a more complete selection.

Possible actions:

```text
Continue with Selected Photos
Manage Photo Access
```

The app should remain functional using the available subset.

Apple's limited-library authorization explicitly allows the user to expose only selected photos rather than the entire library.

---

# 11. Full Access Is Helpful, Not Mandatory

Full Photos access may produce better automatic trip or event detection because the selection engine can see more relevant photographs.

However, the application must distinguish:

```text
Product quality benefit
```

from:

```text
Permission requirement
```

Full access may improve selection quality.

It must not be presented as mandatory when limited access can satisfy the requested workflow.

---

# 12. Permission Changes

Users can change Photos permissions outside the application.

Therefore the app must not assume that a previously stored permission status remains valid.

Check authorization when entering workflows that require Photos access.

For example:

```text
User previously granted Full Access
        ↓
User changes permission in Settings
        ↓
User returns to Photos Curator
        ↓
Application re-checks status
        ↓
UI updates automatically
```

Apple notes that users can change their Photos authorization in Settings and applications should handle those changes correctly.

---

# 13. Denied Permission UX

When Photos access is denied, the application must not repeatedly invoke the system permission request.

Show an explanatory state.

Example:

```text
Photos Access Needed

Photos Curator needs access to the photos you want it to analyze.

[Open Settings]

[Not Now]
```

The user should always have a way to dismiss the message.

---

# 14. Restricted Permission

`.restricted` differs from `.denied`.

It may be caused by system policies or device restrictions.

Recommended message:

```text
Photo access is restricted on this device.

You may need to change your device or family settings before Photos Curator can access your photo library.
```

Do not show a misleading "Try Again" button if Photos Curator cannot resolve the restriction.

---

# 15. On-Device Processing Guarantee

For the MVP, the following operations must execute locally:

```text
Asset metadata extraction
Thumbnail generation
Image quality scoring
Duplicate detection
Image similarity
Face detection
Face-quality analysis
Moment clustering
Group-photo comparison
Landscape analysis
Selection ranking
Final album generation
```

Using Apple's Vision framework for face detection is compatible with this architecture.

Vision provides local image-analysis requests such as face rectangle detection, face landmark analysis, and face capture-quality analysis.

---

# 16. Network Boundary

The application's own networking layer must never receive:

```text
UIImage
CGImage
CIImage
PHAssetResource photo bytes
photo thumbnail bytes
face crops
face landmarks
face embeddings
visual embeddings derived for identity purposes
```

The selection pipeline should not depend on networking.

Conceptually:

```swift
SelectionEngine
    ↓
PhotoAnalysisService
    ↓
Vision / Core ML
    ↓
Local Result

// No NetworkService dependency.
```

This boundary should be reflected in the architecture rather than merely enforced by developer convention.

---

# 17. iCloud Photos

Photos Curator may encounter PhotoKit assets whose full image data is stored in iCloud rather than locally on the device.

In that case, iOS/PhotoKit may need to retrieve the asset before analysis can complete.

This does **not** mean Photos Curator uploads the image to its own backend.

The product wording should distinguish between:

```text
Apple Photos / iCloud retrieving the user's asset
```

and:

```text
Photos Curator uploading the asset
```

Photos Curator must not operate its own cloud copy of the photo.

---

# 18. Face Data Policy

Photos containing people require stricter treatment than generic image analysis.

For MVP purposes, face analysis is allowed only when necessary for photo-selection functionality.

Permitted use cases include:

- detecting whether a photo contains faces;
- counting visible faces;
- estimating whether a face is sufficiently clear;
- identifying poor face capture quality;
- comparing group-photo quality;
- determining whether an otherwise strong photograph contains badly captured faces.

Vision supports face observations and face capture-quality analysis for image-processing use cases.

---

# 19. No Person Identification

The MVP must not attempt to identify who a person is.

Do not implement:

```text
"This is John"
"This is the user's mother"
"This person appears in Instagram account X"
"This face belongs to contact Y"
```

Do not associate faces with:

- Contacts;
- social-media accounts;
- usernames;
- email addresses;
- phone numbers;
- real-world identities.

---

# 20. No Persistent Face Recognition Database

Photos Curator must not create a persistent biometric identity database.

The MVP must not permanently store:

```text
face crops
facial landmark geometry
face embeddings
identity vectors
person identity clusters
face templates
```

If temporary face observations are required during processing, they should remain in memory or temporary session storage and be discarded when no longer required.

---

# 21. Aggregate Face Features

The selection engine may retain coarse derived features where necessary for ranking.

Examples:

```swift
faceCount: Int
hasFaces: Bool
bestFaceQuality: Float?
averageFaceQuality: Float?
```

These values exist to support photo-selection decisions, not identity recognition.

Even these derived features should be treated as sensitive internal analysis data.

They must not be sent to analytics systems at an individual-photo level.

---

# 22. Face Data Must Remain On Device

MVP rule:

> Face-derived data never leaves the user's device.

This includes:

- face crops;
- bounding boxes;
- facial landmarks;
- face quality observations;
- biometric templates;
- embeddings;
- identity clusters.

Apple's current developer terms impose strict restrictions on transferring face data off-device and require clear consent when such transfer is permitted for a specific functionality. Keeping face processing local avoids introducing that category of privacy risk into the MVP.

---

# 23. Source Photo Storage

Photos Curator should generally reference photos through PhotoKit identifiers rather than duplicate source assets.

Preferred:

```swift
PHAsset.localIdentifier
```

Avoid:

```text
Application Documents/
    IMG_0001.JPG
    IMG_0002.JPG
    ...
```

unless an explicit product feature later requires exporting a separate file.

The selection engine should operate on appropriately sized image requests whenever full-resolution data is unnecessary.

---

# 24. Thumbnail Caching

Temporary thumbnails may be cached for:

- scrolling performance;
- processing;
- review screens;
- selection comparison.

Thumbnail cache rules:

1. Store only the resolution needed for the app.
2. Do not treat cached thumbnails as permanent user content.
3. Use a bounded cache.
4. Allow automatic eviction.
5. Clear stale session caches.
6. Never upload thumbnail content for analytics.

A cache miss must always be recoverable by re-requesting the asset through PhotoKit.

---

# 25. Analysis Metadata

Analysis results may be persisted locally to avoid unnecessarily analyzing the same asset repeatedly.

Example persisted information:

```swift
PhotoAnalysis {
    assetIdentifier
    analysisVersion

    sharpnessScore
    exposureScore
    aestheticScore

    faceCount
    faceQualityScore

    duplicateClusterID
    momentID

    analyzedAt
}
```

Persisting these values is acceptable when they provide measurable performance benefits.

Do not store raw intermediate Vision observations unless explicitly required.

---

# 26. Analysis Versioning

Cached analysis should have a model or algorithm version.

Example:

```swift
analysisVersion = 3
```

When analysis behavior changes significantly:

```text
Cached version = 2
Current version = 3
        ↓
Invalidate or recompute affected results
```

Privacy-relevant behavior must not depend on silently preserving obsolete analysis indefinitely.

---

# 27. Session Data

Temporary session state may contain:

- candidate asset identifiers;
- temporary ranking results;
- duplicate clusters;
- moment clusters;
- transient image features;
- temporary thumbnails.

It should be released when:

- the session finishes;
- the user cancels;
- the session becomes invalid;
- the associated assets are no longer available.

Persistent resumable-session state should contain only the minimum information necessary to resume work.

---

# 28. Location Metadata

Photos may contain location information.

The MVP should avoid reading or persisting precise GPS coordinates unless location is explicitly required by a defined selection rule.

Moment clustering should prefer:

```text
capture time
visual similarity
sequence proximity
```

before introducing precise location processing.

If approximate location later becomes useful for trip segmentation, that decision should be documented separately.

The application must not create a persistent movement or location-history profile from photo metadata.

---

# 29. EXIF Metadata

Do not extract the entire EXIF dictionary by default.

Read only fields required for the selection algorithm.

Potentially useful fields include:

```text
capture timestamp
orientation
dimensions
```

Potentially unnecessary fields include:

```text
camera serial number
precise GPS
user comments
manufacturer-specific metadata
```

Data minimization applies to metadata as well as image pixels.

---

# 30. Deletion Policy

Photos Curator's deletion policy should distinguish between:

1. user's original Photos library;
2. Photos Curator's local analysis;
3. temporary caches;
4. analytics data.

---

# 31. Original Photos

Photos Curator must never delete an original user photo automatically because the selection engine considers it bad, blurry, duplicated, or unselected.

For example:

```text
Selected
Maybe
Rejected by curator
```

are **selection decisions**, not deletion instructions.

MVP must not automatically remove assets from the user's Photos library.

---

# 32. Application Analysis Data

Users should be able to delete Photos Curator's locally cached analysis.

Recommended future Settings action:

```text
Reset Photo Analysis
```

Effect:

```text
Delete cached analysis
Delete moment assignments
Delete duplicate clusters
Delete selection history
Delete temporary thumbnails
```

Do not delete the user's original Photos assets.

---

# 33. Session Deletion

When a user explicitly removes a curation session:

Delete:

```text
session state
candidate list
selection decisions
temporary session caches
session-specific analysis not shared elsewhere
```

Preserve:

```text
original Photos library assets
```

---

# 34. App Uninstallation

The MVP must not maintain a Photos Curator cloud copy of photo-analysis data.

Therefore uninstalling the application should effectively remove application-owned local databases and caches according to normal iOS application-container behavior.

The user's Photos library remains untouched.

---

# 35. No Automatic Photo Deletion

The MVP should not contain APIs that delete Photos library assets as part of normal automated selection.

This provides an important safety boundary.

Conceptually:

```text
AI may recommend.
User decides.
```

Even future cleanup functionality should require an explicit user action and confirmation.

---

# 36. Analytics Privacy Boundary

Detailed analytics are specified in:

`11_Analytics_and_Metrics.md`

However, this privacy document defines hard boundaries.

Allowed aggregate event data may include:

```text
curation_started
curation_completed
curation_cancelled

input_photo_count
shortlist_count
final_selection_count

processing_duration_bucket
processing_failure_reason

manual_keep_count
manual_remove_count
```

Analytics must not contain:

```text
photo pixels
thumbnails
asset identifiers
filenames
EXIF
GPS coordinates
face crops
face embeddings
facial landmarks
individual face-quality scores
visual embeddings
```

---

# 37. Asset Identifiers Must Not Enter Analytics

`PHAsset.localIdentifier` should be treated as application-sensitive data.

Never emit events such as:

```json
{
  "event": "photo_selected",
  "assetID": "E1A..."
}
```

Prefer aggregate information:

```json
{
  "event": "curation_completed",
  "inputCount": 842,
  "outputCount": 96
}
```

---

# 38. User Feedback Data

Selection feedback can improve future ranking.

Examples:

```text
User restored AI-rejected photo
User removed AI-selected photo
User selected alternate duplicate
```

For MVP personalization, feedback should remain local.

Example:

```swift
SelectionFeedback {
    decisionType
    ruleCategory
    timestamp
}
```

Avoid sending actual photo identifiers or visual features to a server.

---

# 39. Logging

Production logs must contain no user photo content.

Forbidden:

```text
UIImage data
image path
photo filename
face crop
face landmarks
embedding values
GPS coordinates
full PHAsset identifier
```

Prefer:

```text
"Analysis stage completed"
"Batch size: 64"
"Vision request failed"
"Asset unavailable"
```

Debug logging should follow the same principle whenever practical.

---

# 40. Crash Reporting

If a third-party crash-reporting SDK is introduced, verify that it does not automatically capture:

- screenshots;
- view hierarchy containing photo thumbnails;
- file paths containing sensitive metadata;
- photo identifiers;
- custom logs containing analysis data.

Crash breadcrumbs should contain application-state information rather than user content.

Example:

```text
ProcessingBatch(index: 7)
```

instead of:

```text
Processing IMG_3812.JPG
```

---

# 41. Third-Party SDK Policy

The MVP should minimize third-party SDKs.

Every external SDK increases:

- privacy review complexity;
- network activity;
- App Store privacy-disclosure requirements;
- supply-chain risk;
- debugging complexity.

Before adding an SDK, answer:

```text
Why is this SDK necessary?
What data does it collect?
What domains does it contact?
Does it include a privacy manifest?
Does it perform tracking?
Can the same feature be implemented using Apple frameworks?
```

Apple requires App Store privacy disclosures to account for data practices of integrated third-party partners as well as the application's own behavior.

---

# 42. Advertising

MVP:

```text
No advertising SDK.
No ad attribution.
No advertising identifier.
No cross-app advertising profile.
```

If advertising is added later, the privacy architecture must be reassessed before implementation.

---

# 43. Tracking

MVP must not track users across unrelated applications or websites.

Therefore App Tracking Transparency should not be required solely for the core Photos Curator experience.

If a future SDK introduces tracking behavior, ATT requirements and the App Store privacy declaration must be revisited.

---

# 44. User Accounts

MVP:

```text
No mandatory account
No login
No email requirement
No phone-number requirement
No social sign-in
```

The user's Photos library authorization is sufficient to use the primary product.

This substantially reduces the amount of personal information Photos Curator must store.

---

# 45. Cloud Backend

MVP:

```text
No photo-processing backend.
No face-processing backend.
No photo backup.
No visual embedding database.
```

A lightweight backend may later be introduced for non-photo functionality such as:

- feature flags;
- anonymous metrics;
- remote configuration;
- subscription validation if required.

Such services must remain isolated from image-processing data.

---

# 46. Privacy Manifest

The Xcode target should contain an appropriate:

```text
PrivacyInfo.xcprivacy
```

when required by the APIs and SDKs used by the project.

Privacy manifests describe collected-data categories and certain APIs that require declared reasons.

Apple requires covered required-reason API usage to be declared appropriately, and invalid privacy manifests can result in App Store submission rejection.

Do not copy a generic privacy manifest from another project.

The final manifest must reflect the actual APIs and SDKs present in the compiled application.

---

# 47. Required-Reason APIs

Before App Store submission:

1. Generate or inspect the Xcode privacy report.
2. Check application code.
3. Check every third-party dependency.
4. Identify required-reason APIs.
5. Declare only reasons actually applicable to Photos Curator.
6. Remove unused SDKs or API usage where possible.

Do not invent reasons merely to satisfy validation.

Apple requires declared reasons to accurately correspond to the application's actual use of the covered APIs.

---

# 48. App Store Privacy Details

Before App Store submission, App Store Connect privacy answers must be reviewed against the shipping binary.

If the MVP truly does not collect data outside the device, the App Store privacy answers should reflect that actual implementation.

Do not automatically declare photos as "collected" merely because the application accesses the user's Photos library locally.

The final answers must depend on the precise behavior of the shipping application and all integrated SDKs.

Apple requires developers to describe application and third-party data handling in App Store Connect.

---

# 49. Privacy Policy

Photos Curator must have a publicly accessible privacy policy for App Store distribution.

Apple currently requires a privacy policy URL for iOS applications.

The application's Settings/About screen should also provide easy access to the privacy policy.

Minimum privacy-policy topics:

```text
What data Photos Curator accesses
Why Photos access is required
Whether photos leave the device
Face-analysis behavior
Analytics behavior
Third-party services
Data retention
Data deletion
How permission can be revoked
Contact information
Policy revision date
```

Apple's App Review Guidelines require privacy policies to explain data collection, use, sharing, retention/deletion, and how consent may be withdrawn.

---

# 50. Recommended In-App Privacy Screen

Settings may contain:

```text
Privacy

Photo Analysis
All photo analysis is performed on this device.

Photos Access
Limited / Full / Denied
[Manage in Settings]

Analytics
[Current configuration]

Reset Analysis Data
[Reset]

Privacy Policy
[View]
```

The screen should be informational rather than legalistic.

---

# 51. Recommended Onboarding Privacy Copy

Suggested copy:

> **Your photos stay private**
>
> Photos Curator analyzes photos directly on your iPhone to find duplicates, strong moments, clear faces, and your best images.
>
> Your photos are not uploaded to Photos Curator.

CTA:

```text
Continue
```

This screen is optional but recommended because privacy is an important product differentiator for a photo-analysis application.

---

# 52. Processing Screen Privacy Indicator

The processing screen may include a subtle message:

```text
Analyzing on this iPhone
```

or:

```text
On-device analysis
```

This reinforces the actual architecture without interrupting the workflow.

Do not display this claim if a future version starts sending image data to remote services.

---

# 53. Photo Review Screen

The review interface must not imply that AI has changed the user's original library.

For example:

Prefer:

```text
Not selected
```

over:

```text
Deleted
```

Prefer:

```text
Selected 84 of 912 photos
```

over:

```text
Removed 828 bad photos
```

unless an explicit destructive action actually occurred.

---

# 54. Screenshots and Screen Recording

The application does not need special screenshot prevention for MVP.

However, developers should recognize that photo thumbnails may appear in:

- screenshots;
- screen recordings;
- app switcher snapshots.

Avoid placing unrelated sensitive application data on the same screen.

Special screenshot-blocking behavior is unnecessary unless a concrete threat model later requires it.

---

# 55. Clipboard

Photos Curator must not automatically copy:

- image metadata;
- photo paths;
- face information;
- asset identifiers;

to the system clipboard.

Clipboard usage is not required for the core MVP.

---

# 56. Notifications

Notifications must not expose sensitive photo information.

Avoid:

```text
"We found Sarah in 43 photos."
```

Prefer:

```text
"Your photo selection is ready."
```

For MVP, processing should generally remain foreground/local rather than introducing unnecessary notification infrastructure.

---

# 57. Background Processing

If processing state is persisted for interruption recovery, persisted state must follow the same data-minimization requirements.

Background or resumable processing must not create a separate permanent copy of original photo assets.

See:

`08_Performance_Spec.md`

for interruption and resume behavior.

---

# 58. Local Database Rules

The local application database may persist:

```text
asset references
analysis scores
moment assignments
duplicate clusters
selection decisions
user feedback
algorithm versions
timestamps
```

It must not become a shadow copy of the Photos library.

Avoid fields such as:

```text
originalImageData
faceImageData
completeEXIFBlob
permanentEmbeddingBlob
```

unless a future documented requirement explicitly justifies them.

---

# 59. Sensitive Debug Features

Developer builds may expose analysis details, but debug tooling should not accidentally survive into production.

Examples:

```text
Show face rectangles
Show quality scores
Show duplicate-distance values
Show selection rule explanations
```

These are useful development tools.

Before release, confirm whether they are intended product features or `DEBUG`-only functionality.

---

# 60. Security Baseline

The privacy model relies heavily on keeping processing local.

Basic application-security requirements therefore include:

- use the app sandbox;
- avoid unnecessary shared containers;
- avoid exporting internal databases;
- do not expose cached thumbnails through publicly accessible URLs;
- use Apple's supported storage mechanisms;
- avoid writing sensitive content to plain-text logs;
- protect locally persisted data using appropriate iOS file-protection behavior.

Apple recommends protecting stored user data and using suitable iOS data-protection mechanisms.

---

# 61. App Privacy Report Validation

Before release, manually inspect the application using Apple's App Privacy Report where practical.

Verify:

```text
Photos access occurs when expected.
No unexpected Camera access.
No unexpected Microphone access.
No unexpected Contacts access.
No unexpected Location access.
No unexplained network domains.
```

Apple's App Privacy Report can show protected-resource accesses and network-domain activity generated by applications.

This is particularly useful for detecting unexpected behavior introduced by third-party SDKs.

---

# 62. MVP Permission Scope

The MVP should require only the permissions directly necessary for core functionality.

Expected:

```text
Photos
```

Not expected unless a future feature explicitly requires them:

```text
Camera
Microphone
Contacts
Location
Bluetooth
Local Network
Health
Calendars
Reminders
Motion
Tracking
```

Do not add permission descriptions speculatively.

---

# 63. Permission Architecture

A single service should own Photos authorization behavior.

Example:

```swift
protocol PhotoLibraryAuthorizationService {
    func authorizationStatus() -> PhotoLibraryAuthorizationStatus
    func requestAuthorization() async -> PhotoLibraryAuthorizationStatus
}
```

Suggested internal abstraction:

```swift
enum PhotoLibraryAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case limited
    case full
}
```

UI code should not independently implement permission logic across multiple screens.

---

# 64. Permission State Machine

Recommended state model:

```text
                    ┌─────────────────┐
                    │ notDetermined   │
                    └────────┬────────┘
                             │
                      Request access
                             │
           ┌─────────────────┼─────────────────┐
           ▼                 ▼                 ▼
       limited           authorized         denied
           │                 │                 │
           │                 │                 ▼
           │                 │         Permission Required
           │                 │                 │
           │                 │           Open Settings
           │                 │
           └──────────┬──────┘
                      ▼
                  Photo Picker
                      │
                      ▼
                 Curation
```

`.restricted` exits into a non-actionable explanatory state.

---

# 65. Selection Engine Privacy Contract

`SelectionEngine` may receive:

```swift
AssetID
PhotoAnalysis
Moment
DuplicateCluster
SelectionPreferences
```

It should not require networking or user identity.

Conceptually:

```swift
func curate(
    assets: [AnalyzedAsset],
    preferences: SelectionPreferences
) async throws -> SelectionResult
```

The engine must remain deterministic with respect to local inputs where feasible.

---

# 66. AI Model Privacy Contract

Any ML model included with the application must execute locally for MVP.

Allowed:

```text
Vision framework
Core ML model bundled with app
Core ML model downloaded as an application resource
Local heuristic algorithms
```

Not allowed for MVP:

```text
Upload photo → remote multimodal model
Upload photo → remote aesthetic scoring API
Upload face → recognition API
Upload embeddings → vector database
```

A future remote AI feature would require a new privacy-design review.

---

# 67. Product Language

Privacy claims must match engineering reality.

Allowed only while true:

```text
"Processed on your device."
"Your photos are not uploaded to Photos Curator."
"Face analysis stays on your device."
```

Do not use vague absolute marketing claims such as:

```text
"100% private forever."
"Impossible for anyone to access your photos."
"Zero privacy risk."
```

The product should communicate concrete technical behavior rather than unverifiable guarantees.

---

# 68. Privacy-Sensitive Product Changes

The following changes require updating this document before implementation:

- cloud AI;
- server-side photo analysis;
- account creation;
- cross-device synchronization;
- CloudKit analysis sync;
- face recognition;
- persistent person clustering;
- person naming;
- contact integration;
- social sharing;
- public albums;
- advertising;
- tracking;
- third-party photo analytics;
- automatic photo deletion;
- GPS-based trip history;
- model training from user photos.

These are architecture-level privacy changes, not routine feature additions.

---

# 69. Model Training Policy

MVP:

> User photos must not be used to train Photos Curator models.

This includes:

```text
original images
cropped images
faces
embeddings
selection examples containing image content
```

Local behavioral preferences may later be used for on-device personalization.

Example:

```text
User tends to prefer landscapes
User frequently restores group photos
User prefers fewer near-duplicates
```

Such personalization should remain local unless a future explicit policy says otherwise.

---

# 70. Selection Quality Research

When manually evaluating the selection engine during development, developers may use:

- developer-owned libraries;
- explicitly authorized test datasets;
- synthetic or public datasets with appropriate rights.

Do not silently copy normal users' libraries into a research dataset.

See:

`10_Manual_QA_and_Selection_Evaluation.md`.

---

# 71. Manual QA — Privacy Checklist

Privacy validation is performed manually for this project.

No dedicated automated privacy test target is required.

Before every release candidate, verify:

### Permissions

- [ ] App does not request Photos access at launch without context.
- [ ] Permission explanation is understandable.
- [ ] `NSPhotoLibraryUsageDescription` matches actual behavior.
- [ ] `.authorized` works.
- [ ] `.limited` works.
- [ ] `.denied` works.
- [ ] `.restricted` is handled.
- [ ] Changing permission in Settings updates app behavior.
- [ ] App does not repeatedly pressure users to grant Full Access.

### Photo data

- [ ] No permanent duplicate of original photos is created.
- [ ] Thumbnail caches are bounded.
- [ ] Temporary processing data is cleaned up.
- [ ] Photos are not sent to Photos Curator servers.
- [ ] Asset identifiers do not appear in analytics.

### Face data

- [ ] Face processing runs locally.
- [ ] No face crops are uploaded.
- [ ] No facial embeddings are uploaded.
- [ ] No person identities are created.
- [ ] No permanent biometric database exists.
- [ ] Raw facial landmarks are not unnecessarily persisted.

### Networking

- [ ] App works without a Photos Curator photo-processing backend.
- [ ] Network traffic contains no photo bytes.
- [ ] Network traffic contains no thumbnails.
- [ ] Network traffic contains no face information.
- [ ] All contacted domains are understood.

### Logging

- [ ] Production logs contain no photo content.
- [ ] Production logs contain no face data.
- [ ] Logs contain no GPS metadata.
- [ ] Logs contain no raw asset identifiers.

### Third-party SDKs

- [ ] Every SDK is necessary.
- [ ] Every SDK's privacy behavior is understood.
- [ ] SDK privacy manifests are valid when applicable.
- [ ] App privacy declarations include relevant third-party behavior.

### App Store

- [ ] Privacy policy URL exists.
- [ ] Privacy policy is accessible inside the app.
- [ ] App Store Connect privacy answers match shipping behavior.
- [ ] `PrivacyInfo.xcprivacy` is valid where applicable.
- [ ] Required-reason APIs have legitimate declarations.
- [ ] No unnecessary protected-resource permission strings exist.

---

# 72. Privacy Acceptance Criteria

The MVP privacy implementation is complete when all of the following are true.

## AC-01 — Contextual permission

Given a fresh install,

when the user launches Photos Curator,

the app does not immediately request Photos access before explaining why the permission is needed.

---

## AC-02 — Full access

Given Photos access is `.authorized`,

the user can run a curation session normally.

---

## AC-03 — Limited access

Given Photos access is `.limited`,

the user can curate accessible photos without being blocked.

---

## AC-04 — Denied access

Given Photos access is `.denied`,

the app presents an explanatory state and a path to system Settings without repeatedly showing the system authorization dialog.

---

## AC-05 — Permission changes

Given the user changes Photos permission while outside the app,

when Photos Curator becomes active again,

the application correctly reflects the new authorization state.

---

## AC-06 — No photo upload

During a complete curation session,

no original photo pixels or thumbnail pixels are transmitted to a Photos Curator backend.

---

## AC-07 — Face privacy

During face-related photo analysis,

face observations and derived biometric information remain on the device.

---

## AC-08 — No identity recognition

The application never assigns real-world identities to detected faces.

---

## AC-09 — Non-destructive AI

Rejecting a photo during AI selection does not delete the corresponding asset from the user's Photos library.

---

## AC-10 — Reset

When local analysis data is reset,

Photos Curator removes its cached analysis while preserving the user's original Photos assets.

---

## AC-11 — Analytics isolation

Analytics events contain no:

```text
photo pixels
thumbnail pixels
face data
GPS
filenames
PHAsset identifiers
```

---

## AC-12 — Offline core workflow

After required iCloud-hosted assets are locally available, the core selection engine can operate without requiring communication with a Photos Curator server.

---

# 73. Non-Goals

The MVP privacy design does not attempt to solve:

- end-to-end encrypted cloud synchronization;
- Photos Curator account security;
- multi-user collaboration;
- public photo sharing;
- biometric authentication;
- server-side image inference;
- federated ML training;
- private cloud model training;
- automatic library cleanup;
- permanent people recognition;
- legal compliance automation across every jurisdiction.

These should not be added unless a product requirement justifies the additional complexity.

---

# 74. Future Privacy Review Triggers

A formal review of this document is mandatory before adding:

```text
Server-side AI
CloudKit synchronization
Person recognition
Face embeddings
Shared albums
Social features
Automatic deletion
Ads
Tracking
Account systems
User-generated public content
Photo model training
```

Each change should answer:

1. What new data is accessed?
2. Why is it required?
3. Where is it processed?
4. Where is it stored?
5. How long is it retained?
6. Is it transmitted?
7. Who receives it?
8. Can the feature work with less data?
9. How can the user revoke access?
10. How can the user delete the data?

---

# 75. MVP Decisions Summary

The privacy decisions for Photos Curator MVP are:

| Decision | MVP |
|---|---|
| Photo analysis | On-device |
| Full Photos access | Optional when Limited Access is usable |
| Limited Photos access | Supported |
| Original photo upload | No |
| Thumbnail upload | No |
| Face detection | Allowed locally |
| Face quality analysis | Allowed locally |
| Person identification | No |
| Persistent facial embeddings | No |
| Face-data upload | No |
| Automatic original-photo deletion | No |
| Mandatory account | No |
| Advertising | No |
| Cross-app tracking | No |
| Remote AI | No |
| Persistent application photo copy | No |
| Local analysis cache | Yes |
| Anonymous aggregate analytics | Optional |
| App privacy policy | Required |
| Privacy manifest review | Required |
| Manual privacy QA | Required |
| Automated privacy/unit/UI tests | Not required |

---

# 76. Guiding Rule

Whenever an implementation decision is unclear, use the following default:

> If Photos Curator can deliver the feature without collecting, storing, or transmitting additional personal data, choose the implementation that uses less data.

For this product, strong privacy is not only a compliance property.

It is part of the architecture:

```text
User's Photo Library
        ↓
On-device Analysis
        ↓
On-device Selection
        ↓
User Review
        ↓
User-controlled Result
```

No unnecessary cloud layer is required.

---

# 77. References

This specification should be reviewed against the current Apple documentation before each major App Store release because platform APIs and submission requirements can change.

Key Apple resources include:

- PhotoKit authorization and limited-library access.
- Vision face detection and face capture-quality APIs.
- Apple's privacy and data-minimization guidance.
- Privacy manifests and required-reason APIs.
- App Store Connect privacy disclosures.
- Apple Developer Program rules concerning Face Data.

---

# 78. Final Engineering Principle

For the MVP:

```text
Photos Curator should know enough about a photo to decide whether it is worth keeping.

It should not know more about the user than necessary to make that decision.
```