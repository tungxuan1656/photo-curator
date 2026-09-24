# Photo Organization Pivot Contracts Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules.

**Goal:** Replace the shared cleanup/album product contract with a similarity-first Photos companion and actionable feature plans.

**Architecture:** Keep the existing document ownership paths. Add one organization-rules owner for overlapping labels, query semantics, and group meaning.

**Tech Stack:** Markdown, JSON, existing Swift/SwiftUI/PhotoKit/Vision/SwiftData source as evidence.

## Global constraints

- iPhone 14+ / iOS 26+, on-device processing, English/Vietnamese UI remain the planning baseline.
- Use `./init.sh`; add no tests, test frameworks, or standalone proof harnesses.
- Manual QA is optional and never a feature or release gate.
- This feature changes documentation and work records only.

## Assessment and artifact map

Growing single-app repository with migration pressure, destructive operation contracts, and multi-session delivery.
Reuse the current directories and preserve historical feature results.

| Artifact | Responsibility and change | Refresh event |
|---|---|---|
| `docs/product-specs/product.md` | Rewrite purpose, scope, priority, success | Product decision |
| `docs/product-specs/organization-rules.md` | Create label/group/query semantics | Organization behavior change |
| `docs/product-specs/ux-flows.md` | Rewrite navigation, visible states, inspection | Screen behavior change |
| `docs/product-specs/review-rules.md` | Rewrite action-selection semantics; preserve deletion gates | Mutation contract change |
| `docs/product-specs/ui-copy.md` | Rewrite target bilingual vocabulary and states | User-visible copy change |
| `docs/design-docs/{ios-architecture,data-model,photo-intelligence,curation-runtime-stack,apple-frameworks}.md` | Rewrite observed/target boundaries within existing ownership | Relevant implementation/admission change |
| `docs/ship-gates/{privacy,performance,analytics,manual-qa}.md` | Align boundaries and evidence with organization | Retention, budget, or evidence change |
| `docs/design-docs/decision-log.md` | Append rationale; identify superseded decisions | Accepted consequential decision |
| `docs/exec-plans/roadmap.md`, `features/`, `docs/plans/`, `feature_index.json` | Dependency order, scope, acceptance, recovery | Feature state change |
| `README.md`, `AGENTS.md`, `docs/index.md` | Entry and task routing | Owner/path/purpose change |

No new documentation tree, generic security guide, or duplicate tracker is needed.
Completed plans and evidence remain historical records. They are not rewritten as new results.

## Observed baseline

Source baseline: `01840e7`, inspected 2026-09-23.

| Source | Reusable behavior | Pivot gap |
|---|---|---|
| `apps/photo-curator/App/AppContainer.swift` | Live native analyzer, SwiftData V2, operation stores, cache | No continuous catalog coordinator |
| `Services/Photos/PhotoLibraryPermissionService.swift` | Asset fetch and library-change notification | Observer triggers refresh, not durable incremental indexing |
| `Services/Session/SelectionSessionCoordinator.swift`, `Services/Photos/BatchPipeline.swift` | Bounded analysis, checkpoints, resume | Produces session `SelectionResult`, not library discovery snapshots |
| `Domain/Selection/DuplicateResolver.swift` | FeaturePrint edges, conservative merge checks, deterministic membership IDs | Time-window candidates; no library-wide duplicate retrieval guarantee |
| `Domain/Models/PhotoAnalysis.swift`, `Services/Analysis/UniversalFactAdapter.swift` | Technical facts, native classification tags, availability and mapping revision | No stable user-facing facet taxonomy or durable corrections |
| `Infrastructure/PhotoCuratorSchema.swift`, `WorkspaceStore.swift` | Scopes, independent choices, album/deletion operations | No asset catalog or queryable label projection |
| `Features/Review/ReviewWorkspaceView.swift` | Grid, suggestions, group previews, staged actions | Groups follow the full grid; selection means album membership |
| `Features/Review/PhotoDetail.swift` | Bounded preview and scoped paging | Coupled to `ReviewModel` and session identity |
| `Services/Export/AlbumSaveService.swift`, `Services/Deletion/PhotoDeletionService.swift` | Durable mutation services | Need selection-snapshot entry independent of session picks |

Paths in this table use `apps/photo-curator/` after the first row.
Implementation plans identify exact inspected paths or explicitly proposed new paths.

## Decisions and uncertainties

- Accepted: companion role, similar groups first, useful overlapping labels, cleanup/album as downstream actions.
- Accepted: comparable duplicates/retakes form groups; shared topic alone is a label relationship.
- Intended details are recorded in owner docs for user review before implementation activation.
- feat-040 selects additive schema details and query storage within the documented persistence boundary.
- feat-042 selects bounded cross-date retrieval and records accuracy/resource limitations.
- feat-044 selects an admissible AI provider and freezes the initial supported taxonomy. No model is admitted by this rewrite.
- Numeric quality thresholds require evidence. Do not invent accuracy claims or add prohibited benchmark harnesses.

## Tasks

- [x] Inspect source, historical state, and baseline `./init.sh`.
- [x] Rewrite canonical product and organization contracts.
- [x] Rewrite technical owners and relevant ship-gate documents.
- [x] Add feat-040–047 records and linked readiness plans.
- [x] Rewrite entry routes and append the pivot decision.
- [x] Validate links, dependency graph, scope coverage, and whitespace.
- [x] Run `./init.sh`, close feat-039, and append progress evidence.

## Verification and rollback

Inspect changed Markdown links and tracker JSON with one-off read-only validation.
Run `git diff --check` and `./init.sh`. Record failures without expanding into app repair.
Documentation rollback restores the prior owner documents and tracker together; no app schema changes occur here.

## Handoff

User review of the written product/organization contract precedes implementation approval.
Next implementation candidate: feat-040. All implementation features remain `todo`.

Completed 2026-09-23. Baseline/final `./init.sh` and `git diff --check` passed.
Document validation covered 107 files and 368 local links with zero failures; all 47 tracker records had valid ordered dependencies.
No app implementation, model admission, or image-quality claim is part of this completion.
