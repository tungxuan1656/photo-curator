# feat-037 — Suggestion integration and legacy retirement

## Status

- Status: `active`.
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

This multi-file retirement feature remains implementation-gated by feat-036;
no code is claimed here.

## Approved delivery shape

Use the existing native facts and deterministic fallback only. Extend immutable
suggestion provenance and bind review uncertainty without changing user-choice
semantics. Retire only active legacy route ownership after its callers and
compatibility readers are verified. Qwen and all other research candidates stay
unadmitted.
