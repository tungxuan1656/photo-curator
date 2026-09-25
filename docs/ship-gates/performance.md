# Performance and Lifecycle

**Status:** Catalog budgets, not device measurements · 2026-09-25.
Owns work bounds and resource claims for a persistent photo index.

## Planning budgets

| Work | Starting constraint |
|---|---|
| Library size | Entire authorized photo scope; capacity is unmeasured, not capped by the old 100–2,000 selection target |
| Analysis page | 32 assets; tune within 16–64 only with recorded reason |
| Comparison image batch | 2 images |
| Heavy image concurrency | At most 2 initial lanes |
| Shared image permits | One two-permit `ImageWorkArbiter` across session, enrichment, and visible work |
| Progress publication | At most 4 Hz |
| Durable reconciliation handoff | About 25 assets or 10 seconds, at safe commit boundaries; checkpoint is a resume hint, not evidence authority |
| Browsing | Metadata-first; no wait for complete inference |
| Thumbnail work | Visible cells plus a bounded preheat window |
| Detail previews | Bounded current/adjacent work; release obsolete images |
| Image lifetime | Scoped to the active analysis/comparison/inspection operation; release after use |
| Similarity candidates | Bounded retrieval; no library-wide all-pairs image comparison |
| Query execution | Compact indexed projections; no per-query scan of every analysis JSON |
| Mutations | Serialized operation ownership with fixed exact sets |

These are implementation starting points. They do not establish latency, battery, thermal, or whole-library capacity claims.

## Scheduling

Prioritize image inspection over enrichment.
Batch cheap metadata and process images incrementally off the main actor.
Coalesce library-change notifications into reconciliation generations.
An edited asset invalidates affected evidence; changing filters or selection does not rerun inference.

The first capability is `nativeImageFacts`. Evidence is written durably before
the actor-guarded catalog status commit, publication, and checkpoint advance.
Each commit checks the run token, catalog generation, asset fingerprint, and
analysis/provider revisions. Typed `accessRequired`, `iCloudWaiting`,
`modelUnavailable`, `revisionStale`, `cancelled`, and transient-failure reasons
drive retry behavior; completed empty output is not a failure.

Pause at safe edges on suspension or resource pressure.
Drain cancelled work before publishing terminal state.
Resume with revision checks, not counters alone.
Retry unavailable analysis through explicit user action or a documented changed-condition policy; never spin on persistent failures.
Deletion retry remains exclusively explicit under [review rules](../product-specs/review-rules.md).

Lifecycle invariants: a new run invalidates its prior run token; cancellation
drains structured tasks before terminal publication; reset cancels and drains catalog
plus legacy workers, invalidates the token, clears derived cache/evidence/projections,
status, and checkpoints safely, and rejects late results. The shared
arbiter is the only image-work permit pool and visible work takes priority.

## Scale work

The existing time-window pair enumeration is not evidence of scalable cross-date duplicate retrieval.
feat-042 must bound candidate generation and record any recall tradeoff.
feat-047 evaluates catalog paging, projection rebuilding, disk growth, and interruption across increasing accessible scopes.
Do not store full-resolution images or a full library of decoded images.
Similarity artifact persistence requires the separate decision in [data model](../design-docs/data-model.md).

## Evidence

Every behavior feature runs `./init.sh` and records implementation limits.
Build success does not prove responsiveness or image quality.
Resource reports name device, OS, scope size, provider revision, elapsed time, and observed memory where available.
Unmeasured values stay unmeasured; do not invent numeric release claims.
Manual QA is optional and never a gate. No standalone measurement/proof harness is introduced.
