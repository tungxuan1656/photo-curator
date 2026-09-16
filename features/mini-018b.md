# mini-018b — universal-request cost benchmark

## Status and parent

- Status: `todo` (task-ready; starts after `mini-018a` merges)
- Parent integration feature: `feat-018`
- Reserved ID: `mini-018b`

## Seam and ownership

- One responsibility: measure cold/warm per-request cost of the two new universal
  requests and record the QoS propagation path. Evidence only; no code change.
- Exclusive owns: `docs/evidence/universal-request-cost.md`, `features/mini-018b.md`.
- Forbidden shared contracts: `Domain/Models/PhotoAnalysis.swift`,
  `Services/Analysis/VisionAnalysisService.swift`, `Services/Photos/BatchPipeline.swift`,
  `Infrastructure/FileAnalysisCache.swift`, every `apps/` file, sibling
  `features/mini-018a.md` and `Services/Analysis/UniversalFactAdapter.swift`.
- Merge gate and reviewer: cost table + QoS note reviewable in the evidence file; no
  `apps/` diff; `./init.sh` passes on the parent after merge. Reviewer: integration
  owner plus one independent reviewer, never the module owner alone.

## Admission card (parallel-delivery §4; every field concrete)

- Parent: `feat-018`
- Seam: universal-request cost benchmark (evidence only)
- Exclusive owns: `docs/evidence/universal-request-cost.md`, `features/mini-018b.md`
- Shared contract task: parent plan Task 3 judges the recorded cost against the
  performance.md >~20% regression flag (evidence merge only; no code wiring)
- Target failure: F-017-H (request budget) — universal cost must fit the 1k budget path
- Input: merged 018a adapter phase-1 input shapes + feat-017 H-1000 host-harness baseline
  (1.186 s total, behavior reference only) + performance.md §1/§5 budgets
  (1,000 assets ≤ 5 min; >~20% job-time regression flag; conditions: local assets,
  normal thermals, Low Power off)
- Output: cold per-request cost (aesthetics, classify, each: mean/p50 per asset on the
  A-shape fixture bytes) + warm cost (repeat pass) + existing print-request reference +
  QoS propagation-path note (structured lanes inherit lane priority; no
  `Task.detached`, no priority parameter — code path cite, not a claim). Every number
  labeled by environment (host-harness macOS Vision vs Simulator execution); nothing
  invented, never a device claim.
- Fallback: n/a (evidence only; engine and procedure unchanged)
- Version effect: none (no `analysisVersion` bump; proposes no budget constant)
- Focused QA: numbers reproducible from the recorded method (fixture manifest hashes +
  harness source hash in the evidence file)
- Merge gate: cost table + QoS note reviewable in `docs/evidence/universal-request-cost.md`;
  no `apps/` diff; `./init.sh` passes on the parent after merge
- Reject condition: reports device claims from Simulator/host numbers; touches `apps/`
  or a shared contract; invents a measurement or a budget constant; opens the parent PR

## Acceptance and evidence

- [ ] Cold per-request cost recorded per new request (mean/p50 per asset, environment-labeled).
- [ ] Warm per-request cost + print-request reference recorded (cache-hit path behavior).
- [ ] QoS propagation path recorded as a code-path cite (lanes → handler → requests).
- [ ] No `apps/` diff (`git diff --name-only` shows only the two owned files).
- Manual QA / benchmark command or procedure: harness method recorded in
  `docs/evidence/universal-request-cost.md` (fixture bytes + harness hash + environment).
- Evidence location: `docs/evidence/universal-request-cost.md` (this benchmark).
  Verification: `./init.sh` result, `git diff --name-only`, commit, and PR in Handoff.

## Inline plan

1. After 018a merges: fix the harness input to its phase-1 shapes; record method.
2. Measure cold + warm per-request costs on A-shape bytes; record print reference.
3. Trace and cite the QoS path; write the evidence file; record `./init.sh`.

## Handoff

State `todo` (admitted 2026-09-16 in the feat-018 contract commit; starts after 018a
merges). Blockers: needs stable 018a phase-1 input shapes.
Next: run the benchmark; open the child PR into `tungxuan1656/feat-018-integration`
after gate + review (squash; never to main).
