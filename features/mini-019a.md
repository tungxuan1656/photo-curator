# mini-019a — composition evidence adapter

## Status and parent

- Status: `done` (merged via `8394e19`, PR #39, independent APPROVE; wired by parent Task 3)
- Parent integration feature: `feat-019`
- Reserved ID: `mini-019a`

## Seam and ownership

- One responsibility: collect the three composition Tier-B observations and
  pure-map them to the frozen facts per the parent schema. No pipeline wiring,
  no `make` change, no weights.
- Exclusive owns: `Services/Analysis/CompositionEvidenceAdapter.swift`, `features/mini-019a.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Services/Analysis/VisionAnalysisService.swift`, `Services/Photos/BatchPipeline.swift`,
  `Infrastructure/FileAnalysisCache.swift`, `Configuration/AppConfiguration.swift`,
  every other `apps/` file, siblings `features/mini-019b.md` /
  `Services/Analysis/UtilityEvidenceAdapter.swift` and `features/mini-019c.md` /
  `docs/evidence/tier-b-experimental-matrix.md`.
- Merge gate and reviewer: mapping matches the frozen schema exactly with bounded
  outputs and explicit unavailable values; no shared-contract/sibling diff;
  `./init.sh` passes on the parent after merge. Reviewer: integration owner plus one
  independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-019`
- Seam: composition observation collection and fact mapping (new adapter file
  only; no wiring)
- Exclusive owns: `Services/Analysis/CompositionEvidenceAdapter.swift`, `features/mini-019a.md`
- Shared contract task: parent plan Task 3 wires eligibility + adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` (code wiring, parent only)
- Target failure: F-017-E (landscape/context under-selection) — composition facts
  exist so Task 3 can measure
- Input: frozen schema in `features/feat-019.md` + iOS 26.5 SDK shapes
  (`VNGenerateAttentionBasedSaliencyImageRequest` rev 2 → `VNSaliencyImageObservation`
  with `salientObjects: [VNRectangleObservation]`; `VNDetectHorizonRequest` rev 1 →
  first `VNHorizonObservation` with `angle` in radians; `VNGeneratePersonSegmentationRequest`
  rev 1 `.balanced` → `VNPixelBufferObservation` mask buffer)
- Output: two-phase adapter in the new file — phase 1 exposes per-request entries
  (`collectSaliency`/`collectHorizon`/`collectPersonSegmentation`; the caller runs
  ONLY the eligible request, independent degrade, cancellation checked on entry,
  same 512 px `.up` input); phase 2 pure-maps to `(horizonScore =
  clamped01(1 - abs(angle)/(π/6))` [nil when unavailable]; `visualBalanceScore =
  foreground pixel fraction from the `OneComponent8` mask [nil when unavailable];
  `salientRegionCount = min(10, salientObjects.count)` [nil when unavailable]).
  No box, mask, or pixel buffer crosses to the caller — scalars/counts only.
- Fallback: n/a in code beyond the frozen nil mapping (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles this adapter verbatim (double-run
  byte-compare + bound asserts on A-shape + Golden-shape)
- Merge gate: mapping matches the frozen schema exactly; bounded outputs; unavailable
  values explicit; no shared-contract/sibling diff; `./init.sh` passes on the parent
  after merge
- Reject condition: touches a shared contract or sibling file; invents a fact, weight,
  or threshold; adds a non-frozen request; persists or returns a box, mask,
  landmark, or pixel data

## Acceptance and evidence

- [x] Phase-1 collection degrades per request (one failure never fails the asset) with
  cancellation checks between requests.
- [x] Phase-2 mapping is pure: bounded outputs (2 Optional scores, 1 Optional
  capped count) and the frozen unavailable values, no fabricated defaults.
- [x] No shared-contract, sibling, or other `apps/` diff (`git diff --name-only`).
- Manual QA / benchmark command or procedure: n/a (code only; measured at parent Verify).
- Evidence location: `Services/Analysis/CompositionEvidenceAdapter.swift` (code) + parent
  Verify proof-binary record. `./init.sh` PASS 2026-09-17 on the mini branch
  (swiftformat clean, swiftlint `--strict` 0 violations, Simulator Debug build
  **BUILD SUCCEEDED**, `SKIP [test]` per no-tests policy).

## Inline plan
1. Write phase 1 (per-request entries `collectSaliency`/`collectHorizon`/
   `collectPersonSegmentation`; same handler pattern as the existing
   lane requests, independent degrade; the caller gates each request).
2. Write phase 2 (pure map to the frozen fact triple; explicit unavailable arms;
   mask math never leaves the adapter).
3. Self-check the file compiles inside the parent branch build; record `./init.sh`.

## Handoff

State `done` (merged via `8394e19`, PR #39, independent APPROVE; wired by parent Task 3
into `performAll` via `tierBFacts` + `make` with `analysisVersion` 3; mapping proven live by the Task 3
proof binary — salient 57/60 + 198/200, horizon/balance honestly nil-on-synthetic per the unavailable arm).
Blockers: none.
Next: none (child complete); parent Task 3 done; coordinator opens the parent PR to
main (squash; separate merge task).
