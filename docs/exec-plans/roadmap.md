# Roadmap

**Status:** Phase 1 pivot roadmap · 2026-09-21

This doc owns build order. Product scope is in [product.md](../product-specs/product.md);
execution records are in `feature_index.json` and `features/feat-<id>.md`.
`docs/plans/feat-032.md` through `docs/plans/feat-038.md` are the current
actionable pivot plans. Other `docs/plans/*` files are older historical records
and remain unchanged.

## Pivot sequence

```text
feat-031 blocked/preserved
  → feat-032 contracts/docs/tracker
  → feat-033 durable workspace + migration
  → feat-034 shared grouped review
  → feat-035 album draft + resilient save
  → feat-036 confirmed original deletion
  → feat-037 suggestion integration + legacy retirement
  → feat-038 native analysis + actionable review repair
```

Only one feature is active. A dependent feature becomes active only after its
predecessor's acceptance and required verification pass. Every behavior change
uses reproducible automated evidence plus `./init.sh`; this project adds no test
targets, test files, test frameworks, or standalone proof harnesses.

## Plan records

Current actionable pivot plans are [feat-032](../plans/feat-032.md),
[feat-033](../plans/feat-033.md), [feat-034](../plans/feat-034.md),
[feat-035](../plans/feat-035.md), [feat-036](../plans/feat-036.md), and
[feat-037](../plans/feat-037.md), followed by the audited repair plan
[feat-038](../plans/feat-038.md). Other `docs/plans/*` files are older
historical records; links are preserved and those plans are not current work.

## Phase gates

| Feature | Exit gate |
|---|---|
| 032 | Owner docs agree on shared workspace, independent state, access/deletion, migration, copy, and tracker order |
| 033 | SwiftData workspace round-trips; file/cache boundary and idempotent legacy marker are proven |
| 034 | Both intents use one grouped review surface and preserve user choices through resume/re-analysis |
| 035 | Album draft/save is independent, resumable, and truthful on partial outcomes |
| 036 | Exact-set, full-access, explicit-confirmation deletion is bounded and reconciles without automatic retry |
| 037 | Suggestions are advisory, admitted runtime evidence is complete, and legacy active ownership is retired |
| 038 | Native execution and evidence reach useful review; cache recovery and user-choice persistence remain correct |

## Deferred

Cloud inference, accounts, sync, social features, editing, video, identity
recognition, automatic deletion, and unverified models remain out of scope.
Model candidates stay research-only until license, privacy, runtime, quality,
and iPhone performance evidence is recorded in the owner docs.
