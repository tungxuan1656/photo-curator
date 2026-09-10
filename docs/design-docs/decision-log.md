# Photos Curator — Decision Log

**Doc:** `decision-log.md` · **Status:** Living · **Updated:** 2026-09-10

**Ownership:** This doc OWNS rationale/history only (why a choice was made, append-only DEC-xxx).
It never owns current operational values — those live in owner docs (linked per entry).
Current values: selection policy → `selection-rules.md`, mechanics → `selection-engine.md`,
arch → `ios-architecture.md`, shapes → `data-model.md`, APIs → `apple-frameworks.md`,
budgets → `performance.md`, privacy → `privacy.md`,
QA → `manual-qa.md`, UX → `ux-flows.md`, product → `product.md`,
metrics → `analytics.md`, roadmap → `roadmap.md`.

**Rules:** Append-only. Never silently rewrite history. To change a DEC: keep old text,
mark `Superseded by DEC-xxx`, add new entry. Statuses: `Accepted / Rejected / Superseded / Deferred / Revisit`.
New entry fields: status, date, owner doc, affected docs, risk, trigger/reconsider-when. Keep English simple.

---

## 1. Status table (first — full index)

### 1a. Accepted (27 kept)

| ID | Decision | Owner doc |
|---|---|---|
| DEC-001 | Native iOS app | 01 |
| DEC-002 | SwiftUI primary UI | 05 |
| DEC-003 | Apple-native frameworks first | 05, 07 |
| DEC-004 | On-device processing by default | 01, 09 |
| DEC-005 | Originals untouched | 01, 09 |
| DEC-006 | Multi-stage selection pipeline | 03, 04 |
| DEC-007 | Moment-centric grouping | 03, 04 |
| DEC-008 | Duplicate reduction before final pick | 03, 04 |
| DEC-009 | Optimize album quality, not top-N scores | 03 |
| DEC-010 | Diversity is explicit constraint | 03 |
| DEC-011 | ~1,000 photos primary workload | 08 |
| DEC-012 | Workable to ~5,000 without redesign | 08, 04 |
| DEC-013 | Incremental, cancellable processing | 04, 05, 08 |
| DEC-014 | Cache reusable analysis | 04, 06, 08 |
| DEC-015 | Intentionally simple architecture | 05 |
| DEC-016 | No automated test targets | 10 |
| DEC-017 | Manual QA for selection quality | 10 |
| DEC-018 | Analytics carry no photo/biometric content | 11, 09 |
| DEC-019 | Keep selection-reason metadata | 03, 04, 06 |
| DEC-020 | No personalization required for MVP | 01, 03 |
| DEC-021 | Keep user-feedback shape for future use | 06 |
| DEC-022 | Tolerate interruption | 04, 05, 08 |
| DEC-023 | Handle iCloud assets explicitly | 07, 02 |
| DEC-024 | No cloud-AI dependency for core selection | 01, 07 |
| DEC-025 | Deterministic rules around model outputs | 03, 04 |
| DEC-026 | Never auto-delete rejected photos | 01, 02 |
| DEC-027 | Speed of development over purity | 05 |

### 1b. Deferred TBDs (7 kept, structured)

| ID | Topic | Owner | Status |
|---|---|---|---|
| DEC-TBD-001 | Min iOS version | 07 | Deferred |
| DEC-TBD-002 | Persistent storage tech | 05, 06 | Deferred |
| DEC-TBD-003 | Analytics provider | 11 | Deferred |
| DEC-TBD-004 | Monetization model | 01 | Deferred |
| DEC-TBD-005 | Final album export behavior | 02, 07 | Deferred |
| DEC-TBD-006 | Advanced ML models | 03, 04, 07 | Deferred |
| DEC-TBD-007 | Personalization strategy | 03, 06 | Deferred |

### 1c. Open product questions (from 01 §57 — no answers yet)

