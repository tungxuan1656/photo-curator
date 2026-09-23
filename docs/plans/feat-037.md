# feat-037 — Suggestion integration and legacy retirement

## Scope and canonical constraints

After feat-036, integrate immutable intelligence suggestions into the shared
review workspace and retire the legacy selection route as an active behavior
owner. Stable contracts are defined in
[photo-intelligence.md](../design-docs/photo-intelligence.md),
[curation-runtime-stack.md](../design-docs/curation-runtime-stack.md), and
[review-rules.md](../product-specs/review-rules.md).

Suggestions and facts are immutable, versioned, provenance-bearing, advisory,
and never user choices. Applying one is explicit and must not implicitly mutate
cleanup disposition, album membership, or review progress. Unknown evidence may
enter Needs Review. The suggestion input remains one review-facing contract;
preserve consumer compatibility or explicitly migrate records, without adding
user-choice fields to suggestion records.

Qwen remains frozen and unadmitted. MobileCLIP/FastVLM weights remain
research-only under their model licenses, IQA-PyTorch remains noncommercial,
and no candidate is admitted without license, privacy, fallback, runtime,
quality, and iPhone-performance evidence. The native derived provider is eight
scalar facts, not a learned pixel embedding; the iOS 26 native path remains
complete. Runtime providers stay behind bounded service seams with a
deterministic native fallback. Do not turn host/Simulator results into device
or quality claims.

## Phased execution plan

### Phase 1 — Native suggestion producer and deterministic fallback

**Commit boundary: producer contract and fallback only.**

- Audit the feat-034 shared review input contract and current native fact
  production. Extend the immutable suggestion record with producer provenance,
  analysis/runtime versions, evidence status, and abstention while retaining
  advisory semantics and reader compatibility.
- Audit/extend the native provider and bounded suggestion coordinator around the
  eight scalar facts. Keep model providers unadmitted and ensure unavailable,
  unsupported, and incomplete-input cases resolve through a deterministic native
  fallback/abstention path without model downloads or implicit choices.
- Keep migration/checkpoint decoding requirements visible to later phases and
  limit this commit to model/service contracts and producer behavior.

### Phase 2 — Native SwiftUI suggestion and Needs Review surfaces

**Commit boundary: designer-owned review UI and localization.**

- With the designer as owner of the native SwiftUI surface, bind suggestion
  provenance and uncertainty to Needs Review and the existing preview/compare
  flow. Show producer, versions, evidence status, and abstention without
  presenting advisory output as fact or a decision.
- Add explicit **Use Suggestion** and **Keep My Choice** actions. Preserve user
  authority, independent workspace state, exact-set confirmation, stable resume,
  and the rule that applying a suggestion does not mutate cleanup disposition,
  album membership, or review progress implicitly.
- Add the en/vi catalog entries and verify unavailable-workspace behavior is
  still clear and non-destructive. Keep uncertain items routable to Needs
  Review; do not create a second review-facing contract.

### Phase 3 — Retire legacy active ownership

**Commit boundary: compatibility inventory, then active-route retirement.**

- Inventory every legacy selection-route caller, registration, adapter, and
  persisted compatibility reader across workspace, review, album, deletion,
  migration, and checkpoint flows.
- Add or verify compatibility decoding before removing active ownership. Retain
  migration and checkpoint decoders/readers, historical records, and the
  workspace-unavailable behavior; they must remain readable and must not regain
  authority over current workspace choices.
- Remove only the legacy active route after the inventory and decoder path are
  complete. Preserve the shared workspace, review, album, deletion, and exact-set
  safety boundaries. A rollback restores the compatibility adapter, not the old
  route as a choice authority.

### Phase 4 — Verification and closure

**Commit boundary: closure evidence only.**

- Review the complete diff for immutable/advisory data safety, provenance,
  explicit user actions, en/vi coverage, deterministic fallback, Qwen
  non-admission, decoder retention, and workspace-unavailable behavior.
- Run `./init.sh` and `git diff --check`. Do not add tests, test targets, test
  files, proof harnesses, model downloads, or unverified quality claims.
- Record acceptance evidence and handoff in the feature/progress artifacts as
  required by the repository workflow. Validation owner: parent coordinator.

## Initial legacy ownership inventory — 2026-09-23

The first caller pass confirms that legacy ownership is still active and must
not be removed in this slice:

- `AppModel` constructs and owns `SelectionSessionCoordinator`; `ProcessingModel`
  still drives the source-selection → summary → processing path.
- `RootView` still exposes `.sourceSelection`, `.summary`, and `.processing`;
  review now enters through the shared `.reviewWorkspace` route.
- `AppModel+ReviewEntry` keeps `SelectionFeedback` persistence only when the
  durable workspace is unavailable. This compatibility fallback must remain
  readable and non-authoritative.
- `AppContainer` and `LegacyWorkspaceImporter` retain durable-workspace
  migration and legacy-schema fallback behavior.
- `AppModel+Save`, `AlbumSaveService`, and `LegacySaveFlow` retain the
  file-backed save handoff for unavailable-workspace/reconciliation paths.

This is an inventory checkpoint, not retirement approval. A complete caller
and decoder inventory is required before changing any of these ownership
boundaries.

## Expected implementation areas

Likely existing areas include
`apps/photo-curator/Domain/Models/PhotoAnalysis.swift`,
`Domain/Models/SelectionResult.swift`, `Domain/Selection/SelectionEngine.swift`,
`Domain/Selection/UncertaintyReview.swift`,
`Domain/Selection/QualityGroupBuilder.swift`,
`Domain/Selection/SemanticJury.swift`,
`Services/Analysis/VisionAnalysisService.swift`,
`Services/Analysis/UniversalFactAdapter.swift`,
`Services/Session/SelectionSessionCoordinator.swift`,
`Services/Intelligence/QualityCurationRunner.swift`,
`Services/Intelligence/QwenPairJudge.swift`,
`Services/Intelligence/QwenRuntime.swift`, `App/AppContainer.swift`,
`App/AppModel.swift`, `Features/Review/ReviewModel.swift`,
`Features/Review/NeedsReview.swift`, and
`Features/Review/PhotoAnalysisDetail.swift`.

Likely new seams are `Domain/Models/AnalysisSuggestion.swift` and
`Services/Analysis/SuggestionCoordinator.swift`, unless the existing analysis
service is the smaller safe seam. Actual ownership must follow the existing
contracts and the phase boundaries above.

## Acceptance checklist

- Immutable, versioned, provenance-bearing advisory suggestions use the shared
  contract, native facts, deterministic fallback, and explicit abstention.
- Native SwiftUI review surfaces expose provenance, preview, uncertainty,
  **Use Suggestion**, **Keep My Choice**, and en/vi copy without taking user
  authority.
- Qwen and other unadmitted candidates remain inactive; no model or quality
  admission is implied.
- Legacy active ownership is retired only after caller inventory and
  compatibility coverage; migration/checkpoint decoders and
  workspace-unavailable behavior remain available.
- Parent coordinator records `./init.sh` and `git diff --check` results. No
  tests or proof harnesses are introduced.
