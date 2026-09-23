# feat-037 — Suggestion integration and legacy retirement

## Status

- Status: `done`.
- Depends on: `feat-036`.

## Goal and acceptance

Integrate immutable analysis suggestions into review and retire the legacy
selection route only after the shared workspace is proven. Acceptance:
suggestions have provenance/version/evidence, never mutate user state, and
surface uncertainty as Needs Review; admitted runtime candidates meet license,
privacy, fallback, quality, and performance gates; the legacy route is no
longer an active behavior owner and old data is retired only after migration
markers; `./init.sh` passes without test targets, test files, or proof harness.

## Relevant docs and plan

Primary owners: [photo-intelligence.md](../docs/design-docs/photo-intelligence.md),
[curation-runtime-stack.md](../docs/design-docs/curation-runtime-stack.md),
[review-rules.md](../docs/product-specs/review-rules.md), and
[roadmap.md](../docs/exec-plans/roadmap.md). The actionable record is
[docs/plans/feat-037.md](../docs/plans/feat-037.md).

This multi-file retirement feature completed after feat-036.

## Completion — 2026-09-23

- Review surfaces expose tri-state album membership (`Not chosen
  for album`, `In album`, and `Excluded from album`) through the existing
  `ReviewModel.albumMembership(for:)` seam. Advisory suggestion cards,
  previews, candidate state, workspace cells, and Needs Review remain
  read-only with respect to suggestion output.
- Missing analysis versions render as `Analysis unavailable` rather than
  fabricating `v0`; suggestion preview rows and evidence receive combined
  VoiceOver labels.
- English and Vietnamese catalog entries were added for the new visible and
  accessibility strings.
- Durable workspace sessions no longer read, replay, or write legacy
  `SelectionFeedback`; new rows begin `.unset`, and `SelectionResult` remains
  immutable analysis/suggestion evidence. File-backed readers and writers stay
  only for workspace-unavailable compatibility, migration, checkpoint, save,
  and deletion recovery.
- The existing native `ReviewSuggestion` contract satisfies provenance,
  version, evidence, abstention, and deterministic fallback requirements.
  Qwen and all research candidates remain frozen and unadmitted.

**Verification evidence:** focused SwiftFormat/strict SwiftLint passed with
zero violations; `./init.sh` passed with Simulator `BUILD SUCCEEDED` and no
automated tests under DEC-040; `git diff --check` passed.

**Next:** none.

## Approved delivery shape

Use the existing native facts and deterministic fallback only. Extend immutable
suggestion provenance and bind review uncertainty without changing user-choice
semantics. Retire only active legacy route ownership after its callers and
compatibility readers are verified. Qwen and all other research candidates stay
unadmitted.
