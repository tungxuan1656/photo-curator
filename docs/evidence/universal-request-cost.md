# Universal-request cost benchmark (feat-018)

Evidence only; no code change. Every number below is measured on this run from
real fixture bytes with the harness sources hashed in §6 — nothing invented,
never a device claim. Simulator execution of the new Vision requests is
NOT RUN with reason (§4): the Simulator Vision inference backend is unavailable
(`Failed to create espresso context`), so Simulator-execution numbers cannot be
measured on this host; the host-harness numbers below are the reproducible
record, and parent Task 3 re-measures in the Simulator-execution lane where the
backend exists.

## 1. Input shapes (adapter implementation, commit `5b731bb`)

Phase-1 input: the 512 px analysis `CGImage`, orientation `.up`, one shared
`VNImageRequestHandler` per asset; two requests collected beside the existing
face/print requests with independent `try?` per request and cancellation checks
between requests (`apps/photo-curator/Services/Analysis/UniversalFactAdapter.swift`
`collect`, lines 59–81). Phase-2 pure map: `aestheticScore = clamped01((overall+1)/2)`
(nil when unavailable), `tags` = top-3 by confidence (`[]` when unavailable),
`featurePrintAvailable` passthrough (`false` when no print), `isUtility`
transient only (`map`, lines 93–105). Request revisions per the frozen schema:
classify SDK default (rev 2 on iOS 17+), aesthetics rev 1 (only revision);
observations bounded: first `VNImageAestheticsScoresObservation`
(`overallScore` [-1,1] + `isUtility`), `VNClassificationObservation` list
(`identifier` + `confidence`, 1,303-identifier taxonomy).

## 2. Method

Harness: throwaway Swift file compiled with
`swiftc -O -framework Vision -framework CoreGraphics -framework ImageIO`
(source sha256 `f9de810c621be3a6cfb490b528430805faec8682667185415c8c3a9e6a76a118`;
binary sha256 `ea15237982574a399cf9a47b35739613ddd02b08cbd354477a3a2fd11a62fbe6`;
source kept at `/tmp/cost-bench-full.swift`, binary at `/tmp/cost-bench-full` —
both outside the repo, hosts only, never shipped). Per asset: decode fixture
JPEG → downscale to 512 px long edge (`.high` interpolation, matches the
analysis-image class) → fresh `VNImageRequestHandler(cgImage:orientation:.up)`
→ `perform([aesthetics])` timed → `perform([classify])` timed (same handler,
sequential, exactly the 018a `collect` order) → separate fresh handler +
`perform([print])` timed as the existing-request reference. Cold = first pass
over all 60 assets in a fresh process (model/page caches cold); warm = immediate
repeat pass in the same process (caches warm). Per-request timing via `Date()`;
mean/p50 over the 60 per-asset samples; no batching, no concurrency (per-request
cost isolates the request; lane parallelism is a pipeline property, not measured
here). Fixture bytes: A-shape (`fixtures-A`, 60 files, seed-17017
solids+shapes; manifest `33bf85cfc4674caa2368c895bf319c869c86c75e48f17e7f645f5c743f5f2f4b`;
per-file sha256 in `out-A.json:fixtureHashes`).

Environment (host-harness): Mac mini, Apple M2, 8 cores, 17,179,869,184 bytes
(16 GiB) RAM; macOS 26.5.1 (25F80); Xcode 26.6 (17F113); Swift 6.3.3; run
2026-09-16. Cold/warm labels below mean process-cache state on THIS host —
NOT on-device cold/warm, NOT a device claim.

## 3. Cost table (host-harness, A-shape 60 assets @ 512 px)

Three consecutive runs of the same binary; run 1 is the recorded evidence,
runs 2–3 are cold stability repeats (warm was run 1 only in the original
session; warm repeats below are two further runs of the same binary on the
same A-shape fixture bytes).

