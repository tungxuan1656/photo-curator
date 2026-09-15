# feat-015 — Flow + Screens Interaction Repair Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Use `subagent-driven-development` or `executing-plans` only when installed and appropriate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the verified interaction-only flow/screen defects (stranded sessions, unconfirmed destructive starts, extra interstitial, wrong review entry, dead-end permission states, unreadable selection controls) with no engine, scoring, or pipeline changes.

**Architecture:** Add a small cold-start resume seam (one directory listing + latest-checkpoint loader read from disk on `RootView.task`, cached as an in-memory snapshot on `AppModel`), rewire one review entry intent (`showReview` builds the `ReviewModel` then routes, replacing the `.reviewReady` interstitial), and repair per-screen controls/copy in place — one shared `SelectionToggle` icon view removes the S10/S12 duplication.

**Tech Stack:** Swift 5, SwiftUI + Observation, NavigationStack typed routes, FileStore/SessionCheckpointStore, existing ReviewModel/ProcessingModel/AppModel intents.

## Global Constraints

- Start only after feat-014 is done and merged; one active feature at a time; branch `feat/feat-015` from `main`.
- No engine, scoring, clustering, similarity, threshold, batch-pipeline, or iCloud-fetch changes; no new data-model fields.
- UI copy avoids deletion language ("delete", "trash", "rejected"); use Selected / Removed / Add back (ux-flows §1.9, §3).
- Selection controls are never color-only: icon + border + text/checkmark (ux-flows §13).
- Tap targets meet iOS minimums (44pt); Dynamic Type must not clip controls.
- No test targets, no `*Test*.swift`, no test-only architecture; validation is `./init.sh` + manual Dataset A tap-through (manual-qa §5.1–§5.3).
- Discard/destructive confirmations use the exact ux-flows §4.3 copy ("Discard this curation?" / "Your original photos will stay unchanged. The current analysis and selection will be removed." / Keep Curation / Discard Curation).
- SwiftLint strict, SwiftFormat, 120 cols; SwiftUI never calls PhotoKit/Vision; engine never imports SwiftUI; `Infrastructure/` Foundation-only.

---

## File Structure

- Modify `apps/photo-curator/Infrastructure/FileStore.swift` — add `listJSONFiles(under:)` directory listing.
- Modify `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift` — add `latestCheckpoint()` (newest checkpoint + optional result + save-state presence, tolerant decode).
- Modify `apps/photo-curator/App/AppModel.swift` — add `ResumeSnapshot`, `resumeSnapshot`, `refreshResumeSnapshot()`, `continueResumedSession()`, `confirmingNewSession` + `requestNewSession()`/`startNewSession(confirmed:)`; rewire `showReview(for:)` to build-then-route; delete `freezeConfirmedSource` double-add side effect (keep behavior, countable once — done in Task 4).
- Modify `apps/photo-curator/App/AppRoute.swift` — delete `.reviewReady(sessionID:)`.
- Modify `apps/photo-curator/App/RootView.swift` — delete `.reviewReady` destination; `.task` also calls `refreshResumeSnapshot()`; failed-review retries route through `showReview`.
- Modify `apps/photo-curator/App/AppModel+Save.swift` — trim album name at save (`saveAlbum` + `runSave` input).
- Modify `apps/photo-curator/Features/Onboarding/HomeView.swift` — Continue card (S17) + Start New confirm.
- Modify `apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift` — Dismiss on every branch.
- Modify `apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift` — denied/empty/limited recovery actions + one-photo hint.
- Modify `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` — conditional iCloud line.
- Modify `apps/photo-curator/Features/Processing/ProcessingView.swift` — delete `ReviewReadyView`; completed state calls `showReview`.
- Modify `apps/photo-curator/Features/Processing/ProcessingModel.swift` — one pause copy: "Curation paused. Your progress is saved. Reopen the app to continue."
- Modify `apps/photo-curator/Features/Review/ReviewOverview.swift` — grid-first entry, compact stats, unavailable line, Discard.
- Modify `apps/photo-curator/Features/Review/CuratedGrid.swift` — new shared `SelectionToggle` + Undo copy.
- Modify `apps/photo-curator/Features/Review/SimilarGroups.swift` — reuse `SelectionToggle`, best-pick a11y.
- Modify `apps/photo-curator/Features/Review/RemovedPhotos.swift` — "Add back" copy.
- Modify `apps/photo-curator/Features/Review/PhotoDetail.swift` — swipe, failure state, a11y, position label.
- Modify `apps/photo-curator/Features/Review/FinalReview.swift` — trimmed-name Save gate.
- Modify `apps/photo-curator/Features/Review/Completion.swift` — partial-context line.
- Modify `apps/photo-curator/Features/Settings/SettingsView.swift` — notDetermined requests permission.
- Create `apps/photo-curator/SharedUI/SelectionToggle.swift` — shared 44pt icon toggle.
- Modify `features/feat-015.md` — record evidence on close.

