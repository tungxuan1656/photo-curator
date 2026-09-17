# mini-019b — utility evidence adapter

## Status and parent

- Status: `done` (merged via `2274281`, PR #38, independent APPROVE; wired by parent Task 3)
- Parent integration feature: `feat-019`
- Reserved ID: `mini-019b`

## Seam and ownership

- One responsibility: collect the two utility Tier-B observations and pure-map
  them to the frozen utility facts per the parent schema. Evidence only beyond
  the mapping trigger-coverage note; no code change outside the adapter, no
  pipeline wiring, no `make` change, no weights.
- Exclusive owns: `Services/Analysis/UtilityEvidenceAdapter.swift`, `features/mini-019b.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Services/Analysis/VisionAnalysisService.swift`, `Services/Photos/BatchPipeline.swift`,
  `Infrastructure/FileAnalysisCache.swift`, `Configuration/AppConfiguration.swift`,
  every other `apps/` file, siblings `features/mini-019a.md` /
  `Services/Analysis/CompositionEvidenceAdapter.swift` and `features/mini-019c.md` /
  `docs/evidence/tier-b-experimental-matrix.md`.
- Merge gate and reviewer: mapping matches the frozen schema exactly with bounded
  outputs, trigger coverage recorded, no raw text persisted; no
  shared-contract/sibling diff; `./init.sh` passes on the parent after merge.
  Reviewer: integration owner plus one independent reviewer, never the module
  owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-019`
- Seam: utility observation collection and fact mapping plus trigger-coverage
  note (new adapter file only; no wiring)
- Exclusive owns: `Services/Analysis/UtilityEvidenceAdapter.swift`, `features/mini-019b.md`
- Shared contract task: parent plan Task 3 wires eligibility + adapter phases into
  `VisionAnalysisService.performAll` + `PhotoAnalysis.make` and judges trigger
  coverage against the Golden-shape expectation (code wiring, parent only)
- Target failure: screenshot/document pollution — utility facts exist so
  selection policy (feat-020+) can demote them
- Input: frozen schema in `features/feat-019.md` + iOS 26.5 SDK shapes
  (`VNRecognizeTextRequest` rev 3, `.accurate`, language correction on →
  `VNRecognizedTextObservation` list with `topCandidates(1)` confidence;
  `VNDetectDocumentSegmentationRequest` rev 1 → `VNRectangleObservation` list;
  Tier-A `mediaSubtypes` + transient `isUtility` as eligibility inputs — the
  adapter receives eligibility as a flag, it does not fetch PhotoKit)
- Output: two-phase adapter in the new file — phase 1 collects the 2 observations
  (independent degrade, cancellation checks between requests, same 512 px `.up`
  input); phase 2 pure-maps to `(hasText = any observation with top-1
  confidence ≥ 0.5` [nil when unavailable]; `textLineCount = min(50, count)`
  [nil when unavailable]; `screenshotProbability = 1.0 subtype / 0.7 document /
  0.2 text / 0.0 else` [nil when utility Tier-B not run]; `isDocument = any
  rectangle` [nil when unavailable]). Raw strings are dropped inside phase 2;
  only the Booleans/counts/probability cross the boundary. Honest miss-rate note:
  photos of documents with neither trigger signal are not covered; the coverage
  fraction on Golden-shape is measured at parent Verify, not widened here.
- Fallback: n/a in code beyond the frozen nil mapping (proven at parent Verify)
- Version effect: none (no `analysisVersion` bump in the child)
- Focused QA: parent Verify proof binary compiles this adapter verbatim
  (double-run byte-compare + bound asserts + trigger-coverage on A-shape +
  Golden-shape); privacy proof scans persisted rows for text content
- Merge gate: mapping matches the frozen schema exactly; bounded outputs;
  unavailable values explicit; no raw text, box, or string list persisted or
  returned; trigger-coverage method recorded; no shared-contract/sibling diff;
  `./init.sh` passes on the parent after merge
- Reject condition: touches a shared contract or sibling file; invents a fact,
  weight, or threshold; persists or returns a raw string, box, or confidence
  pair; widens the eligibility predicate; adds a non-frozen request

## Acceptance and evidence

- [x] Phase-1 collection degrades per request (one failure never fails the asset) with
  cancellation checks between requests (`UtilityEvidenceAdapter.collect`: entry +
  between-request `Task.checkCancellation`, `try?` per request in its own
  `autoreleasepool`; only `CancellationError` escapes).
- [x] Phase-2 mapping is pure: bounded outputs (`hasText: Bool?`, `textLineCount:
  Int?` capped at 50, `screenshotProbability: Double?` in {1.0, 0.7, 0.2, 0.0},
  `isDocument: Bool?`) and the frozen unavailable values (`nil` per failed
  request; caller keeps `nil` for never-run assets); raw strings dropped inside
  phase 2 (phase 1 snapshots top-1 confidences only, never recognized strings).
- [x] Trigger-coverage method recorded (predicate inputs + expected Golden-shape
  behavior; see note below); no `apps/` diff beyond the two owned files.
- [x] No shared-contract, sibling, or other `apps/` diff (`git diff --name-only`
  shows only `Services/Analysis/UtilityEvidenceAdapter.swift` + this card).
- Manual QA / benchmark command or procedure: n/a (code only; measured at parent Verify).
- Evidence location: `Services/Analysis/UtilityEvidenceAdapter.swift` (code) + parent
  Verify proof-binary record.

## Trigger-coverage note (basis for parent Verify)

- Predicate inputs (caller-side, Tier-A same pass): `mediaSubtypes` contains
  screenshot OR transient `isUtility == true`, AND technically usable. The
  adapter receives eligibility as the `isScreenshotSubtype` flag for the 1.0
  arm and is only invoked for eligible assets; it never fetches PhotoKit.
- Expected Golden-shape behavior: every screenshot-subtype asset maps to
  `screenshotProbability` 1.0; document rectangles lift non-screenshots to 0.7;
  confident text lines lift the remainder to 0.2; anything else stays 0.0.
- Honest miss: photos of documents with neither trigger signal (no screenshot
  subtype, `isUtility` false) never invoke the adapter and stay `nil`; the
  coverage fraction on Golden-shape is measured at parent Verify per
  `docs/plans/feat-019.md` Task 3, not widened here.

## Inline plan

1. After 019a merges: write phase 1 (collect the 2 observations; same handler
   pattern, independent degrade).
2. Write phase 2 (pure map to the frozen utility facts; strings dropped inside;
   explicit unavailable arms).
3. Record the trigger-coverage method; self-check compile in the parent branch;
   record `./init.sh`.

## Handoff

State `done` (merged via `2274281`, PR #38, independent APPROVE; wired by parent Task 3
into `performAll` via `tierBFacts` + `make` with `analysisVersion` 3; mapping proven live by the Task 3
proof binary — utility ran only on `isUtility` assets per the frozen predicate: A 39/60, Golden 143/200).
Blockers: none.
Next: none (child complete); parent Task 3 done; coordinator opens the parent PR to
main (squash; separate merge task).