| Request | Cold mean ms/asset | Cold p50 ms/asset | Warm mean ms/asset | Warm p50 ms/asset | Fails (cold) |
|---|---|---|---|---|---|
| `VNCalculateImageAestheticsScoresRequest` (new) | 5.05 | 3.98 | 3.84 | 3.80 | 0/60 |
| `VNClassifyImageRequest` (new) | 5.42 | 4.71 | 4.62 | 4.57 | 0/60 |
| aesthetics + classify per asset (new-request sum) | 10.47 | 8.67 | 8.46 | — | — |
| `VNGenerateImageFeaturePrintRequest` (existing reference) | 4.17 | 3.67 | 3.54 | 3.51 | 0/60 |

Stability repeats (cold): run 2 — aesthetics 5.09/3.93, classify 5.41/4.65,
sum 10.50/8.55, print 4.13/3.63; run 3 — aesthetics 4.44/3.88, classify
5.15/4.59, sum 9.59/8.47, print 3.82/3.52. Warm stability repeats (mean/p50):
repeat A — aesthetics 4.12/3.81, classify 4.97/4.61, print 3.83/3.53;
repeat B — aesthetics 4.07/3.83, classify 4.98/4.61, print 3.76/3.50
(same binary `ea152379…62fbe6`, same A-shape fixture bytes, 60 assets @ 512 px).
Cold-aesthetics max 38.85 ms
(first-asset model-load outlier; min 3.71 ms); all other maxima ≤ 11.46 ms.
Request-alloc + handler-create overhead is noise (0.004 ms + 0.016 ms mean,
separately probed). Spot check on one fixture (`A_001.jpg`, full 800×600
decode): aesthetics `overallScore 0.51171875`, `isUtility false`; classify
1,303 results (top: `document 0.134`, `chart 0.134`, `diagram 0.134` —
synthetic-solid labels are meaningless; recorded only to prove the classify
path returns the full taxonomy on fixture bytes).

Reads against the feat-017 H-1000 host-harness baseline (1.186 s total =
0.069 s metadata + 1.113 s cheap-analysis + 0.0024 s clustering + 0.0006 s
ranking; behavior reference only): the new-request sum (~10.5 ms/asset cold on
this host) is NOT directly comparable — the baseline's 1.19 ms/asset is a
pipeline average over byte-derived luma heuristics with zero Vision
inference (`expensiveAnalysisDuration 0.0`, no `VNRequest` executed), while the
numbers above are per-request Vision inference time. Parent Task 3 judges the
real pipeline delta (cold full re-analyze incl. 2 new requests vs warm cache
hits + print rebuild) against the performance.md >~20% regression flag; no
budget constant is proposed or changed here.

## 4. Simulator-execution: NOT RUN with reason

A Simulator-arch binary (`arm64-apple-ios26.5-simulator`, platform 7,
source sha256 `f943b9d016632bd1444d5576453faf4d5d5e0c0ed60780e6eae9c40d1b0d2ed3`)
installed and launched on the booted iPhone 17 Pro Simulator (iOS 26.5,
UDID `BE48CD78…AF29E`) against byte-identical fixture copies (md5-verified
`d3a5951d7651b87ce0ab8276920d75b7`) fails every Vision request — new AND
existing — with `Failed to create espresso context` /
`Could not create inference context` (aesthetics, classify, print, face-rects,
face-quality all throw; 60/60 fails). The Simulator on this host has no Vision
inference backend, so per-request Simulator-execution cost is honestly
unmeasurable here — reported as NOT RUN, not as zero, not as a device claim.
Parent Task 3 re-measures where the backend exists; the host-harness table in
§3 is the reproducible record until then.

## 5. QoS propagation path (code cite, not a claim)

No new task API; the two new requests inherit lane priority through the
existing structured lanes:

- Lane: `BatchPipeline.drain` → `withThrowingTaskGroup(of: AssetOutcome.self)`
  (`apps/photo-curator/Services/Photos/BatchPipeline.swift:245`) with
  `group.addTask { try await self.processOne(asset) }` (`:251`) — bounded lanes
  (`effectiveLaneCount()` = `performance.maxConcurrentImageRequests` (2),
  `:314-316`); cache-hit print rebuild via `withTaskGroup` in
  `rebuildSimilarities` (`:211-213`) and `SimilarityRebuilder` (`:17-21`).
  No `Task.detached`, no priority parameter anywhere on these paths.
