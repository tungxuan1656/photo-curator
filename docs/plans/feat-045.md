# Faceted Discovery and Label Editing Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Both feat-043 and feat-044 must be done before activation.

**Goal:** Combine labels into useful photo/group results with exact snapshot selection.

**Architecture:** Query compact effective-label projections, then join group membership as a result view. Separate temporary selection from draft membership.

**Tech Stack:** SwiftData queries/projections, SwiftUI/Observation, localized label taxonomy.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese, accessible controls.
- Follow [organization semantics](../product-specs/organization-rules.md#filter-semantics).
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes feat-043 catalog navigation and feat-044 effective assignments/correction intents.
Produces revisioned result IDs/counts, filtered group contexts, and a frozen action selection for feat-046.

## Files and tasks

### 1. Implement the query contract

Modify feat-040 catalog store at its confirmed path.
Proposed new: `apps/photo-curator/Domain/Organization/LibraryQuery.swift`, `Features/Library/LibraryQueryModel.swift`.

- [ ] Implement AND across facets, OR within a facet, and intersected date/source scope.
- [ ] Deduplicate IDs and expose coverage independently from match counts.
- [ ] Compute contextual facet counts without summing overlapping labels as unique photos.
- [ ] Return deterministic paged results and a complete ID snapshot for Select All.

### 2. Add discovery and correction UI

Modify feat-043 `LibraryView` and `LibraryModel` at their confirmed paths.
Proposed new: `apps/photo-curator/Features/Library/LabelBrowserView.swift`, `LibraryFilterView.swift`, `PhotoLabelEditor.swift`.

- [ ] Add facet chips, Clear Filters, label shortcuts, and explicit empty/incomplete states.
- [ ] Add Photos/Matching Groups views over the same query.
- [ ] Show matched/total counts and outside-filter alternatives without silently including them in result selection.
- [ ] Bind label confirm/reject/personal actions to durable correction intents with save-failure recovery.

### 3. Freeze action selection

Existing reuse candidate: `apps/photo-curator/SharedUI/SelectionToggle.swift`.
Proposed new: `apps/photo-curator/Features/Library/LibrarySelectionState.swift`.

- [ ] Give selection its own state rather than `ReviewModel.selectedAssetIDs` album semantics.
- [ ] Capture exact result IDs/revision; do not add new analysis matches automatically.
- [ ] Clear selection on query change and require an explicit group selection context for outside-filter photos.
- [ ] Invalidate affected previews on access loss and publish named action/count state for feat-046.
- [ ] Update `apps/photo-curator/Localizable.xcstrings` with en/vi count and accessibility variants.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Review Nature AND (Blur OR Underexposure), overlapping label counts, partial inference, paged Select All, query changes, and two-of-five group context.
Inspect that no query/selection action mutates album or cleanup state.

## Rollback and handoff

Query UI can return to All Photos/Groups without deleting labels or projections.
Document selection snapshot identity and invalidation rules for feat-046.
