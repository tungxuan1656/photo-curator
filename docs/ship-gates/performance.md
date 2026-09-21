# Performance Gate

**Status:** Phase 1 pivot contract · budgets owner

Budgets are starting points, not device claims. Measure on the iPhone 14+
/iOS 26+ baseline before making a claim; Simulator/host evidence cannot prove
latency, memory, thermal behavior, or image quality.

## Starting budgets

| Work | Starting budget |
|---|---:|
| Normal source | 100–2,000 photos |
| Analysis batch | 32 (tune 16–64) |
| Heavy image concurrency | 2 |
| Progress publication | ≤4 Hz |
| Checkpoint | every ~25 assets or ~10 s at safe edges |
| Decoded full images | bounded per-asset only |
| Review thumbnails | visible plus small preheat window |
| Workspace persistence | compact SwiftData transactions |
| Deletion mutation | exact set, serialized operation |
| Retry | explicit action; none automatic for deletion |

## Runtime rules

Analysis is incremental and resumable. It loads metadata first, processes
bounded image batches, writes compact facts/checkpoints, and releases decoded
images. A choice change must not force image re-analysis. Review remains
responsive and retains user choices under memory pressure or interruption.

Album save and deletion are separate operations. Persist semantic progress and
per-ID outcomes at safe edges. Never claim a time or storage result that has
not been measured; never claim immediate recovered bytes after deletion.

## Gate

A release candidate must show stable resume, bounded memory, responsive review,
truthful partial outcomes, and explicit deletion gating through reproducible
automated evidence plus `./init.sh`. No test targets, test files, test
frameworks, or standalone proof harnesses are allowed.
