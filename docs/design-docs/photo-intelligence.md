# Photo Intelligence (facts and suggestions owner)

**Status:** Phase 1 contract · research-informed, no new model admitted

This document owns the boundary between immutable photo facts and advisory
candidate suggestions. `review-rules.md` owns user choice semantics;
`curation-runtime-stack.md` owns concrete runtime candidates and licenses.

## Contract

Analysis produces immutable, versioned facts: technical signals, grouping
evidence, content aggregates, and availability. A separate suggestion record
may reference those facts and propose a classification, group relationship,
or album candidate. Suggestions carry provenance, runtime/model revision, and
evidence status. They never write cleanup disposition, album membership, or
review progress.

Current `NativeDerivedEmbeddingProvider` is **not a learned pixel embedding**.
It derives an 8-scalar vector from already persisted facts (sharpness,
exposure, resolution, aesthetic/horizon/balance fallbacks, face count, and text
signal). It is transient scalar math, not a model and not pixel understanding.
Vision FeaturePrint remains a separate perceptual-nearness signal.

Qwen is frozen and unadmitted. No Qwen result may be described as production
quality behavior until image-sensitive evidence, runtime/lifecycle evidence,
license review, and device/resource evidence exist. MobileCLIP and FastVLM
current weights are research-only because their model licenses restrict
product development. IQA-PyTorch is noncommercial under PolyForm
Noncommercial; an upstream code license must not be treated as a commercial
weight or derivative license.

## Shared review input contract

feat-034 owns the minimum review-facing suggestion contract and an adapter over
existing native analysis/grouping outputs. feat-037 extends producers and retires
the legacy adapter; feat-034 does not depend on feat-037 to render or accept suggestions.

Each immutable record contains:

- Stable suggestion ID and scope ID.
- Exact candidate asset IDs and source group identity, when available.
- Analysis/grouping version and source revision used to produce the record.
- Provenance: native provider or legacy-native adapter; model revision only when applicable.
- Evidence status: available, insufficient, or unavailable; reason codes with localized display copy.
- Optional explicit proposal: one choice dimension and its per-asset values, never deletion staging.

Derive identity deterministically from source identity, revisions and the exact
proposal. A changed proposal creates a new record. Missing provenance/version
must remain unknown; it cannot be invented or presented as model-backed evidence.
Records lacking a stable revision or complete proposal can be displayed as
unavailable/insufficient but cannot enable Use Suggestion.

feat-034 adapts existing native facts only; legacy selected/rejected output is
not applied automatically as a new user choice. An empty native suggestion set
is valid and uses the empty Needs Review state. Acceptance follows the preview
and independent-mutation rules in [review-rules.md](../product-specs/review-rules.md#review-action-transitions).
feat-037 must preserve this consumer contract or migrate its records explicitly.

## Evidence vocabulary

`research-only` means a candidate can be investigated but is not shipped;
`unverified` means no app-specific benchmark or device-fit claim exists;
`admitted` requires a separate decision with quality, privacy, license,
runtime, and performance evidence. No benchmark or device fit is claimed by
this document.

## Candidate register

| Candidate/capability | License/source note | Runtime/evidence status |
|---|---|---|
| SigLIP2 Base | Apache-2.0 model card | research-only; runtime, size, and device fit unverified |
| TinyCLIP | MIT repository/model-card candidate | research-only; conversion and device fit unverified |
| LAR-IQA | MIT repository; weights/conversion pending | research-only; artifact/license audit pending |
| LIQE | MIT upstream; artifact audit pending | research-only; weights and device fit unverified |
| PP-OCRv5 Latin | PaddleOCR documentation lists Vietnamese support | research-only; product artifact/license/runtime review pending |
| SmolVLM 256M/500M | Apache-2.0 candidate artifacts | research-only; runtime and device fit unverified |
| LFM2.5-VL-450M | LFM license has a revenue condition; Vietnamese is not listed | research-only; legal/runtime/device review pending |
| Qwen3.5 0.8B/2B | Artifact/runtime/license review required | frozen, unadmitted; no quality or device claim |
| MobileCLIP current weights | `LICENSE_MODELS` restricts use | research-only; not product-admissible as currently licensed |
| FastVLM current weights | `LICENSE_MODEL` restricts use | research-only; not product-admissible as currently licensed |
| IQA-PyTorch | PolyForm Noncommercial repository license | research-only; not a commercial production dependency |

Sources and research date are recorded in the authoritative deepwork brief:
research performed 2026-09-21; no app-specific benchmark was performed.

## Safety and admission

- Missing facts remain unknown, never a fabricated zero.
- Suggestions are bounded and explainable; abstention is valid.
- New models require an owner-doc update, artifact checksum/license record,
  local-only execution path, fallback, cancellation/unload behavior, and
  reproducible automated evidence plus `./init.sh`.
- iPhone 14+ and iOS 26+ remain the planning baseline. Simulator or host
  results do not establish iPhone latency, memory, thermal, or quality claims.
