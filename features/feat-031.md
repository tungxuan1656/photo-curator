# feat-031 — Quality-first on-device Qwen curation

## Status

- Status: `todo` — planning complete, implementation awaits user approval.
- Depends on: `feat-028`, `feat-030` (both done).
- Branch: `feat/feat-031-qwen-curation`.

## Goal

Select better representatives and preserve distinct content in 50–100-photo sets with on-device Qwen analysis.
Target iPhone 14 and later, with a 180-second local-analysis budget.

## Scope and ownership

Own the bounded quality pipeline, Qwen runtime and model delivery, visual grouping, album selection, decision provenance, and related review presentation.
Own the affected configuration, persistence, coordinator, localization, and automated evidence contracts.
Exact existing and proposed paths are in the [implementation plan](../docs/plans/feat-031.md#6-file-ownership).

Exclude cloud inference, training, identity recognition, original deletion, Gemma/LFM integration, and unrelated UI redesign.

## Acceptance

- [ ] A1: Independent image evidence establishes coverage, duplicate, best-shot, and recall improvements under plan §10.
- [ ] A2: Qwen3.5-2B uses actual image input through pinned MLX dependencies. The 4B tier has a separate admission result.
- [ ] A3: Model installation, cancellation, pressure, background, and missing-model paths pass automated evidence.
- [ ] A4: Grouping precedes irreversible pruning. Every excluded content group has an accountable outcome.
- [ ] A5: Normal, partial, resume, review, and save paths preserve user choices and session ownership.
- [ ] A6: Versions, downloads, retention, en/vi copy, and rollback match updated owner documents.
- [ ] A7: Automated proof and `./init.sh` pass. No test target, test framework, or manual-QA gate is introduced.

## Readiness plan

Review the linked plan, approve implementation, then activate this feature.
Execute its stages in order. Freeze artifacts and corpus labels before quality comparisons.
Keep hardware claims separate from Simulator evidence.

## Relevant docs

The [plan reading route](../docs/plans/feat-031.md#3-owner-documents-and-contract-changes) identifies each canonical owner.

## Verify and handoff

- Planning baseline: `./init.sh` PASS on 2026-09-18 at `54389e5`.
- Planning verification: fresh `./init.sh` PASS, `git diff --check` PASS, and all 16 local documentation links/anchors resolve.
- Index validation passes: `todo`, completed dependencies, one execution-order entry, and no active-feature conflict.
- Implementation commands are proposed in plan §10, not yet available.
- No application changes, dependency installation, model download, or model benchmark occurred in this planning session.
- Next: review `docs/plans/feat-031.md` and approve implementation.
