# feat-004 — SourceSelection + Summary on real fetch

## Goal

Land SourceSelection + Summary on real fetch so real source reaches real summary.

## Scope

- `Features/SourceSelection/`
- `SharedUI/AsyncPhotoThumbnail.swift`
- `App/AppModel.swift`
- `App/AppRoute.swift`
- `App/RootView.swift`
- Sequential touch: `Features/Onboarding/HomeView.swift` (CTA enable only; owned by feat-002, edited here once per flat-sequential rule because the S05 entry point lives in Home — no other feat-002 files touched).

## Non-goals

- Anything outside owns; Vision batch pipeline stays in feat-005.

## Design (accepted 2026-09-11, Approach B: client-side filter, no protocol change; fixed per Oracle review 2026-09-11)

- `fetchAssets()` has no inputs (`Services/ServiceProtocols.swift:19`) and is frozen by feat-001/feat-003 (not in feat-004 owns). Album/date-range/trip filters are in-memory over `[PhotoAsset]` in `Features/SourceSelection/` — no `ServiceProtocols.swift` change, no `Photos` import in Views. True server-side `PHAssetCollection` album enumeration stays out; "album" in S05 is a preset label over the fetched set, not a PhotoKit collection fetch. Oracle decision (a): date presets (Last-Month/3-Months/Year) accepted gate-scoped for album/trip — kept; true collection enumeration needs a protocol change outside owns.
- Selection state lives in `AppModel` (single source of truth per ux-flows invariant 4). `Features/SourceSelection/SourceFilter.swift` holds pure value types (`SourceLoadState`, `SourceFilter`, `SelectionSummary`) plus the stable chrono-sort helper; Views render only. `AppModel` exposes `photoLibrary`/`imageLoader` passthroughs plus `loadSource()`, `toggleSelection(_:)`, freeze-only `freezeConfirmedSource()` and `continueToSummary()` (freeze + push). S06 Start calls freeze-only and never routes to Processing (transition owned by feat-006; freeze-only accepted for this gate).
- Frozen order is deterministic: private `stableChronoSorted` (implementation detail of feat-004, not a cross-chain contract) orders by (`creationDate ?? .distantPast`, then `id.rawValue` as tiebreak), so equal/missing dates still yield one stable `[AssetID]` order and `confirmedSourceAssets()` preserves that frozen order for the coordinator. Cross-chain contract is only the frozen `[AssetID]` (`confirmedSourceIDs`) + ordered `[PhotoAsset]` (`confirmedSourceAssets()`).
- Grid uses new `SharedUI/AsyncPhotoThumbnail.swift` (`thumbnail` fast/opportunistic only, never `analysisImage`). Cancel on disappear is SwiftUI `.task(id:)` cancellation → feat-003 `cancelImageRequest` cooperation. One failed thumbnail shows a neutral placeholder and never blocks the grid (ux-flows §2.2).
- Library changes: subscribe to `.photoLibraryDidChange` (feat-003 `LibraryChangeTracker`), re-fetch fresh, reconcile `selectedIDs` (missing = unavailable, never silently processable), never rerun any pipeline.
- 1k-load: metadata fetch is one pass (`reserveCapacity`, cheap fields only); grid is `LazyVGrid` with `id: \.id`, bounded thumb pixels (200–500 px per apple-frameworks §6.1), no preheat of thousands, no full-resolution loads, no custom disk image cache. Owner: `docs/product-specs/ux-flows.md` S05/S06, `docs/design-docs/ios-architecture.md` §3/§5, `docs/design-docs/apple-frameworks.md` §4–§7, `docs/ship-gates/performance.md` §1, `docs/design-docs/data-model.md` §3–§5.
- Build order (Oracle fix): value types first (Task 1), then `AppRoute`+`AppModel`+Home CTA (Task 2, consumes Task 1 only), then thumbnail+S05 (Task 3), then S06+`RootView` wiring (Task 4, consumes all above). Every task's `./init.sh` passes with only tasks so far applied.

## Implementation Plan (inline per AGENTS.md; no docs/plans file)

> **Execution:** Follow the repository's implementation and verification rules. Steps use checkbox (`- [ ]`) syntax for tracking. Plan stays inline: only 1 substantial signal fires (≥4 files touched, single workspace `apps/photo-curator.xcodeproj`), with no DB migration/breaking API and no phases/rollback — so `<2` signals, default inline per AGENTS.md. Apply tasks strictly in order 1→4.

