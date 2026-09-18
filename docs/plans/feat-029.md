# Immersive Photo Inspection Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn S11 into a fullscreen, gesture-safe photo inspector that lets users inspect details without weakening selection, paging, privacy, or memory guarantees.

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
- Vertical gestures never dismiss, remove, restore, or page a photo.
- Respect Dynamic Type, Reduce Motion, safe areas, portrait, and landscape.
- Do not add test targets, `*Test*.swift` files, test frameworks, or a manual-QA gate. Required evidence is `scripts/proof/feat-029.sh` plus `./init.sh`.

---

## File structure

- Modified during feature definition: `docs/product-specs/ux-flows.md` — durable S11 inspection behavior and accessible alternatives.
- Create `apps/photo-curator/Features/Review/PhotoInspectionState.swift` — pure fit/zoom/pan/page state and bounds math; no SwiftUI view or pixels.
- Create `apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift` — fullscreen image canvas, gesture wiring, and non-gesture inspection controls.
- Modify `apps/photo-curator/Features/Review/PhotoDetail.swift` — session-aware load lifecycle, fullscreen S11 shell, pager/selection/analysis integration.
- Create `scripts/proof/feat-029-proof.swift` — deterministic interaction-state proof compiled with the state source.
- Create `scripts/proof/feat-029.sh` — stages the shipped state source, runs the proof, asserts the required view accessibility surface, and exits nonzero on a regression.
- Modify `features/feat-029.md` and `progress.md` only while activating, verifying, or closing the feature.

### Task 1: Build a deterministic inspection state machine and proof

**Files:**

- Create: `apps/photo-curator/Features/Review/PhotoInspectionState.swift`
- Create: `scripts/proof/feat-029-proof.swift`
- Create: `scripts/proof/feat-029.sh`

**Interfaces:**

- Consumes: viewport size, aspect-fit rendered image size, gesture magnification/translation, and the active pager index.
- Produces: `PhotoInspectionState`, which exposes `scale`, `offset`, `isAtFit`, `reset()`, bounded zoom/pan updates, and one-step paging eligibility.

- [ ] Define a value type that imports `CoreGraphics` only and starts at `scale == 1` with `.zero` offset.
- [ ] Define the constants in one place: `fitScale = 1`, `doubleTapScale = 2`, and `maximumScale = 3`.
- [ ] Implement a clamp that restricts scale to `1...3` and offset to the excess rendered image area at the current scale. When an axis has no excess, its offset is zero.
- [ ] Implement `reset()` to return exactly to Fit and centered offset.
- [ ] Implement a double-tap transition: Fit → `doubleTapScale`; any zoomed state → Fit.
- [ ] Expose `canPageHorizontally` only when `scale` equals Fit and the horizontal drag clears a documented minimum translation. Do not infer page direction while zoomed.
- [ ] Write the Swift proof as an executable, not a test target. Compile the shipped state source together with the proof using `swiftc`.
- [ ] Assert: scale clamps at 3; offset clamps on both axes; reset clears the offset; Fit drag produces one page direction; zoomed drag produces no page; and changing an asset resets state.
- [ ] In `feat-029.sh`, fail if the proof source differs from the staged state source, then compile and run the proof. Print named PASS lines for each asserted rule.
- [ ] Run `./scripts/proof/feat-029.sh` and record the exact output in the active feature handoff.

### Task 2: Implement the fullscreen canvas and accessible controls

**Files:**

