# Curation Runtime Stack

**Status:** Phase 1 research register · no new model admitted
**Updated:** 2026-09-21

This doc owns concrete runtime/API candidate status. Stable facts/suggestion
contracts are in [photo-intelligence.md](photo-intelligence.md). No candidate
below is a production commitment without evidence.

## Current native path

PhotoKit supplies metadata and bounded images. Vision supplies FeaturePrint,
face, and other facts where available. Local heuristics remain the baseline.
`NativeDerivedEmbeddingProvider` is current scalar math over eight persisted
facts, not a learned pixel embedding and not a model. It is transient and does
not establish semantic image understanding.

## Frozen or research-only candidates

| Candidate | License/evidence note | Status |
|---|---|---|
| SigLIP2 Base | Apache-2.0 model card | research-only; runtime/device fit unverified |
| TinyCLIP | MIT repository/model card | research-only; conversion/device fit unverified |
| LAR-IQA | MIT repo; weights/conversion pending | research-only; audit pending |
| LIQE | MIT upstream; artifact audit pending | research-only; audit pending |
| PP-OCRv5 Latin | Vietnamese support documented | research-only; artifact/runtime review pending |
| SmolVLM 256M/500M | Apache-2.0 candidates | research-only; device fit unverified |
| LFM2.5-VL-450M | LFM revenue condition; Vietnamese not listed | research-only; legal/runtime review pending |
| Qwen3.5 0.8B/2B | artifact/runtime/device verification required | frozen and unadmitted |
| MobileCLIP current weights | `LICENSE_MODELS` restricts product use | research-only, not admitted |
| FastVLM current weights | `LICENSE_MODEL` restricts product use | research-only, not admitted |
| IQA-PyTorch | PolyForm Noncommercial | research-only, noncommercial only |

No app-specific benchmarks, iPhone measurements, or device-fit claims are
made here. Qwen remains frozen after the pivot; the old quality-mode route is
not an active product behavior owner.

## Runtime rules

- On-device only for photo facts and suggestions; no network fallback.
- Every candidate needs an artifact/license record, bounded routing,
  cancellation/unload behavior, fallback, privacy review, and reproducible
  evidence before admission.
- Missing or failed intelligence falls back to native facts and leaves the
  suggestion unavailable; it never overwrites user state.
- Model files are not bundled or downloaded implicitly during analysis.
- Simulator/host results cannot prove iPhone latency, memory, thermal, or
  quality. Planning baseline is iPhone 14+ / iOS 26+.
