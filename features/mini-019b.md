# mini-019b — utility evidence adapter

## Status and parent

- Status: `todo` (task-ready; admitted 2026-09-17 by the feat-019 contract commit)
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

- [ ] Phase-1 collection degrades per request (one failure never fails the asset) with
  cancellation checks between requests.
- [ ] Phase-2 mapping is pure: bounded outputs (1 Optional Bool text flag, 1
  Optional capped count, 1 Optional probability, 1 Optional Bool document flag)
  and the frozen unavailable values; raw strings dropped inside phase 2.
- [ ] Trigger-coverage method recorded (predicate inputs + expected Golden-shape
  behavior); no `apps/` diff beyond the two owned files.
- [ ] No shared-contract, sibling, or other `apps/` diff (`git diff --name-only`).
- Manual QA / benchmark command or procedure: n/a (code only; measured at parent Verify).
- Evidence location: `Services/Analysis/UtilityEvidenceAdapter.swift` (code) + parent
  Verify proof-binary record.

## Inline plan

1. After 019a merges: write phase 1 (collect the 2 observations; same handler
   pattern, independent degrade).
2. Write phase 2 (pure map to the frozen utility facts; strings dropped inside;
   explicit unavailable arms).
3. Record the trigger-coverage method; self-check compile in the parent branch;
   record `./init.sh`.

## Handoff

State `todo` (admitted 2026-09-17; starts after 019a merges).
Blockers: none.
Next: dispatch after 019a merges; merge second (019a → 019b order).
