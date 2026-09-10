# feat-002B — Onboarding + Permission + Home

## Goal

S02/S03/S04/S19 skeleton runs on Noop mocks: first-run Welcome → Permission education → Home, permission rechecked when returning from Settings, copy matches ux-flows, no real PhotoKit wiring yet (deferred to feat-002INT).

## Scope

- `App/AppRoute.swift`: typed routes for `NavigationStack` (welcome, permissionEducation, home).
- `App/AppModel.swift`: `@MainActor @Observable` holding route + `authorization` + `hasSeenWelcome`, calling the `PhotoLibraryService` protocol (Noop in G1).
- `App/RootView.swift`: `NavigationStack` root, conditional Welcome/Home, `navigationDestination(for:)`, permission recheck on appear/return.
- `Features/Onboarding/WelcomeView.swift` (S02), `PermissionEducationView.swift` (S03), `HomeView.swift` (S04), `AccessGuidanceSheet.swift` (S19 sheet).
- `PhotoCuratorApp.swift`: builds `AppContainer.live()` once, injects `AppModel` via `.environment` (per ios-architecture §5).
- Permission base: `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` in the pbxproj + `PrivacyInfo.xcprivacy` base (no standalone `Info.plist` file because `GENERATE_INFOPLIST_FILE=YES`).
- Do not touch: `Infrastructure/`, `Domain/`, `Services/`, `Configuration/`, `App/AppContainer.live()`.

## Non-goals

- No real PhotoKit fetch, Vision, scoring, duplicates, or moments (G2–G4).
- No SourceSelection S05/S06 (feat-003B), Processing S07/S08 (feat-004B), Review/Save (G4–G5).
- No changes to `AppContainer.live()` (owned by feat-002INT), no changes to `Configuration/`.
- No `feature_index.json` + `progress.md` edits (leader only, inside the INT PR).
- No test targets, `*Test*.swift`, packages, DB, or DI frameworks (DEC-015/016).

## Acceptance

- [ ] `./init.sh` passes (format + strict swiftlint + build; SKIP [test]).
- [ ] First run: the S02 → S03 → system-prompt path renders; `Continue` calls the protocol, `Not Now` returns to Home in the access-required state; the system prompt always follows S03.
- [ ] Every full/limited/denied/restricted state has a visible path: full is normal, limited is valid (not an error) + Choose More Photos, denied shows the `Photos Access Needed` card + `Open Settings`, no dead `Curate Photos` button.
- [ ] Copy matches ux-flows §5–§6/§11; vocabulary uses `removed / add back` (never `delete/trash/rejected`).
- [ ] `Features/` + `App/` never `import PhotoKit`; the engine never `import SwiftUI`; UI only calls the `PhotoLibraryService` protocol.
- [ ] `grep -rn "PhotosCurator" apps/photo-curator/App apps/photo-curator/Features` is empty (excluding history); the pbxproj contains the usage key; the app launches on the simulator to Home.
- [ ] PR `lane-B/feat-002B → int/G1` titled `[feat-002B][lane-B]`, stays inside `owns`, cross-review done.

## Relevant docs

- `docs/product-specs/ux-flows.md` (§5 S02/S03, §6.1 S04, §11 S19)
- `docs/design-docs/ios-architecture.md` (§4 topology, §5 composition, §12 state)
- `docs/ship-gates/privacy.md` (§5 permission/retention, §8 manifest)
- `docs/design-docs/apple-frameworks.md` (§1 boundaries, §3 permission API)
- `docs/design-docs/decision-log.md` (DEC-004 on-device, DEC-005/026 originals untouched)
- `docs/exec-plans/team-build-plan.md` (§2 G1, §4 git workflow)
- `docs/exec-plans/roadmap.md` (P0 foundation)

## Plan

> **Execution:** Follow the repository's implementation and verification rules. No automated tests per DEC-016 — each task's test cycle is `./init.sh` (SwiftFormat + `swiftlint lint --strict` + simulator build). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the onboarding skeleton in 8 tasks so lane B runs standalone on Noop; INT swaps in the real wiring later.

**Architecture:** Value-type `AppRoute` + `@MainActor @Observable AppModel` holding route/auth; `RootView` is the single `NavigationStack`; 4 thin screens that only render state and trigger intents; all auth logic goes through the `PhotoLibraryService` protocol. Ordered so `./init.sh` stays green after every task.

**Tech Stack:** Swift 5.0, SwiftUI + Observation, Foundation only, single target `photo-curator` (synced folders — new files need no `.pbxproj` edit except the permission key).