---

### Task 1: Resume store seam

**Files:**
- Modify: `apps/photo-curator/Infrastructure/FileStore.swift`
- Modify: `apps/photo-curator/Infrastructure/SessionCheckpointStore.swift`

**Interfaces:**
- Consumes: existing `path(for:)`, `resultPath(for:)`, `saveStatePath(for:)`, `files.load/save`.
- Produces: `func listJSONFiles(under relativePath: String) -> [String]` (FileStore); `struct ResumableSession: Sendable { let checkpoint: SessionCheckpoint; let hasResult: Bool; let hasSaveState: Bool }` + `func latestCheckpoint() async -> ResumableSession?` (SessionCheckpointStore).

- [ ] **Step 1: Add the directory listing to FileStore**

```swift
/// Lists JSON filenames (no directories) under one relative directory.
/// Missing directory returns []. Never throws: resume probing must not fail launch.
func listJSONFiles(under relativePath: String) -> [String] {
    guard let target = try? url(for: relativePath) else { return [] }
    guard let items = try? FileManager.default.contentsOfDirectory(
        at: target, includingPropertiesForKeys: [.contentModificationDateKey]
    ) else { return [] }
    return items
        .filter { $0.pathExtension == "json" }
        .map { $0.deletingPathExtension().lastPathComponent }
}
```

- [ ] **Step 2: Add the latest-checkpoint loader to SessionCheckpointStore**

```swift
/// Cold-start resume probe: newest decodable checkpoint plus presence of its
/// result and save-state siblings. Missing/corrupt files are skipped, never thrown.
struct ResumableSession: Sendable {
    let checkpoint: SessionCheckpoint
    let hasResult: Bool
    let hasSaveState: Bool
}

func latestCheckpoint() async -> ResumableSession? {
    let ids = await files.listJSONFiles(under: directory)
    var best: (SessionCheckpoint, Date)?
    for raw in ids {
        guard let uuid = UUID(uuidString: raw) else { continue }
        let id = SessionID(rawValue: uuid)
        guard let checkpoint = try? await files.load(SessionCheckpoint.self, from: path(for: id)) else { continue }
        if best == nil || checkpoint.updatedAt > best!.0.updatedAt {
            best = (checkpoint, checkpoint.updatedAt)
        }
    }
    guard let found = best?.0 else { return nil }
    let hasResult = (try? await files.load(SelectionResult.self, from: resultPath(for: found.sessionID))) != nil
    let hasSave = await loadSaveState(sessionID: found.sessionID) != nil
    return ResumableSession(checkpoint: found, hasResult: hasResult, hasSaveState: hasSave)
}
```

- [ ] **Step 3: Verify store gate**

Run: `swiftlint lint --strict apps/photo-curator/Infrastructure/FileStore.swift apps/photo-curator/Infrastructure/SessionCheckpointStore.swift`
Expected: PASS, 0 violations.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Infrastructure/FileStore.swift apps/photo-curator/Infrastructure/SessionCheckpointStore.swift
git commit -m "feat(015): add latest-checkpoint resume seam"
```

---

### Task 2: Resume snapshot + guarded Start New on AppModel

**Files:**
- Modify: `apps/photo-curator/App/AppModel.swift` (near `activeSessionID`/`lastSessionID`, `startCuration()`, `showReview(for:)`)

**Interfaces:**
- Consumes: `SessionCheckpointStore.latestCheckpoint()`, `ProcessingModel.retry()/start(request:sourceAssets:)`, `beginReview(for:)`, `hasInterruptedSave(for:)`, `loadResult(for:)`, `container.photoLibrary.fetchAssets()`.
- Produces: `struct ResumeSnapshot: Sendable, Equatable { let sessionID: SessionID; let stage: String; let sourceCount: Int; let updatedAt: Date; let hasResult: Bool; let hasSaveState: Bool }`; `var resumeSnapshot: ResumeSnapshot?`; `var confirmingNewSession = false`; `func refreshResumeSnapshot() async`; `func continueResumedSession()`; `func requestNewSession()`; `func startNewSession(confirmed: Bool)`; rewired `func showReview(for:)`.

- [ ] **Step 1: Add the snapshot state and refresh**

```swift
/// Cold-start resume snapshot for the S17 Home card. In-memory only; it
/// mirrors the newest on-disk checkpoint and clears once its session is
/// owned, discarded, or completed.
struct ResumeSnapshot: Sendable, Equatable {
    let sessionID: SessionID
    let stage: String
    let sourceCount: Int
    let updatedAt: Date
    let hasResult: Bool
    let hasSaveState: Bool
}

