# feat-019 execution plan

Goal: add bounded contextual quality facts only for eligible photos.

## Scope

1. Freeze Tier-B eligibility, expected-value skipping, bounded output shapes, privacy, fallback, and the `analysisVersion` 2 → 3 rule in `features/feat-019.md`.
2. Implement composition and utility evidence collection with unavailable values when requests cannot run.
3. Wire the facts, update cache/checkpoint handling, and verify skip coverage, persistence privacy, determinism, and cost.
4. Close the feature after `./init.sh` and the recorded proof pass. Defer optional experiments unless a named residual failure requires them.

## Verification and rollback

Run `./init.sh`, byte-compare repeated results, and confirm stale rows requeue. Revert the feature branch or keep the deterministic fallback if the gate fails.
