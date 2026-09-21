# Immersive Photo Inspection Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn S11 into a fullscreen, gesture-safe, visually polished photo inspector that lets users inspect details without weakening selection, paging, privacy, or memory guarantees.

**Architecture:** Keep `PhotoDetail` as the session-aware coordinator: it owns the current `AssetID`, calls the existing bounded `PhotoImageLoader.preview`, and delegates selection to `ReviewModel`. Add a value-type inspection transform state for zoom/pan/page arbitration and a focused SwiftUI canvas for fullscreen rendering. The transform state is compiled into a repository proof; the view layer consumes it without storing pixels outside the current `CGImage`.

**Tech Stack:** Swift 5, SwiftUI, Observation, CoreGraphics, existing PhotoKit-backed `PhotoImageLoader`, repository proof scripts, iOS Simulator build.

## Global Constraints

- Activate `feat-029` only after user selection; keep it the sole active feature.
- Preserve the existing `PhotoDetail(assetID:sessionID:pagerIDs:)` callers and their context-local pager order.
- Keep `ReviewModel` as the sole selection state. Call `ReviewModel.toggle(_:)`; never mirror selected state in the viewer.
- Request only `PhotoImageLoader.preview`; retain the existing 2048-pixel cap and never request original/full-resolution pixels.
- Retain one current `CGImage` only. Cancel superseded loads, clear it on exit, and reject stale results.
- Keep PhotoKit behind `PhotoImageLoader`. Do not persist image pixels, add cache fields, or change selection/ranking/analysis behavior.
- Do not make pinch, drag, or double-tap the only path: provide operable buttons and VoiceOver actions.
- At Fit, a deliberate downward swipe dismisses S11; at zoom, vertical gestures pan and never dismiss, remove, restore, or page a photo.
- Scope tap, double-tap, and drag inspection gestures to the image surface; chrome buttons must not wait for gesture arbitration.
- Keep native `NavigationLink` dismissal unless the focused gesture-scope fix fails to remove the Back delay; do not broaden to modal navigation preemptively.
- Respect Dynamic Type, Reduce Motion, safe areas, portrait, and landscape.
- Do not add test targets, `*Test*.swift` files, test frameworks, standalone proof files, or a manual-QA gate. Required verification is `./init.sh`.

---

## File structure

- Modified during feature definition: `docs/product-specs/ux-flows.md` — durable S11 inspection behavior and accessible alternatives.
- Create `apps/photo-curator/Features/Review/PhotoInspectionState.swift` — pure fit/zoom/pan/page state and bounds math; no SwiftUI view or pixels.
- Create `apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift` — fullscreen image canvas, gesture wiring, and non-gesture inspection controls.
- Modify `apps/photo-curator/Features/Review/PhotoDetail.swift` — session-aware load lifecycle, fullscreen S11 shell, pager/selection/analysis integration.
- Modify `features/feat-029.md` and `progress.md` only while activating, verifying, or closing the feature.

### Task 1: Build a deterministic inspection state machine

**Files:**

- Create: `apps/photo-curator/Features/Review/PhotoInspectionState.swift`

**Interfaces:**

- Consumes: viewport size, aspect-fit rendered image size, gesture magnification/translation, and the active pager index.
- Produces: `PhotoInspectionState`, which exposes `scale`, `offset`, `isAtFit`, `reset()`, bounded zoom/pan updates, and one-step paging eligibility.

- [x] Define a value type that imports `CoreGraphics` only and starts at `scale == 1` with `.zero` offset.
- [x] Define the constants in one place: `fitScale = 1`, `doubleTapScale = 2`, and `maximumScale = 6`.
- [x] Implement a clamp that restricts scale to `1...6` and offset to the excess rendered image area at the current scale. When an axis has no excess, its offset is zero.
- [x] Implement `reset()` to return exactly to Fit and centered offset.
- [x] Implement a double-tap transition: Fit → `doubleTapScale`; any zoomed state → Fit.
- [x] Expose `canPageHorizontally` only when `scale` equals Fit and the horizontal drag clears a documented minimum translation. Expose Fit-only downward dismissal separately; do not infer either action while zoomed.
- [x] Implement the state rules in the shipped Swift source and run `./init.sh` after the change.

### Task 2: Implement the fullscreen canvas and accessible controls

**Files:**

