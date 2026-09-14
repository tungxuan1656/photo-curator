# feat-009 — Review Core (Overview/Grid/Detail) Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the feat-008 result inspectable and manually adjustable through S09 overview, S10 grid, and S11 detail.

**Architecture:** One session-owned `ReviewModel` wraps the persisted chronological `SelectionResult` plus frozen `PhotoAsset` metadata; new routes reuse `.reviewReady` as the entry; overview/grid/detail mutate only that model while thumbnails and a bounded 2048 px detail preview reuse the single `PHCachingImageManager` pipeline; edits stay session-local and no engine rerun occurs.

**Tech Stack:** Swift 5, SwiftUI/Observation + `NavigationStack`, `ScrollView`/`LazyVGrid`, PhotoKit `PHCachingImageManager`, existing `AsyncPhotoThumbnail` seam.

## Global Constraints

- Start only after feat-008 is recorded done; one active feature at a time.
- Review edits are session-local while `AppModel.reviewModel` exists; add no persistence, engine rerun, export, groups, removed-browsing, or final-review work (feat-010/011/012 own those).
- Show no raw score, Vision term, deletion vocabulary, trash icon, or custom zoom/swipe gesture state.
- All view-owned `@State` is private; `ForEach` identity is `AssetID`; cells receive small value inputs.
- Use modern `NavigationStack`/`NavigationLink(value:)`, dedicated accessibility modifiers, `foregroundStyle`, `.alert(_:isPresented:actions:message:)`; no Liquid Glass or unrelated iOS 26 visuals.
- No third-party dependency, test target, `*Test*.swift`, mock-only architecture, persistent debug artifact.

---

## File Structure

- Create `apps/photo-curator/Features/Review/ReviewModel.swift` — `@MainActor @Observable` session state: `selectedIDs`, `displayIDs`, remove/restore/toggle/undo.
- Modify `apps/photo-curator/App/AppModel.swift` — `reviewModel` plus `beginReview(for:)` from persisted result + frozen assets.
- Modify `apps/photo-curator/App/AppRoute.swift` — add `.reviewOverview(sessionID:)` and `.curatedGrid(sessionID:)`.
- Modify `apps/photo-curator/App/RootView.swift` — route both only on matching `reviewModel`; otherwise recoverable load state.
- Modify `apps/photo-curator/Features/Processing/ProcessingView.swift:147-154` — Continue calls `beginReview`; add zero-pick abnormal state.
- Create `apps/photo-curator/Features/Review/ReviewOverview.swift` — S09 counts plus two actions into `.curatedGrid`.
- Create `apps/photo-curator/Features/Review/CuratedGrid.swift` — S10 lazy grid, dim-don't-shift removal, count, Undo.
- Modify `apps/photo-curator/Services/ServiceProtocols.swift:26-29` + `NoopImageLoader` — add `preview(for:targetSize:)`.
- Modify `apps/photo-curator/Services/Photos/ImageLoaderService.swift:16-25` — implement bounded `.aspectFit` preview.
- Create `apps/photo-curator/Features/Review/PhotoDetail.swift` — S11 local pager, bounded preview, In Album/Removed toggle.
- Modify `features/feat-009.md` — link this plan; record device evidence on close.

---

### Task 1: ReviewModel session state

**Files:**
- Create: `apps/photo-curator/Features/Review/ReviewModel.swift`

**Interfaces:**
- Consumes: `SessionID`, `SelectionResult`, `[AssetID: PhotoAsset]`.
- Produces: `@MainActor @Observable final class ReviewModel { let sessionID: SessionID; let result: SelectionResult; let sourceByID: [AssetID: PhotoAsset]; private(set) var selectedIDs: Set<AssetID>; let displayIDs: [AssetID]; private(set) var lastRemovedID: AssetID?; var selectedAssetIDs: [AssetID]; func isSelected(_:) -> Bool; func remove/restore/toggle/undoLastRemoval }`.

- [ ] **Step 1: Implement the model**

