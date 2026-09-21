# feat-037 — Suggestion integration and legacy retirement

## Status

- Status: `todo`.
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