- Create: `apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift`
- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`

**Interfaces:**

- Consumes: `CGImage?`, `PhotoInspectionState`, `isLoading`, `loadFailed`, the active pager position, and closures for `back`, `previous`, `next`, `toggleSelection`, `showAnalysis`, and `retry`.
- Produces: `PhotoInspectionCanvas` with one `@Binding var inspectionState: PhotoInspectionState` and no `ReviewModel` or PhotoKit dependency.

- [x] Render the image edge-to-edge on a near-black canvas with aspect-fit content. Keep every overlay inside the safe area and readable over light or dark images.
- [x] Render loading as a neutral placeholder that retains Back and pager controls where valid. Render failure as “We couldn't load this photo.” with **Try Again** and **Back**.
- [x] Add a top overlay with Back and `current / total`; add a bottom overlay with explicit **In Album**/**Removed**, **View Analysis**, and a visible **Fit** action only while zoomed.
- [x] Add previous/next buttons with disabled first/last boundaries. Do not wrap the pager.
- [x] Wire pinch and double-tap to the state machine. While zoomed, route drag translation to bounded panning; at Fit, route qualifying horizontal drags to paging and qualifying downward drags to the dismiss closure.
- [x] Reset the transform whenever `currentAssetID` changes, on retry before a successful new image displays, and after the user activates **Fit**.
- [x] Let one tap hide/show decorative chrome only. Essential VoiceOver actions remain available even when visual chrome is hidden.
- [x] Add accessibility labels and hints for photo position, selected/removed state, Previous photo, Next photo, View Analysis, Fit, zoom state, Try Again, and Back. Add custom accessible zoom-in/zoom-out or reset actions.
- [x] Use 44-point minimum interactive frames, text labels plus symbols, system Dynamic Type styles, and Reduce Motion-aware state transitions.
- [x] Run `swiftlint lint --strict apps/photo-curator/Features/Review/PhotoInspectionState.swift apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift apps/photo-curator/Features/Review/PhotoDetail.swift`.

### Task 5: Polish S11 chrome, motion, and gesture ownership

**Files:**

- Modify: `apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift`
- Modify: `features/feat-029.md` and `progress.md` only while verifying and closing this follow-up.

**Interfaces:**

- Consumes: the existing `PhotoInspectionState`, image/pager callbacks, `accessibilityReduceMotion`, and current S11 accessibility labels.
- Produces: Liquid Glass control islands with a material fallback, scoped image-only gestures, animated chrome/image state changes, responsive button feedback, and unchanged pager/selection/navigation contracts.

- [x] Move single-tap, double-tap, magnification, and drag recognizers from the full canvas onto the image interaction surface so Back and other controls receive taps immediately.
- [x] Replace the large opaque chrome panels and default bordered styles with iOS 26 Liquid Glass islands: Back/position at top-left, Previous/Next at top-right, lower selection/analysis/Fit actions, continuous rounded corners, explicit accessibility labels, 44-point hit targets, and a translucent-material fallback.
- [x] Animate chrome visibility with short edge-aware fade/offset transitions; crossfade loading/image changes; animate discrete zoom/page actions with a responsive spring or ease curve; keep continuous pinch/pan unanimated.
- [x] Add selection/page sensory feedback only to discrete actions and preserve Reduce Motion behavior for all explicit animations.
- [x] Run focused SwiftFormat/SwiftLint, `./init.sh`, Simulator launch smoke, and `git diff --check`; record evidence before closing the feature.

### Task 3: Preserve review and PhotoKit lifecycle invariants

**Files:**

- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`
- Inspect only: `apps/photo-curator/Features/Review/CuratedGrid.swift`, `SimilarGroups.swift`, `RemovedPhotos.swift`, `NeedsReview.swift`, `ReviewModel.swift`, `apps/photo-curator/Services/ServiceProtocols.swift`, `apps/photo-curator/Services/Photos/ImageLoaderService.swift`

**Interfaces:**

- Consumes: `PhotoImageLoader.preview(for:targetSize:)`, `ReviewModel.toggle(_:)`, `ReviewModel.isSelected(_:)`, `appModel.path`, and existing `pagerIDs`.
- Produces: a full-screen S11 that preserves all existing caller and loading contracts without a service API change.

- [x] Retain the current task-cancellation and stale-result token guards. A cancelled A→B→C request must not mark A or B as failed or overwrite C.
- [x] Retain one bounded `CGImage?` in `PhotoDetail`; set it to `nil` before a new asset load and when the view disappears.
- [x] Keep the existing `PhotoImageLoader.preview` request and 2048-pixel cap. Do not change `ServiceProtocols.swift` or `ImageLoaderService.swift` unless measured feature evidence proves that this bounded request cannot support the agreed inspector; any exception requires a revised plan and explicit bounded memory proof.
- [x] Route the selection control directly to `model.toggle(currentAssetID)`. Re-read `model.isSelected(currentAssetID)` on render; do not add local selected state.
- [x] Preserve `View Analysis` navigation for the current asset and return to the same pager context afterward; Back and Fit-only downward dismissal pop only S11.
- [x] Preserve every caller's supplied `pagerIDs` order. Navigation and selection edits must not rebuild or reorder the active pager.
- [x] Verify by source inspection that no change is needed in the four entry surfaces or `ReviewModel`; if a caller contract must change, stop and amend this plan before coding it.

### Task 4: Run reproducible evidence and close only after all gates pass

**Files:**

- Modify: `features/feat-029.md`
- Modify: `progress.md`

**Interfaces:**

- Consumes: the shipped transform source, fullscreen canvas source, `PhotoDetail`, and workspace verification command.
- Produces: feature evidence sufficient to mark `feat-029` done.

- [x] Run `./init.sh` and record the verification result for the shipped transform, pager, and accessibility changes.
- [x] Run a reproducible Simulator build/install/launch smoke against the current scheme. Record the device identifier, launch result, and no-crash evidence; do not make a manual walkthrough a gate.
- [x] Run `./init.sh` and require format PASS, strict SwiftLint PASS, Simulator `BUILD SUCCEEDED`, and policy test SKIP.
- [x] Verify `git diff --check` is clean and no `*Test*.swift` files or test targets were added.
- [x] Check every acceptance box with the implementation review and `./init.sh` evidence. Record the command, output, unavailable-path result, and no-service-contract-change result in `features/feat-029.md`.
- [x] Append one concise `progress.md` block with result, evidence, blockers, and one next action; then mark `feature_index.json` and `features/feat-029.md` done only if every acceptance item passes.