| ID | Question | Owner | Status |
|---|---|---|---|
| OPEN-P01 | Input scope: photos vs date range vs both? | 01, 02 | Deferred |
| OPEN-P02 | Album size: exact number or S/M/L presets? | 01, 02 | Deferred |
| OPEN-P03 | Auto-suggest album size? | 01, 03 | Deferred |
| OPEN-P04 | How much alternative browsing in review? | 02 | Deferred |
| OPEN-P05 | Mandatory-include mark before curation? | 02, 03 | Deferred |
| OPEN-P06 | Screenshots: exclude or deprioritize? | 03 | Deferred |
| OPEN-P07 | Live Photos representation in MVP? | 02, 07 | Deferred |
| OPEN-P08 | Prefer edited versions? | 03 | Deferred |
| OPEN-P09 | Do Apple Photos favorites boost rank? | 03 | Deferred |
| OPEN-P10 | Feedback persistence across sessions? | 06, 03 | Deferred |

### 1d. Open UX pointers (owned by 02 §16 — grouped, ~20 questions)

| ID | Group | Covers | Owner | Status |
|---|---|---|---|---|
| OPEN-UX01 | Input & size select | picker wording, range UI, S/M/L vs number, suggestion display | 02 | Deferred |
| OPEN-UX02 | Progress & cancel | progress stages, %, cancel/pause wording, background note | 02, 08 | Deferred |
| OPEN-UX03 | iCloud & error states | download wait copy, offline, denied/limited, retry | 02, 07 | Deferred |
| OPEN-UX04 | Review grid & alternatives | grid density, compare, swap-winner, bulk actions | 02 | Deferred |
| OPEN-UX05 | Save & history | save destination, confirm copy, session history scope | 02, 07 | Deferred |

(Each group holds ~3–5 micro-questions; full wording owned by 02. This log tracks only decision state.)

### 1e. Open numeric / Uncertain (values owned elsewhere — this log tracks state)

| ID | Topic | Owner | Affected | Status |
|---|---|---|---|---|
| OPEN-N01 | Quality-tier cutoffs | 03 | 04, 10 | Deferred |
| OPEN-N02 | Similarity thresholds (dup/near-dup) | 03 | 04, 10 | Deferred |
| OPEN-N03 | Moment windows (45s/180s, dense events) | 03 | 04, 10 | Deferred |
| OPEN-N04 | Ordinary/rich/high-count boundaries | 03 | 04, 10 | Deferred |
| OPEN-N05 | Clamp edges (min 30–40, max 120–150) | 03 | 04, 10 | Deferred |
| OPEN-N06 | Weight set (diversity/coverage/repetition/bonus) | 03 | 04, 10 | Deferred |
| OPEN-N07 | Batch sweet spot (16–64), concurrency caps | 08 | 04, 05 | Deferred |
| OPEN-N08 | Vision edge cases (eyes, blur intent, small faces, signs) | 03 | 07, 10 | Deferred |

---

## 2. Accepted decisions (compressed — rationale only)

Format per entry: decision → why → risk/trigger. Current numbers live in owner docs.

**DEC-001 — Native iOS app (Accepted, 2026-09-10).**
Deep PhotoKit/Vision/lifecycle integration needed; cross-platform adds cost at the most native layer.
Risk if reversed: rewrite. Revisit only if iOS succeeds and Android demand is proven. Owner: 01.

**DEC-002 — SwiftUI primary (Accepted).**
Fast, concise, state-driven; UIKit only for gaps. Risk: minor wrappers later. Owner: 05.

**DEC-003 — Apple-native first (Accepted).**
Less maintenance, size, privacy and abandonment risk. Third-party needs clear benefit. Owner: 05, 07.

**DEC-004 — On-device by default (Accepted).**
Personal photos; avoids upload latency, cost, network need. Constraint: must fit CPU/GPU/memory/thermal.
Cloud only for optional extras, never core selection. Owner: 01, 09.

**DEC-005 — Originals untouched (Accepted).**
Selection ≠ management. Operate on refs/metadata/thumbnails/decisions. Risk of breach: trust loss. Owner: 01.

**DEC-006 — Multi-stage pipeline (Accepted).**
Top-N ranking repeats the same scene. Stages: discover → light analysis → quality filter →
group → moments → best-of-group → shortlist → diversity pick → album. Scores are inputs, not the answer.
Owner: 03, 04.

