# Useful AI Labels and Corrections Implementation Plan

> **Execution:** Follow the repository's implementation and verification rules. Provider admission is a decision within this feature, not pre-approved model selection.

**Goal:** Produce useful overlapping labels with durable user corrections.

**Architecture:** Map image-sensitive provider evidence into stable taxonomy IDs. Store immutable automatic assignments separately from user overrides and query projections.

**Tech Stack:** Swift, current Vision analysis seam, optional separately admitted local provider, SwiftData projections.

## Global constraints

- iPhone 14+ / iOS 26+, on-device, English/Vietnamese label names.
- No implicit model download, cloud inference, personal-identity inference, or fabricated confidence.
- Run `./init.sh`; no tests/proof harnesses. Manual QA is not a gate.

## Inputs and outputs

Consumes feat-041 evidence/jobs and feat-040 versioned label/override storage.
Produces supported label definitions, automatic assignments, effective labels, and correction intents for feat-045.

## Files and tasks

### 1. Freeze useful supported labels and provider decision

Existing: `apps/photo-curator/Services/Analysis/UniversalFactAdapter.swift`, `VisionAnalysisService.swift`, `UtilityEvidenceAdapter.swift`, `Domain/Models/PhotoAnalysis.swift`.
Owners: [runtime](../design-docs/curation-runtime-stack.md), [intelligence](../design-docs/photo-intelligence.md), [organization](../product-specs/organization-rules.md).

- [ ] Assess current native classification against the candidate facets; separate metadata, semantic, and technical sources.
- [ ] Define each enabled label's ID, positive meaning, exclusions, compatible labels, and localization keys.
- [ ] Record provider/image evidence, unavailable capabilities, licenses where relevant, and resource limits.
- [ ] Escalate inadequate native coverage or missing admission evidence instead of silently claiming full taxonomy support.
- [ ] Keep Qwen blocked unless a separate explicit admission decision changes its status.

### 2. Implement evidence-backed assignment

Proposed new: `apps/photo-curator/Domain/Organization/PhotoLabelTaxonomy.swift`, `PhotoLabelMapper.swift`.
Modify the confirmed feat-040 catalog records/store and feat-041 coordinator.

- [ ] Map provider observations into versioned multi-label assignments with source/asset/provider/mapping revisions.
- [ ] Preserve unsupported, pending, stale, unavailable, and successful-empty states distinctly.
- [ ] Use metadata directly when it provides the fact; do not guess it with AI.
- [ ] Retain raw provider scores as scores; leave confidence absent when the source supplies none.

### 3. Persist correction precedence

- [ ] Add atomic confirm/reject/restore-automatic intents keyed by asset and label.
- [ ] Add stable personal-label identities and explicit assignments without family recognition.
- [ ] Rebuild effective-label projections with overrides taking precedence across re-analysis and restart.
- [ ] On save failure, retain prior committed assignments and expose retry to the UI consumer.

## Verification

Run baseline/final `./init.sh` and `git diff --check`.
Review multi-label overlap, unknown output, rejected-label persistence, model revision changes, rename/localization identity, and metadata attribution.
Record actual provider evaluation separately from source/build evidence. Unsupported candidate labels cannot satisfy delivery acceptance.

## Rollback and handoff

Invalidate a rejected automatic mapping/provider revision without deleting overrides or personal labels.
Unsupported providers leave facts unknown, not fabricated native equivalents.
Hand the frozen taxonomy, assignment states, and correction intents to feat-045.
