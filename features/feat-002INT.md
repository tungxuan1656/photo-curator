# feat-002INT — Connect G1: wire real DI

## Goal

Replace Noop doubles with real G1 wiring so the permission flow runs for real (full/limited/denied/restricted/notDetermined) on the protocol boundary, with `./init.sh` green. No fetch/Vision/scoring yet (G2–G4).

## Scope

- Create `Services/Photos/PhotoLibraryPermissionService.swift`: real `PhotoLibraryService` auth via PhotoKit access-level APIs; `fetchAssets()` throws `SelectionError.internal` (owned by feat-003A).
- Extend `Services/ServiceProtocols.swift`: add `presentLimitedLibraryPicker()` to `PhotoLibraryService` (leader-approved post-G0 extension) + Noop no-op impl.
- Edit `App/AppContainer.swift`: add concrete `checkpointStore: SessionCheckpointStore` (per ios-architecture §5); `live()` wires real permission service + file-backed cache/checkpoint; everything else stays Noop.
- Edit `App/AppModel.swift`: `isRequesting` guard in `requestPermission()` (double-tap fix); `presentPicker()` passthrough.
- Edit `Features/Onboarding/AccessGuidanceSheet.swift`: `.limited` calls picker via model; switch exhaustive (explicit `.notDetermined`/`.authorized`).
- Edit `HomeView.swift`: remove redundant `.task` (RootView already rechecks on appear + scenePhase).
- Edit `PrivacyInfo.xcprivacy`: add `NSPrivacyAccessedAPITypes` (UserDefaults `CA92.1`).

## Non-goals

- No asset fetch, metadata map, thumbnails, Vision, scoring, duplicates, moments, export (G2–G5; feat-003A owns `Services/Photos/PhotoLibraryService.swift` — this feat MUST NOT create that file).
- No SourceSelection S05/S06 (feat-003B); HomeView Curate CTA stays disabled with its TODO.
- No typed `ProcessingStage`, no coordinator, no change-observer wiring (§10 arrives with fetch stages).
- No test targets, `*Test*.swift`, packages, DB, DI frameworks (DEC-015/016).

## Acceptance

- [ ] `./init.sh` passes (format + strict swiftlint + build; SKIP [test]).
- [ ] `AppContainer.live()` returns real permission service + `FileAnalysisCache`/`SessionCheckpointStore` on a shared `FileStore`; only photoLibrary/analysisCache change hands vs G0, rest stay Noop.
- [ ] Auth mapping: `.notDetermined` → explain + request once; `.authorized` normal; `.limited` valid + picker; `.denied` Settings path, no prompt loop; `.restricted` plain note; `@unknown` fails safe (no crash).
- [ ] Rapid double-tap on Continue fires exactly one `requestAuthorization()`.
- [ ] `Services/` never imports SwiftUI; `Features/`+`App/` never import PhotoKit/Photos (picker goes through the protocol); `Infrastructure/` stays Foundation-only.
- [ ] Simulator: fresh install shows S02→S03→system prompt; deny path shows access-required card; no crash on Settings return.

## Relevant docs

- `docs/design-docs/apple-frameworks.md` (§3 authorization API, §10 changes deferred)
- `docs/design-docs/ios-architecture.md` (§5 composition, §6 boundaries)
- `docs/product-specs/ux-flows.md` (§5 S02/S03, §6.1 S04, §11 S19)
- `docs/ship-gates/privacy.md` (§5 permission/retention, §8 manifest)
- `docs/exec-plans/team-build-plan.md` (§4 INT lifecycle)

## Plan

> **Execution:** No automated tests per DEC-016 — each task's test cycle is `./init.sh`. Checkbox syntax for tracking.

**Tasks:**
1. `PhotoLibraryPermissionService` (Photos only): `authorizationStatus()` maps `PHPhotoLibrary.authorizationStatus(for: .readWrite)`; `requestAuthorization()` awaits `PHPhotoLibrary.requestAuthorization(for: .readWrite)` via checked continuation; `@unknown default` → `.restricted`; `fetchAssets()` throws `SelectionError.internal` with TODO(feat-003A); `presentLimitedLibraryPicker()` hops to MainActor, finds key-window root VC from connected scenes, calls `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)` (no-op if VC missing).
2. Protocol extension: `presentLimitedLibraryPicker()` on `PhotoLibraryService` + Noop empty impl.
3. `AppContainer.live()`: shared `FileStore` rooted in Application Support `/photo-curator`; cache with `AppConfiguration.default.analysis.analysisVersion`; add `checkpointStore` field.
4. `AppModel`: `isRequesting` guard + `presentPicker()`; sheet + HomeView updates; manifest `CA92.1`.
5. `./init.sh` green; record evidence.

**Plan artifact decision:** Inline. Bounded tracked work (1 new file, ~5 small edits, 1 workspace, <200 lines, no migration).

## Global Constraints

- Swift 5.0, iOS 26 minimum, single target (synced folders — no `.pbxproj` edit).
- Zero third-party deps; engine never imports SwiftUI; UI never calls PhotoKit directly.
- Lines 120 warn / 150 error; SwiftFormat indent 4.
- Branch `int/G1` (leader-owned); commit subjects `feat-002INT: <imperative>`.

## Verify

- `./init.sh`
- Simulator walkthrough: fresh install → S02 → S03 → Continue → system prompt; deny → access-required card; Settings return → no crash.

## Handoff

- State: done
- Evidence: 8 commits cfd0c97..e5d6efd on int/G1; ./init.sh PASS fresh on final HEAD (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); boundary greps clean (no PhotoKit in App/Features, no SwiftUI in Services/Infra/Domain); simulator smoke iPhone 17 Pro iOS 26.5: install + launch OK, S02 Welcome renders, no crash with real PHPhotoLibrary wiring (note: booted iOS 26.2 device rejected the app — deployment target is 26.5)
- Partially verified (needs lead finger/device): tap-through S03→system prompt, deny card path, Settings-return recheck, limited picker presentation, double-tap single-request at runtime; real-iPhone dataset-A smoke still recommended before G2
- Deviation: added `import PhotosUI` (required for presentLimitedLibraryPicker; docs §3 already names PhotosUI)
- Blockers: none
- Next: PR int/G1 → main (merge commit); G2 unblocked (003A owns fetch, 003B owns S05/S06)

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
