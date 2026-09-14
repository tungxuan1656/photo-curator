# feat-008 — Scoring + diversity + verify

## Goal

Land scoring + diversity + verify per selection-rules §14 with reason codes.

## Scope

- `Domain/Scoring/QualityScorer.swift` (new: weighted score + disposition + per-moment rank + round-robin shortlist)
- `Domain/Selection/DiversitySelector.swift` (new: protected-first greedy utility fill)
- `Domain/Selection/FinalAlbumBuilder.swift` (new: one-decision-per-source + invariants, engineVersion 2)
- `Domain/Selection/SelectionEngine.swift` (full pipeline replacing pass-through)
- `Services/Session/SelectionSessionCoordinator.swift` (shared finalizeAvailable entry point)
- `Services/Session/SimilarityRebuilder.swift` (new: bounded partial-path artifact rebuild)
- `Features/Processing/ProcessingModel.swift` (finalizeAvailable forwarding)

## Non-goals

- Review UI (feat-009); threshold tuning beyond existing config values.
## Acceptance

- [ ] Sizing per selection-rules §14; reason codes; chronological order
- [ ] `./init.sh` passes

## Depends

- feat-007
## Plan

Plan: `docs/plans/feat-008.md`

## Handoff

- State: active
- Evidence: baseline ./init.sh PASS on feat-007 HEAD (2026-09-14; format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test])
- Blockers: none
- Next: Task 1 — create QualityScorer + shortlist.
