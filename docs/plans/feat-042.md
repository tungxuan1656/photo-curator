# Library-wide Comparison Groups Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Resolve the retrieval decision before implementation.

**Goal:** Build useful comparison groups without album-selection constraints.

**Architecture:** Reuse image-sensitive native evidence behind separate retake and cross-date near-copy candidate paths. Publish compact revisioned groups into the catalog.

**Tech Stack:** Swift domain grouping, Vision similarity seam, catalog projections, bounded image loading.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese explanations.
- Shared topic alone never establishes comparison membership.
- No unbounded all-pairs image comparison or implicitly persisted visual embeddings.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes feat-041 current asset evidence and capability availability.
Produces exact-member comparison snapshots, relation reasons, current coverage, and invalidation notifications.
Groups remain independent of `selectedAssetIDs`, album target count, and filter query.

## Files and tasks

### 1. Resolve retrieval and artifact lifetime

Inspect `apps/photo-curator/Domain/Selection/DuplicateResolver.swift`, `Services/Analysis/ImageSimilarityArtifact.swift`, `Services/Session/SimilarityRebuilder.swift`.

- [ ] Document the current time-window recall limit and unknown-date behavior.
- [ ] Compare bounded candidate approaches for cross-date near-copies and same-capture retakes.
- [ ] Choose an approach with explicit candidate/memory bounds and documented missed-match tradeoffs.
- [ ] If it requires persisted visual artifacts, obtain an explicit data/privacy decision before adding storage.
- [ ] Record evidence and unresolved quality limits in the runtime/intelligence owners; do not invent an accuracy threshold.

### 2. Produce coherent groups

Existing: `apps/photo-curator/Domain/Models/SelectionGrouping.swift`, `Domain/Selection/QualityGroupBuilder.swift`, `Domain/Selection/DuplicateResolver.swift`.
Proposed new: `apps/photo-curator/Domain/Organization/ComparisonGroupBuilder.swift`.

- [ ] Separate group construction from representative album selection.
- [ ] Validate candidate edges with image evidence and prevent unrelated endpoint merges through transitive chains.
- [ ] Distinguish near-copy and retake relation wording; reserve exact-duplicate wording for exactness evidence.
- [ ] Produce deterministic membership identities/revisions and an optional representative without automatic keeper authority.
- [ ] Keep unsupported/unavailable assets browseable outside groups.

### 3. Publish incremental snapshots

Integrate feat-040 `LibraryCatalogStore` and feat-041 `LibraryAnalysisCoordinator` at their confirmed paths.

- [ ] Invalidate groups affected by revised, added, or inaccessible assets.
- [ ] Atomically replace derived projections without changing user labels, drafts, or staging.
- [ ] Preserve open comparison snapshots and publish an explicit update indication.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Review cross-date copies, missing dates, unrelated same-topic images, chain merges, identical scores, stale revisions, and no-group output against the implementation.
Record any available image-sensitive evidence separately from build/source evidence.

## Rollback and handoff

Retain provider/grouping revision so invalid derived groups can be invalidated and rebuilt.
Do not erase user work when disabling a grouping revision.
Document group snapshot/reason/coverage contracts for feat-043.
