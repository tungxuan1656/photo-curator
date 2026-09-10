# Performance Spec (budgets owner)

**Responsibility:** This file owns perf budgets, targets, and measurement: workload sizes, batch and concurrency limits, resolution cost assumption, derived-cache versioning rule, checkpoint and cancel and resume budgets, memory and progress limits, completion-time targets, and Definition of Done.

**Not owned here:** selection semantics ([03](../product-specs/selection-rules.md), [04](../design-docs/selection-engine.md)), stored representation ([06](../design-docs/data-model.md)), PhotoKit/Vision API mechanics and iCloud behavior ([07](../design-docs/apple-frameworks.md)), privacy and logging redaction ([09](privacy.md)), QA procedure ([10](manual-qa.md)), analytics events ([11](analytics.md)). Where those topics appear below, this file states the budget; the linked file states the mechanism.

Related docs:

- `selection-rules.md` — what gets selected
- `selection-engine.md` — pipeline order and chosen analysis size
- `data-model.md` — stored shape of cache and checkpoints
- `apple-frameworks.md` — PhotoKit and Vision call shape
- `privacy.md` — sole owner of redaction and retention
- `manual-qa.md` — QA steps
- `analytics.md` — event names

---

## 1. Budgets (single table, read first)

One table. All numbers are starting defaults. Centralize them in code in one policy struct. Tune after profiling on the oldest supported device.

| Budget | Value |
|---|---|
| Max selection job | ~5,000 assets |
| Analysis batch size | 32 (tune in 16–64) |
| Heavy Vision concurrency | 2 |
| Light image analysis concurrency | 2–4 |
| Large PhotoKit image requests | 2 |
| Vision concurrency ceiling | 4 (ceiling for profiling, not default) |
| Constrained Vision concurrency (Low Power, pressure) | 1 |
| Persistence writes | Serialized or small batches |
| Selection and ranking stage | 1 task with efficient loops |
| Analysis input class | ~512 px long edge; exact size per feature lives in [04](../design-docs/selection-engine.md) |
| No custom persistent thumbnail cache | None; Photos caching plus bounded preheat only |
| Derived-analysis cache | Enabled with version key |
| Checkpoint interval | Every ~25 assets or ~10 s, whichever comes first, at batch edges |
| Steady-state RSS target | ≤ ~350 MB on oldest supported device |
| Temporary peak RSS target | ≤ ~500 MB on oldest supported device |
| Progress publish rate | ≤ 4 Hz |
| Progress stage-weight start (tunable estimate) | Metadata 5 / Cheap analysis 35 / Expensive analysis 40 / Clustering 10 / Final ranking 10 |
| Scroll frame goal | 60 fps where practical; no app-owned main-thread block over ~16 ms during scroll |
| Startup to interactable | ~1–2 s; no library scan or Vision at launch |
| Time to first visible progress | < 500 ms after Start |
| Cancel UI ack | < 250 ms; no new expensive work < 1 s where practical |
| Completion 300 assets | ≤ 2 min (look closer above 3 min) |
| Completion 1,000 assets | ≤ 5 min (look closer above 8 min) |
| Completion 2,500 assets | ≤ 12 min (look closer above 20 min) |
| Completion 5,000 assets | ≤ 25 min (look closer above 40 min) |
| Cached rerun, 1,000 analyzed | Seconds, not minutes |
| Relative regression flag | Job time up > ~20% with no planned quality change |

Conditions for completion targets: assets local, normal thermals, Low Power off, normal config, oldest supported device. Separate iCloud download time from compute time. Recalibrate targets from the working prototype rather than bending selection quality to hit a number.

## 2. Workloads

| Workload | Assets | Use |
|---|---|---|
| Small | 100–300 | Short event or hand-picked range |
| Normal | ~1,000 | Primary MVP case |
| Large | ~2,500 | Long trip or large event |
| Stress | ~5,000 | MVP max |

Behavior past ~5,000 stays functional where possible. No tuning past ~5,000 is required for MVP.

Core rule: bound active expensive work at each stage. Favor steady throughput over short bursts that end in heat or memory pressure.

```text
Bad:  5,000 assets -> 5,000 image requests -> 5,000 Vision tasks -> spike
Good: 5,000 assets -> metadata scan -> small batches -> few image
      requests -> few Vision workers -> persist -> release -> next batch
```

## 3. Execution strategy

Pipeline order and selection policy live in [03](../product-specs/selection-rules.md) and [04](../design-docs/selection-engine.md). This file only bounds how they run.

