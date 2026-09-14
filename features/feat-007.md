# feat-007 — Duplicates + moments

## Goal

Land duplicates + moments so clusters and moments are correct on dataset B.

## Scope

- `Domain/Models/PhotoAnalysis.swift` (SceneType Hashable only)
- `Domain/Models/SelectionGrouping.swift` (new: candidates, edges, clusters, moments, stable IDs)
- `Domain/Selection/DuplicateResolver.swift` (new: windowed union-find + local winner)
- `Domain/Selection/MomentBuilder.swift` (new: gap scan with continuity)
- `Domain/Selection/SelectionEngine.swift` (candidates + similarityEdges + pass-through)
- `Services/Analysis/ImageSimilarityArtifact.swift` (new: transient Vision wrapper)
- `Services/Analysis/VisionAnalysisService.swift` (single-pass print + cache-hit artifact)
- `Services/Photos/BatchPipeline.swift` (run-local artifacts + similarityEdges)
- `Services/ServiceProtocols.swift` (ImageAnalysisOutput contract)
- `Services/Session/SelectionSessionCoordinator.swift` (async edge-aware selectResult)
- `docs/design-docs/data-model.md` (transient grouping representation only)

## Non-goals

- Scoring, sizing, diversity, verification (feat-008); Review UI (feat-009).

## Acceptance

- [ ] Clusters and moments correct on dataset B
- [ ] `./init.sh` passes

## Depends

- feat-006
## Handoff

- State: active
- Evidence: baseline ./init.sh PASS (2026-09-14; format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test])
- Blockers: none
- Next: Task 1 — create ImageSimilarityArtifact + ImageAnalysisService contract.

<!-- harness-slim 1.4.0 · generated 2026-09-10 -->
