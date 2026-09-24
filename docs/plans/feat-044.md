# Useful AI Labels and Corrections Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. The provider admission below is user-approved for feat-044; implementation is complete.

**Goal:** Produce useful overlapping labels with durable user corrections.

**Architecture:** Map image-sensitive provider evidence into stable taxonomy IDs. Store immutable automatic assignments separately from user overrides and query projections.

**Tech Stack:** Swift, current Vision analysis seam, optional separately admitted local provider, SwiftData projections.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese label names.
- No implicit model download, cloud inference, personal-identity inference, or fabricated confidence.
- Admit only the existing on-device Vision built-in classifier. Do not add a model, Qwen, cloud path, or Photos private semantic API.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Approved provider, taxonomy, and revisions

Use the existing `VNClassifyImageRequest` observation stream on the bounded
oriented analysis image. The request does not assign a revision because the
supported SDK surface exposes the OS-selected default; record that provenance
as unpinned rather than claiming a manually selected revision. Freeze these
durable contract identifiers:

| Revision | Value | Boundary |
|---|---|---|
| Source | `vision-classification-observation-v1` | Identifier/confidence observations only |
| Provider | `vision-classify-sdk-default-unpinned` | Apple Vision built-in classifier; OS-selected SDK default |
| Runtime | `vision-ios26-native-v1` | iOS on-device Vision framework; no model artifact |
| Mapping | `vision-scene-map-v2` | Explicit raw Vision identifier mapping and ambiguity policy |
| Taxonomy | `vision-scene-taxonomy-v1` | `people`, `group`, `landscape`, `architecture`, `food`, `animal`, `indoor`, `outdoor`, `document`, `screenshot` only |
| Label layer | `catalog-labels-v7` | Durable assignments, corrections, personal labels, effective projection |

The mapper keeps only those ten exact scene IDs. It does not promote related
raw identifiers such as `beach`, `party`, or `restaurant`. A label is admitted
only at or above `0.75`; mutually exclusive supported labels require a lead of
at least `0.10`, while ties and smaller leads stay unknown. Unsupported
identifiers are not persisted. Metadata facts retain metadata attribution and
are not rewritten as AI semantics. Because the Vision request uses the
OS-selected default revision, a future OS change is a new provider provenance
rather than silently reusing this one.

### V7 durable label design

- **Automatic assignment:** immutable per asset/label/evidence revision, with
  source, provider/runtime, mapping, taxonomy, asset revision, evidence state,
  and optional raw score; no invented confidence.
- **Override:** separate per asset/label user intent with `confirm`, `reject`,
  or `restoreAutomatic`; reject suppresses only that automatic assignment and
  restore removes only that override.
- **Personal label:** stable user-owned label identity plus explicit asset
  assignments; never produced by Vision and never interpreted as identity.
- **Effective projection:** rebuildable V7 query rows from current automatic
  assignments, override precedence, and personal assignments. Re-analysis
  may replace automatic rows but cannot erase corrections or personal labels.
- **Availability:** preserve `pending`, `unsupported`, `unavailable`,
  `stale`, `completedEmpty`, and successful assignments as distinct states.

## Inputs and outputs

Consumes feat-041 evidence/jobs and feat-040 versioned label/override storage.
Produces supported label definitions, automatic assignments, effective labels, and correction intents for feat-045.

## Files and tasks

### 1. Freeze useful supported labels and provider decision

Existing: `apps/photo-curator/Services/Analysis/UniversalFactAdapter.swift`, `VisionAnalysisService.swift`, `UtilityEvidenceAdapter.swift`, `Domain/Models/PhotoAnalysis.swift`.
Owners: [runtime](../design-docs/curation-runtime-stack.md), [intelligence](../design-docs/photo-intelligence.md), [organization](../product-specs/organization-rules.md).

- [x] Assess current native classification against the candidate facets; separate metadata, semantic, and technical sources.
- [x] Define the ten enabled scene IDs, their source attribution, exclusions, and revision identity; unsupported candidates remain unavailable.
- [x] Record provider/image evidence, unavailable capabilities, runtime boundary, and resource/availability limits; no new license-bearing artifact is admitted.
- [x] Escalate inadequate native coverage or missing admission evidence instead of silently claiming full taxonomy support.
- [x] Keep Qwen blocked unless a separate explicit admission decision changes its status.

### 2. Implement evidence-backed assignment

Proposed new: `apps/photo-curator/Domain/Organization/PhotoLabelTaxonomy.swift`, `PhotoLabelMapper.swift`.
Modify the confirmed feat-040 catalog records/store and feat-041 coordinator.

- [x] Map provider observations into versioned multi-label assignments with source/asset/provider/runtime/mapping/taxonomy revisions.
- [x] Preserve unsupported, pending, stale, unavailable, and successful-empty states distinctly.
- [x] Use metadata directly when it provides the fact; do not guess it with AI.
- [x] Retain raw provider scores as scores; leave confidence absent when the source supplies none.

### 3. Persist correction precedence

- [x] Add atomic confirm/reject/restore-automatic intents keyed by asset and label.
- [x] Add stable personal-label identities and explicit assignments without family recognition.
- [x] Rebuild `catalog-labels-v7` effective-label projections with overrides taking precedence across re-analysis and restart.
- [x] On save failure, retain prior committed assignments and expose retry to the UI consumer.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Review multi-label overlap, unknown output, rejected-label persistence, model revision changes, rename/localization identity, and metadata attribution.
Record actual provider evaluation separately from source/build evidence. Unsupported candidate labels cannot satisfy delivery acceptance.

## Rollback and handoff

Invalidate a rejected automatic mapping/provider revision without deleting overrides or personal labels.
Unsupported providers leave facts unknown, not fabricated native equivalents.
Hand the frozen taxonomy, assignment states, and correction intents to feat-045.
