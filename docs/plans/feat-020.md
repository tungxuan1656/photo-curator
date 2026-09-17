# feat-020 execution plan

Goal: improve people and group scoring with weakest-face protection and deterministic fallback.

## Scope

1. Freeze aggregation inputs, weakest-face protection, candid guard, reason codes, privacy, and the `analysisVersion` 3 → 4 rule in `features/feat-020.md`.
2. Compute transient per-face distribution scalars from existing Tier-A observations.
3. Wire the scalars into scoring and reason selection without adding Vision requests or persisting raw face data.
4. Close the feature after `./init.sh`, byte-compare determinism, privacy, cache requeue, and A/Golden/B evidence pass.

## Verification and rollback

Run `./init.sh` and preserve the previous deterministic selection if the people/group gate fails.