var resumeSnapshot: ResumeSnapshot?
var confirmingNewSession = false

/// Launch probe: remembers the newest unfinished session for the Home card.
/// A session with a persisted non-empty result or save-state counts as
/// unfinished even when the in-memory run already cleared ownership.
func refreshResumeSnapshot() async {
    if activeSessionID != nil { resumeSnapshot = nil; return }
    guard let found = await container.checkpointStore.latestCheckpoint() else {
        resumeSnapshot = nil
        return
    }
    let result = try? await container.checkpointStore.loadResult(sessionID: found.checkpoint.sessionID)
    if let result, !result.selectedAssetIDs.isEmpty {
        resumeSnapshot = ResumeSnapshot(
            sessionID: found.checkpoint.sessionID,
            stage: found.checkpoint.stage,
            sourceCount: found.checkpoint.sourceAssetIDs.count,
            updatedAt: found.checkpoint.updatedAt,
            hasResult: true,
            hasSaveState: found.hasSaveState
        )
        return
    }
    if found.hasSaveState {
        resumeSnapshot = ResumeSnapshot(
            sessionID: found.checkpoint.sessionID,
            stage: found.checkpoint.stage,
            sourceCount: found.checkpoint.sourceAssetIDs.count,
            updatedAt: found.checkpoint.updatedAt,
            hasResult: false,
            hasSaveState: true
        )
        return
    }
    if found.checkpoint.stage == ProcessingStage.finalSelection.rawValue {
        resumeSnapshot = nil
        return
    }
    resumeSnapshot = ResumeSnapshot(
        sessionID: found.checkpoint.sessionID,
        stage: found.checkpoint.stage,
        sourceCount: found.checkpoint.sourceAssetIDs.count,
        updatedAt: found.checkpoint.updatedAt,
        hasResult: false,
        hasSaveState: false
    )
}
```

- [ ] **Step 2: Guard Start New and add Continue**

```swift
/// Home "Start New" when a resume snapshot exists: ask first (ux-flows §4.3),
/// because starting supersedes and deletes the retained session's data.
func requestNewSession() {
    if resumeSnapshot != nil || activeSessionID != nil {
        confirmingNewSession = true
        return
    }
    showSourceSelection()
}

func startNewSession(confirmed: Bool) {
    confirmingNewSession = false
    guard confirmed else { return }
    resumeSnapshot = nil
    showSourceSelection()
}

