# Curation Runtime Stack

**Status:** Observed baseline and candidate register · updated 2026-09-23.
Owns concrete provider status and admission records, not taxonomy or product behavior.
Historical candidate/license notes originate from the 2026-09-21 research; recheck exact artifacts before admission.

## Current implementation

| Component | Current role | Limit |
|---|---|---|
| PhotoKit | Metadata and bounded image delivery | No semantic classification guarantee |
| Vision via `VisionAnalysisService` | Native image facts, classification, transient FeaturePrint | No app-specific accuracy claim |
| `UniversalFactAdapter` | Versioned mapping of classification/aesthetic observations | Not a complete organization taxonomy |
| `NativeDerivedEmbeddingProvider` | Eight-scalar derived vector | Not pixel embedding or semantic understanding |
| Native grouping/scoring | Session-bound comparison and suggestions | Not a continuous library index |
| Qwen/MLX source and packages | Retained legacy integration/artifact management | Not wired as an admitted live analysis path |

## Capability-driven selection

Select providers separately for visual retrieval, semantic labels, and optional comparative quality.
One general-purpose language model is not a default dependency for every capability.
Use reliable metadata directly. Use image-sensitive AI for semantic labels.

feat-042 owns the grouping evidence/retrieval decision.
feat-044 owns the label-provider decision and exact supported taxonomy.
Neither feature can describe scalar similarity as learned visual semantics.

## Research candidates

| Candidate | Historical artifact/license note | Status |
|---|---|---|
| SigLIP2 Base | Apache-2.0 model-card candidate | Research-only; conversion/device fit unverified |
| TinyCLIP | MIT repository/model-card candidate | Research-only; artifact and runtime review required |
| LAR-IQA | MIT repository; weights/conversion pending | Research-only |
| LIQE | MIT upstream; exact artifact audit pending | Research-only |
| PP-OCRv5 Latin | Vietnamese support recorded in prior research | Research-only; OCR text storage is not approved |
| SmolVLM 256M/500M | Apache-2.0 candidate artifacts | Research-only; device fit unverified |
| LFM2.5-VL-450M | Revenue condition; Vietnamese not listed in prior review | Research-only; terms require recheck |
| Qwen3.5 0.8B/2B | Artifact/runtime/device evidence incomplete | Frozen, unadmitted; feat-031 remains blocked |
| MobileCLIP / FastVLM weights | Prior review found product-use restrictions | Not admitted; review exact current terms before reconsideration |
| IQA-PyTorch | Prior review found PolyForm Noncommercial | Not a commercial production dependency |

This register grants no license approval and makes no current model benchmark claim.
No new model is selected by the organization pivot.

## Admission record requirements

An admission decision records:

- Exact artifact, version/checksum, runtime revision, and applicable code/weight licenses.
- Supported capabilities and label IDs, including abstention behavior.
- Image-sensitive evidence and known errors, with provenance and evaluation limits.
- Resource observations, cancellation/unload behavior, and missing-model fallback.
- Local storage and network behavior consistent with [privacy](../ship-gates/privacy.md).
- Required `./init.sh` evidence, distinguished from image-quality evidence.

The repository forbids standalone proof/benchmark harnesses. Missing evaluation evidence requires an explicit decision, not invented results.
Device claims require device evidence; a Simulator build cannot supply it.

## Delivery and fallback

No model is downloaded implicitly during analysis.
A new provider must define its installation/delivery path before activation.
Photo inference remains on device with no cloud fallback.
Provider failure preserves current user corrections and exposes unavailable capabilities.
An unsupported taxonomy is not silently replaced with guessed labels.
