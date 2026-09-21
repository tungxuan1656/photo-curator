# feat-035 — Album draft and resilient save

## Status

- Status: `todo`.
- Depends on: `feat-034`.

## Goal and acceptance

Persist album draft membership independently from cleanup, then save it
resiliently to a Photos album. Acceptance: explicit save creates or resumes a
collision-safe album write without duplicate additions; partial outcomes are
truthful and retry only by explicit user action; save interruption reconciles;
save never clears the workspace or cleanup disposition; limited access reports
the correct recovery path; `./init.sh` passes without test targets, test files,
or proof harness. Feat-035 owns the album-save operation entity/state and adds
it through an explicit SwiftData schema migration; feat-033 does not own it.

## Relevant docs and plan

Primary owners: [review-rules.md](../docs/product-specs/review-rules.md),
[ux-flows.md](../docs/product-specs/ux-flows.md),
[apple-frameworks.md](../docs/design-docs/apple-frameworks.md), and
[data-model.md](../docs/design-docs/data-model.md). The actionable record is
[docs/plans/feat-035.md](../docs/plans/feat-035.md).

This shared PhotoKit/state feature remains implementation-gated by feat-034;
no code is claimed here.