- Start with cheap metadata (`localIdentifier`, dates, size, type, subtype, favorite, burst info). Use it to group, skip unsupported media, and pick required analysis. Do not fetch pixels first.
- Use the smallest image that still answers the Vision question. Full resolution only for features that state a need, or for on-demand review and export. The chosen per-feature size lives in [04](../design-docs/selection-engine.md); this file budgets around the ~512 px class.
- Process in finite batches (§1). Each batch: load IDs, fetch bounded images, analyze, persist derived results, release image memory, checkpoint, next batch. No later stage keeps a decoded image from a done batch.
- Use Swift structured concurrency with a small bounded worker pool (`TaskGroup`, actor queue, or similar small pipeline). Never one live task per asset. No custom thread pool unless profiling proves need.
- Adapt to device state: normal uses §1 values; Low Power, heat, or memory warning lowers concurrency toward 1, shrinks prefetch, clears nonessential caches, avoids guess-ahead work; critical heat or memory finishes the safe unit, checkpoints, clears decoded images, pauses, and tells UI. Never push hard while the device reports critical heat.
- Keep the main actor for UI state only. Image decode, Vision, distance math, clustering, migrations, large writes, file work, and cache cleanup run off main. Publish compact job-level state (`completed`, `stage`, `cancelled`, `album`), not per-photo mutations.
- Review grid uses lazy containers and identifier-based cell models, not decoded images. Preheat a bounded window around the visible range through `PHCachingImageManager`. Never preheat the full set. Stored shapes live in [06](../design-docs/data-model.md).
- Selection logic works on compact summaries (IDs, scores, cluster and moment refs), not `UIImage` values. Sorting a few thousand compact values is cheap; image fetch, decode, Vision, and repeat analysis are the real costs.
- Persist in batches at batch edges. Keep fast-changing progress in memory; persist semantic points (asset done, batch done, stage done, job state changed).
- Re-selection reruns ranking, not Vision, when visual analysis is still valid. Changing album size or taste flags reuses cached analysis.
- No silent quality cuts at large sizes. Pressure slows speed first (prefetch, concurrency, batch size, caches, pause), not correctness. A fast lower-quality mode needs an explicit product call in [03](../product-specs/selection-rules.md).
- Persisted values and config constants live in one place. Never scatter batch size, worker counts, image size, checkpoint gaps, or progress rate through code. Never show them as user settings; dev diagnostics may show them during profiling.

## 4. Memory and complexity

- Treat decoded images as costly (a 4000 × 3000 × 4-byte decode is ~48 MB before overhead). Keep temporary image life short: fetch, decode, run Vision, pull out compact scores, release. Never attach `UIImage`, `CGImage`, or pixel buffers to long-lived models.
- Healthy pattern: memory moves up and down across batches and settles in a band. A steady climb across batches (220 → 310 → 410 → 520 MB) points to held refs or cache misuse.
- On memory warning: stop prefetch, clear nonessential image caches, lower concurrency, shrink next batch if needed, keep persisted analysis and checkpoint, continue only when safe. RAM cache and persisted analysis are separate ideas.
- Duplicate work uses cheap candidate buckets first (time closeness, moment or burst membership, coarse signature, size), then detailed match inside small neighborhoods only. Moment grouping sorts once (`O(N log N)`), then scans near-sequentially (`O(N)`). A future global-match feature uses approximate nearest-neighbor, not global pairing, for MVP.

Invariants (only MUST lines in this doc):

- The app MUST never load the full photo set into memory as decoded images.
- Similarity and clustering MUST NOT use global O(N²) expensive comparison.

## 5. Derived cache and versions

What the cache stores and its exact fields live in [06](../design-docs/data-model.md). This file sets only the reuse budget rule.

- Cache holds compact derived values (counts, scores, signatures, scene info, cluster and moment refs), never image blobs. Face detail limits follow [09](privacy.md).
- Reuse a cached result only when its key still holds: asset ID plus asset edit state plus pipeline version plus config version. No full-byte hashing; that alone reads every file.
- Bump the analysis version on incompatible Vision or reading changes. Invalidate lazily on next use (reuse when valid, recompute when not). Never reprocess the whole library on app update for a version bump.
- Recompute on: photo edit, asset replace, pipeline or config change, corrupt entry. Unrelated app changes (UI strings, colors) never void analysis.
- Later jobs reuse valid entries for the same photo, so repeat work trends toward seconds. Drop orphaned rows, old versions, and missing assets lazily; no fancy eviction scheme is needed for MVP. Retention and delete rules live in [09](privacy.md).
- No permanent copy of all PhotoKit thumbnails. Photos already caches images; a second copy adds disk, invalidation, and privacy cost for no engine gain.

