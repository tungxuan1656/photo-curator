# feat-038 — Native analysis and actionable review repair plan

## Audit basis and boundaries

Rechecked against `90ae8bf` (feat-037) and the current working tree. The user's
`InfoPlist.xcstrings` and `Localizable.xcstrings` edits predate this audit.
Preserve them. This is static source/call-path evidence, not a replay of the
user's device session or an image-quality benchmark.

The user approved native-only direction and requested this feature plan.
Implementation remains `todo`. Do not activate feat-031 or admit a model.
Approved choice semantics remain authoritative: suggestions do not automatically
include/exclude photos, mark progress, or stage deletion.

Source paths below are relative to `apps/photo-curator/`.

## Rechecked findings

### Execution and output

| ID / priority | Evidence | Consequence and required outcome |
|---|---|---|
| F01 / P1 | `App/AppModel.swift:requestedQualityMode/startCuration`, `Services/Intelligence/QualityCurationRunner.swift:run` | Requests Qwen2B for ≤100 photos, uses installed model and resource gates; >100 switches to native. Docs say Qwen frozen. Make production direction and visible installation state agree. |
| F02 / P1 | `Features/Processing/ProcessingModel.swift:shouldShowNativeFallbackNotice`, runner `resourceAdmissionFailure` | Installation, runtime/memory/disk failures share broad fallback copy. Download success does not establish execution. Native-only runs must not claim AI failure. Exact cause on the user's device is not known. |
| F03 / P1 | `App/AppModel+ReviewEntry.swift:ensureReviewScope`, `ReviewModel.init`, `Domain/Models/ReviewSuggestion.swift:suggestions` | New membership is intentionally unset, but proposals cover only duplicate winners. Preserve unset choices and expose nonduplicate evidence as actionable suggestions. Do not seed choices automatically. |
| F04 / P1 | `AppModel+ReviewEntry.swift:beginReview` guards nonempty `selectedAssetIDs` | All-low-quality/all-unavailable output can be valid yet review is rejected. Allow review/recovery based on source/outcome validity, not album picks. |
| F05 / P2 | `ReviewWorkspaceView.swift:ReviewGridSection` renders suggestions/groups after the full grid and uses `suggestions.prefix(3)` | Findings can be below hundreds of photos; remaining suggestions have no complete list here. Provide discoverable summary and access to every proposal. |
| F06 / P2 | `ReviewWorkspaceView.swift:workspaceHeader`, `ReviewModel.resolvedUncertaintyCount` | “reviewed” counts legacy feedback resolution, not durable progress. Report independent counts for analysis, suggestions, album, cleanup and reviewed items. |

### Algorithm and evidence

