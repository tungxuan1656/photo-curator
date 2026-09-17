# feat-017 execution plan

Goal: record the V2 baseline and failure inventory before behavior changes.

## Scope

1. Freeze fixtures, nine metric denominators, versions, devices, and evidence locations in `features/feat-017.md`.
2. Run the A–H, Golden, and Real Trip baseline and record reproducible rows.
3. Record the 1,000-photo budget observations and classify failures with candidate remedies.
4. Close the feature after review of the ledger and `./init.sh`.

## Verification and rollback

Run `./init.sh` and preserve the baseline if a later experiment fails. This feature changes no production scoring, thresholds, weights, versions, or QA policy.
