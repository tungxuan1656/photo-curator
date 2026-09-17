# mini-020a — group evidence calculator

## Status and parent

- Status: `done` (merged via `84af07d`, PR #42, Codex APPROVE; wired by parent Task 3)
- Parent integration feature: `feat-020`
- Reserved ID: `mini-020a`

## Seam and ownership

- One responsibility: compute the transient per-face quality distribution
  from the Tier-A face observations and pure-map it to bounded scalars for
  the parent to consume. No pipeline wiring, no `make` change, no weights,
  no reason codes.
- Exclusive owns: `Services/Analysis/GroupEvidenceCalculator.swift`, `features/mini-020a.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Domain/Scoring/QualityScorer.swift`, `Domain/Selection/SelectionEngine.swift`,
  `Services/Analysis/VisionAnalysisService.swift`,
  `Services/Photos/BatchPipeline.swift`, `Infrastructure/FileAnalysisCache.swift`,
  `Configuration/AppConfiguration.swift`, every other `apps/` file.
- Merge gate and reviewer: mapping matches the frozen contract exactly with
  bounded outputs and explicit unavailable values; no persisted or returned
  face box/landmark/pixel data; no shared-contract/sibling diff; `./init.sh`
  passes on the parent after merge. Reviewer: integration owner plus one
  independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-020`
- Seam: per-face distribution computation (new calculator file only; no wiring)
- Exclusive owns: `Services/Analysis/GroupEvidenceCalculator.swift`, `features/mini-020a.md`
- Shared contract task: parent plan Task 3 wires the calculator into
  `VisionAnalysisService.performAll` (pass-through) + `QualityScorer.score`
  (weakest-face fold) + `FinalAlbumBuilder.decision` (reason codes) and bumps
  `analysisVersion` 3 → 4 (code wiring, parent only)
- Target failure: F-017-D (group-photo / people handling) — the distribution
  exists so Task 3 can measure
- Input: frozen contract in `features/feat-020.md` + iOS 26.5 SDK shapes
  (`VNDetectFaceRectanglesRequest` → face observations count;
  `VNDetectFaceCaptureQualityRequest` → per-face `faceCaptureQuality` values;
  same 512 px `.up` input; transient, never persisted)
- Output: pure calculator in the new file — per-face values map to
  `(faceCount, minFaceQuality, meanFaceQuality)` bounded scalars
  (`faceCount = max(0, count)`; qualities `clamped01`; nil arms when no faces
  or quality unavailable). No box, landmark, crop, or pixel buffer crosses to
  the caller — scalars only, transient only.
- Fallback: n/a in code beyond the frozen nil arm (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles this calculator verbatim
  (double-run byte-compare + distribution asserts + weakest-face asserts on
  B-shape + Golden-shape with face-bearing fixtures where available)
- Merge gate: mapping matches the frozen contract exactly; bounded outputs;
  unavailable values explicit; no shared-contract/sibling diff; `./init.sh`
  passes on the parent after merge
- Reject condition: touches a shared contract or sibling file; invents a fact,
  weight, threshold, reason code, or Vision request; persists or returns a box,
  landmark, crop, embedding, or pixel data; reinterprets the version-3 frozen
  Tier-A/B schema

## Acceptance and evidence

- [x] Pure map: per-face values → bounded `(faceCount, minFaceQuality,
  meanFaceQuality)` with the frozen nil arms, no fabricated defaults.
- [x] No persisted or returned face box, landmark, crop, embedding, or pixel
  data; no shared-contract, sibling, or other `apps/` diff (`git diff --name-only`).
- [x] Manual QA / benchmark command or procedure: n/a (code only; measured at parent Verify).
- [x] Evidence location: `Services/Analysis/GroupEvidenceCalculator.swift` (code) + parent
  Verify proof-binary record.

Evidence: `nonisolated static func map(faceCount:faceQualities:)` — no-faces
(`faceCount <= 0`) → all-nil; quality nil/empty → count-only with
`faceCount = max(0, count)`; otherwise min/mean over 0…1-clamped values
(local clamp: `PhotoAnalysis.clamped01` is main-actor-isolated, so this
off-main map clamps inline — same bound). Inputs are the Tier-A count plus
`Double` quality values only; no observation, box, landmark, crop,
embedding, or pixel type appears in the signature. `swiftformat --lint` and
`swiftlint lint --strict` pass on the new file (2026-09-17).

## Inline plan

1. Write the pure map (per-face inputs → bounded triple; explicit unavailable
   arms; no Vision import beyond the observation value types the caller passes).
2. Document the unavailable case (no faces → all-nil; quality missing → count
   only) in the file header.
3. Self-check the file compiles inside the parent branch build; record `./init.sh`.

State `done` (worker implementation complete; not yet merged into the parent branch).
`git diff --name-only` shows only the two owned files. `./init.sh` PASS
(2026-09-17: format PASS, lint --strict PASS, Simulator build SUCCEEDED, test SKIP by policy).
Blockers: none.
Next: independent review (integration owner + one reviewer, never the module
owner alone), then merge into `tungxuan1656/feat-020-integration`; parent
Task 3 wires the calculator and runs the Verify proof binary.

## Handoff

State `done` (merged via `84af07d`, PR #42, Codex APPROVE; wired by parent Task 3
into `performAll` via calculator pass-through + `make` with `analysisVersion` 4;
mapping proven live by the Task 3 proof binary — distribution asserts all TRUE,
weakest-face fold 0.7333 vs 0.6000 PASS, picks identical v3→v4 on faceless bytes).
Blockers: none.
Next: none (child complete); parent Task 3 done; coordinator opens the parent PR to
main (squash; separate merge task).