**Goal:** Implement S05 SourceSelection + S06 Summary on the real feat-003 fetch so 50 real assets run S05→S06 and a frozen source reaches a real summary; exercise the 1k-load path here (first real caller).

**Architecture:** `AppModel` owns route + source state; `SourceFilter`/`SelectionSummary` are pure `Sendable` values; `AsyncPhotoThumbnail` owns one per-cell load; `SourceSelectionView` (S05) + `SelectionSummaryView` (S06) are thin SwiftUI over `AppModel`. No Vision, no scoring, no export, no `ServiceProtocols.swift` change.

**Tech Stack:** Swift 5/SwiftUI, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, PhotoKit read via `PhotoLibraryService`/`PhotoImageLoader` only, SwiftLint --strict + SwiftFormat.

## Global Constraints

- Swift 5/SwiftUI, xcodeproj apps/photo-curator.xcodeproj scheme photo-curator, SwiftLint --strict + SwiftFormat.
- NO test targets/no *Test*.swift/manual validation only + ./init.sh SKIP [test].
- iOS 26 min; smoke on iOS 26.5 device/simulator.
- On-device only never delete originals; only write is user-approved album (later feat).
- AssetID wraps PHAsset.localIdentifier; never persist `PHAsset`, `UIImage`, or `CGImage`.
- Analysis edge 512 (`AppConfiguration.default.selection.analysisImageMaxDimension`); S05 uses thumbnail class only, never analysis/full resolution.
- Budgets maxConcurrentImageRequests 2 / analysisBatchSize 32 / checkpointEvery 25 assets-10s / progressMaxHertz 4; S05 starts no batch pipeline and publishes no progress above 4 Hz (grid cells update independently).
- Reuse SelectionError (`.invalidInput`, `.cancelled`, `.internal`); no new top-level error enum.

## File Structure

Build order is part of the contract (Oracle fix): Task 1 → Task 2 → Task 3 → Task 4.

- Create `apps/photo-curator/Features/SourceSelection/SourceFilter.swift` — Task 1: `SourceLoadState`, `SourcePreset`, `SourceFilter`, slimmed `SelectionSummary` (gate-rendered fields only), private `stableChronoSorted` implementation detail (no dependencies; builds alone).
- Modify `apps/photo-curator/App/AppRoute.swift` — Task 2: add `.sourceSelection`, `.summary` (additive only; feat-006 preserves both cases).
- Modify `apps/photo-curator/App/AppModel.swift` — Task 2: selection state + `loadSource()` + `freezeConfirmedSource()`/`continueToSummary()` + frozen `confirmedSourceIDs` (consumes Task 1 types only).
- Modify `apps/photo-curator/Features/Onboarding/HomeView.swift` — Task 2: enable Curate Photos CTA (sequential touch of feat-002-owned file; CTA only).
- Create `apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift` — Task 3: per-cell thumbnail loader (consumes Task 2 `AppModel.imageLoader`).
- Create `apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift` — Task 3: S05 grid + filters + empty/denied/limited + change refresh.
- Create `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` — Task 4: S06 checkpoint screen (freeze-only Start, selected + unavailable counts only; date-span presentation deferred to feat-013 polish).
- Modify `apps/photo-curator/App/RootView.swift` — Task 4: destinations for the two new routes (deferred here so it compiles against the Task 3 views).

---

### Task 1: Shared value types first (no dependencies; builds alone)

**Files:**
- Create: `apps/photo-curator/Features/SourceSelection/SourceFilter.swift`

**Interfaces:**
- Consumes: `PhotoAsset(id:creationDate:pixelWidth:pixelHeight:mediaSubtype:isFavorite:source:)`, `AssetID(rawValue:)`
- Produces: `enum SourceLoadState: Equatable, Sendable`; `enum SourcePreset: String, CaseIterable, Sendable`; `struct SourceFilter: Equatable, Sendable` with `func apply(to assets: [PhotoAsset]) -> [PhotoAsset]`; slimmed `struct SelectionSummary: Equatable, Sendable` (gate-rendered `selectedCount` + `unavailableCount` only); private `func stableChronoSorted(_ assets: [PhotoAsset]) -> [PhotoAsset]` (feat-004 implementation detail, not consumed by feat-005; feat-005 consumes `SourceFilter.apply` + slimmed `SelectionSummary` only for types, plus the frozen `[AssetID]`/`[PhotoAsset]` contract from Task 2)