| ID / priority | Evidence | Consequence and required outcome |
|---|---|---|
| F07 / P1 | `Domain/Selection/QualityAlbumSelector.swift:selectedIDs`, `DiversitySelector.swift:insertCoreRepresentatives`, `SelectionEngine.swift:targetCount` | Quality route targets usable moment count; normal route uses ratio/min/max. Core representatives are inserted before target checks. Unify native policy and make any coverage exception explicit. Do not promise a hard 150 cap the selector can exceed. |
| F08 / P1 | `DuplicateResolver.swift:candidates`, `MomentBuilder.swift:continuesMoment` | Dated edges cover ≤90s; visual continuity is queried at 180–900s. That branch has no qualifying dated input. Supply bounded continuity evidence or remove the unsupported rule. |
| F09 / P1 | `Services/Analysis/VisionAnalysisService.swift:performAll`, `UniversalFactAdapter.swift:map` | Classification tags are produced, but scene is only people/unknown. Scene-dependent grouping/diversity cannot distinguish food/landscape/etc. Map supported classifications conservatively and retain unknown. |
| F10 / P2 | `QualityGroupBuilder.swift:build` versus `SelectionEngine.swift:select` | Quality moments use all analyzed frames; normal moments use duplicate representatives. Retake density changes moment segmentation and selection. Establish one canonical membership/coverage mapping. |
| F11 / P2 | `MomentBuilder.swift:continuesMoment`, default missing-date order | Unknown dates and sparse scene evidence can join unrelated assets into one moment. Missing time must not imply one event. |
| F12 / P2 | `Domain/Models/PhotoAnalysis.swift:make`, `Domain/Scoring/QualityScorer.swift:score` | Technical score is 0.6 sharpness + 0.4 exposure; final score adds available people/composition terms. Stored breakdown remains technical-only. Distinguish these scores and persist truthful contributions rather than suggesting every measured fact participates. |
| F13 / P2 | `VisionAnalysisService.swift:heuristics/performAll` | Resolution measures resized pixels, subject placement stores maximum face quality, group score is faceCount/6. Rename or correct facts and consumers; do not claim these measure original resolution, placement or calibrated group quality. |
| F14 / P2 | `VisionAnalysisService.swift:tierABaseline`, `tierBFacts` | Request failure can become zero faces; utility requests are gated by technical usability. Distinguish unavailable detection from no faces and disclose gated/not-run facts. No requirement to run every expensive request on every photo. |
| F15 / P2 | `VisualEmbeddingProvider.swift:vector/merged`, `DiversitySelector.swift:utility` | Unknown fields use numeric defaults; heterogeneous distances merge with min; missing edges receive maximum visual novelty. Preserve missingness and avoid cross-scale similarity claims. |
| F16 / P2 | `VisualEmbeddingRouter.tierCCandidates`, `GlobalDiversityGraphBuilder.build`, `QualityScorer.shortlist` | ID-sorted pair truncation biases evidence coverage; hard 250 shortlist truncation can drop moments despite coverage comments. Use bounded fair selection and truthful coverage accounting. |
| F17 / P2 | `FinalAlbumBuilder.swift:decision`, `ReviewModel.buildSimilarGroups`, `ReviewSuggestion.facts` | Groups are reconstructed from reason strings; low-quality members can disappear from groups. Adapter stamps current analysis version instead of the producing run's version. Persist compact grouping/provenance and avoid fabricated freshness. |
| F18 / P2 | `DuplicateResolver.swift:resolve/variantCompatible` | Pairwise semantic compatibility prevents some chain merges, but does not require all members to be visually close. A–B/B–C may join A/C without evidence. Treat clusters as advisory; require a bounded visual-consistency rule for stronger retake claims. |

### Recovery and state: additional findings

| ID / priority | Evidence | Consequence and required outcome |
|---|---|---|
| F19 / P1 | `Services/Photos/BatchPipeline.swift:restore`, `Infrastructure/FileAnalysisCache.swift:store` | Completed checkpoint + missing cache becomes unavailable. Cache writes are best-effort, so a lost row can permanently suppress recomputation within a session. Requeue missing/stale/corrupt facts; distinguish explicit unavailable outcomes. |
| F20 / P1 | `FileAnalysisCache.swift:analysis`, `Domain/Models/PhotoAsset.swift` | Cache checks only analysis version; no asset modification fingerprint. An edited photo can combine old facts with freshly rebuilt FeaturePrint. Invalidate both against the same asset revision. |
| F21 / P1 | `Features/Review/ReviewModel.swift:progressByID/stagedCleanupByID/albumMembershipByID` and setters | Mutable choice dictionaries are ObservationIgnored. Progress/cleanup actions do not reliably invalidate dependent UI. Make authoritative presentation state observable without relying on unrelated album edits. |
| F22 / P1 | `AppModel+ReviewEntry.swift:makeReviewModel/persistWorkspaceChoice` | Independent Tasks save each item with separate awaits. A bulk action can commit partially or interleave with a later action. Serialize/generation-pin writes and commit each exact action atomically. |
| F23 / P1 | `ReviewModelActions.swift:retrySaveError`, `ReviewWorkspaceView.swift:saveFailureCard`, persistence catch | Live changes remain after failure, yet copy says previous choices unchanged. Retrying an older payload can overwrite newer intent; album retry also changes membership dictionary without updating selectedIDs. Use consistent commit/rollback and supersession semantics. |
| F24 / P2 | `ReviewWorkspaceView.swift` cell/group opacity, segmented labels and screenshot; catalog call sites | Album-unselected images appear faded during cleanup; long segments truncate and strings remain English. Represent unset separately from excluded, keep usable photos visible, and verify dynamic en/vi keys. |

## Corrections and limits of the previous audit

- **Withdraw the production partial-session-ID bug:** coordinator native output
  has a generated ID, but `AppModel.finalizePartial` rewraps it with the real
  session ID before saving. Preserve this working caller contract.