**Plan artifact decision:** Plan stays inline here. AGENTS.md requires >=2 substantial signals for `docs/plans/feat-<id>.md`; this work has 1 (7 new files, 1 workspace, no migration, no internal phases/rollback — the real wiring is the separate feat-002INT). Precedent: feat-001 (8 files) also stayed inline.

## Global Constraints

- No test targets, no `*Test*.swift` files, no test frameworks (AGENTS.md; DEC-016).
- Validation is manual only; `./init.sh` reports `SKIP [test]` (AGENTS.md).
- Swift 5.0, iOS 26 minimum, single app target `photo-curator`.
- Zero third-party runtime dependencies (ios-architecture invariant).
- The engine never imports SwiftUI; SwiftUI never calls PhotoKit/Vision directly (team-build-plan).
- Lines fit 120 cols (warn) / 150 (error); SwiftFormat (`--maxwidth 120`, indent 4) runs before lint in `./init.sh`.
- App prefix is `PhotoCurator`; canonical model is `PhotoAsset`; `SelectionEngine` stays concrete (DEC-015/028).
- No file has two owners within one stage; contracts freeze in G0 — post-G0 extensions go through leader review (team-build-plan).
- Branch `lane-B/feat-002B` (from `int/G1`); commit subjects `feat-002B: <imperative>`; no `WIP` (team-build-plan §4).
- `feature_index.json` + `progress.md` are touched by the leader only inside the INT PR — this lane branch does NOT edit them.

---

### Task 1: AppRoute

**Files:**
- Create: `apps/photo-curator/App/AppRoute.swift`

**Interfaces:**
- Consumes: nothing (first file).
- Produces: `AppRoute` enum — Tasks 2/3 use `path: [AppRoute]` and `navigationDestination(for: AppRoute.self)`.

- [ ] **Step 1: Create the file with this exact content**

```swift
/// Typed navigation routes for the G1 skeleton. Full route set grows in later stages.
enum AppRoute: Hashable, Sendable {
    case welcome
    case permissionEducation
    case home
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: `PASS [format]`, `PASS [lint]`, `PASS [build]`, `SKIP [test]`, `=== Verification passed ===`. Fix flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/App/AppRoute.swift
git commit -m "feat-002B: add AppRoute typed routes"
```

### Task 2: AppModel

**Files:**
- Create: `apps/photo-curator/App/AppModel.swift`

**Interfaces:**
- Consumes: `AppRoute` (Task 1), `AppContainer` + `PhotoLibraryService`/`PhotoLibraryAuthorization` (G0 contract).
- Produces: `@MainActor @Observable AppModel` — Tasks 3–7 use `appModel.path`, `authorization`, `hasSeenWelcome`, `showPermissionEducation()`, `skipPermission()`, `refreshAuthorization()`, `requestPermission()`.

- [ ] **Step 1: Create the file with this exact content**

```swift
import Foundation
import Observation

/// G1 skeleton session state. Runs on the `PhotoLibraryService` protocol (Noop in G1);
/// real permission wiring lands in feat-002INT.
@MainActor
@Observable
final class AppModel {
    var path: [AppRoute] = []
    var authorization: PhotoLibraryAuthorization = .notDetermined
    var hasSeenWelcome: Bool = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func showPermissionEducation() {
        path.append(.permissionEducation)
    }

    func skipPermission() {
        hasSeenWelcome = true
        path = [.home]
    }

    func refreshAuthorization() async {
        authorization = await container.photoLibrary.authorizationStatus()
    }

    func requestPermission() async {
        authorization = await container.photoLibrary.requestAuthorization()
        hasSeenWelcome = true
        path = [.home]
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS + `SKIP [test]`. Fix flagged lines, re-run until green.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/App/AppModel.swift
git commit -m "feat-002B: add AppModel skeleton on Noop protocol"
```

### Task 3: RootView + App entry

**Files:**
- Create: `apps/photo-curator/App/RootView.swift`
- Modify: `apps/photo-curator/PhotoCuratorApp.swift`