- [ ] **Step 1: Create pure filter + summary + deterministic sort (client-side; fetch has no inputs)**

```swift
import Foundation

enum SourceLoadState: Equatable, Sendable {
    case idle, loading, loaded, empty, denied, failed
}

enum SourcePreset: String, CaseIterable, Sendable {
    case all, lastMonth, last3Months, lastYear, favorites
}

struct SourceFilter: Equatable, Sendable {
    var preset: SourcePreset = .all
    var hideScreenshots = false

    func apply(to assets: [PhotoAsset]) -> [PhotoAsset] {
        let now = Date()
        let cal = Calendar.current
        let start: Date? = switch preset {
        case .all: nil
        case .lastMonth: cal.date(byAdding: .month, value: -1, to: now)
        case .last3Months: cal.date(byAdding: .month, value: -3, to: now)
        case .lastYear: cal.date(byAdding: .year, value: -1, to: now)
        case .favorites: nil
        }
        return assets.filter { asset in
            if hideScreenshots, asset.mediaSubtype == .screenshot { return false }
            if preset == .favorites, !asset.isFavorite { return false }
            guard let start, let date = asset.creationDate else { return true }
            return date >= start
        }
    }
}

struct SelectionSummary: Equatable, Sendable {
    let selectedCount: Int
    let unavailableCount: Int
}

/// Deterministic chrono order (private feat-004 implementation detail, not a
/// cross-chain contract): creationDate first, `localIdentifier` tiebreak
/// so equal/missing dates still freeze to one stable snapshot order.
private func stableChronoSorted(_ assets: [PhotoAsset]) -> [PhotoAsset] {
    assets.sorted {
        let left = $0.creationDate ?? .distantPast
        let right = $1.creationDate ?? .distantPast
        if left != right { return left < right }
        return $0.id.rawValue < $1.id.rawValue
    }
}
```

Album/trip note fixed here: with no album field on `PhotoAsset` and no fetch input, "album" and "trip" arrive as date presets in this feat (Last Month/3 Months/Year); a PhotoKit collection browser needs a service change owned by a later feat, not this one.

Verify: `rg -n "struct SourceFilter|struct SelectionSummary|func stableChronoSorted|enum SourceLoadState" apps/photo-curator/Features/SourceSelection/SourceFilter.swift` shows all four.

- [ ] **Step 2: Run format + lint + build (Task 1 alone compiles: Foundation only)**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 2: Routes + AppModel selection state + Home CTA (consumes Task 1 only)

**Files:**
- Modify: `apps/photo-curator/App/AppRoute.swift`
- Modify: `apps/photo-curator/App/AppModel.swift`
- Modify: `apps/photo-curator/Features/Onboarding/HomeView.swift`

**Interfaces:**
- Consumes: `func fetchAssets() async throws -> [PhotoAsset]` (`Services/ServiceProtocols.swift:19`), `PhotoLibraryAuthorization`, `SourceFilter`, slimmed `SelectionSummary`, private `stableChronoSorted` (Task 1 internal), `SelectionError.invalidInput`
- Produces: `AppRoute.sourceSelection`, `AppRoute.summary`; `AppModel.loadSource() async`, `AppModel.toggleSelection(_ id: AssetID)`, `AppModel.freezeConfirmedSource()`, `AppModel.continueToSummary()`, `AppModel.showSourceSelection()`, `AppModel.confirmedSourceIDs: [AssetID]`, `AppModel.confirmedSourceAssets() -> [PhotoAsset]`, `AppModel.sourceByID: [AssetID: PhotoAsset]`, `AppModel.summary: SelectionSummary` (slimmed: `selectedCount` + `unavailableCount` only; fetched/filter counts derived locally from `allAssets`/`filteredAssets` where needed; feat-005 consumes frozen `confirmedSourceIDs` + `confirmedSourceAssets()` snapshot order + `sourceByID` only — `stableChronoSorted` is not part of the contract; feat-006 consumes freeze/start intents + additive routes)

- [ ] **Step 1: Add S05/S06 routes (additive; later feats preserve both cases)**

```swift
enum AppRoute: Hashable, Sendable {
    case welcome
    case permissionEducation
    case home
    case sourceSelection
    case summary
}
```