```swift
import Foundation
import Observation

@MainActor @Observable
final class ReviewModel {
    let sessionID: SessionID
    let result: SelectionResult
    let sourceByID: [AssetID: PhotoAsset]
    private(set) var selectedIDs: Set<AssetID>
    let displayIDs: [AssetID]
    private(set) var lastRemovedID: AssetID?

    init(sessionID: SessionID, result: SelectionResult, sourceByID: [AssetID: PhotoAsset]) {
        self.sessionID = sessionID
        self.result = result
        self.sourceByID = sourceByID
        self.selectedIDs = Set(result.selectedAssetIDs)
        self.displayIDs = result.selectedAssetIDs
    }

    var selectedAssetIDs: [AssetID] {
        displayIDs.filter(selectedIDs.contains)
    }

    func isSelected(_ id: AssetID) -> Bool { selectedIDs.contains(id) }

    func remove(_ id: AssetID) {
        guard selectedIDs.remove(id) != nil else { return }
        lastRemovedID = id
    }

    func restore(_ id: AssetID) {
        guard displayIDs.contains(id) else { return }
        selectedIDs.insert(id)
    }

    func toggle(_ id: AssetID) {
        if isSelected(id) { remove(id) } else { restore(id) }
    }

    func undoLastRemoval() {
        guard let id = lastRemovedID else { return }
        restore(id)
        lastRemovedID = nil
    }
}
```

- [ ] **Step 2: Verify model gate**

Run: `./init.sh`
Expected: PASS; no caller yet.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Review/ReviewModel.swift
git commit -m "feat(009): add session review model"
```

---

### Task 2: AppModel entry + routes + root wiring

**Files:**
- Modify: `apps/photo-curator/App/AppModel.swift` (near `showReview`/`loadResult`)
- Modify: `apps/photo-curator/App/AppRoute.swift:4-16`
- Modify: `apps/photo-curator/App/RootView.swift:19-38`

**Interfaces:**
- Consumes: `ReviewModel`, `confirmedSourceAssets()`, `container.checkpointStore.loadResult`, `processing.progress.unavailableCount`.
- Produces: `private(set) var reviewModel: ReviewModel?`; `func beginReview(for sessionID: SessionID) async`; routes `.reviewOverview(sessionID:)` and `.curatedGrid(sessionID:)`.

- [ ] **Step 1: Add beginReview and routes**

```swift
private(set) var reviewModel: ReviewModel?

func beginReview(for sessionID: SessionID) async {
    guard let result = await loadResult(for: sessionID), result.sessionID == sessionID, !result.selectedAssetIDs.isEmpty else { return }
    let live = Dictionary(uniqueKeysWithValues: confirmedSourceAssets().map { ($0.id, $0) })
    reviewModel = ReviewModel(sessionID: sessionID, result: result, sourceByID: live)
    path.append(.reviewOverview(sessionID: sessionID))
}
```

```swift
case reviewOverview(sessionID: SessionID)
case curatedGrid(sessionID: SessionID)
```

```swift
case let .reviewOverview(id):
    if appModel.reviewModel?.sessionID == id {
        ReviewOverview(sessionID: id)
    } else {
        ReviewLoadFailedView(sessionID: id)
    }
case let .curatedGrid(id):
    if appModel.reviewModel?.sessionID == id {
        CuratedGrid(sessionID: id)
    } else {
        ReviewLoadFailedView(sessionID: id)
    }
```

Implement `ReviewLoadFailedView` as a small private view in `RootView.swift` (or `ReviewOverview.swift` if cleaner): title “We couldn't load your selection.”, footnote “Your progress is saved.”, plus Try Again (calls `beginReview`) and Back to Home. Keep unavailable counts out-of-band; do not add `SelectionResult.unavailableCount`.

- [ ] **Step 2: Wire Continue from ReviewReady**

```swift
Button("Continue") {
    Task { await appModel.beginReview(for: sessionID) }
}
.buttonStyle(.borderedProminent)
```

When the loaded result is empty, render the abnormal state instead of navigating: “We couldn't build a selection” with Try Again (`retryProcessing`) and Choose Different Photos (`goHome` + source selection). Preserve explicit user action; no auto-route.

- [ ] **Step 3: Verify navigation gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/App/AppModel.swift apps/photo-curator/App/AppRoute.swift apps/photo-curator/App/RootView.swift apps/photo-curator/Features/Processing/ProcessingView.swift
git commit -m "feat(009): wire review entry and routes"
```