- Handler: `VisionAnalysisService.analyze` is `nonisolated` with "no `Task{}`
  wrapper, so the pipeline lane's cancellation — and its userInitiated
  priority — propagate directly into the Vision work"
  (`apps/photo-curator/Services/Analysis/VisionAnalysisService.swift:19-23`);
  `performAll` runs synchronously in-lane: one handler, `.up`, independent
  `try?` per request, cancellation checks between requests (`:92-118`).
- Requests: 018a `collect` issues the aesthetics + classify `perform` calls
  (`try? handler.perform([aesthetics])`, `try? handler.perform([classify])` at
  `apps/photo-curator/Services/Analysis/UniversalFactAdapter.swift:59-70`,
  with the request allocations at `:62-63`); parent Task 3 (`bc7cbd0`) wires
  `collect` into `performAll` at
  `apps/photo-curator/Services/Analysis/VisionAnalysisService.swift:139-140`
  (cancellation-checked `try`, beside the face/print calls at `:101-113`), maps
  phase 2 at `:148`, and passes the new facts into `PhotoAnalysis.make` at
  `:149-159` inside the same synchronous lane body.
  `similarityArtifact` (cache-hit path) keeps the single print-request shape
  (`VisionAnalysisService.swift:37-50`).

Effect: the new requests execute on the cooperative-pool thread of the lane's
structured child task at whatever priority the pipeline root carries — same as
every existing request. No priority is set, raised, lowered, or escaped at any
point on this path (verified by grep: no `Task.detached`, no `TaskPriority`,
no priority argument in `VisionAnalysisService.swift`, `UniversalFactAdapter.swift`,
`BatchPipeline.swift` lane bodies).

## 6. Reproducibility

- Fixture manifest (A-shape): `33bf85cfc4674caa2368c895bf319c869c86c75e48f17e7f645f5c743f5f2f4b`
  (from `out-A.json:fixtures.manifestSha256`; provenance `synthetic-generated
  (PIL solids+shapes, seed 17017)`; 60 files in `/tmp/f017-evidence/fixtures-A`;
  per-file sha256 in `out-A.json:fixtureHashes`). Golden-shape
  (`e61200e01993a990258a196869cf8352647ac746982311f1538bd1ed17c2826d`, 200 files)
  and H-1000 (`5a165b85f61e9dbc64a14ec66af6ed1cf06b973b840a31be1a88bf7c3b62dbf8`,
  1,000 files) manifests recorded for parent Task 3 scale-up; not re-measured here.
- Harness source hash: `f9de810c621be3a6cfb490b528430805faec8682667185415c8c3a9e6a76a118`
  (`/tmp/cost-bench-full.swift`); binary:
  `ea15237982574a399cf9a47b35739613ddd02b08cbd354477a3a2fd11a62fbe6`
  (`/tmp/cost-bench-full`). Prior-evidence sources (unchanged, for chain):
  `main.swift` `9d7696f6dae52b155301b669c87db684b76ee6e21ef4a2828f405e55527dc3c8`,
  `runner.swift` `2fa039495011eae05774f6d954e0041b6dbec9fb796fedf0b49bf66328c6d86e`,
  `synth-labels.py` `409601a182b6121d04eaa1a59af2c546f9f1738d89271389b67cac5aacb0745c`.
- Reference budgets (performance.md §1, quoted verbatim — proposed nothing):
  Completion 1,000 assets ≤ 5 min (look closer above 8 min); Relative regression
  flag: job time up > ~20% with no planned quality change; conditions: assets
  local, normal thermals, Low Power off, normal config, oldest supported device.
  Baseline: feat-017 H-1000 host-harness 1.186 s (behavior reference only).
- Config at measure: `analysisVersion 1, engineVersion 2, configVersion 1`,
  cache `schemaVersion 1` (pre-Task-3; the version-2 bump lands in parent Task 3).
- Simulator-execution source hash: `f943b9d016632bd1444d5576453faf4d5d5e0c0ed60780e6eae9c40d1b0d2ed3`
  (`/tmp/SimCostMain.swift` → `/tmp/simcost-sim` `580a5c483935e07ad22373e47d26ffee0fd641adadfa565202bf7e91580d33f0`).

Simulator-only HARD RULE observed: no physical iPhone touched via any channel.
No device claim is made or implied anywhere in this file.