Verify: `rg -n "case sourceSelection|case summary" apps/photo-curator/App/AppRoute.swift` shows both cases.

- [ ] **Step 2: Add selection state + freeze-only intent with deterministic order**

```swift
@MainActor
@Observable
final class AppModel {
    var sourceState: SourceLoadState = .idle
    var allAssets: [PhotoAsset] = []
    var selectedIDs = Set<AssetID>()
    var filter = SourceFilter()
    var unavailableCount = 0
    var confirmedSourceIDs: [AssetID] = []

    var photoLibrary: any PhotoLibraryService { self.container.photoLibrary }
    var imageLoader: any PhotoImageLoader { self.container.imageLoader }
    var sourceByID: [AssetID: PhotoAsset] {
        Dictionary(uniqueKeysWithValues: self.allAssets.map { ($0.id, $0) })
    }
    var filteredAssets: [PhotoAsset] { self.filter.apply(to: self.allAssets) }
    var summary: SelectionSummary {
        SelectionSummary(
            selectedCount: self.selectedIDs.count,
            unavailableCount: self.unavailableCount
        )
    }

    func showSourceSelection() { self.path.append(.sourceSelection) }

    func toggleSelection(_ id: AssetID) {
        if self.selectedIDs.contains(id) { self.selectedIDs.remove(id) }
        else { self.selectedIDs.insert(id) }
    }

    func loadSource() async {
        self.sourceState = .loading
        do {
            let assets = try await self.container.photoLibrary.fetchAssets()
            self.allAssets = assets
            let live = Set(assets.map(\.id))
            let missing = self.selectedIDs.subtracting(live)
            self.unavailableCount = missing.count
            self.selectedIDs.subtract(missing)
            if assets.isEmpty { self.sourceState = .empty }
            else { self.sourceState = .loaded }
        } catch {
            if await self.container.photoLibrary.authorizationStatus() == .denied
                || await self.container.photoLibrary.authorizationStatus() == .restricted {
                self.sourceState = .denied
            } else {
                self.sourceState = .failed
            }
        }
    }

    func refreshSourceAfterLibraryChange() async {
        let priorSelected = self.selectedIDs
        await self.loadSource()
        let live = Set(self.allAssets.map(\.id))
        self.unavailableCount = priorSelected.subtracting(live).count
    }

    /// Freeze-only handoff for the feat-006 coordinator. No navigation here:
    /// S05 navigates via `continueToSummary()`; S06 Start calls this and stops
    /// (Processing transition is owned by feat-006).
    func freezeConfirmedSource() {
        let live = self.sourceByID
        let liveAssets = self.selectedIDs.compactMap { live[$0] }
        self.confirmedSourceIDs = stableChronoSorted(liveAssets).map(\.id)
    }

    /// S05 Continue: freeze the snapshot, then push S06.
    func continueToSummary() {
        self.freezeConfirmedSource()
        self.path.append(.summary)
    }

    /// Snapshot in frozen order: maps the frozen IDs back to assets so the
    /// coordinator consumes the same stable chrono order that was confirmed.
    func confirmedSourceAssets() -> [PhotoAsset] {
        let live = self.sourceByID
        return self.confirmedSourceIDs.compactMap { live[$0] }
    }
}
```

`SourceLoadState` is intentionally not redeclared here — it comes from Task 1's `SourceFilter.swift`.

Verify: `rg -n "func loadSource|func freezeConfirmedSource|func continueToSummary|confirmedSourceIDs" apps/photo-curator/App/AppModel.swift` shows all four; `rg -n "enum SourceLoadState" apps/photo-curator/App/AppModel.swift` returns nothing (no duplicate type).

- [ ] **Step 3: Enable the Home CTA (remove feat-003 disable)**

```swift
Button("Curate Photos") {
    appModel.showSourceSelection()
}
.buttonStyle(.borderedProminent)
```

Replace the disabled `Button("Curate Photos") {}` + `.disabled(true)` block and delete the `TODO(feat-003)` comment line. Denied/restricted branches stay untouched (access-required card, never a dead CTA).

Verify: `rg -n "TODO\(feat-003\)|disabled\(true\)" apps/photo-curator/Features/Onboarding/HomeView.swift` returns nothing.

- [ ] **Step 4: Run format + lint + build (Tasks 1–2 only: no view references yet)**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 3: AsyncPhotoThumbnail + S05 grid (consumes Tasks 1–2)

