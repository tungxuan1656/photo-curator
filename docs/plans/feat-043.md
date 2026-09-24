# Group-first Discovery and Inspection Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Activate after feat-042 and user approval.

**Goal:** Make groups and inspection directly usable from the catalog.

**Architecture:** Introduce catalog navigation and read models. Adapt existing inspector/preview components to asset snapshots instead of requiring `ReviewModel` sessions.

**Tech Stack:** SwiftUI, Observation, existing bounded photo loader, catalog query snapshots.

## Global constraints

- iPhone 14+ / iOS 26+, en/vi, VoiceOver, Dynamic Type, 44-point controls, Reduce Motion.
- Opening a photo never changes album membership or deletion staging.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes catalog metadata, group snapshots, and analysis coverage from feat-040–042.
Produces discovery/group/detail routes and result-scoped inspection state for feat-045.

## Files and tasks

### 1. Add catalog discovery

Existing: `apps/photo-curator/App/AppRoute.swift`, `RootView.swift`, `AppModel.swift`, `Features/Onboarding/HomeView.swift`.
Proposed new: `apps/photo-curator/Features/Library/LibraryModel.swift`, `LibraryView.swift`.

- [ ] Route the main organization entry to groups, with direct All Photos and later label entry.
- [ ] Publish metadata-first browsing plus per-capability partial/paused/iCloud status.
- [ ] Keep saved-work recovery reachable without the cleanup/album entry requirement.

### 2. Adapt group and inspector surfaces

Existing: `apps/photo-curator/Features/Review/SimilarGroups.swift`, `PhotoDetail.swift`, `PhotoInspectionCanvas.swift`, `PhotoInspectionState.swift`, `PhotoAnalysisDetail.swift`.
Proposed new: `apps/photo-curator/Features/Library/ComparisonGroupView.swift`.

- [ ] Pass exact asset IDs and scoped order to detail without requiring a selection-session result.
- [ ] Give every thumbnail, including suggestion/group previews, a distinct inspection route.
- [ ] Preserve bounded zoom/paging, retry, and active-photo state on incremental updates.
- [ ] Show relation/member counts and evidence beside compared photos; omit unsupported judgments.
- [ ] Remove album-toggle meaning from the new inspector while preserving legacy recovery adapters.

### 3. Complete states and localization

Existing: `apps/photo-curator/SharedUI/AsyncPhotoThumbnail.swift`, `Localizable.xcstrings`, `InfoPlist.xcstrings`.

- [ ] Add empty, pending, unavailable, changed-group, and access-loss states from the copy owner.
- [ ] Preserve VoiceOver inspection and navigation paths independently of selection controls.
- [ ] Update current owner docs with actual route/type names after integration.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Inspect all thumbnail call sites for a detail path, scoped paging, distinct selection hit targets, missing images, and stable refresh behavior.
Do not claim an observed interaction pass from compilation alone.

## Rollback and handoff

Retain legacy saved-work routes and the shared image loader.
Disable only the new route if catalog data is unavailable; never delete catalog or saved user state.
Hand query/group navigation context to feat-045.