---

### Task 3: S09 overview

**Files:**
- Create: `apps/photo-curator/Features/Review/ReviewOverview.swift`

**Interfaces:**
- Consumes: `ReviewModel` via `@Environment(AppModel.self)`, `AppRoute.curatedGrid`.
- Produces: `struct ReviewOverview: View { let sessionID: SessionID }`.

- [ ] **Step 1: Implement overview**

```swift
import SwiftUI

struct ReviewOverview: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                let total = model.result.selectedAssetIDs.count + model.result.rejectedAssetIDs.count
                VStack(spacing: 12) {
                    Text("Your curated album is ready").font(.title2.bold())
                    Text("\(model.selectedIDs.count) selected from \(total) photos")
                    Button("Review Selection") { appModel.path.append(.curatedGrid(sessionID: sessionID)) }
                        .buttonStyle(.borderedProminent)
                    Button("Review & Save") { appModel.path.append(.curatedGrid(sessionID: sessionID)) }
                }.padding()
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Review")
    }
}
```

Hide Similar/Removed entries entirely until feat-010; show no scores, Vision terms, or deletion copy.

- [ ] **Step 2: Verify overview gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Review/ReviewOverview.swift
git commit -m "feat(009): add review overview"
```

---

### Task 4: S10 curated grid

**Files:**
- Create: `apps/photo-curator/Features/Review/CuratedGrid.swift`

**Interfaces:**
- Consumes: `ReviewModel`, `AsyncPhotoThumbnail(assetID:targetSizePixels:)`, `PhotoDetail` route (Task 5 presents it via `NavigationLink(value:)` with an `AssetID` destination handled in `RootView` or locally).
- Produces: `struct CuratedGrid: View { let sessionID: SessionID }` with dim-don't-shift cells, persistent count, Undo.

- [ ] **Step 1: Implement the lazy grid**

```swift
import SwiftUI
import UIKit

struct CuratedGrid: View {
    let sessionID: SessionID
    @Environment(AppModel.self) private var appModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if let model = appModel.reviewModel, model.sessionID == sessionID {
                VStack {
                    Text("\(model.selectedIDs.count) selected").font(.headline)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(model.displayIDs, id: \.self) { id in
                                ReviewCell(assetID: id, isSelected: model.isSelected(id))
                            }
                        }
                    }
                    if let undone = model.lastRemovedID {
                        Button("Undo") { model.undoLastRemoval() }
                    }
                }
            } else {
                ProgressView("Loading your selection…")
            }
        }
        .navigationTitle("Selection")
    }
}

private struct ReviewCell: View {
    let assetID: AssetID
    let isSelected: Bool
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: assetID) {
                AsyncPhotoThumbnail(assetID: assetID, targetSizePixels: CGSize(width: 400, height: 400))
                    .aspectRatio(1, contentMode: .fill)
                    .opacity(isSelected ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            Button(isSelected ? "Remove from album" : "Add to album") {
                appModel.reviewModel?.toggle(assetID)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        }
    }
}
```

Size `targetSizePixels` from display scale like SourceSelection (`UIScreen.main.bounds.width / 3 * scale`, clamped 200–500) instead of the fixed 400 above. Register `navigationDestination(for: AssetID.self)` for `PhotoDetail(assetID:)` at the grid level (or in `RootView` if the existing route switch is cleaner). Removed cells stay dimmed in place; the checkmark button never navigates.

- [ ] **Step 2: Verify grid gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Review/CuratedGrid.swift
git commit -m "feat(009): add curated grid"
```

---

### Task 5: Detail preview seam + S11 detail

**Files:**
- Modify: `apps/photo-curator/Services/ServiceProtocols.swift:26-29`
- Modify: `apps/photo-curator/Services/Photos/ImageLoaderService.swift:16-25`
- Create: `apps/photo-curator/Features/Review/PhotoDetail.swift`

**Interfaces:**
- Consumes: `ReviewModel.displayIDs`, `PhotoImageLoader.preview(for:targetSize:)`.
- Produces: `func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage`; `struct PhotoDetail: View { let assetID: AssetID }` with local pager and In Album/Removed toggle.