- The screenshot does not prove zero analysis or zero engine picks. Reaching
  `beginReview` currently requires a nonempty result pick set. Zero album count
  is user-choice state; it must not be equated with zero analysis.
- Unset membership is intentional. The bug is incomplete/discoverability-poor
  suggestion handoff, not failure to auto-select or auto-delete.
- Moment visual continuity is unreachable for dated 180–900s pairs under the
  current 90s pair window; this claim does not cover undated adjacency pairs.
- All-low-quality output need not select a “least bad” image. It must still
  explain evidence and allow review.
- Fixed thresholds (0.5, 0.25), zero favorite bonuses, time-local matching and
  coarse face heuristics are limitations, not proof of incorrect classification
  on the supplied images. No calibration or device benchmark was performed.
- Blur probability is derived from sharpness; exposure-tail probabilities feed
  exposure. Adding these again to a score would double-count evidence.
- `duplicateSimilarityThreshold` has no current consumer. Remove/deprecate it
  rather than presenting it as an active separate exact-duplicate detector.
- Scope is analysis-to-review correctness. This audit does not certify every
  album-save/deletion implementation path or third-party runtime.

## Proposed repair design

### Phase 1 — Native execution and recoverable evidence (A1, A2, A6)

1. Remove production Qwen prompts/settings/runner wiring and native-as-error copy.
   Keep historical decoders and research source isolated. Do not automatically
   delete downloaded artifacts: the earlier cleanup proposal was only noted,
   not approved for execution. Retain an explicit storage-removal action for
   installed legacy artifacts with truthful inactive status.
2. Use a single native orchestration path across source sizes. Resolve the
   policy in Phase 2 instead of blindly changing all runs to qualityNative.
3. Version cached facts with asset modification metadata and analysis revision.
   Legacy rows without a valid fingerprint are cache misses, not unavailable photos.
4. Separate checkpoint completion from durable fact availability. Recompute
   lost rows and preserve explicit retry behavior for inaccessible/iCloud assets.
5. Accept valid zero-pick results and show per-source outcomes, including partial
   runs. Keep session identity pinned at persistence and review boundaries.

### Phase 2 — Consistent native algorithms (A5, A7)

Proposed defaults below require approval when activating this feature; do not
silently turn them into current product policy in canonical docs.

1. Share facts/grouping across both intents. Separate technical eligibility,
   relative ranking, and album-size selection; album rejection is never a cleanup verdict.
2. Use duplicate representatives for moment segmentation, retaining full member
   mappings. Compare bounded adjacent moment candidates independently of the
   duplicate window. Unknown dates remain separate unless positive evidence connects them.
3. Map native classification identifiers with an explicit allowlist and confidence
   policy; unsupported/ambiguous results remain unknown. Record the mapping revision.
4. Keep existing ranking weights initially; correct semantic labels and missing
   evidence first. Eliminate count-only “group quality” as a quality claim.
   Store final-score contributions and reason evidence, not a technical-only breakdown.
5. Proposed album sizing baseline: `min(usableCount, clamp(ceil(usableCount *
   targetRatio), minimum, maximum))`. Apply the existing parameters consistently;
   preserve additional eligible photos as alternatives. Record uncovered moments
   instead of exceeding a declared hard maximum silently.
6. Disable scalar Tier-C influence on visual novelty until calibrated; retain
   FeaturePrint evidence without cross-provider min merging. Missing edges are
   unknown, not maximum novelty. Use bounded, balanced pair selection with
   coverage counters rather than ID-prefix truncation.
7. Bound candidate comparisons and cluster validation. No unbounded library-wide
   all-pairs pass. Disclose time-local coverage; do not claim exact duplicate detection.

### Phase 3 — Durable actionable review (A2, A3, A4, A7)

1. Persist a compact versioned analysis outcome with source IDs, status/reasons,
   score contributions, groups/moments and provenance. Keep facts outside SwiftData
   choices; tolerate old result records with unknown provenance.
2. Present summary and proposals before the full grid. Provide access to all
   proposals, not just the first three. Preserve unavailable and low-quality
   findings even with no usable pick or no duplicate cluster.
3. Album proposals include explicit candidate inclusion. Cleanup proposals can
   recommend Keep or request review with evidence. Never equate album diversity
   exclusions with bad photos or automatically stage deletion.
4. Observe dimension state directly; reviewed counters read durable progress.
   Preserve tri-state membership and undim undecided cleanup photos.