**Files:**
- Create: `apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift`
- Create: `apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift`

**Interfaces:**
- Consumes: `func thumbnail(for id: AssetID, targetSize: CGSize) async throws -> CGImage` (fast/opportunistic inside feat-003 loader), `Notification.Name.photoLibraryDidChange`, `AppModel.filteredAssets/loadSource/toggleSelection/continueToSummary` (S05 derives counts locally from `selectedIDs`/`filteredAssets`, never via `summary`), `SelectionError.cancelled/.internal/.invalidInput`
- Produces: `struct AsyncPhotoThumbnail: View` with `init(assetID: AssetID, targetSizePixels: CGSize)`; `struct SourceSelectionView: View` (feat-005/006 reuse the thumbnail init for review grids; sizes are pixels = points × scale)

- [ ] **Step 1: Create the cell that loads once and discards on disappear**

```swift
import CoreGraphics
import SwiftUI

struct AsyncPhotoThumbnail: View {
    let assetID: AssetID
    let targetSizePixels: CGSize

    @Environment(AppModel.self) private var appModel
    @State private var cgImage: CGImage?

    var body: some View {
        Group {
            if let cgImage {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .clipped()
        .task(id: assetID) {
            do {
                let cg = try await appModel.imageLoader.thumbnail(for: assetID, targetSize: targetSizePixels)
                self.cgImage = cg
            } catch {
                self.cgImage = nil
            }
        }
    }
}
```

Rules fixed in code: `.task(id:)` cancellation maps to loader `cancelImageRequest` via feat-003 cooperation; `.cancelled` and any failure both yield the neutral placeholder so one bad cell never blocks the grid; no `analysisImage` call here (analysis edge 512 is reserved for feat-005). Image fill uses `.resizable()` + `.scaledToFill()` + outer `.clipped()` (compiling SwiftUI; no `.aspectFill` modifier exists; `.scaledToFill()` chosen over `.aspectRatio(contentMode: .fill)` per repo `legacy_swiftui_aspect_ratio` strict-lint rule).

Verify: `rg -n "thumbnail\(for|task\(id:|scaledToFill" apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift` shows all three; `rg -n "analysisImage|aspectFill" apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift` returns nothing.

- [ ] **Step 2: Create S05 view (header, presets, lazy grid, all states)**

```swift
import SwiftUI

struct SourceSelectionView: View {
    @Environment(AppModel.self) private var appModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            Text("\(appModel.selectedIDs.count) photos selected")
                .font(.headline)
            Text("Photos Curator will analyze these photos and propose a smaller album. Your originals stay unchanged.")
                .font(.footnote)
            Picker("Range", selection: $appModel.filter.preset) {
                Text("All").tag(SourcePreset.all)
                Text("Month").tag(SourcePreset.lastMonth)
                Text("3 Months").tag(SourcePreset.last3Months)
                Text("Year").tag(SourcePreset.lastYear)
                Text("Favorites").tag(SourcePreset.favorites)
            }
            .pickerStyle(.segmented)
            content
            Button("Continue") { appModel.continueToSummary() }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.selectedIDs.isEmpty)
        }
        .navigationTitle("Choose source photos")
        .task { await appModel.loadSource() }
        .onReceive(NotificationCenter.default.publisher(for: .photoLibraryDidChange)) { _ in
            Task { await appModel.refreshSourceAfterLibraryChange() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch (appModel.authorization, appModel.sourceState) {
        case (.denied, _), (.restricted, _), (_, .denied):
            Text("Photos Access Needed")
            Text("Allow photo access to choose images for curation.")
        case (_, .loading), (_, .idle):
            ProgressView("Loading photos…")
        case (_, .empty):
            Text("No Photos Available")
            Text("Add photos to your library or allow access to more photos, then try again.")
            Button("Try Again") { Task { await appModel.loadSource() } }
        case (_, .failed):
            Text("Couldn't load photos")
            Button("Retry") { Task { await appModel.loadSource() } }
        case (_, .loaded):
            if appModel.authorization == .limited {
                Text("Limited Photos Access — only shared photos appear. Use Choose More Photos in Home to add more.")
                    .font(.footnote)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(appModel.filteredAssets) { asset in
                        ZStack(alignment: .topTrailing) {
                            AsyncPhotoThumbnail(assetID: asset.id, targetSizePixels: thumbPixels)
                                .aspectRatio(1, contentMode: .fill)
                            Image(systemName: appModel.selectedIDs.contains(asset.id) ? "checkmark.circle.fill" : "circle")
                                .onTapGesture { appModel.toggleSelection(asset.id) }
                                .accessibilityLabel(asset.isFavorite ? "Photo, favorite, selected" : "Photo, selected")
                        }
                    }
                }
            }
            if appModel.unavailableCount > 0 {
                Text("\(appModel.unavailableCount) photos were unavailable and could not be analyzed.")
                    .font(.footnote)
            }
        }
    }
}
```

