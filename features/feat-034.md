# feat-034 — Shared grouped review

## Status

- Status: `todo`.
- Depends on: `feat-033`.

## Goal and acceptance

Build the shared photo-first workspace for **Clean Up Photos** and **Build an
Album**. Acceptance: one grouped review surface supports both intents; filters,
group cards, compare, Needs Review, and action tray preserve all independent
state dimensions; user choices survive incremental analysis, resume, and
navigation; suggestions remain advisory; en/vi labels, accessibility, and
recoverable states match owner docs; `./init.sh` passes without test targets,
test files, or proof harness.

## Relevant docs and plan

Primary owners: [ux-flows.md](../docs/product-specs/ux-flows.md),
[ui-copy.md](../docs/product-specs/ui-copy.md),
[review-rules.md](../docs/product-specs/review-rules.md), and
[photo-intelligence.md](../docs/design-docs/photo-intelligence.md). Freeze
interaction seams and state ownership before implementation. The actionable
record is [docs/plans/feat-034.md](../docs/plans/feat-034.md).

This multi-file feature remains implementation-gated by feat-033; no code is
claimed here.
