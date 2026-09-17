# feat-018 execution plan

Goal: add bounded universal quality facts with deterministic fallback and cache requeue.

## Scope

1. Freeze the fact schema, Vision request mapping, PhotoKit allowlist, privacy limits, and `analysisVersion` 1 → 2 rule in `features/feat-018.md`.
2. Implement the adapter and benchmark it on A and Golden fixtures.
3. Wire the facts into analysis, update cache/checkpoint handling, and verify fallback determinism and cost.
4. Close the feature after `./init.sh` and the recorded proof pass.

## Verification and rollback

Run `./init.sh`, byte-compare repeated results, and confirm stale rows requeue. Revert the feature branch or disable the optional facts if the gate fails.
