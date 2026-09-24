# Optional Organization Exploration

**Status:** Optional, non-blocking guidance · 2026-09-23.
Manual QA is never an acceptance criterion, blocker, or release gate under DEC-040.
Required behavior verification remains `./init.sh`; no test targets or standalone proof harnesses are permitted.

## Purpose

User reports can reveal whether groups and labels help actual organization.
These observations are useful evidence, but are not a substitute for recorded implementation verification.
Quality claim definitions belong to [photo intelligence](../design-docs/photo-intelligence.md#evidence-and-quality).

## Optional exploration cases

| Case | Question |
|---|---|
| Repeated selfies with expression changes | Does one coherent comparison group preserve all useful alternatives? |
| Similar beaches from different trips | Do labels connect them without a false retake group? |
| Same image saved on different dates | Does cross-date retrieval find the near-copy? |
| Chained visual variations | Does grouping avoid merging unrelated endpoints? |
| Blurred nature shots and deliberate night photos | Are technical signals distinct from a delete recommendation? |
| Documents and screenshots with text | Are kind labels useful without exposing raw text? |
| Two filtered matches in a five-photo group | Are outside-filter alternatives visible but not silently selected? |
| Incorrect AI label corrected by user | Does the correction survive re-analysis and restart? |
| Partial access or unavailable iCloud image | Does the app show honest coverage and recovery? |
| Album or deletion interrupted | Does saved work remain reachable without inferred success? |

## Report format

Record build, provider/grouping revision if visible, entry route, expected behavior, actual behavior, and impact.
Use failure categories such as false merge, missed near-copy, incorrect label, missing label, inaccessible detail, or action-scope mismatch.
Keep private image identifiers and screenshots out of public records.
Do not convert optional exploration into a release checklist or revive historical fixture/proof procedures.