/// Home "Continue" for the retained session: re-enter at the right surface.
/// Processing/checkpointed work reopens Processing; a finished result (or an
/// interrupted save) opens review/saving via showReview; otherwise the run
/// resumes from its checkpoint.
func continueResumedSession() {
    guard let snapshot = resumeSnapshot else { return }
    resumeSnapshot = nil
    activeSessionID = snapshot.sessionID
    lastSessionID = snapshot.sessionID
    if snapshot.hasSaveState || snapshot.hasResult {
        showReview(for: snapshot.sessionID)
        return
    }
    if processing.sessionID == snapshot.sessionID {
        path.append(.processing(sessionID: snapshot.sessionID))
        Task { await resumeIfPaused() }
        return
    }
    Task {
        do {
            let checkpoint = try await container.checkpointStore.load(sessionID: snapshot.sessionID)
            let assets = try await container.photoLibrary.fetchAssets()
            let live = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
            let ordered = checkpoint.sourceAssetIDs.compactMap { live[$0] }
            guard !ordered.isEmpty else { return }
            confirmedSourceIDs = checkpoint.sourceAssetIDs
            let request = SelectionRequest(
                sessionID: snapshot.sessionID,
                sourceAssetIDs: checkpoint.sourceAssetIDs,
                config: .default
            )
            processing.start(request: request, sourceAssets: ordered)
            path.append(.processing(sessionID: snapshot.sessionID))
        } catch {
            path.append(.processing(sessionID: snapshot.sessionID))
        }
    }
}
```

The `catch` fallback above intentionally reopens Processing even when the checkpoint cannot be reloaded: `ProcessingModel.execute` re-checks permission and the coordinator resume path re-reads the checkpoint, so a corrupt manifest surfaces as the normal S08 attention state instead of a dead Home card.

- [ ] **Step 3: Rewire showReview to build-then-route (deletes the interstitial hop)**

```swift
/// Review entry from Processing completed / Home Continue / load-failed retry:
/// builds the ReviewModel (or reconciles an interrupted save), then routes
/// directly to S09 (or S15). Never pushes .reviewReady.
func showReview(for sessionID: SessionID) {
    Task {
        if await hasInterruptedSave(for: sessionID) {
            _ = await beginReview(for: sessionID)
            return
        }
        let ok = await beginReview(for: sessionID)
        if !ok {
            path.append(.reviewOverview(sessionID: sessionID))
        }
    }
}
```

`beginReview` already appends `.reviewOverview` (or `.saving` when an interrupted save exists) on success; the `!ok` branch pushes the overview route anyway so `RootView` renders `ReviewLoadFailedView` (Try Again calls `showReview` again, Back to Home exits) instead of stranding the user on Processing completed. `beginReview` returns false only for missing/mismatched/empty results — never while a save flight owns the session — so no duplicate `.saving` push races the S15 claim.

- [ ] **Step 4: Clear the snapshot on ownership changes**

In `startCuration()` after `activeSessionID = request.sessionID`: add `resumeSnapshot = nil`. In `discardCuration()` and `resetAnalysis()`: add `resumeSnapshot = nil`. In the `processing.onCompleted` closure in `init`: keep ownership clearing, add nothing (the finished result stays discoverable via `refreshResumeSnapshot`).

- [ ] **Step 5: Verify model gate**

Run: `swiftlint lint --strict apps/photo-curator/App/AppModel.swift`
Expected: PASS, 0 violations.

- [ ] **Step 6: Commit**

```bash
git add apps/photo-curator/App/AppModel.swift
git commit -m "feat(015): add resume snapshot and rewire review entry"
```

---

### Task 3: Home card + routes + launch refresh

**Files:**
- Modify: `apps/photo-curator/Features/Onboarding/HomeView.swift`
- Modify: `apps/photo-curator/App/AppRoute.swift`
- Modify: `apps/photo-curator/App/RootView.swift`

**Interfaces:**
- Consumes: `AppModel.resumeSnapshot`, `continueResumedSession()`, `requestNewSession()`, `startNewSession(confirmed:)`, `confirmingNewSession`, `showReview(for:)`.
- Produces: S17 Continue card; Start New confirm dialog; no `.reviewReady` case anywhere.

- [ ] **Step 1: Add the Continue card and Start New confirm to HomeView**

```swift
if let snapshot = appModel.resumeSnapshot {
    VStack(spacing: 8) {
        Text("Continue Curation").font(.headline)
        Text("\(snapshot.sourceCount) photos · \(snapshot.stage) · \(snapshot.updatedAt, style: .relative)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        Button("Continue") { appModel.continueResumedSession() }
            .buttonStyle(.borderedProminent)
        Button("Start New") { appModel.requestNewSession() }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Continue curation, \(snapshot.sourceCount) photos")
} else {
    Button("Curate Photos") {
        appModel.showSourceSelection()
    }
    .buttonStyle(.borderedProminent)
}
```

Keep the existing authorization switch around this block: the card renders only when access is `.authorized`/`.limited`; denied/restricted keep the access-required card. Append the confirm dialog to the root `VStack`:

```swift
.confirmationDialog(
    "Discard this curation?",
    isPresented: $appModel.confirmingNewSession,
    titleVisibility: .visible
) {
    Button("Discard Curation", role: .destructive) { appModel.startNewSession(confirmed: true) }
    Button("Keep Curation", role: .cancel) { appModel.startNewSession(confirmed: false) }
} message: {
    Text("Your original photos will stay unchanged. The current analysis and selection will be removed.")
}
```

`$appModel.confirmingNewSession` needs `@Bindable var appModel = appModel` at the top of `body` (same pattern as `SourceSelectionView.swift:16`).

- [ ] **Step 2: Delete the .reviewReady route**

In `AppRoute.swift` delete the line `case reviewReady(sessionID: SessionID)`. In `RootView.swift` delete the `case let .reviewReady(id): ReviewReadyView(sessionID: id)` destination branch. In `RootView.swift` `.task`, add after `refreshAuthorization()`:

```swift
await appModel.refreshResumeSnapshot()
```

`ReviewLoadFailedView` Try Again currently calls `beginReview` directly (which pushes the route itself); change it to call the sync `showReview` entry (it spawns its own Task, so no `Task { await ... }` wrapper):

```swift
primary: { appModel.showReview(for: sessionID) },
```

- [ ] **Step 3: Verify navigation gate**

Run: `swiftlint lint --strict apps/photo-curator/Features/Onboarding/HomeView.swift apps/photo-curator/App/AppRoute.swift apps/photo-curator/App/RootView.swift apps/photo-curator/Features/Review/ReviewOverview.swift`
Expected: PASS, 0 violations; `grep -rn "reviewReady\|ReviewReadyView" apps/` returns nothing.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Features/Onboarding/HomeView.swift apps/photo-curator/App/AppRoute.swift apps/photo-curator/App/RootView.swift apps/photo-curator/Features/Review/ReviewOverview.swift
git commit -m "feat(015): add home continue card, drop reviewReady route"
```

---

### Task 4: Delete ReviewReadyView + repoint Processing completion

**Files:**
- Modify: `apps/photo-curator/Features/Processing/ProcessingView.swift`

**Interfaces:**
- Consumes: `AppModel.showReview(for:)` (rewired in Task 2).
- Produces: no `ReviewReadyView` type; completed state routes via `showReview`.

- [ ] **Step 1: Delete the ReviewReadyView struct and repoint Continue**

Delete lines 125–213 (`ReviewReadyView` struct, its doc comment, and the `unavailable` helper). The completed branch already calls `appModel.showReview(for: id)` (`ProcessingView.swift:50`) — keep it unchanged; it now lands directly on S09/S15/load-failed. Update the file header comment: replace "The explicit Continue-to-Review button calls `showReview(for:)`; there is no auto-routing" with "The Continue-to-Review button calls `showReview(for:)`, which builds the ReviewModel then routes directly to S09 (or S15 on an interrupted save)."

- [ ] **Step 2: Verify processing gate**

Run: `swiftlint lint --strict apps/photo-curator/Features/Processing/ProcessingView.swift`
Expected: PASS; `grep -rn "ReviewReady" apps/` returns nothing.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Processing/ProcessingView.swift
git commit -m "feat(015): delete reviewReady interstitial"
```

---

### Task 5: Review entry + S09 stats, unavailable, Discard

**Files:**
- Modify: `apps/photo-curator/Features/Review/ReviewOverview.swift`

**Interfaces:**
- Consumes: `ReviewModel` (`selectedIDs`, `removedAssetIDs`, `similarGroups`, `result`), `processing.progress.unavailableCount`, `AppModel.discardCuration()`.
- Produces: grid-first primary entry; no behavioral API change.

- [ ] **Step 1: Rework the overview body**

```swift
var body: some View {
    Group {
        if let model = appModel.reviewModel, model.sessionID == sessionID {
            let total = model.result.selectedAssetIDs.count + model.result.rejectedAssetIDs.count
            let unavailable = appModel.processing.progress.unavailableCount
            VStack(spacing: 12) {
                Text("Your curated album is ready").font(.title2.bold())
                Text("\(model.selectedIDs.count) selected from \(total) photos")
                Text("\(model.removedAssetIDs.count) not selected · \(model.similarGroups.count) groups to review")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if unavailable > 0 {
                    Text("\(unavailable) photos were unavailable and could not be analyzed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Review Selection") { appModel.path.append(.curatedGrid(sessionID: sessionID)) }
                    .buttonStyle(.borderedProminent)
                if !model.similarGroups.isEmpty {
                    Button("Review Similar Photos") { appModel.path.append(.similarGroups(sessionID: sessionID)) }
                }
                Button("Review Removed") { appModel.path.append(.removedPhotos(sessionID: sessionID)) }
                Button("Discard Curation", role: .destructive) { confirmingDiscard = true }
            }.padding()
        } else {
            ProgressView("Loading your selection…")
        }
    }
    .navigationTitle("Review")
    .alert(
        "Discard this curation?",
        isPresented: $confirmingDiscard,
        actions: {
            Button("Keep Curation", role: .cancel) {}
            Button("Discard Curation", role: .destructive) { appModel.discardCuration() }
        },
        message: {
            Text("Your original photos will stay unchanged. The current analysis and selection will be removed.")
        }
    )
}
```

Delete the "Review & Save" button (it skipped the grid, violating §8.1); grid/detail/groups/removed all reach S14 through their own flows, and Final Review stays reachable from the grid path. Add `@State private var confirmingDiscard = false` to the view.

- [ ] **Step 2: Verify review gate**

Run: `swiftlint lint --strict apps/photo-curator/Features/Review/ReviewOverview.swift`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Review/ReviewOverview.swift
git commit -m "feat(015): grid-first review entry with discard"
```

---

### Task 6: Shared SelectionToggle + S10/S12/S13 vocab

**Files:**
- Create: `apps/photo-curator/SharedUI/SelectionToggle.swift`
- Modify: `apps/photo-curator/Features/Review/CuratedGrid.swift`
- Modify: `apps/photo-curator/Features/Review/SimilarGroups.swift`
- Modify: `apps/photo-curator/Features/Review/RemovedPhotos.swift`

**Interfaces:**
- Consumes: `isSelected: Bool`, `onToggle: () -> Void`.
- Produces: `struct SelectionToggle: View { let isSelected: Bool; let onToggle: () -> Void }` — 44pt icon + border + text state, never color-only.

- [ ] **Step 1: Create the shared toggle**

```swift
import SwiftUI

/// Shared selection toggle for S10/S12: 44pt checkmark icon with border and
/// text state. Never color-only (ux-flows §13).
struct SelectionToggle: View {
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                Text(isSelected ? "Selected" : "Removed")
                    .font(.caption)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 1)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(isSelected ? "Remove photo from album" : "Add photo to album")
    }
}
```

- [ ] **Step 2: Use it in CuratedGrid + SimilarGroups, unify RemovedPhotos copy**

In `CuratedGrid.swift` `ReviewCell`, replace the text `Button(isSelected ? "Remove from album" : "Add to album", action: onToggle)` with `SelectionToggle(isSelected: isSelected, onToggle: onToggle)`. Same replacement in `SimilarGroups.swift` `SimilarGroupCard` (keeping its existing `.accessibilityLabel` behavior, which the shared view already provides — delete the per-site label). In `RemovedPhotos.swift`, change `Button("Add")` to `Button("Add back")` with `.accessibilityLabel("Add photo back to album")`. In `CuratedGrid.swift`, change the Undo button to `Button("Removed from album — Undo")`. In `SimilarGroups.swift`, add to the engine-winner label: `.accessibilityLabel("Recommended best pick")`, and to the current-winner label: `.accessibilityLabel("Best pick")`.

- [ ] **Step 3: Verify toggle gate**

Run: `swiftlint lint --strict apps/photo-curator/SharedUI/SelectionToggle.swift apps/photo-curator/Features/Review/CuratedGrid.swift apps/photo-curator/Features/Review/SimilarGroups.swift apps/photo-curator/Features/Review/RemovedPhotos.swift`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/SharedUI/SelectionToggle.swift apps/photo-curator/Features/Review/CuratedGrid.swift apps/photo-curator/Features/Review/SimilarGroups.swift apps/photo-curator/Features/Review/RemovedPhotos.swift
git commit -m "feat(015): shared selection toggle and vocab unify"
```

---

### Task 7: S05/S06/S18/S19 recovery + copy conditions

**Files:**
- Modify: `apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift`
- Modify: `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift`
- Modify: `apps/photo-curator/Features/Settings/SettingsView.swift`
- Modify: `apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift`

**Interfaces:**
- Consumes: `AppModel.openSettingsURL()`, `presentPicker()`, `requestPermission()`, `loadSource()`, `summary.hasICloudAssets` (new, Task 7).
- Produces: no new routes; recovery buttons inline.

- [ ] **Step 1: Repair S05 denied/empty/limited + one-photo hint**

In `SourceSelectionView.swift` `content`, replace the denied branch:

```swift
case (.denied, _), (.restricted, _), (_, .denied):
    Text("Photos Access Needed").font(.headline)
    Text("Allow photo access to choose images for curation.")
    Button("Open Settings") { appModel.openSettingsURL() }
        .buttonStyle(.borderedProminent)
    Button("Learn More") { showsAccessGuidance = true }
```

`showsAccessGuidance` needs `@State private var showsAccessGuidance = false` on `SourceSelectionView` plus `.sheet(isPresented: $showsAccessGuidance) { AccessGuidanceSheet() }` on the root VStack. Replace the empty branch:

```swift
case (_, .empty):
    Text("No Photos Available").font(.headline)
    Text("Add photos to your library or allow access to more photos, then try again.")
    if appModel.authorization == .limited {
        Button("Choose More Photos") { appModel.presentPicker() }
            .buttonStyle(.borderedProminent)
    }
    Button("Try Again") { Task { await appModel.loadSource() } }
```

Change the limited notice to include an inline picker button:

```swift
if appModel.authorization == .limited {
    Text("Limited Photos Access — only shared photos appear.")
        .font(.footnote)
    Button("Choose More Photos") { appModel.presentPicker() }
        .font(.footnote)
}
```

Add under the header count, only when exactly one photo is selected:

```swift
if appModel.selectedIDs.count == 1 {
    Text("Photos Curator works best with a larger set.")
        .font(.footnote).foregroundStyle(.secondary)
}
```

- [ ] **Step 2: Condition the S06 iCloud line on real iCloud assets**

In `AppModel.swift` add next to `summary`:

```swift
/// True when any confirmed source asset needs iCloud fetch (S06 copy condition).
var summaryHasICloudAssets: Bool {
    let live = sourceByID
    return confirmedSourceIDs.compactMap { live[$0] }.contains { $0.source == .iCloud }
}
```

In `SelectionSummaryView.swift`, split the static body text:

```swift
Text(
    "We'll group similar shots, evaluate photo quality, and build a smaller selection for you to review. "
        + "Analysis happens on this iPhone. "
        + "This may take a while for large libraries."
)
.font(.body)
if appModel.summaryHasICloudAssets {
    Text("Some photos may need to download from iCloud.")
        .font(.body)
}
```

- [ ] **Step 3: Repair Settings notDetermined + sheet Dismiss**

In `SettingsView.swift` Photos Access section, add a leading branch:

```swift
if appModel.authorization == .notDetermined {
    Text("Photo access is not set up yet.")
        .font(.footnote).foregroundStyle(.secondary)
    Button("Continue") {
        Task { await appModel.requestPermission() }
    }
    .accessibilityLabel("Continue to photo access setup")
} else if appModel.authorization == .denied || ...
```

In `AccessGuidanceSheet.swift`, add a Dismiss button to every branch (after the primary action):

```swift
Button("Dismiss") { dismiss() }
```

On the denied branch, place it after Open Settings; on limited, after Choose More Photos. The restricted/notDetermined/authorized branches keep Done and need no change.

- [ ] **Step 4: Verify source/settings gate**

Run: `swiftlint lint --strict apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift apps/photo-curator/Features/Settings/SettingsView.swift apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift apps/photo-curator/App/AppModel.swift`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift apps/photo-curator/Features/Settings/SettingsView.swift apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift apps/photo-curator/App/AppModel.swift
git commit -m "feat(015): repair source/settings recovery paths"
```

---

### Task 8: S11 pager/swipe/error/a11y + S14 trim + S16 partial + pause copy

**Files:**
- Modify: `apps/photo-curator/Features/Review/PhotoDetail.swift`
- Modify: `apps/photo-curator/Features/Review/FinalReview.swift`
- Modify: `apps/photo-curator/App/AppModel+Save.swift`
- Modify: `apps/photo-curator/Features/Review/Completion.swift`
- Modify: `apps/photo-curator/Features/Processing/ProcessingModel.swift`

**Interfaces:**
- Consumes: `ReviewModel.toggle/isSelected`, `AppModel.saveAlbum/retryRemainingSave`, `SaveState.remainingIDs`.
- Produces: no API change; S11 swipe + failure view; trimmed save names; partial-context completion copy.

- [ ] **Step 1: S11 swipe + failure state + a11y**

In `PhotoDetail.swift`, add `@State private var loadFailed = false`. In the `.task(id: currentAssetID)`, set `loadFailed = false` before the request and `loadFailed = true` in the `catch` (keeping the same-ID guard). Replace the image `Group` with:

```swift
Group {
    if let cgImage {
        Image(decorative: cgImage, scale: 1, orientation: .up)
            .resizable()
            .scaledToFit()
    } else if loadFailed {
        ErrorStateView(
            title: "We couldn't load this photo.",
            message: "Your progress is saved.",
            primaryTitle: "Try Again",
            primary: { retryToken += 1; loadFailed = false; cgImage = nil },
            secondaryTitle: "Back",
            secondary: { appModel.path.removeLast() }
        )
    } else {
        Rectangle().fill(.quaternary)
            .frame(minHeight: 200)
    }
}
```

Resetting `loadFailed`/`cgImage` re-renders into the placeholder branch, but `.task(id: currentAssetID)` only re-fires when the ID changes — so also bump a retry token read by the task: add `@State private var retryToken = 0`, change the modifier to `.task(id: [currentAssetID, retryToken])`, and use `primary: { retryToken += 1; loadFailed = false; cgImage = nil }`. Attach swipe to the VStack:

```swift
.gesture(
    DragGesture(minimumDistance: 40, coordinateSpace: .local)
        .onEnded { value in
            if value.translation.width < -40 {
                currentAssetID = order[min(order.count - 1, index + 1)]
            } else if value.translation.width > 40 {
                currentAssetID = order[max(0, index - 1)]
            }
        }
)
```

Vertical drags are ignored (no destructive action). Update a11y:

```swift
.accessibilityLabel("Photo \(index + 1) of \(order.count), \(model.isSelected(currentAssetID) ? "selected" : "removed")")
```

and on the date text add `.accessibilityHidden(false)` + include the date in the image label when present:

```swift
if let date = model.sourceByID[currentAssetID]?.creationDate {
    Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
        .accessibilityLabel(Text(date, style: .date))
}
```

Delete the `else { ProgressView("Loading photo…") }` order-missing branch; replace with `ErrorStateView(title: "We couldn't load this photo.", message: "Your progress is saved.", primaryTitle: "Back", primary: { appModel.path.removeLast() })` — no infinite spinner remains.

- [ ] **Step 2: Trim album names + partial completion line + pause copy**

In `AppModel+Save.swift` `saveAlbum(for:)`, after `let name = model.albumName` add:

```swift
let name = model.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
```

In `FinalReview.swift`, change the Save disabled gate to:

```swift
.disabled(model.albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty || appModel.isSaving(sessionID: sessionID))
```

and show the guidance line when blank:

```swift
if model.albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    Text("Name your album to save it.")
        .font(.footnote).foregroundStyle(.secondary)
}
```

In `Completion.swift`, after the saved line add:

```swift
if !state.remainingIDs.isEmpty {
    Text("Some photos could not be added. Your originals are unchanged.")
        .font(.footnote).foregroundStyle(.secondary)
}
```

In `ProcessingModel.swift`, replace all three `"Curation paused. Progress is saved."` strings with `"Curation paused. Your progress is saved. Reopen the app to continue."`.

- [ ] **Step 3: Verify detail/save gate**

Run: `swiftlint lint --strict apps/photo-curator/Features/Review/PhotoDetail.swift apps/photo-curator/Features/Review/FinalReview.swift apps/photo-curator/App/AppModel+Save.swift apps/photo-curator/Features/Review/Completion.swift apps/photo-curator/Features/Processing/ProcessingModel.swift`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/Features/Review/PhotoDetail.swift apps/photo-curator/Features/Review/FinalReview.swift apps/photo-curator/App/AppModel+Save.swift apps/photo-curator/Features/Review/Completion.swift apps/photo-curator/Features/Processing/ProcessingModel.swift
git commit -m "feat(015): detail swipe states, trim save name, unify pause copy"
```

---

### Task 9: Feature close

**Files:**
- Modify: `features/feat-015.md`

**Interfaces:**
- Consumes: `./init.sh` output, Dataset A device tap-through evidence.
- Produces: closed feature + progress next action.

- [ ] **Step 1: Run full verification and record**

Run: `./init.sh`
Expected: PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]).

Then manual Dataset A tap-through on a physical iPhone (manual-qa §5.1–§5.3): first-run → pick → summary → processing → review grid/detail/groups/removed/final → save → completion → Done; kill-and-relaunch Home Continue; denied/limited/empty S05 paths. Mark each acceptance box in `features/feat-015.md`, fill Handoff (State: done, Evidence, Blockers, Next).

- [ ] **Step 2: Commit**

```bash
git add features/feat-015.md
git commit -m "feat(015): close flow and screens interaction repair"
```

---

## Self-Review

1. **Spec coverage:** stranded resume (Tasks 1–3, §10 + §6.1); unconfirmed supersede + missing review discard (Tasks 2–3 + 5, §4.3); reviewReady interstitial (Task 4, §8); wrong Review & Save destination (Task 5, §8.1); dead-end S05/S18/S19 + S06 iCloud condition (Task 7, §5.3/§6.2/§6.3/§11/§12.2); unreadable controls + vocab + Undo (Task 6, §8.2/§8.5/§13); S11 swipe/error/a11y + S14 trim + S16 partial + pause copy (Task 8, §8.3/§9/§7.1). S12 tap-to-swap stays explicit (recorded deviation, §8.4); S13 bottom Back stays (system Back suffices); S15 swipe-back stays harmless (save flight joins); S16 "Curate More Photos" stays out (optional per §9.3); one-photo blocking stays out (spec forbids minimums, §6.2).
2. **Placeholder scan:** no TBD/TODO/placeholder; every code block is concrete Swift; every gate is a `swiftlint`/`grep`/`./init.sh` command with expected output.
3. **Type consistency:** `ResumeSnapshot`/`ResumableSession`/`SelectionToggle` names match across Tasks 1–3 and 6; `showReview(for:)` stays sync across Tasks 2–4; `summaryHasICloudAssets` defined in Task 7 Step 2 before use; trimmed-name gate matches in Task 8 Step 2; deleted `.reviewReady` has zero references after Task 4.