- Create: `apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift`
- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`

**Interfaces:**

- Consumes: `CGImage?`, `PhotoInspectionState`, `isLoading`, `loadFailed`, the active pager position, and closures for `back`, `previous`, `next`, `toggleSelection`, `showAnalysis`, and `retry`.
- Produces: `PhotoInspectionCanvas` with one `@Binding var inspectionState: PhotoInspectionState` and no `ReviewModel` or PhotoKit dependency.

- [ ] Render the image edge-to-edge on a near-black canvas with aspect-fit content. Keep every overlay inside the safe area and readable over light or dark images.
- [ ] Render loading as a neutral placeholder that retains Back and pager controls where valid. Render failure as “We couldn't load this photo.” with **Try Again** and **Back**.
- [ ] Add a top overlay with Back and `current / total`; add a bottom overlay with explicit **In Album**/**Removed**, **View Analysis**, and a visible **Fit** action only while zoomed.
- [ ] Add previous/next buttons with disabled first/last boundaries. Do not wrap the pager.
- [ ] Wire pinch and double-tap to the state machine. While zoomed, route drag translation to bounded panning; at Fit, route a qualifying horizontal drag to the pager closure. Ignore vertical-drag decisions.
- [ ] Reset the transform whenever `currentAssetID` changes, on retry before a successful new image displays, and after the user activates **Fit**.
- [ ] Let one tap hide/show decorative chrome only. Essential VoiceOver actions remain available even when visual chrome is hidden.
- [ ] Add accessibility labels and hints for photo position, selected/removed state, Previous photo, Next photo, View Analysis, Fit, zoom state, Try Again, and Back. Add custom accessible zoom-in/zoom-out or reset actions.
- [ ] Use 44-point minimum interactive frames, text labels plus symbols, system Dynamic Type styles, and Reduce Motion-aware state transitions.
- [ ] Run `swiftlint lint --strict apps/photo-curator/Features/Review/PhotoInspectionState.swift apps/photo-curator/Features/Review/PhotoInspectionCanvas.swift apps/photo-curator/Features/Review/PhotoDetail.swift`.

### Task 3: Preserve review and PhotoKit lifecycle invariants

**Files:**

- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`
- Inspect only: `apps/photo-curator/Features/Review/CuratedGrid.swift`, `SimilarGroups.swift`, `RemovedPhotos.swift`, `NeedsReview.swift`, `ReviewModel.swift`, `apps/photo-curator/Services/ServiceProtocols.swift`, `apps/photo-curator/Services/Photos/ImageLoaderService.swift`

**Interfaces:**

- Consumes: `PhotoImageLoader.preview(for:targetSize:)`, `ReviewModel.toggle(_:)`, `ReviewModel.isSelected(_:)`, `appModel.path`, and existing `pagerIDs`.
- Produces: a full-screen S11 that preserves all existing caller and loading contracts without a service API change.

- [ ] Retain the current task-cancellation and stale-result token guards. A cancelled A→B→C request must not mark A or B as failed or overwrite C.
- [ ] Retain one bounded `CGImage?` in `PhotoDetail`; set it to `nil` before a new asset load and when the view disappears.
- [ ] Keep the existing `PhotoImageLoader.preview` request and 2048-pixel cap. Do not change `ServiceProtocols.swift` or `ImageLoaderService.swift` unless measured feature evidence proves that this bounded request cannot support the agreed inspector; any exception requires a revised plan and explicit bounded memory proof.
- [ ] Route the selection control directly to `model.toggle(currentAssetID)`. Re-read `model.isSelected(currentAssetID)` on render; do not add local selected state.
- [ ] Preserve `View Analysis` navigation for the current asset and return to the same pager context afterward.
- [ ] Preserve every caller's supplied `pagerIDs` order. Navigation and selection edits must not rebuild or reorder the active pager.
- [ ] Verify by source inspection that no change is needed in the four entry surfaces or `ReviewModel`; if a caller contract must change, stop and amend this plan before coding it.

### Task 4: Run reproducible evidence and close only after all gates pass

**Files:**

- Modify: `features/feat-029.md`
- Modify: `progress.md`

**Interfaces:**

- Consumes: the shipped transform source, fullscreen canvas source, `PhotoDetail`, repository proof script, and workspace verification command.
- Produces: feature evidence sufficient to mark `feat-029` done.

- [ ] Run `./scripts/proof/feat-029.sh`; require named PASS output for clamp, Fit-page, zoom-pan, reset-on-asset-change, current-only result, and required accessibility-control assertions.
- [ ] Run a reproducible Simulator build/install/launch smoke against the current scheme. Record the device identifier, launch result, and no-crash evidence; do not make a manual walkthrough a gate.
- [ ] Run `./init.sh` and require format PASS, strict SwiftLint PASS, Simulator `BUILD SUCCEEDED`, and policy test SKIP.
- [ ] Verify `git diff --check` is clean and no `*Test*.swift` files or test targets were added.
- [ ] Check every acceptance box only with its corresponding proof/build evidence. Record commands, output, unavailable-path result, and no-service-contract-change result in `features/feat-029.md`.
- [ ] Append one concise `progress.md` block with result, evidence, blockers, and one next action; then mark `feature_index.json` and `features/feat-029.md` done only if every acceptance item passes.
