# feat-037 — Suggestion integration and legacy retirement plan

## Scope and dependency

After feat-036, integrate immutable intelligence suggestions into the shared
review experience and retire the legacy selection route as an active behavior
owner. This feature does not admit Qwen or another model by documentation
assertion. Stable contracts are in
[photo-intelligence.md](../design-docs/photo-intelligence.md),
[curation-runtime-stack.md](../design-docs/curation-runtime-stack.md), and
[review-rules.md](../product-specs/review-rules.md).

## Anticipated code areas

Existing areas to reshape: `apps/photo-curator/Domain/Models/PhotoAnalysis.swift`,
`Domain/Models/SelectionResult.swift`,
`Domain/Selection/SelectionEngine.swift`,
`Domain/Selection/UncertaintyReview.swift`,
`Domain/Selection/QualityGroupBuilder.swift`,
`Domain/Selection/SemanticJury.swift`,
`Services/Analysis/VisionAnalysisService.swift`,
`Services/Analysis/UniversalFactAdapter.swift`,
`Services/Session/SelectionSessionCoordinator.swift`,
`Services/Intelligence/QualityCurationRunner.swift`,
`Services/Intelligence/QwenPairJudge.swift`,
`Services/Intelligence/QwenRuntime.swift`,
`App/AppContainer.swift`, `App/AppModel.swift`,
`Features/Review/ReviewModel.swift`,
`Features/Review/NeedsReview.swift`, and
`Features/Review/PhotoAnalysisDetail.swift`.

Anticipated new areas: `Domain/Models/AnalysisSuggestion.swift` and
`Services/Analysis/SuggestionCoordinator.swift`, unless the existing analysis
service is the smaller safe seam. Legacy route retirement may touch route
registration and the selection-result adapter; migration decoders remain.

## Intelligence and safety constraints

Facts and suggestions are immutable, versioned, provenance-bearing, and
advisory. Applying a suggestion is explicit and cannot implicitly mutate
cleanup disposition, album membership, or review progress. Unknown evidence
remains unknown and can enter Needs Review.

Qwen stays frozen/unadmitted. Current MobileCLIP/FastVLM weights remain
research-only under their model licenses; IQA-PyTorch remains noncommercial.
No candidate is admitted without license, privacy, fallback, runtime, quality,
and iPhone performance evidence. The native derived provider is eight scalar
facts, not a learned pixel embedding. The iOS 26 native path remains complete.

Data safety: suggestion records never become user choices and migration
readers remain available. UX safety: suggestions are explicit and uncertain
items route to Needs Review. API safety: runtime providers stay behind bounded
service seams with deterministic native fallback; no Qwen activation is
planned.

## Work steps

1. Define suggestion identity, provenance, analysis/runtime versions, evidence
   status, and abstention without adding user-choice fields.
2. Adapt native fact production and bounded suggestion coordination with a
   deterministic unavailable/fallback path.
3. Bind suggestions and uncertainty to Needs Review and compare surfaces with
   explicit choice actions and stable resume behavior.
4. Inventory legacy selection-route callers; add compatibility decoding before
   removing active route ownership.
5. Retire only the active legacy path after workspace, review, album, and
   deletion dependencies are proven; retain historical docs and readers.
6. Record any future model admission as a separate evidence-backed decision;
   do not turn host/Simulator results into device or quality claims.

## Validation

Run `./init.sh` after implementation. No tests, test targets, test files, proof
harnesses, model downloads during analysis, or unverified quality claims may be
introduced. Use `git diff --check` and automated lint/build evidence; image
quality and iPhone fit require separate evidence.

## Rollback and migration

Keep suggestion records readable as advisory and retain native fallback. If a
candidate fails license, runtime, privacy, or quality admission, disable that
candidate and preserve facts/user choices. Retire the legacy route only after
the committed migration marker; rollback restores the compatibility adapter,
not old behavior as an authority over workspace choices.

## Acceptance mapping

- Immutable advisory suggestions → model/service and ReviewModel integration.
- Frozen unadmitted Qwen → runtime guard and evidence/decision record.
- Needs Review/user authority → review surfaces and independent workspace state.
- Legacy retirement → route inventory, migration decoder, compatibility path.
- Gate → feature acceptance and `./init.sh` without tests/harnesses.
