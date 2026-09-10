# Analytics and Metrics (Event Contract Only, Conditional)

**Doc:** `analytics.md` (native filename kept)
**Status:** CONDITIONAL — this doc applies only if a metrics provider and consent choice are decided. If no provider is chosen, ship without analytics. Analytics failure never blocks curation.
**Role:** Single owner of the analytics event contract only. Other docs own their areas. This doc does not copy them.

**Ownership (per blueprint):**
This doc owns the 13-event MVP set, the session model with ephemeral ID, and the core rate definitions (acceptance, removal, restore, edit, save, regen, review effort, time-to-album, completion). It also owns segmentation keys, offline rules, and the consent and retention pointers.

This doc does not own privacy and redaction rules (09 is sole owner), perf targets (08), QA evaluation method (10 is primary), or product goals (01). See links below.

**Related docs:**

- `product.md` — product goals (not restated here)
- `performance.md` — perf targets (not restated here)
- `privacy.md` — privacy, redaction, consent, retention rules (sole owner)
- `manual-qa.md` — QA method, primary evaluation (analytics is secondary)

---

## 1. MVP event set (13 events)

Small set only. Use `snake_case`. Describe product meaning, not button names.

| # | Event | When to send | Key fields |
|---|---|---|---|
| 1 | `selection_started` | User starts a run | `input_photo_count`, `input_size_bucket`, `target_selection_count`, `engine_version` |
| 2 | `analysis_completed` | Analysis finishes | `analyzed_photo_count`, `skipped_photo_count`, `duplicate_cluster_count`, `moment_count`, `analysis_duration_seconds` |
| 3 | `selection_completed` | Engine makes first picks | `input_photo_count`, `candidate_count`, `selected_photo_count`, `engine_version`, `processing_duration_seconds` |
| 4 | `review_started` | User opens the picks | `selected_photo_count` |
| 5 | `photo_removed_from_selection` | User drops a pick | `reason_category` if known (else `unknown`) |
| 6 | `photo_restored_to_selection` | User adds back a skipped photo | `original_rejection_category` if known (else `unknown`) |
| 7 | `selection_regenerated` | FUTURE — no UX flow yet; keep row reserved | `previous_selected_count`, `requested_selected_count`, `reason` if known |
| 8 | `album_saved` | User saves the final album | `initial_selected_count`, `final_selected_count`, `removed_count`, `restored_count`, `review_duration_seconds`, `regeneration_count` |
| 9 | `selection_abandoned` | Run ends with no save | `stage` (`analysis`, `selection`, `review`) |
| 10 | `processing_interrupted` | Run stops but can resume | `processed_photo_count`, `input_photo_count`, `stage`, `reason` |
| 11 | `processing_resumed` | Run resumes after stop | `stage`, `remaining_photo_count` |
| 12 | `processing_failed` | Run fails and cannot resume | `error_category` (fixed list, no raw messages) |
| 13 | `selection_feedback_submitted` | Optional rating after save | `rating`, `reason`, `engine_version` |

Rules:

- Send aggregates per session. Do not send one event per photo.
- Event 13 is optional. Events 1–12 are the MVP core.
- Reason and error values use fixed word lists. No free text in MVP.

---

## 2. Common context and session model

Add this small context to each event:

```text
app_version, selection_engine_version, session_id
device_class, os_version_major
```

Optional: `processing_mode`, `input_size_bucket`.

Session model:

- One run is one session: start → analysis → picks → review → save or leave.
- `session_id` is a random ID made for that run only. It links events from the same run.
- It holds no user name, no photo ID, no album name, no device ID, no time stamp inside it.

Size buckets (shared with 08 and 10, defined here only for grouping):

```text
1_100, 101_500, 501_1000, 1001_2500, 2501_5000, 5000_plus
```

---

## 3. Core metrics (from the events above)

User choices are the truth. Engine scores do not decide quality.

| Metric | Formula | Good direction |
|---|---|---|
| Acceptance rate | kept auto picks / all auto picks | up |
| Removal rate | removed auto picks / all auto picks (= 1 − acceptance) | down |
| Restore rate | user-added photos / rejected photos shown | down |
| Edit rate | (removed + restored) / first pick count | down |
| Album save rate | saved sessions / finished sessions | up |
| Regen rate | sessions with regen / reviewed sessions | down |
| Review effort | `review_duration_seconds` + removals + restores + regens; also per 100 picks | down |
| Time to album | time from `selection_started` to `album_saved` | down |
| Completion rate | finished runs / started runs | up |
| Failure rate | failed runs / started runs | down |
| Resume success rate | resumed runs / interrupted runs | up |
| Processing time | median + P90 of analysis, selection, total | down |

Notes:

- Report time values as median and P90, not mean only.
- Report rates with sample size (session count). Do not trust small samples.
- Main quality pair: high acceptance + low restore. One alone can mislead.
- North star: share of auto picks kept in saved albums, read with restore rate.

---

## 4. Segmentation (small set only)

Group metrics by:

```text
engine_version, input_size_bucket, selection_ratio_bucket
```

Selection ratio = `selected_photo_count / input_photo_count`. Ratio buckets:

```text
under_5, 5_10, 10_20, 20_40, over_40 (percent)
```

Compare engine versions with the same table each time: acceptance, restore, edit, save, regen, review time, processing time. Check quality and speed together.

---

## 5. Rules that protect the app

- Analytics sits after the engine. The engine never waits for analytics.
- If analytics has no network, drop or briefly queue the event and keep going. Never block, slow, or error the pick, review, or save steps.
- Queue limits: small fixed size, drop old first, no photo data inside.
- Local debug stats (score spreads, cluster counts) stay on device. They are not production events.
- No per-photo tracking. Describe the session, not the photo library.

---

## 6. What this doc does not own (links only)

- Privacy, forbidden fields, log redaction, consent, retention: see `privacy.md`. That doc is the sole owner. This doc sends counts and time buckets only, per 09.
- Perf targets and budgets: see `performance.md`. This doc only defines how to measure time.
- QA method, datasets, pass rules: see `manual-qa.md`. Manual QA is primary. Analytics only backs it up.
- Product goals and scope: see `product.md`.

---

## 7. Acceptance checks (event contract only)

Pass when:

- AC-01: A full run sends events 1–4 and 8 with counts and engine version.
- AC-02: Removals, restores, and regens (5–7) link to the same `session_id`. Regen metrics apply only if event 7 leaves FUTURE.
- AC-03: All core rates in §3 can be built from stored events.
- AC-04: Results group by `engine_version` and `input_size_bucket`.
- AC-05: With analytics off or offline, pick, review, and save still work with no error.
- AC-06: No event carries fields blocked by 09.

---

## 8. Uncertain

- U-01: Provider not chosen (system metric kit, vendor SDK, or no backend in v1). Events stay valid either way.
- U-02: Consent wording and opt-in vs opt-out depend on provider and region. Follow 09.
- U-03: Retention period for stored aggregates is open. Follow 09 until set.
