# Privacy and Retention

**Status:** Organization pivot contract · 2026-09-23.
Owns sensitive-data boundaries, local retention, access changes, and disclosure.

## Data boundary

Photo analysis runs on device. The core app has no account, backend, cloud inference, or required analytics.
Apple Photos retains originals; the app stores references and derived organization data.
PhotoKit can retrieve iCloud images as part of the user's library. This is not a Photos Curator upload.

Photos, thumbnails, labels, corrections, model output, identifiers, and derived visual data never enter app-controlled upload paths.
Logs and crash attachments exclude photo IDs, filenames, pixels, OCR text, faces, precise location, personal labels, and album names.
Aggregate diagnostics cannot include values that identify an individual photo or person.

## Stored state

[Data model](../design-docs/data-model.md) owns physical storage and schema.
Catalog metadata and derived projections are local and scoped to authorized assets.
User label corrections and saved work are durable user state, not disposable inference cache.
FeaturePrint objects, face boxes, and original pixels remain transient.
Persisted image embeddings require a separate recorded decision before introduction.

The pivot does not add a raw OCR text index or face identity database.
Personal labels such as children or work are explicit user assignments.

## Access changes

Limited access is a normal browsing and organization mode.
The app must not imply that a limited subset represents the entire phone library.
When access changes, remove inaccessible assets from actionable results and invalidate affected operation previews.
Preserve local corrections and unresolved operation records without exposing inaccessible image content.
Reauthorization can reconnect records by asset ID and current revision.

An inaccessible asset is not proof of deletion.
Original deletion follows the exact-set/full-access contract in [review rules](../product-specs/review-rules.md#deletion-gate).

## Reset and retention

- Reset Analysis removes derived facts and projections, then permits recomputation.
- Reset Analysis preserves user labels, overrides, album drafts, staging, and operation history.
- Cache eviction never removes originals or user state.
- Unresolved mutation records survive screen dismissal and analysis reset.
- Any future action that erases user organization data needs separate explicit wording and confirmation.

Model delivery must not send photo content or photo-linked metadata.
No model downloads start implicitly during analysis.

## Disclosure and verification

Usage descriptions, privacy manifests, and store disclosures must match the shipped capabilities, not the target roadmap.
Explain that local labels organize the companion catalog; they are not promised to appear as Apple Photos keywords.
Do not promise immediate storage recovery after deletion.

Run `./init.sh` for behavior changes and inspect the relevant data paths.
No analytics provider is selected by this pivot. The conditional contract is in [analytics](analytics.md).