## 6. Checkpoint, cancel, and resume budgets

Stored checkpoint shape lives in [06](../design-docs/data-model.md). iCloud fetch shape lives in [07](../design-docs/apple-frameworks.md).

- Checkpoint at §1 gaps. Persist completed analysis as it lands so a stop at photo 4,999 keeps 4,999 results. Keep job state small: job ID, times, config, ID list, pipeline version, stage, completed count, status. Per-photo cache stays the source of truth for what needs redo; no second task database.
- Analysis is idempotent: same asset state plus same version plus same config gives the same stored result. Resume means: load job, check cache, skip valid entries, run the rest, keep the bar where it was instead of resetting to zero.
- Cancel flows from the root job task to batch and worker tasks. Workers check before fetch, after fetch, before and between Vision calls, and before persistence where fitting. Never start a new asset after cancel is known. Ack follows §1 timing; finish the safe unit, checkpoint, release temps, move state.
- Cancel keeps valid completed analysis for later restart. Background, lock, call, or kill is a resumable stop, not a delete. An explicit Pause button is out of MVP scope unless UX trials ask for it.
- Foreground checkpoint plus resume is the correctness path. Long-run background continuation (`BGContinuedProcessingTask` where available) is an extra only; plain `BGProcessingTask` time is system-planned and can stop, so never treat it as a finish promise.
- One bad asset never ends a multi-thousand job. Record the miss, keep going, report `analyzed` vs `unavailable` at the end, and still build an album when enough valid assets remain. Retry a local transient miss once; mark lasting misses unavailable and move on. No retry loops.
- For iCloud sets, show download state apart from analysis state (`Downloading photo 214` vs `Analyzing photo 214`). Prefer lower-resolution copies when they answer the question, so network, battery, and heat stay low.

## 7. Measurement

QA steps live in [10](manual-qa.md). Event names live in [11](analytics.md). Redaction rules live in [09](privacy.md); never log pixels, file names, face data, GPS, or full asset IDs for perf notes.

Capture per run at minimum:

```text
totalJobDuration, metadataDuration, cheapAnalysisDuration,
expensiveAnalysisDuration, clusteringDuration, rankingDuration,
cacheHitRate, averageAssetAnalysisTime, p95AssetAnalysisTime,
peakMemory, failedAssetCount
```

Also note stage spans with `OSSignposter` around job, metadata, load, Vision, clustering, ranking, and persistence batches. Enough to see where time goes; no signpost per tiny op.

Record conditions with each number:

```text
iPhone model, iOS version, app build, asset count,
local vs iCloud mix, battery and Low Power state,
start thermal state, analysis version
```

Bench first on the oldest supported device. A fast current phone never serves as the only reference.

Fix order during profiling: crashes and memory kills, main-thread blocks, repeat Vision work, image size and decode, concurrency, similarity cost, persistence cost, small code tweaks last. Never tune a small loop while full-resolution decodes still run.

Perf bug scale: crash or corrupt or deadlock or stuck cancel on a normal 1,000-photo run is critical; same at ~5,000, or broken resume, restart-from-zero, steep batch growth, or ignored heat is high; clear slowdown vs baseline, grid stutter, dead cache reuse, or chatty progress is medium; small progress wobble or minor tune-ups are low.

## 8. Definition of Done

- 1,000-photo job finishes cleanly on the oldest supported device.
- 5,000-photo job finishes with flat memory across batches.
- UI stays usable during analysis; progress stays at §1 rate.
- Vision and image fetch use §1 bounded concurrency.
- Full-resolution decode runs only where stated.
- Repeat selection reuses valid analysis; album-size changes skip Vision.
- Cancel hits §1 timing and keeps completed analysis.
- Stop or kill resumes without redoing valid work.
- Similarity work stays inside bounded neighborhoods.
- Heat and memory pressure degrade speed with no kill.
- Instruments shows no large leak and no analysis block on main.
- No test targets added (manual validation only, per [10](manual-qa.md)).

## 9. Uncertain

1. True absolute times on the oldest supported device; current targets are starts and need prototype data.
2. Best batch size in the 16–64 span for heat vs speed.
3. Best per-feature pixel size inside the ~512 px class without quality loss (call owned by [04](../design-docs/selection-engine.md)).
4. Stage-weight split for progress bars; needs tuning from real runs.
5. Heat and Low Power step points across device models.