- [ ] **Step 1: Add the bounded preview entry point**

```swift
protocol PhotoImageLoader: Sendable {
    func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage
    func analysisImage(for id: AssetID) async throws -> CGImage
    func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage
}

struct NoopImageLoader: PhotoImageLoader {
    func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
        throw SelectionError.internal
    }
}
```

```swift
func preview(for id: AssetID, targetSize: CGSize) async throws -> CGImage {
    let edge: CGFloat = 2048
    return try await requestImage(for: id, targetSize: CGSize(width: edge, height: edge), contentMode: .aspectFit, fast: false)
}
```

Reuse the single manager/request state, final-quality delivery, iCloud handling, and cancellation; honor the caller `targetSize` when smaller than the 2048 cap.

- [ ] **Step 2: Implement detail with local pager**

```swift
import CoreGraphics
import SwiftUI

struct PhotoDetail: View {
    let assetID: AssetID
    @Environment(AppModel.self) private var appModel
    @State private var currentAssetID: AssetID
    @State private var cgImage: CGImage?

    init(assetID: AssetID) {
        self.assetID = assetID
        _currentAssetID = State(initialValue: assetID)
    }

    var body: some View {
        Group {
            if let model = appModel.reviewModel, let index = model.displayIDs.firstIndex(of: currentAssetID) {
                VStack {
                    DetailImage(cgImage: cgImage)
                    Button(model.isSelected(currentAssetID) ? "In Album" : "Removed") {
                        model.toggle(currentAssetID)
                    }
                    .buttonStyle(.borderedProminent)
                    HStack {
                        Button("Previous") { currentAssetID = model.displayIDs[max(0, index - 1)] }
                            .disabled(index == 0)
                        Button("Next") { currentAssetID = model.displayIDs[min(model.displayIDs.count - 1, index + 1)] }
                            .disabled(index == model.displayIDs.count - 1)
                    }
                    if let date = model.sourceByID[currentAssetID]?.creationDate {
                        Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .task(id: currentAssetID) {
                    cgImage = nil
                    do {
                        cgImage = try await appModel.imageLoader.preview(for: currentAssetID, targetSize: CGSize(width: 2048, height: 2048))
                    } catch {
                        cgImage = nil
                    }
                }
            } else {
                ProgressView("Loading photo…")
            }
        }
        .navigationTitle("Photo")
    }
}
```

Clear `cgImage` in `.onDisappear` and on ID change (handled by the `nil` reset above); show a neutral quaternary placeholder on failure; VoiceOver labels toggle state and previous/next position; no score, trash icon, swipe/zoom state, persistence, or rerank.

- [ ] **Step 3: Verify detail gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Services/ServiceProtocols.swift apps/photo-curator/Services/Photos/ImageLoaderService.swift apps/photo-curator/Features/Review/PhotoDetail.swift
git commit -m "feat(009): add detail preview and photo detail"
```

---

### Task 6: Feature close

**Files:**
- Modify: `features/feat-009.md`

**Interfaces:**
- Consumes: physical-device S09–S11 evidence, `./init.sh` output.
- Produces: linked plan; recorded acceptance; feat-010 handoff.

- [ ] **Step 1: Link the plan and close the feature**

In `features/feat-009.md` add `Plan: docs/plans/feat-009.md`, then on manual QA record Dataset A S09–S11 evidence and `./init.sh` output, mark S09/S10/S11 operable, append the `progress.md` block with feat-010 next (bounded cluster/moment export seam for Similar Groups + Removed Photos).

- [ ] **Step 2: Verify docs gate**

Run: `./init.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add features/feat-009.md
git commit -m "feat(009): link plan and close review core"
```

---

## Self-Review

1. **Spec coverage:** every train §5 requirement maps above — model (Task 1), entry/routes (Task 2), S09 (Task 3), S10 (Task 4), preview + S11 (Task 5), close (Task 6).
2. **Placeholder scan:** no TBD/TODO/placeholder; every code block is concrete and every command is `./init.sh` plus manual Dataset A.
3. **Type consistency:** `ReviewModel`, `.reviewOverview`/`.curatedGrid`, `preview(for:targetSize:)`, `PhotoDetail(assetID:)`, and session-local edit semantics match across tasks.
