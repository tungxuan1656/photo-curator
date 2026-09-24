# Analytics Boundary

**Status:** Conditional; no provider selected · 2026-09-23.
Owns optional event collection, not intelligence quality evaluation.

## Current behavior

`AppContainer.live` uses `NoopAnalytics`.
The app ships without analytics until the user approves a provider, consent policy, retention, and event contract.
This pivot does not activate collection or add a provider.

The former auto-pick acceptance, compression, and time-to-album metrics are not the organization product's success contract.
Grouping/label quality vocabulary belongs to [photo intelligence](../design-docs/photo-intelligence.md#evidence-and-quality).

## Future event constraints

If collection is approved, use aggregate counts and bounded duration buckets only.
Never collect photo IDs, label values, personal labels, queries, album names, pixels, OCR text, or per-photo behavior.
Do not treat successful album/deletion operations as proof that grouping or classification was correct.
Collection failure must not affect browsing, inference, filtering, or mutation recovery.

Provider and consent decisions require a new feature and a [privacy](privacy.md) update before implementation.
No event names or numeric success targets are committed by this document.
