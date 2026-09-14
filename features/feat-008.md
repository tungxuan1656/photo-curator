# feat-008 — Scoring + diversity + verify

## Goal

Land scoring + diversity + verify per selection-rules §14 with reason codes.

## Scope

- `Domain/Scoring/QualityScorer.swift` (new: weighted score + disposition + per-moment rank + round-robin shortlist)
- `Domain/Selection/DiversitySelector.swift` (new: protected-first greedy utility fill)
- `Domain/Selection/FinalAlbumBuilder.swift` (new: one-decision-per-source + invariants, engineVersion 2)
- `Domain/Selection/SelectionEngine.swift` (full pipeline + feedback overrides replacing pass-through)
- `Services/Session/SelectionSessionCoordinator.swift` (shared finalizeAvailable entry point)
- `Services/Session/SimilarityRebuilder.swift` (new: bounded partial-path artifact rebuild)
- `Features/Processing/ProcessingModel.swift` (finalizeAvailable forwarding)
- `App/AppModel.swift` (finalizePartial via coordinator)
- `docs/design-docs/data-model.md` (decision/reason mapping only)
## Non-goals

- Review UI (feat-009); threshold tuning beyond existing config values.
## Acceptance

- [x] Sizing per selection-rules §14; reason codes; chronological order
- [x] `./init.sh` passes

## Depends

- feat-007
## Plan

Plan: `docs/plans/feat-008.md`
## Handoff

- State: done
- Evidence: self-review 2 agents (engine-logic 8 PASS/6 FAIL→fixed, service-boundary 10/10 PASS) + fixes committed (moment missing-signal continuity, edited moment rep, forced-cluster guard, usable-only swap consistency, loser-moment inheritance); ./init.sh PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); device QA deferred to feat-009 review instrument per plan (S09–S11 are the G2 eyes on this engine)
- Blockers: none (code review closed; device Dataset B + Golden evaluation runs on feat-009 grid/detail)
- Next: feat-009 (Review core S09/S10/S11) on stacked branch from feat-008 HEAD.
