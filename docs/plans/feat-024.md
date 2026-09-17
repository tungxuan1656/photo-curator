# feat-024 execution plan

Goal: bounded Tier-C visual-embedding capability that routes shortlist-scale pairs only, feeds diversity novelty only, and degrades to the complete native FeaturePrint fallback. No Core ML model ships; FastViT stays benchmark-only (not vendored).

## Scope

Owns: `VisualEmbeddingProvider` capability abstraction, `VisualEmbeddingRouter` bounded Tier-C routing, `NativeDerivedEmbeddingProvider` selected representation, `NoopVisualEmbeddingProvider` fallback anchor, `VisualEmbeddingEdges` merge, `SelectionEngine.select` `tierCEdges` wiring (diversity only), `SelectionSessionCoordinator` production wiring (both paths via `AppContainer.tierCProvider`, noop fallback), this plan, the runtime-stack §6 record, and the DEC entries.

Explicitly NOT: cluster membership (`DuplicateResolver`, feat-021 frozen), moment boundaries (`MomentBuilder`, feat-022 frozen), scorer math/weights/thresholds, new Vision requests, new persisted fields, `analysisVersion` bump (stays 4 — no persisted-shape change, no migration), global shortlist/diversity redesign (feat-023), specialist models (feat-025), Core ML vendoring, cloud AI.

## Contract (frozen)

Inputs: shortlist-scale `PhotoAsset` list (≤ 250) for the router; `[SimilarityCandidate]` pairs + version-4 `PhotoAnalysis` rows for the provider; FeaturePrint `[SimilarityEdge]` + Tier-C `[SimilarityEdge]` for the merge.

Outputs: canonical capped `[SimilarityCandidate]` (router); transient `[SimilarityEdge]` (provider); merged `[SimilarityEdge]` for diversity only.

Routing: router refuses > 250 assets (`[]` — no model work); pairs capped at 4,000 canonical lexicographic pairs; provider skips pairs with missing analysis; merge unions by unordered pair keeping the minimum distance; engine default (`tierCEdges: []`) merges to the FeaturePrint edges exactly. Production: both `SelectionSessionCoordinator` paths route analyzed assets through the same router + injected provider (`AppContainer.tierCProvider`, default native); router refusal or empty provider output falls back to noop (no edges, FeaturePrint fallback exactly); clusters + moments keep FeaturePrint edges only.

Version: `analysisVersion` stays 4. No persisted-shape change, so no requeue/migration change. No new Vision request, model, dependency, or cache key.

## Model record (runtime-stack §12 fields)

- Capability: visual representation / embedding (Tier-C candidate scale).
- Status: SELECTED (native derived embedding, default-on safe) / benchmark-only (FastViT headless, not vendored).
- Target failure: repeated scene/composition across time that FeaturePrint + categorical facts cannot separate for diversity novelty (feat-021/feat-022 ceilings: day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity).
- Implementation: `NativeDerivedEmbeddingProvider` — fixed 8-dim vector from persisted scalars only (sharpness, exposure, resolution, aesthetic/horizon/balance nil→0.5, faceCount/6, textLines/10); normalized Euclidean distance + 0.5 penalty when both scenes known and differ.
- Source/version/license/checksum: no vendored model — NOT APPLICABLE. Source: derived from persisted `PhotoAnalysis` facts (no weights file). License: no third-party weights, no redistribution review needed. Checksum: N/A (nothing to checksum). This is the evidence-driven minimal outcome: no model work for every photo, nothing to license/ship.
- FastViT headless family: status BENCHMARK-ONLY (runtime-stack §6, unchanged). Source: Apple ml-fastvit (https://github.com/apple/ml-fastvit) / Apple model catalog; version: unpinned (no conversion performed); license: review required at vendoring time (research-vs-commercial terms must be re-verified before any inclusion); checksum: N/A (not vendored); input/output/precision/size/compute/min-device/latency: NOT MEASURED (no model integrated). Reconsider trigger below.
- Input/output: router shortlist assets → capped pairs; provider pairs + analyses → transient edges. Precision: Double distances, deterministic. Size: 0 bytes shipped. Minimum hardware/OS: unchanged (iOS 26 native path). Compute units: CPU-only scalar math, no Neural Engine/GPU use.
- Tier/routing: C (candidate/shortlist scale only, ≤ 250 assets, ≤ 4,000 pairs). Load/unload: none (no model to load; provider is stateless).
- Fallback: complete — `NoopVisualEmbeddingProvider` (no Tier-C edges) and the engine default both run the pre-feat-024 FeaturePrint path exactly (E1 + N1 proof arms).
- Baseline evidence: Golden-shaped 200→15 + H 1000→56 identical across all three arms (fallback/noop/tierc byte-identical picks, double-run byte-identical).
- Benchmark evidence: `/tmp/f024-evidence/` proof binary (REAL shipped sources verbatim); 14 named cases ALL PASS (R1–R4, P1–P5, E1–E3, N1–N2); exact counts in `features/feat-024.md` Handoff.
- Decision: ship the native derived provider as the Tier-C representation with bounded routing; keep FastViT benchmark-only (do not vendor).
- Reconsider trigger: a named residual failure where persisted facts call two frames identical but album diversity needs them separated, with fixture evidence showing a pixel-level embedding moves picks — then run the FastViT benchmark gate (license re-review + checksum + size/latency/memory/thermal + quality delta) before any vendoring.
- Last reviewed: 2026-09-17.

## Determinism

Canonical router order (sorted IDs, lexicographic pairs, cap); provider pure map (no I/O, no randomness); merge canonical order; engine double-run byte-compare equal on picks per arm; N2 proves clusters + moments frozen (Tier-C never touches them).

## Verification and rollback

Proof binary compiles the REAL shipped Domain + configuration sources verbatim and runs Golden-shaped (200) + 1k-scale (1000) through REAL `SelectionEngine.select` on three arms (fallback/noop/tierc) twice with byte-compare, plus 14 named-case asserts. Pass bar: all arms complete; fallback == noop picks exactly; double-run byte-compare equal all arms; all named cases PASS; 1k completes without critical fail; `./init.sh` PASS; `git diff --name-only` shows owned files only.

Rollback: revert `VisualEmbeddingProvider.swift` + `SelectionEngine.swift` Tier-C wiring + `SelectionSessionCoordinator` Tier-C helper/callsites + `AppContainer.tierCProvider`/`AppModel` passthrough (plus this plan and the feature/progress records). No migration exists to undo — version never moved, no persisted shape changed, no model vendored.