**Interfaces:**
- Consumes: `AppModel` (Task 2), `AppRoute` (Task 1), `HomeView`/`WelcomeView` (Tasks 4/6 — forward reference; this task's `./init.sh` FAILs on build until Tasks 4–6 land, so run lint-only here).
- Produces: `RootView` with `NavigationStack`; `PhotoCuratorApp` builds `AppContainer.live()` once + injects `AppModel`.

- [ ] **Step 1: Create `App/RootView.swift` with this exact content**

```swift
import SwiftUI

/// G1 skeleton root. One `NavigationStack` with typed routes; permission rechecked on appear.
struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack(path: $appModel.path) {
            Group {
                if appModel.hasSeenWelcome {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .welcome:
                    WelcomeView()
                case .permissionEducation:
                    PermissionEducationView()
                case .home:
                    HomeView()
                }
            }
        }
        .task {
            await appModel.refreshAuthorization()
        }
    }
}
```

- [ ] **Step 2: Replace `PhotoCuratorApp.swift` body with this exact content (keep header comments)**

```swift
import SwiftUI

@main
struct PhotoCuratorApp: App {
    @State private var appModel: AppModel

    init() {
        let container = AppContainer.live()
        _appModel = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
    }
}
```

- [ ] **Step 3: Run lint check (build lands after Tasks 4–6)**

Run: `swiftlint lint --strict apps/photo-curator/App/RootView.swift apps/photo-curator/PhotoCuratorApp.swift`
Expected: `Done linting! Found 0 violations`. Fix flagged lines, re-run until clean.

- [ ] **Step 4: Commit**

```bash
git add apps/photo-curator/App/RootView.swift apps/photo-curator/PhotoCuratorApp.swift
git commit -m "feat-002B: add RootView NavigationStack and App entry"
```

### Task 4: WelcomeView (S02)

**Files:**
- Create: `apps/photo-curator/Features/Onboarding/WelcomeView.swift`

**Interfaces:**
- Consumes: `AppModel.showPermissionEducation()` (Task 2).
- Produces: `WelcomeView` — used by `RootView` (Task 3).

- [ ] **Step 1: Create the file with this exact content**

```swift
import SwiftUI

/// S02 Welcome, first run only. Copy owned by ux-flows §5.1.
struct WelcomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Turn hundreds of photos into a small, polished album.")
                .font(.headline)
            Text("Finds the best shots. Trims similar photos. You stay in control of the final album.")
            Button("Get Started") {
                appModel.showPermissionEducation()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Welcome")
    }
}
```

- [ ] **Step 2: Run lint check (build lands after Tasks 5–6)**

Run: `swiftlint lint --strict apps/photo-curator/Features/Onboarding/WelcomeView.swift`
Expected: `Done linting! Found 0 violations`.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Onboarding/WelcomeView.swift
git commit -m "feat-002B: add WelcomeView S02"
```

### Task 5: PermissionEducationView (S03)

**Files:**
- Create: `apps/photo-curator/Features/Onboarding/PermissionEducationView.swift`

**Interfaces:**
- Consumes: `AppModel.requestPermission()`, `skipPermission()` (Task 2). Never calls PhotoKit directly.
- Produces: `PermissionEducationView` — used by `RootView` (Task 3).

- [ ] **Step 1: Create the file with this exact content**

```swift
import SwiftUI

/// S03 permission education, always before the system prompt (ux-flows invariant §1.8).
/// Copy owned by ux-flows §5.2.
struct PermissionEducationView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose photos for curation")
                .font(.headline)
            Text("Photos Curator needs access to the photos you choose so it can analyze them and build your curated album. Photo analysis happens on this iPhone.")
            Button("Continue") {
                Task {
                    await appModel.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Not Now") {
                appModel.skipPermission()
            }
        }
        .padding()
        .navigationTitle("Photo Access")
    }
}
```

- [ ] **Step 2: Run lint check**

Run: `swiftlint lint --strict apps/photo-curator/Features/Onboarding/PermissionEducationView.swift`
Expected: `Done linting! Found 0 violations`.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Onboarding/PermissionEducationView.swift
git commit -m "feat-002B: add PermissionEducationView S03"
```

### Task 6: HomeView (S04)

**Files:**
- Create: `apps/photo-curator/Features/Onboarding/HomeView.swift`

**Interfaces:**
- Consumes: `AppModel.authorization`, `refreshAuthorization()` (Task 2); presents `AccessGuidanceSheet` (Task 7 — forward reference, lint-only here).
- Produces: `HomeView` — `RootView` destination + sheet host.

- [ ] **Step 1: Create the file with this exact content**

```swift
import SwiftUI
import UIKit

/// S04 Home skeleton. Copy owned by ux-flows §6.1. Denied replaces the CTA with the
/// access-required card (never a dead Curate Photos button).
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick a trip, event, or batch of photos. Photos Curator will find the strongest set for you to review.")
            switch appModel.authorization {
            case .authorized, .limited, .notDetermined:
                Button("Curate Photos") {}
                    .buttonStyle(.borderedProminent)
                if appModel.authorization == .limited {
                    Button("Limited Photos Access — Choose More Photos") {
                        showsAccessGuidance = true
                    }
                }
            case .denied, .restricted:
                Text("Photos Access Needed")
                    .font(.headline)
                Text("Allow photo access to choose images for curation.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Learn More") {
                    showsAccessGuidance = true
                }
            }
        }
        .padding()
        .navigationTitle("Photos Curator")
        .sheet(isPresented: $showsAccessGuidance) {
            AccessGuidanceSheet()
        }
        .task {
            await appModel.refreshAuthorization()
        }
    }
}
```

