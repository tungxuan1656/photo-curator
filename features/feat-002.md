# feat-002 — Foundation: store + onboarding + real DI (ex-G1)

## Goal

Merged ex-G1 now done: file-backed store (FileStore + CheckpointStore + AnalysisCache) plus onboarding S02/S03/S04/S19 plus real DI permission flow run together with `./init.sh` green.

## Scope

- `Infrastructure/` 3 actors: `FileStore.swift` (generic Codable save/load/remove/exists, atomic writes), `SessionCheckpointStore.swift` (opaque stage manifest under `checkpoints/`), `FileAnalysisCache.swift` (memory + file backing under `analysis-cache/`, version-gated).
- `App/` route/model/root: `AppRoute.swift` (welcome, permissionEducation, home), `AppModel.swift` (`@MainActor @Observable`, route + authorization + `isRequesting` guard + `presentPicker()`), `RootView.swift` (`NavigationStack` root, recheck on appear/return), plus 4 views in `Features/Onboarding/` (`WelcomeView` S02, `PermissionEducationView` S03, `HomeView` S04, `AccessGuidanceSheet` S19 sheet).
- `Services/Photos/PhotoLibraryPermissionService.swift`: real auth via PhotoKit access-level APIs; `fetchAssets()` throws pending feat-003.
- `Services/ServiceProtocols.swift`: add `presentLimitedLibraryPicker()` to `PhotoLibraryService` + Noop no-op impl.
- `App/AppContainer.swift`: `live()` real wiring — shared `FileStore`, `FileAnalysisCache`, `SessionCheckpointStore`; rest stay Noop.
- `PrivacyInfo.xcprivacy`: manifest `NSPrivacyAccessedAPITypes` UserDefaults `CA92.1`.

## Non-goals

- No fetch/Vision/scoring/duplicates/export (feat-003+).
- No SourceSelection S05/S06 (feat-004), Processing S07/S08 (feat-006), Review/Save (feat-009+).

## Acceptance

- [ ] `./init.sh` passes (format + strict swiftlint + build; SKIP [test]).
- [ ] `AppContainer.live()` wires real permission service + file-backed cache/checkpoint; rest stay Noop.
- [ ] Auth mapping: notDetermined explains + requests once; full normal; limited valid + picker; denied Settings path; restricted plain note.
- [ ] Rapid double-tap on Continue fires exactly one `requestAuthorization()`.
- [ ] Boundary imports: `Services/` never imports SwiftUI; `Features/`+`App/` never import PhotoKit/Photos; `Infrastructure/` Foundation-only.
- [ ] Simulator: fresh install shows S02→S03→system prompt; deny path shows access-required card.

## Relevant docs

- `docs/design-docs/data-model.md`
- `docs/design-docs/ios-architecture.md`
- `docs/product-specs/ux-flows.md` (§5 S02/S03, §6.1 S04, §11 S19)
- `docs/design-docs/apple-frameworks.md` (§3 permission API)
- `docs/ship-gates/privacy.md` (§5 permission/retention, §8 manifest)
- `docs/ship-gates/performance.md` (§1 budgets)

## Plan

Executed as ex feat-002A/B/INT, now merged. No further tasks.

## Verify

- `./init.sh`

## Handoff

- State: done
- Evidence: ex PR #4 (lane-B) + PR #5 (lane-A) squash-merged to int/G1, PR #6 int/G1→main merged; INT 8 commits; ./init.sh PASS (format, swiftlint --strict, BUILD SUCCEEDED, SKIP [test]); simulator iPhone 17 Pro iOS 26.5 install+launch OK
- Blockers: none
- Next: feat-003

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
