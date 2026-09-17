# mini-019c — experimental availability matrix (CONDITIONAL)

## Status and parent

- Status: `todo` (CONDITIONAL — activates only when the parent names the
  residual failure; admitted 2026-09-17 by the feat-019 contract commit)
- Parent integration feature: `feat-019`
- Reserved ID: `mini-019c`

## Seam and ownership

- One responsibility: benchmark the named experimental candidates against the
  residual failure and record an accept/reject recommendation per candidate.
  Evidence only; no code change.
- Exclusive owns: `docs/evidence/tier-b-experimental-matrix.md`, `features/mini-019c.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Services/Analysis/VisionAnalysisService.swift`, `Services/Photos/BatchPipeline.swift`,
  `Infrastructure/FileAnalysisCache.swift`, `Configuration/AppConfiguration.swift`,
  every `apps/` file, siblings `features/mini-019a.md` /
  `Services/Analysis/CompositionEvidenceAdapter.swift` and `features/mini-019b.md` /
  `Services/Analysis/UtilityEvidenceAdapter.swift`.
- Merge gate and reviewer: benchmark-backed accept/reject per candidate with
  availability, cost, and privacy notes; no `apps/` diff; `./init.sh` passes on
  the parent after merge. Reviewer: integration owner plus one independent
  reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-019`
- Seam: experimental availability matrix (evidence only)
- Exclusive owns: `docs/evidence/tier-b-experimental-matrix.md`, `features/mini-019c.md`
- Shared contract task: parent Task 3 judges the matrix and either accepts a
  candidate into a later version bump or records REJECTED (evidence merge only;
  no code wiring)
- Target failure: PARENT-NAMED residual failure only — this mini stays `todo`
  until Task 3 names the exact failure ID (e.g. a measured F-017-E remainder the
  shipped Tier-B facts do not move). No work starts on a hypothetical.
- Input: the named residual failure + the three frozen candidates below (iOS 26.5
  SDK state verified 2026-09-17; re-check headers before benchmarking):
  - Smudge: NO such request exists in the iOS 26.5 SDK headers (grep for
    `smudge` across Vision headers returns nothing). Baseline disposition:
    UNAVAILABLE — record as such unless the header check at dispatch finds it.
  - Body pose (`VNDetectHumanBodyPoseRequest` rev 1): contextual, never an
    all-people-photo requirement per runtime-stack §5; benchmark false positives
    on action vs posed portraits.
  - Landmarks (`VNDetectFaceLandmarksRequest`): optional, add only after QA shows
    a concrete miss per apple-frameworks §8; face detail beyond the existing
    version-2 slots stays transient per privacy.md.
- Output: per-candidate accept/reject with availability proof, per-asset
  cold cost, false-positive notes (motion blur / shallow depth for smudge-class
  signals; posed portraits for pose), privacy handling (transient-only unless a
  new privacy decision permits otherwise), and a reconsider trigger. Nothing
  invented, never a device claim; every number labeled by environment.
- Fallback: n/a (evidence only; engine and procedure unchanged)
- Version effect: none (an accepted candidate lands in a later version bump owned
  by a later feature, never in this mini)
- Focused QA: numbers reproducible from the recorded method (fixture manifest
  hashes + harness source hash in the evidence file)
- Merge gate: matrix reviewable in `docs/evidence/tier-b-experimental-matrix.md`;
  no `apps/` diff; `./init.sh` passes on the parent after merge
- Reject condition: starts without a parent-named residual failure; touches
  `apps/` or a shared contract; invents a measurement, a budget constant, or a
  device claim; recommends shipping a candidate without the benchmark

## Acceptance and evidence

- [ ] Residual failure named by the parent (ID + measured gap) before work starts.
- [ ] Per-candidate accept/reject recorded with availability, cost,
  false-positive, and privacy notes.
- [ ] No `apps/` diff (evidence file + card only).
- Manual QA / benchmark command or procedure: harness method recorded in
  `docs/evidence/tier-b-experimental-matrix.md` §2 (fixture bytes + harness hash
  + environment).
- Evidence location: `docs/evidence/tier-b-experimental-matrix.md` (this matrix).

## Inline plan

1. Parent names the residual failure; re-check the iOS SDK headers for each candidate.
2. Benchmark per-asset cost + false-positive behavior on the failure's shape bytes.
3. Write the accept/reject matrix; record `./init.sh`.

## Handoff

State `todo` (CONDITIONAL — admitted 2026-09-17; NOT started; activation needs a
parent-named residual failure).
Blockers: activation condition (parent Task 3 names the failure or records 019c
as not-needed).
Next: none until activated.
