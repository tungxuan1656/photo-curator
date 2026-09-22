# feat-034 — Shared grouped review

## Status

- Status: `active`.
- Depends on: `feat-033`.

## Goal and acceptance

Build the shared photo-first workspace for **Clean Up Photos** and **Build an
Album**. Acceptance: one grouped review surface supports both intents; filters,
group cards, compare, Needs Review, and action tray preserve all independent
state dimensions; user choices survive incremental analysis, resume, and
navigation; suggestions remain advisory; the minimum suggestion consumer contract
and native adapter are owned here, without a feat-037 dependency; en/vi labels, accessibility, and
recoverable states match owner docs; `./init.sh` passes without test targets,
test files, or proof harness.

## Relevant docs and plan

Primary owners: [ux-flows.md](../docs/product-specs/ux-flows.md),
[ui-copy.md](../docs/product-specs/ui-copy.md),
[review-rules.md](../docs/product-specs/review-rules.md), and
[photo-intelligence.md](../docs/design-docs/photo-intelligence.md). Freeze
interaction seams and state ownership before implementation. The actionable
record is [docs/plans/feat-034.md](../docs/plans/feat-034.md).

feat-033 is complete and `feature_index.json` holds feat-034 `active` as the
sole active feature. Baseline `./init.sh` PASS on `main` before branching
(`tungxuan1656/feat-034-integration`).

## Implementation and verification

- Home routes both intents (`Clean Up Photos`, `Build an Album`) to one
  workspace via `pendingReviewIntent` + `startCleanupReview`/`startAlbumReview`;
  review entry routes to `.reviewWorkspace` (legacy overview/grid/group/Needs
  routes retained behind the same model).
- `beginReview` ensures one durable scope per session through
  `WorkspaceStore.createScope`, seeds item rows from the result, restores
  album selection from durable items (legacy feedback otherwise), and persists
  each applied choice dimension-scoped via `persistWorkspaceChoice`; failure
  keeps live state and surfaces explicit retry without claiming saved state.
- `ReviewModel` owns canonical transitions (`addToAlbum`, `removeFromAlbum`,
  `keepPhoto`, `stageForDeletion`, `unstageDeletion`, `markReviewed`,
  `markOpened`) plus gated `applySuggestion`; `ReviewWorkspaceView` is the
  shared shell (header/filter/grid/group/compare/Needs Review/action tray).
- Suggestion contract (`ReviewSuggestion`, `NativeReviewSuggestionAdapter`)
  adapts native facts only with exact-ID preview and per-dimension apply;
  deletion staging is inexpressible; empty sets use Needs Review empty state.
- Owner en/vi strings added (58 keys); all review literals resolve from the
  catalog; state labels reuse album/cleanup/progress/suggestion owner names.
- Verification: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations,
  generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
  `git diff --check` PASS. No test targets, test files, or proof harness.
