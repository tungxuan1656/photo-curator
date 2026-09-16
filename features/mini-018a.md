# mini-018a — universal aesthetics and classification adapter

## Status and parent

- Status: `active` (dispatched 2026-09-16; implementation complete, awaiting gate review + merge)
- Parent integration feature: `feat-018`
- Reserved ID: `mini-018a`

## Seam and ownership

- One responsibility: collect the two new universal observations and pure-map them to
  facts per the frozen parent schema. No pipeline wiring, no `make` change, no weights.
- Exclusive owns: `Services/Analysis/UniversalFactAdapter.swift`, `features/mini-018a.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Services/Analysis/VisionAnalysisService.swift`, `Services/Photos/BatchPipeline.swift`,
  `Infrastructure/FileAnalysisCache.swift`, `Configuration/AppConfiguration.swift`,
  every other `apps/` file, sibling `features/mini-018b.md` and
  `docs/evidence/universal-request-cost.md`.
- Merge gate and reviewer: mapping matches the frozen schema exactly with bounded
  outputs and explicit unavailable values; no shared-contract/sibling diff;
  `./init.sh` passes on the parent after merge. Reviewer: integration owner plus one
  independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-018`
- Seam: universal aesthetics + classification observation collection and fact mapping
  (new adapter file only; no wiring)
- Exclusive owns: `Services/Analysis/UniversalFactAdapter.swift`, `features/mini-018a.md`
- Shared contract task: parent plan Task 3 wires the adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` (code wiring, parent only)
- Target failure: F-017-E / F-017-F (universal facts exist so Task 3 can measure)
- Input: frozen schema in `features/feat-018.md` + iOS 26.5 SDK shapes
  (`VNCalculateImageAestheticsScoresRequest` rev 1 → first
  `VNImageAestheticsScoresObservation` with `overallScore` [-1,1] + `isUtility`;
  `VNClassifyImageRequest` default rev 2 → `VNClassificationObservation` list with
  `identifier` + `confidence`; existing first-print-or-nil)
- Output: two-phase adapter in the new file — phase 1 collects the 2 new observations
  beside the existing requests (independent degrade, cancellation checks between
  requests, same 512 px `.up` input); phase 2 pure-maps to
  `(aestheticScore = clamped01((overall+1)/2), tags = top-3 identifier+confidence,
  featurePrintAvailable)` with the frozen unavailable values (nil / [] / false).
  `isUtility` passes through as transient input only. No Vision call shapes beyond the
  frozen table; no tier-B request, model, or dependency.
- Fallback: n/a in code beyond the frozen nil/empty/false mapping (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles this adapter verbatim (double-run
  byte-compare + F-017-E/F movement on A-shape + Golden-shape)
- Merge gate: mapping matches the frozen schema exactly; bounded outputs; unavailable
  values explicit; no shared-contract/sibling diff; `./init.sh` passes on the parent
  after merge
- Reject condition: touches a shared contract or sibling file; invents a fact, weight,
  or threshold; adds a tier-B request, model, or dependency; persists a blob, box, or location

## Acceptance and evidence

- [x] Phase-1 collection degrades per request (one failure never fails the asset) with
  cancellation checks between requests.
- [x] Phase-2 mapping is pure: bounded outputs (1 Optional score, ≤3 tags, 1 Bool) and
  the frozen unavailable values, no fabricated defaults.
- [x] No shared-contract, sibling, or other `apps/` diff (`git diff --name-only`).
- Manual QA / benchmark command or procedure: n/a (code only; measured at parent Verify).
- Evidence location: `Services/Analysis/UniversalFactAdapter.swift` (code) + parent
  Verify proof-binary record. Verification: `./init.sh` PASS (format, `swiftlint --strict`,
  Simulator build SUCCEEDED, SKIP [test] by policy); `git diff --name-only` shows only
  the two owned files; commit and PR recorded in Handoff.

## Inline plan

1. Write phase 1 (collect the 2 new observations; same handler pattern as the existing
   face/print requests, independent degrade).
2. Write phase 2 (pure map to the frozen fact triple; explicit unavailable arms).
3. Self-check the file compiles inside the parent branch build; record `./init.sh`.

## Handoff

State `active` (implemented 2026-09-16; two-phase adapter reviewable, gate self-check
passed: mapping matches frozen schema, bounded outputs, explicit unavailable values,
no shared-contract/sibling diff, `./init.sh` PASS).
Blockers: none (needs integration-owner + independent review, then merge).
Next: merge into `tungxuan1656/feat-018-integration` after gate + review (squash; never
to main); then dispatch `mini-018b`.
