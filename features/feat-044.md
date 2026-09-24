# feat-044 — Useful AI labels and durable corrections

## Status

- Status: `done`
- Depends on: `feat-041`.

## Goal

Provide a supported multi-label taxonomy with image-sensitive evidence and durable user overrides.

## Scope and ownership

Own provider admission, taxonomy IDs, mapping, automatic assignments, overrides, personal labels, and effective-label projection.
The label browser/editor UI belongs to feat-045.
Contracts: [organization](../docs/product-specs/organization-rules.md), [intelligence](../docs/design-docs/photo-intelligence.md), [runtime](../docs/design-docs/curation-runtime-stack.md).

## Approved admission and revision contract

The autonomous decision for feat-044 is to admit only the existing on-device
Vision built-in classifier. No new model, Qwen path, cloud path, or Photos
private semantic API is admitted.

| Revision | Frozen value | Meaning |
|---|---|---|
| Source | `vision-classification-observation-v1` | `VNClassifyImageRequest` identifier/confidence observations from the bounded oriented analysis image |
| Provider | `vision-classify-sdk-default-unpinned` | Apple Vision built-in classifier using the OS-selected SDK default; no unsupported manual revision claim |
| Runtime | `vision-ios26-native-v1` | On-device Vision framework supplied by iOS; no downloaded runtime or model artifact |
| Mapping | `vision-scene-map-v2` | Explicit raw Vision identifier → app-owned label mapping with ambiguity policy |
| Taxonomy | `vision-scene-taxonomy-v1` | Exactly: `people`, `group`, `landscape`, `architecture`, `food`, `animal`, `indoor`, `outdoor`, `document`, `screenshot` |
| Durable label layer | `catalog-labels-v7` | Automatic assignments, separate overrides, personal labels, and rebuildable effective projection |

The admitted semantic labels require image-sensitive classifier evidence. The
existing confidence floor is `0.75`; the `0.10` ambiguity margin applies only
to mutually exclusive/exclusion label pairs. Compatible labels may overlap.
Unsupported or ambiguous observations remain unknown. The raw Vision
identifier is evidence attribution, not a user-facing taxonomy ID.

V7 stores immutable automatic assignments separately from user state. A
confirm/reject override is keyed by asset and label, survives re-analysis and
restart, and can be restored to automatic behavior. Personal labels have
stable user-owned identities and explicit assignments; they are never model
output. The effective projection combines current automatic assignments with
override precedence and personal assignments, and is rebuildable without
erasing corrections.

## Acceptance

- [x] An explicit decision records provider/runtime evidence and the exact supported taxonomy; unsupported candidates are not claimed.
- [x] Semantic labels use image-sensitive AI; metadata labels retain truthful source attribution.
- [x] A photo can have multiple supported labels across facets with evidence/revision/availability.
- [x] Confirm/reject/personal-label mutations persist separately; re-analysis preserves user overrides.
- [x] Pending, unsupported, unavailable, stale, and successful empty output remain distinguishable.
- [x] No beauty/keep/family-identity claims are fabricated; quality gaps and `./init.sh` evidence are recorded.

## Readiness plan

1. Evaluate native coverage and freeze a useful supported taxonomy/provider decision.
2. Implement versioned assignments and correction precedence.
3. Publish effective-label projections and explicit degraded states.

See [plan](../docs/plans/feat-044.md).

## Evidence and handoff

- State: `done`; admission and the exact ten-ID taxonomy are implemented. Qwen remains blocked separately.
- Implementation evidence: native Vision classification is image-sensitive and bounded; raw identifiers map explicitly to namespaced app-owned label IDs. Automatic assignments carry asset revision, generation, evidence reference, analysis revision, provider/runtime/mapping/taxonomy revisions, score, confidence floor, and ambiguity margin.
- Persistence evidence: analysis commit atomically creates a durable label-publication-pending marker and retracts/rebuilds automatic effective rows; startup and resume always scan pending rows before work scheduling. Successful assignment publication clears the marker in the same transaction as label state. Reconciliation transitions changed and removed assets to stale and retracts their automatic projections in the generation transaction. Reset is atomic and propagates failures; projections carry a catalog-level monotonic revision.
- Oracle residual closure: Vision provenance now truthfully records the OS-selected unpinned `VNClassifyImageRequest` default, mapping revision is `vision-scene-map-v2`, and ambiguity admission is documented and enforced at the `0.75` floor with a `0.10` lead for mutually exclusive labels.
- Verification: `./init.sh` PASS on 2026-09-24 (SwiftFormat, strict SwiftLint, generic iOS Simulator build; tests skipped under DEC-040); `git diff --check` PASS.
- Handoff: feat-045 consumes the durable taxonomy, assignment states, correction intents, and effective-label projection.
- No tests/proof harnesses or mandatory manual QA.
- Next: feat-045 owns the label browser/editor UI; no further feat-044 source work is pending.
