# feat-005 — Vision core + batch pipeline

## Goal

Land Vision core + batch pipeline so every asset has versioned PhotoAnalysis.

## Scope

- `Services/Analysis/VisionAnalysisService.swift`
- `Domain/Models/PhotoAnalysis.swift`
- `Services/Photos/BatchPipeline.swift`

## Non-goals

- Anything outside owns; Processing UI stays in feat-006.

## Acceptance

- [ ] Every asset has versioned PhotoAnalysis; batch + checkpoint per performance §1
- [ ] `./init.sh` passes

## Depends

- feat-004

## Handoff

- State: todo
- Evidence: —
- Blockers: none
- Next: Open branch feat/feat-005 once feat-004 is done.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
