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

- State: active (code complete; acceptance gate open)
- Evidence: implementation commits 3a74355 + 11fc065 + c4db568 + fb8e280 + b1102e6 on feat/feat-008 (scorer + shortlist, diversity selector, final builder engineVersion 2, full engine pipeline + shared finalizeAvailable partial path, decision mapping); ./init.sh PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test])
- Blockers: Dataset B + Golden manual QA not run — gate `sizing per selection-rules §14; reason codes; chronological order` cannot close on ./init.sh alone
- Next: Run Dataset B + Golden device/debugger pass (partition, chronology, reasons, cluster invariant, target sizing), record metrics per manual-qa template in features/feat-008.md.