**DEC-007 — Moment-centric (Accepted).**
Several shots = one event; group by time/similarity/burst/location/subject before final pick. Owner: 03, 04.

**DEC-008 — Duplicates first (Accepted).**
Group near-duplicates, reason about the winner only, or heavy moments dominate. Owner: 03, 04.

**DEC-009 — Album quality over top-N (Accepted).**
Goal: best collection representing the experience, not N highest scores. Owner: 03.

**DEC-010 — Explicit diversity (Accepted).**
Dims: moment, similarity, people, scene, orientation, subject, time spread.
A weaker photo may win for coverage. Owner: 03.

**DEC-011 — ~1,000-photo target (Accepted).**
Realistic big trip/event; fits on-device. Evaluate perf here first. Owner: 08.

**DEC-012 — Usable to ~5,000 (Accepted).**
Via staging, thumbnails, batching, cache, early filter, lazy load. Avoid full-set O(N²); compare in clusters.
Owner: 08, 04.

**DEC-013 — Incremental + cancellable (Accepted).**
Backgrounding, cancel, memory, iCloud gaps are normal. Expose cancel-aware async APIs with progress. Owner: 04, 05.

**DEC-014 — Cache analysis (Accepted).**
Dims/timestamps/quality/Vision/prints/groups/thumbnails cached with asset identity + version for invalidation.
Owner: 04, 06.

**DEC-015 — Simple architecture (Accepted).**
App → Features / SelectionEngine / Services / Models / Infra. No extra protocols, packages-per-feature,
DI frameworks, buses, or plugin systems without a real problem. Owner: 05.

**DEC-016 — No test targets (Accepted).**
Speed over suite at this stage; no XCTest/UI-test infra. Quality via §DEC-017 instead — validation still required.
Owner: 10.

**DEC-017 — Manual QA for quality (Accepted).**
No single metric = good album. Datasets: trip, family, event, landscape/portrait-heavy, low-light,
burst-heavy, screenshots-mix, iCloud-heavy. Dims: dup suppression, coverage, faces, blur, diversity. Owner: 10.

**DEC-018 — Analytics carry no image/biometric content (Accepted).**
Only aggregates (counts, durations, add/remove tallies). Never images, crops, vectors, inferred names. Owner: 11, 09.

**DEC-019 — Keep reason metadata (Accepted).**
Store state + reasons (+ rival ID) per decision so QA/review/tuning can explain rejects. Owner: 03, 04, 06.

**DEC-020 — No MVP personalization (Accepted).**
Prove generic rules first; cold-start learning is costly. MVP uses quality/dups/moments/faces/composition/diversity.
Owner: 01, 03.

**DEC-021 — Keep feedback shape (Accepted).**
Model remove/restore/favorite/swap-winner now; learn later. Cheap option value. Owner: 06.

**DEC-022 — Tolerate interruption (Accepted).**
Background/kill/memory/PhotoKit errors must not corrupt state. Checkpoint where cheap; else restart stage. Owner: 04, 05.

**DEC-023 — Explicit iCloud handling (Accepted).**
States: local / needs-download / pending / unavailable / failed. One bad asset never fails a session; UI says so.
Owner: 07, 02.

**DEC-024 — No cloud-AI core (Accepted).**
No OpenAI/vision-API uploads for selection (cost, latency, privacy, lock-in). Local analysis + rules suffice for MVP.
Owner: 01, 07.

**DEC-025 — Rules around models (Accepted).**
Vision/ML = signals → normalize → score → group → rules → decision. Predictable, tunable, debuggable. Owner: 03, 04.

**DEC-026 — Never auto-delete (Accepted).**
Reject = "not in this album", not "safe to delete". Any future cleanup needs its own flow + confirm + review.
Owner: 01, 02.

**DEC-027 — Ship speed over purity (Accepted).**
Given equal quality, pick less code, fewer deps, easier debug. Resist clean-architecture rewrites without proof.
Owner: 05.

---

## 3. Deferred TBDs (structured — no answers invented)

**DEC-TBD-001 — Min iOS version (Deferred).**
Owner: 07. Affected: 05, 08. Decide from needed Vision/SwiftUI/PhotoKit APIs + store distribution.
Risk: too low = API gaps; too high = lost users. Trigger: first device-matrix pass.