1k behavior fixed in code: `LazyVGrid` + `id: \.id` (via `Identifiable`), thumb pixels clamped 200–500, no preheat loop, cells release on scroll-away via `.task` cancel; zero selected keeps Continue disabled with no alert; S05 Continue freezes via `continueToSummary()` (no separate push call from the view; the `.summary` push lives inside `continueToSummary()`).

Verify: `rg -n "LazyVGrid|photoLibraryDidChange|continueToSummary" apps/photo-curator/Features/SourceSelection/SourceSelectionView.swift` shows all three.

- [ ] **Step 3: Run format + lint + build (Tasks 1–3 only)**

Run: `./init.sh`
Expected: format clean, `swiftlint --strict` clean, `BUILD SUCCEEDED`, `SKIP [test]`.

### Task 4: S06 Summary on real fetch + RootView wiring + 1k exercise + manual validation

**Files:**
- Create: `apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift`
- Modify: `apps/photo-curator/App/RootView.swift`

**Interfaces:**
- Consumes: slimmed `AppModel.summary` (`selectedCount` + `unavailableCount` only), `AppModel.freezeConfirmedSource()`
- Produces: `struct SelectionSummaryView: View`; `RootView` destinations for `.sourceSelection`/`.summary` (feat-006 preserves both cases and owns the Processing transition out of S06)

- [ ] **Step 1: Create S06 checkpoint screen from the real fetch (freeze-only Start)**

```swift
import SwiftUI

struct SelectionSummaryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Ready to curate \(appModel.summary.selectedCount) photos")
                .font(.title2)
            Text("We'll group similar shots, evaluate photo quality, and build a smaller selection for you to review. Analysis happens on this iPhone. Some photos may need to download from iCloud. This may take a while for large libraries.")
                .font(.body)
            if appModel.summary.unavailableCount > 0 {
                Text("\(appModel.summary.unavailableCount) photos were unavailable and could not be analyzed.")
                    .font(.footnote)
            }
            Button("Start Curation") {
                appModel.freezeConfirmedSource()
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.summary.selectedCount == 0)
            Button("Change Photos") { dismiss() }
        }
        .padding()
        .navigationTitle("Summary")
    }
}
```

`Start Curation` calls freeze-only `freezeConfirmedSource()` and stops — it does not push or route anywhere (Processing transition owned by feat-006). S06 renders selected + unavailable counts only; date-span presentation is explicitly deferred to feat-013 polish.

Verify: `rg -n "Ready to curate|Change Photos|Start Curation|freezeConfirmedSource" apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` shows all four; `rg -n "showSummary|confirmSelection" apps/photo-curator/Features/SourceSelection/SelectionSummaryView.swift` returns nothing.

- [ ] **Step 2: Wire destinations in RootView (deferred here so both views exist)**

```swift
case .sourceSelection:
    SourceSelectionView()
case .summary:
    SelectionSummaryView()
```

Add inside the existing `navigationDestination(for: AppRoute.self)` switch next to `.home`.

Verify: `rg -n "SourceSelectionView|SelectionSummaryView" apps/photo-curator/App/RootView.swift` shows both.

- [ ] **Step 3: Run full verification**

Run: `./init.sh`
Expected: `BUILD SUCCEEDED`, `SKIP [test]`.

- [ ] **Step 4: Manual smoke on 50 real assets + 1k load (no test targets per policy)**

Check: (a) grant Full access on a library with ≥50 photos → Home Curate Photos → S05 grid fills, header count tracks taps, Continue disabled at 0; (b) pick a date preset → grid filters; select 50 → Continue → S06 shows "Ready to curate 50 photos" with selected + unavailable counts (date span deferred to feat-013, not checked here); (c) Limited mode → limited banner + Choose More Photos path in Home still works; Denied → access-required card, no dead CTA; (d) delete 1 selected photo in Photos app mid-session → return → unavailable line appears and count drops; (e) 1k local assets → S05 scrolls without stutter, no full-resolution fetch in Instruments, memory settles (no held `CGImage` batch).