- [ ] **Step 2: Run verification (full build now resolves Tasks 3–6)**

Run: `./init.sh`
Expected: full PASS + `SKIP [test]`. If `AccessGuidanceSheet` missing (Task 7) fails the build, run lint-only instead and continue to Task 7 before re-running the full script.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Onboarding/HomeView.swift
git commit -m "feat-002B: add HomeView S04 skeleton"
```

### Task 7: AccessGuidanceSheet (S19)

**Files:**
- Create: `apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift`

**Interfaces:**
- Consumes: `AppModel.authorization` (Task 2).
- Produces: `AccessGuidanceSheet` — presented by `HomeView` (Task 6). Unblocks the Task 6 full build.

- [ ] **Step 1: Create the file with this exact content**

```swift
import SwiftUI
import UIKit

/// S19 access management sheet, not a full flow. Copy owned by ux-flows §11.
struct AccessGuidanceSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            switch appModel.authorization {
            case .limited:
                Text("Photos Curator can only use the photos currently shared with the app.")
                Button("Choose More Photos") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            case .denied, .restricted:
                Text("Photo access is turned off. Enable it in Settings to curate photos.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            default:
                Text("Photo analysis is performed on this device.")
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: Run verification**

Run: `./init.sh`
Expected: full PASS now (all views resolve) — `PASS [format]`, `PASS [lint]`, `PASS [build]`, `SKIP [test]`.

- [ ] **Step 3: Commit**

```bash
git add apps/photo-curator/Features/Onboarding/AccessGuidanceSheet.swift
git commit -m "feat-002B: add AccessGuidanceSheet S19"
```

### Task 8: Permission key + privacy manifest + evidence

**Files:**
- Modify: `apps/photo-curator.xcodeproj/project.pbxproj` (add `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` only)
- Create: `apps/photo-curator/PrivacyInfo.xcprivacy`
- Modify: `features/feat-002B.md` (Handoff Evidence)

**Interfaces:**
- Consumes: all Tasks 1–7 (the skeleton must be green first).
- Produces: an installable build with the usage description; the privacy manifest base for INT.

- [ ] **Step 1: Add the usage key (no `Info.plist` file — `GENERATE_INFOPLIST_FILE=YES`)**

In the Xcode target `photo-curator` > Build Settings, add:

```text
INFOPLIST_KEY_NSPhotoLibraryUsageDescription = Photos Curator needs access to your photo library to analyze and select your best photos. Photo analysis is performed on your device.
```

String owned by privacy §5.1. Touch no other build setting (the pbxproj is a shared gray zone with lane A — the leader resolves conflicts at INT).

- [ ] **Step 2: Create `apps/photo-curator/PrivacyInfo.xcprivacy` with this exact content**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 3: Run verification**

Run: `./init.sh` (expect full PASS), then:

```bash
grep -rn "INFOPLIST_KEY_NSPhotoLibraryUsageDescription" apps/photo-curator.xcodeproj/project.pbxproj
grep -rn "import PhotoKit" apps/photo-curator/App apps/photo-curator/Features || true
```

Expected: the first grep prints the key line; the second prints nothing (SwiftUI never touches PhotoKit).

- [ ] **Step 4: Record evidence and commit**

Set the Handoff in this file to: State `active`, Evidence `./init.sh PASS (BUILD SUCCEEDED, SKIP [test]) + S02/S03/S04/S19 skeleton on Noop`, Next `open PR [feat-002B][lane-B] lane-B/feat-002B → int/G1`.

```bash
git add apps/photo-curator.xcodeproj/project.pbxproj apps/photo-curator/PrivacyInfo.xcprivacy features/feat-002B.md
git commit -m "feat-002B: add permission key, privacy manifest, evidence"
```

## Verify

- `./init.sh`
- Manual walkthrough (Noop skeleton): fresh launch → S02 Welcome → Get Started → S03 → Continue (Noop `.denied` → Home access-required card) / Not Now (Home access-required); the Home limited path shows the Choose More Photos sheet; rechecking on return from Settings does not crash.

## Handoff

- State: active
- Evidence: —
- Blockers: none
- Next: Execute Tasks 1–8 in order, keep `./init.sh` green after each task, then open PR `[feat-002B][lane-B]` into `int/G1`.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
