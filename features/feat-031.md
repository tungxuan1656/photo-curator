# feat-031 — Quality-first on-device Qwen curation

## Status

- Status: `active` — implementation approved by the user on 2026-09-18.
- Depends on: `feat-028`, `feat-030` (both done).
- Branch: `feat/feat-031-qwen-curation`.

## Goal

Select better representatives and preserve distinct content in 50–100-photo sets with on-device Qwen analysis.
Target iPhone 14 and later, with a 180-second local-analysis budget.

## Scope and ownership

Own the bounded quality pipeline, Qwen runtime and model delivery, visual grouping, album selection, decision provenance, and related review presentation.
Own the affected configuration, persistence, coordinator, localization, and verification contracts.
Exact existing and proposed paths are in the [implementation plan](../docs/plans/feat-031.md#6-file-ownership).

Exclude cloud inference, training, identity recognition, original deletion, Gemma/LFM integration, and unrelated UI redesign.

## Acceptance

- [ ] A1: Independent image evidence establishes coverage, duplicate, best-shot, and recall improvements under plan §10.
- [ ] A2: Qwen3.5-2B uses actual image input through pinned MLX dependencies. The 4B tier has a separate admission result.
- [x] A3: Startup validates the pinned model, explicit setup downloads it without blocking the UI, Settings exposes lifecycle state, and missing-model runs use a visible native fallback; `./init.sh` passes.
- [ ] A4: Grouping precedes irreversible pruning. Every excluded content group has an accountable outcome.
- [ ] A5: Normal, partial, resume, review, and save paths preserve user choices and session ownership.
- [ ] A6: Versions, downloads, retention, startup setup, en/vi copy, fallback disclosure, and rollback match updated owner documents.
- [x] A7: `./init.sh` passes. No test target, test framework, standalone proof file, or manual-QA gate is introduced.

## Readiness plan

Implementation is approved. Execute the linked plan stages in order.
Freeze artifacts and corpus labels before quality comparisons.
Keep hardware claims separate from Simulator evidence.

Accepted lifecycle design (2026-09-19): `ModelInstallationService` remains the
download and verification primitive. `ModelInstallationModel` owns the shared
startup, Settings, alert, retry, cancel, and progress state. Startup checks the
pinned revision once and never downloads without an explicit user action. The
`Download Model` action runs a non-blocking task while the app is open; verified
partial files resume on a later launch. `Later` suppresses repeated prompts for
that launch. A run snapshots model availability and never switches engines
mid-run. Missing Qwen uses `qualityNative` with explicit UI and provenance.

## Relevant docs

The [plan reading route](../docs/plans/feat-031.md#3-owner-documents-and-contract-changes) identifies each canonical owner.

## Verify and handoff

- Planning baseline: `./init.sh` PASS on 2026-09-18 at `54389e5`.
- Planning verification: fresh `./init.sh` PASS, `git diff --check` PASS, and all 16 local documentation links/anchors resolve.
- Index validation passes: `active`, completed dependencies, one execution-order entry, and no second active feature.
- Implementation slice verification: `./init.sh` PASS on 2026-09-18 after adding MLX products, the Qwen manifest/runtime, and the plugin-validation workaround; format, strict lint, Simulator build, and policy test skip all pass.
- Task 2 partial evidence: MLX Swift LM, Swift Hugging Face, and Swift Transformers revisions are pinned; the app builds for the generic Simulator destination with the Swift 5 target and default actor-isolation settings.
- Task 2 partial evidence: downloaded pinned 2B weights and all manifest files validate locally; a temporary executable linked the shipped `QwenRuntime` against the pinned MLX checkouts and passed local load, two-image generation in both orders, and unload on macOS/Metal. The model produced image descriptions, but both responses were fenced free-form arrays instead of the required strict JSON object, so the model is not admitted for production judgments. A bounded strict response validator now rejects those outputs and malformed/oversized variants.
- Task 2 remains open: no production profile admission, controlled corpus comparison, arm64-device build, cancellation/teardown trace, or allocator/footprint record exists.
- Completed Task 2 implementation slice: the isolated `QwenPairJudge` now has an injectable runtime protocol, bounded preview lease, frozen `compare-v1` prompt, strict response admission, generation cancellation, and unload. Production image-quality admission remains blocked on real evidence.
- Task 3 partial evidence: `ModelInstallationService` now performs revision-derived, resumable per-file streaming into staging, hash/size validation, atomic activation, state streaming, cancellation, backup exclusion, removal, and verified post-relaunch discovery without network or weights.
- Task 3 partial evidence: `AppContainer.live()` now owns the installer under the application-support model root.
- Task 3 remains open: UI wiring, live inference leases/resource admission, offline runtime load, and transport fault coverage are not complete.
- Task 4 partial evidence: `QualityGroupBuilder` preserves every analyzed candidate and exposes existing coherent retake clusters plus chronological coverage groups without selecting or discarding assets. It remains an explicit FeaturePrint/time fallback; no pixel encoder or quality gain is claimed.
- Phase 2 partial evidence: `QualityComparisonScheduler` now runs one bounded serial lane with request and wall deadlines, cancellation, request-ID/generation validation, admission counts, and closed degradation reasons. `QualityAlbumSelector` now uses the quality path's content-sized target instead of the native 30-photo minimum, applies Qwen preferences only inside existing retake groups, rejects unusable winners, and persists compact quality provenance without raw prompts, images, or responses.
- Phase 2 partial evidence: `QualityCurationRunner` owns grouping, optional installed 2B loading, bounded comparisons, unload, deterministic selection, and `qualityNative` fallback. Normal and Continue Without Them coordinator paths share it for frozen small-set sessions; native mode remains above the 100-photo scope and the Foundation Models jury is bypassed on quality runs. Model weights remain runtime-downloaded under Application Support and are not bundled in the app.
- Phase 2 verification: `./init.sh` passes on 2026-09-19 with SwiftFormat, strict SwiftLint, generic Simulator build, and policy test skip.
- Phase 2 lifecycle evidence: quality checkpoints carry requested mode, pinned model revision, runtime revision, manifest fingerprint, and the run-start model-availability snapshot. A resume with a different quality identity ignores prior analysis completion and reuses only valid cache work; native checkpoints remain compatible with the pre-quality nil identity. Installed model provenance now records the manifest fingerprint.
- Task 4 remains open: no admitted pixel encoder or subject-detail verifier exists, so no image-quality improvement claim is allowed. Model setup UI, resource admission, physical-device build/measurements, actual image-sensitivity/order evidence, and full cancellation/failed-result evidence remain open.
- Accepted lifecycle slice implementation: startup prompt, non-blocking explicit download, Settings state, retry/cancel/remove, visible no-AI fallback, and en/vi copy are wired. `SelectionRequest.qualityModelAvailableAtStart` and `QualityCheckpointIdentity.modelAvailableAtStart` prevent relaunch, retry, resume, and partial-result paths from enabling Qwen after native fallback has started.
- Deterministic selector slice: quality targets are derived from usable coverage-group count; usable zero-pick groups are repaired unless a selected duplicate representative covers them; audits distinguish unavailable, unusable, covered, selected, and repaired outcomes; Qwen retake preferences resolve by cluster with native-rank fallback for cycles; final duplicate decisions use the post-comparison representative; quality metadata records config version 2.
- Resume correctness slice: relaunch restores the checkpoint's frozen requested mode instead of synthesizing 2B, preserving native, `qualityNative`, 2B, 4B, and legacy native behavior.
- Latest implementation verification: `./init.sh` PASS on 2026-09-19 with SwiftFormat, strict SwiftLint, generic Simulator `BUILD SUCCEEDED`, and the policy test skip.
- Resource/lifecycle slice: model removal waits for active inference leases, rejects new leases during removal, aborts safely when the removal task is cancelled, retains the lease when unload is not confirmed, and fails closed when device memory headroom is unavailable or below the 2B soft ceiling plus reserve. Scheduler cancellation exits the request loop, and native fallback preserves non-applied attempt counts while discarding applied Qwen evidence.
- Resource/lifecycle review: Oracle marked this code slice safe to hand off with no remaining code findings. This is source-level evidence only; no physical-device memory/thermal run or fault-injected concurrency run exists.
- Next: complete pixel-derived grouping, real image-sensitive Qwen evidence, full lifecycle/drain evidence, and hardware/profile admission before treating Qwen comparisons as admitted quality behavior.