## Self-Review checklist (fixed inline before handoff; re-run after Oracle fixes 2026-09-11)

- [ ] Spec coverage: S05 zero/one/large-set rules, Continue-off-at-zero, originals-safety line, limited/denied/empty/retry states, S06 Start (freeze-only)/Change Photos, selected + unavailable counts, `photoLibraryDidChange` refresh, 1k lazy grid — each maps to ux-flows §6.2/6.3/12.2, apple-frameworks §4–§7, performance §1. Date-span presentation explicitly deferred to feat-013 polish (not in this gate).
- [ ] Build-order check: Task 1 builds alone (Foundation only); Task 2 adds only Task-1 consumers; Task 3 adds thumbnail+S05 on Tasks 1–2; Task 4 adds S06+RootView last — every `./init.sh` passes with only tasks so far applied; no forward type/view references remain.
- [ ] Navigation check: S05 Continue → `continueToSummary()` (freeze + push) is the only S06 push path; S06 Start → `freezeConfirmedSource()` with no push; `rg -n "showSummary|selectAllFiltered|clearSelection|confirmSelection" apps/photo-curator/Features/ apps/photo-curator/SharedUI/ apps/photo-curator/App/` returns nothing (removed APIs fully absent; `continueToSummary()` appends `.summary` directly).
- [ ] Determinism check: freeze path uses private `stableChronoSorted` (date, then `id.rawValue` tiebreak; feat-004 implementation detail, not a cross-chain contract); `confirmedSourceAssets()` maps the frozen IDs in order; cross-chain contract is only frozen `[AssetID]` + ordered `[PhotoAsset]`.
- [ ] Compiling-UI check: `rg -n "aspectFill" apps/photo-curator/SharedUI/ apps/photo-curator/Features/` returns nothing; thumbnail fill is `.resizable()` + `.scaledToFill()` + `.clipped()`.
- [ ] Placeholder scan: `rg -n "TODO|TBD|FIXME|similar to|same as above" apps/photo-curator/Features/SourceSelection apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift apps/photo-curator/App/` returns nothing.
- [ ] Type consistency: `AssetID(rawValue:)` only, `PhotoAsset` cheap fields only, `SelectionError` reused (no new error enum), `SourceFilter` matches `Domain/Models` shapes while slimmed `SelectionSummary` (`selectedCount` + `unavailableCount` only) is intentionally gate-scoped, `thumbnail(for:targetSize:)` pixels (points × scale, clamped 200–500), no `analysisImage`/Vision/scoring/export imports in this feat.
- [ ] Cross-chain stability: `AppRoute.sourceSelection`/`.summary` additive; Produces (`confirmedSourceIDs`, `confirmedSourceAssets()`, `sourceByID`, `SourceFilter.apply`, slimmed `SelectionSummary`, `AsyncPhotoThumbnail init`) unchanged in name/type for feat-005/006; private `stableChronoSorted` is explicitly excluded from the contract.

## Acceptance

- [x] S05/S06 run on 50 real assets; real source reaches real summary (PROVISIONAL 2026-09-11, user-approved: simulator install/launch no-crash evidence; 50-asset tap-through + limited/denied + change-refresh + 1k device QA deferred as documented deviation)
- [x] `./init.sh` passes

## Depends

- feat-003

## Handoff

- State: done
- Evidence: SDD Tasks 1→4 review-clean on feat/feat-004 (commits df6b236..29a1471: b7e50a6 values, e2422d7 model+routes, 6513960 thumbnail+S05, 1e22dd5 S06+RootView, 29a1471 final fix wave); 4 task oracle reviews clean; final review 5 Important fixed in one wave; re-review 4/5 + 1 parked residual (transient error-path stale state, not load-bearing — ruling in .agent-work/sdd/feat-004/progress.md); ./init.sh PASS every task; simulator install/launch no-crash.
- Blockers: deferred follow-ups — real-device QA (50-asset, limited/denied, change-refresh, 1k) + parked stale-error-state race; both tracked, neither blocks feat-005 (frozen-snapshot contract guarded).
- Next: feat-005 on stacked branch feat/feat-005.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