5. Commit an exact user action transactionally before marking it saved. Serialize
   actions per scope and reject stale-generation writes/retries. On failure,
   restore committed presentation or explicitly show pending state; never claim
   unchanged choices while leaving an unexplained optimistic overlay.
6. Suggestions retain immutable proposal IDs/revisions. Preview reads live values;
   changes require fresh confirmation. Retry cannot resurrect a superseded choice.
7. Update native provider copy, counts, reason labels, empty/error states and
   VoiceOver in en/vi, preserving existing String Catalog work.

## Ownership and affected areas

- Execution: `App/AppModel.swift`, `App/AppContainer.swift`,
  `Features/Settings/ModelInstallationModel.swift`, settings/setup views,
  source-summary/processing views and `Services/Session/*`.
- Facts/cache: `Services/Analysis/*`, `Services/Photos/BatchPipeline.swift`,
  `Services/Photos/PhotoLibraryPermissionService.swift`, `Infrastructure/FileAnalysisCache.swift`,
  `Infrastructure/SessionCheckpointStore.swift`, relevant service protocols and
  `Domain/Models/{PhotoAsset,PhotoAnalysis,SelectionResult,ReviewSuggestion}.swift`.
- Algorithms: `Configuration/{AppConfiguration,QualityCurationPolicy}.swift`,
  `Domain/Scoring/QualityScorer.swift`, `Domain/Selection/*` touched by findings.
- State/UI: `App/AppModel+ReviewEntry.swift`, `Infrastructure/WorkspaceStore.swift`,
  `Features/Review/*`, `Localizable.xcstrings`.
- Docs: update the linked feature owners only when implemented contracts change;
  preserve historical evidence. No new model dependency, schema for image blobs,
  test target, proof harness, or unrelated visual redesign.

## Verification and acceptance scenarios

At activation run `./init.sh` and record baseline failures. Each phase uses
focused source/call-path review; final behavior-changing work must run
`./init.sh` and `git diff --check`. No automated test files/frameworks or
standalone proof artifacts. Manual QA is not an acceptance gate (DEC-040).

Review these cases through production logic and record the exact supporting
symbols/branches; clearly distinguish source reasoning from executed evidence:

| Scenario | Required invariant |
|---|---|
| Nine photos in one moment, no duplicates | Useful ranked evidence/proposals or explicit insufficiency; not an unexplained empty review |
| 100 versus 101 photos | Same native policy; no Qwen/size-triggered algorithm switch |
| Zero usable / all unavailable | Review/recovery opens; no fabricated picks or scores |
| Native retake group with low-quality member | Full membership and reason remain accessible; advisory representative is not a deletion verdict |
| No dates, mixed scenes, 180–900s gap | Missing time/evidence stays unknown; continuity input is reachable |
| Missing FeaturePrint / classification request fails | Visible evidence availability; no novelty reward or false “no people” certainty |
| Asset edited / cache write lost / checkpoint present | Recompute stale or missing facts; preserve user choices |
| More than 250 candidates / 4,000 pairs | Bounded work, balanced coverage, explicit truncation/coverage accounting |
| Stage, unstage, Mark Reviewed without album edit | Immediate reactive state and correct independent counts |
| Bulk write fails / rapid opposite edits / stale retry | Atomic or truthful pending state; latest explicit choice wins after relaunch |
| Partial finalize / resume / old result | Correct session binding and backward-readable data; no version fabricated from current constants |
| Vietnamese + large text | Readable filters, counts/actions and accessible state labels |

Lint/build cannot establish photographic quality or iPhone performance. Do not
claim threshold calibration from compilation. Broader tuning requires an explicit
evidence decision, not speculative weight changes in this repair.

## Migration, rollback and completion

- Version additive result/cache changes. Invalidate rebuildable facts only;
  retain scope choices and album/deletion operation records.
- Preserve old mode/result/checkpoint decoding. Resume old Qwen-requested runs
  through native with truthful execution metadata; never dispatch Qwen implicitly.
- Roll back UI/execution adapters without reverting persisted choices. Keep
  parsers for data written during this feature; never reopen a store destructively.
- Finish phases in order under one active feature. Record acceptance evidence,
  unresolved limitations and final `./init.sh` in the feature and append progress.
- If policy or contract choices remain unresolved at activation, obtain approval
  before changing them. This planning session claims no implementation completion.