**DEC-TBD-002 — Storage tech (Deferred).**
Owner: 05, 06. Options: Codable files / SwiftData / Core Data / tiny DB.
Rule: simplest that fits volume + lifecycle (see OPEN-N data questions). Risk: over-build. Trigger: persistence need.

**DEC-TBD-003 — Analytics provider (Deferred).**
Owner: 11. Options: none → Apple metrics → light custom → third-party. Must satisfy 09 + DEC-018.
Risk: privacy breach. Trigger: first metrics need.

**DEC-TBD-004 — Monetization (Deferred).**
Owner: 01. Options: paid / unlock / sub / freemium / free-cap. Must not warp MVP arch.
Risk: paywall rework. Trigger: pre-launch.

**DEC-TBD-005 — Export behavior (Deferred).**
Owner: 02, 07. Options: Photos album / internal collection / file export / several.
Driven by MVP UX (see OPEN-UX05). Risk: permission surprise. Trigger: save-flow build.

**DEC-TBD-006 — Advanced ML (Deferred).**
Owner: 03, 04, 07. Options: custom quality/aesthetic model, embeddings, expression analysis.
Only after Apple-baseline is QA-measured. Risk: size/battery/regression. Trigger: baseline gaps in 10.

**DEC-TBD-007 — Personalization (Deferred).**
Owner: 03, 06. Options: weight tweaks → implicit/explicit → on-device learning. From observed behavior, not speculation.
Risk: complexity without gain. Trigger: repeat-user data (see OPEN-P10).

---

## 4. Open product questions (from 01 §57 — recorded, not answered)

Owner: 01 (+ listed co-owner). Risk + trigger per item. None blocks core pipeline unless noted.

**OPEN-P01 — Input scope (Deferred).** Photos vs date range vs both? Owner 01, 02.
Risk: scope creep into picker. Trigger: input-screen prototype.

**OPEN-P02 — Size select (Deferred).** Exact number vs S/M/L? Owner 01, 02.
Risk: choice overload vs weak control. Trigger: same prototype. Values → 03 if presets map to numbers.

**OPEN-P03 — Auto-suggest size (Deferred).** Suggest from source count? Owner 01, 03.
Risk: wrong guess annoys. Trigger: sizing QA. Value (ratio/clamps) → 03.

**OPEN-P04 — Alternatives in review (Deferred).** How much browsing/swap? Owner 02.
Risk: cluttered review. Trigger: review prototype (see OPEN-UX04).

**OPEN-P05 — Mandatory mark (Deferred).** Pin photo pre-curation? Owner 02, 03.
Risk: hard constraints distort diversity. Trigger: review testing. Rule → 03.

**OPEN-P06 — Screenshots (Deferred).** Exclude vs deprioritize? Owner 03.
Risk: junk keepers or lost context. Trigger: QA on mixed libraries. Rule → 03.

**OPEN-P07 — Live Photos (Deferred).** Still vs loop vs badge? Owner 02, 07.
Risk: API/perf cost. Trigger: asset-type pass in 07.

**OPEN-P08 — Edited versions (Deferred).** Prefer edits? Owner 03.
Risk: double-keeping twins. Trigger: QA on edited sets. Rule → 03.

**OPEN-P09 — Favorites (Deferred).** Boost Apple-Photos favorites? Owner 03.
Risk: bias vs delight. Trigger: QA. Weight → 03 (see OPEN-N06).

**OPEN-P10 — Feedback persistence (Deferred).** Per-session vs cross-session? Owner 06, 03.
Risk: storage/privacy weight. Trigger: repeat-use data. Shape → 06.

---

## 5. Open UX groups (detail owned by 02 — state only)

**OPEN-UX01 — Input & size (Deferred).** Wording for picker, range UI, S/M/L labels, suggestion line.
Owner 02 (values 03). Risk: confusion at entry. Trigger: input prototype.

**OPEN-UX02 — Progress & cancel (Deferred).** Stage names, % vs counts, cancel/pause, background note.
Owner 02, 08. Risk: frozen-feel during long runs. Trigger: 1,000-photo run.

