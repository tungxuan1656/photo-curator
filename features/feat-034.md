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

## Review fix wave (16-reviewer findings, 2026-09-22)

Fixed true-positives (per-user scope: feat-034 plus touched feat-027/031 code,
false-positives #1/#10/#11/#12/#23 intentionally untouched):

- Progress (#2+#3): removed workspace `onAppear` mass `markOpened`; detail
  `onAppear` + pager open/close mark `unseen→inProgress` only via a
  session-local overlay (`progressByID` seeded from durable items, updated by
  `markOpened`/`markReviewed`); existing `inProgress`/`reviewed` never regress.
- Staged filter (#4): `ReviewStagedSection` reads session-local
  `stagedCleanupIDs` (seeded from durable `cleanupDisposition`, updated by
  stage/unstage/keep) and renders staged grid + unstage-all instead of
  write-only `Nothing staged`.
- Retry payload (#5+#17) + scope (#14): `ReviewChoiceSaveError` carries exact
  failed dimension values; Retry calls `retrySaveError()` (scope/session
  guarded, same-choice match); success clears only the matching error; failure
  reports the exact payload instead of dropping it.
- Durable feedback (#6): `ensureReviewScope` takes legacy `SelectionFeedback`
  and seeds missing durable item membership (removed→excluded,
  restored→included) so resume never drops pre-workspace remove/restore.
- Intent (#7): `pendingReviewIntent` reset on Home/Start-New paths;
  `reviewIntentForSession` captured at review entry; header reads it
  (`Clean Up Photos` vs `Review Photos`); `createScope` refreshes persisted
  intent on re-entry.
- Scope delete (#15): `WorkspaceStore.deleteScope` + `deleteSessionData` call
  so discard/finish/reset leave no orphaned scope/item rows (idempotent).
- Drag guard (#9): `SourceSelectionView.onDragStart` bounds-checks the stale
  snapshot index before `filteredAssets[startIndex]`.
- Suggestion (#16/#18/#19/#20): `ReviewSuggestionCopy` is
  `LocalizedStringResource` so vi resolves from the catalog; `previewRows`
  reads live model choices (no phantom `albumUnset` oldValue); `applySuggestion`
  returns false on no-op `.unset`; staleness recomputed from live
  `sourceRevision` via `isSuggestionStale` instead of a sticky flag.
- Quality (#13): `QualityAlbumSelector` passes through real `configVersion`
  (new request field from `AppConfiguration.default`), `groupingVersion`
  0-when-empty, `promptVersion` `none`-when-no-comparisons.
- Scheduler (#21): per-request `cancel(requestID:)` on `QualityPairJudging`/
  `QwenPairJudge`/`QwenRuntime` (new `cancelledRequestIDs` + `requestID` on
  `QwenInferenceRequest`); one 12s timeout no longer poisons the run generation.
- l10n (#8/#22/#24): processing fallback uses the catalogued
  `AI unavailable - using…` key for label + VoiceOver; settings byte-progress
  uses `/` instead of English `of`; `CFBundleDisplayName` en fixed to
  `Photos Curator`.
- Verification: `./init.sh` PASS (SwiftFormat, strict SwiftLint 0 violations,
  generic Simulator `BUILD SUCCEEDED`, `SKIP [test]` by DEC-040);
  `git diff --check` PASS. No test targets, test files, or proof harness.
