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
Own the affected configuration, persistence, coordinator, localization, and automated evidence contracts.
Exact existing and proposed paths are in the [implementation plan](../docs/plans/feat-031.md#6-file-ownership).

Exclude cloud inference, training, identity recognition, original deletion, Gemma/LFM integration, and unrelated UI redesign.

## Acceptance

- [ ] A1: Independent image evidence establishes coverage, duplicate, best-shot, and recall improvements under plan §10.
- [ ] A2: Qwen3.5-2B uses actual image input through pinned MLX dependencies. The 4B tier has a separate admission result.
- [ ] A3: Model installation, cancellation, pressure, background, and missing-model paths pass automated evidence.
- [ ] A4: Grouping precedes irreversible pruning. Every excluded content group has an accountable outcome.
- [ ] A5: Normal, partial, resume, review, and save paths preserve user choices and session ownership.
- [ ] A6: Versions, downloads, retention, en/vi copy, and rollback match updated owner documents.
- [ ] A7: Automated proof and `./init.sh` pass. No test target, test framework, or manual-QA gate is introduced.

## Readiness plan

Implementation is approved. Execute the linked plan stages in order.
Freeze artifacts and corpus labels before quality comparisons.
Keep hardware claims separate from Simulator evidence.

## Relevant docs

The [plan reading route](../docs/plans/feat-031.md#3-owner-documents-and-contract-changes) identifies each canonical owner.

## Verify and handoff

- Planning baseline: `./init.sh` PASS on 2026-09-18 at `54389e5`.
- Planning verification: fresh `./init.sh` PASS, `git diff --check` PASS, and all 16 local documentation links/anchors resolve.
- Index validation passes: `active`, completed dependencies, one execution-order entry, and no second active feature.
- Implementation slice verification: `./init.sh` PASS on 2026-09-18 after adding MLX products, the Qwen manifest/runtime, and the plugin-validation workaround; format, strict lint, Simulator build, feat-030 proof, and policy test skip all pass.
- Task 2 partial evidence: MLX Swift LM, Swift Hugging Face, and Swift Transformers revisions are pinned; the app builds for the generic Simulator destination with the Swift 5 target and default actor-isolation settings.
- Task 2 partial evidence: downloaded pinned 2B weights and all manifest files validate locally; a temporary executable linked the shipped `QwenRuntime` against the pinned MLX checkouts and passed local load, two-image generation in both orders, and unload on macOS/Metal. The model produced image descriptions, but both responses were fenced free-form arrays instead of the required strict JSON object, so the model is not admitted for production judgments. A bounded strict response validator now rejects those outputs and malformed/oversized variants in `scripts/proof/feat-031.sh`.
- Task 2 remains open: no `QwenPairJudge` integration, controlled corpus comparison, arm64-device build, cancellation/teardown trace, or allocator/footprint record exists.
- Accepted next slice: implement an isolated `QwenPairJudge` with an injectable runtime protocol, bounded preview lease, frozen `compare-v1` prompt, strict response admission, generation cancellation, and unload. Do not wire selection or persist raw output in this slice.
- Task 3 partial evidence: `ModelInstallationService` now performs revision-derived, resumable per-file streaming into staging, hash/size validation, atomic activation, state streaming, cancellation, backup exclusion, removal, and verified post-relaunch discovery; it is covered by `scripts/proof/feat-031.sh` without network or weights.
- Task 3 partial evidence: `AppContainer.live()` now owns the installer under the application-support model root; the feat-026 whole-source proof injects the same dependency and remains green (`99 PASS / 0 FAIL`).
- Task 3 remains open: UI wiring, live inference leases/resource admission, offline runtime load, and transport fault coverage beyond the deterministic proof are not complete.
- Task 4 partial evidence: `QualityGroupBuilder` preserves every analyzed candidate and exposes existing coherent retake clusters plus chronological coverage groups without selecting or discarding assets. It remains an explicit FeaturePrint/time fallback; no pixel encoder or quality gain is claimed.
- Next: add the quality runner/selector contract only after pixel-derived grouping evidence and the admitted Qwen response path are available.