**OPEN-UX03 — iCloud & errors (Deferred).** Waiting/offline/denied/limited/retry copy, granularity without noise.
Owner 02, 07. Risk: support load. Trigger: iCloud + permission tests.

**OPEN-UX04 — Review & alternatives (Deferred).** Grid size, compare, swap-winner, select/remove, bulk undo.
Owner 02. Risk: correction cost (01 §40.6). Trigger: review prototype.

**OPEN-UX05 — Save & history (Deferred).** Destination choice, confirm copy, failure copy, history scope.
Owner 02, 07. Risk: duplicate albums / lost trust. Trigger: save-flow build.

---

## 6. Open numerics (values owned elsewhere — tune via 10)

Each: owner doc holds the number; this log holds status + risk + trigger. Do not hardcode values here.

**OPEN-N01 — Quality cutoffs (Deferred).** Owner 03 (mech 04, QA 10).
Risk: too strict drops keepers; too loose keeps junk. Trigger: tier QA.

**OPEN-N02 — Similarity cutoffs (Deferred).** Owner 03 (04, 10).
Risk: leakage vs over-merge. Trigger: dup QA ≥85% best-shot agreement (01 §43).

**OPEN-N03 — Moment windows (Deferred).** ~45s strong / ~180s extended + dense-event edges. Owner 03 (04, 10).
Risk: split events or merged days. Trigger: temporal QA.

**OPEN-N04 — Moment-size bounds (Deferred).** Ordinary 1 / rich 2–3 / high-count caps. Owner 03 (04, 10).
Risk: heavy-day dominance. Trigger: balance QA.

**OPEN-N05 — Album clamps (Deferred).** Min 30–40, max 120–150, ratio ~10%. Owner 03 (04, 10).
Risk: tiny inputs padded, huge inputs starved. Trigger: small/large library QA.

**OPEN-N06 — Weights/bonuses (Deferred).** Diversity/coverage/repetition/favorite/edit. Owner 03 (04, 10).
Symbolic here; numbers only in config. Risk: quota-like bias. Trigger: diversity QA.

**OPEN-N07 — Batch/concurrency (Deferred).** Batch 16–64, Vision caps, pixel class ~512px, heat steps.
Owner 08 (04, 05). Risk: heat/throttle or slow runs. Trigger: oldest-device profiling.

**OPEN-N08 — Vision edge reliability (Deferred).** Eyes low-light, motion-blur intent, small faces, sign-vs-scene.
Policy: keep-when-unsure; no penalty on low confidence. Owner 03 (07, 10).
Risk: false rejects. Trigger: targeted QA sets.

Plus storage-shape unknowns (owner 06): moment/cluster durability, fingerprint fields, debug rows, resume stub.
Mechanics unknowns (owner 04): dup window vs cost, gap edges, full-res verify need, tie-break keys.

---

## 7. Non-decisions (stay flexible — not DECs)

Weights, folder names, type renames, button/spacing/color choices are tuning/implementation, not log entries.
They live in 03/04/05/02 respectively.

## 8. When to add a DEC

Add one when the answer is yes to any: changes what the app does? privacy expectations? destructive?
core selection philosophy? major dep/backend? local↔cloud? persistence arch? new layer? hard to reverse?
pipeline/moment/optimization change? new ML dep? full-res at scale? image data leaves device?
Otherwise it belongs in the owner doc, not here.

## 9. Entry template

```markdown
# DEC-xxx — Title
Status: Proposed|Accepted|Rejected|Superseded|Deferred|Revisit · Date: YYYY-MM-DD
Owner: `0x-....md` · Affected: [...]
Decision: ...
Rationale: ...
Risk: ... · Reconsider when: ...
```

## 10. Principles (priority order)

Protect photos → privacy → useful album → understandable → real-iPhone perf →
simple → few deps → ship speed → cheap extensibility → no speculative infra.

## 11. Philosophy (one screen)

Native iOS + SwiftUI + PhotoKit + Vision + on-device + batch/cache + moment/similarity +
explicit rules + manual QA + minimal infra. Avoid: cloud core, backends, heavy architecture,
early personalization, big dep graphs, test targets, deletion, opaque top-N.
