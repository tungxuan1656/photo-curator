# Manual QA and Selection Evaluation (QA method owner)

**Doc:** `manual-qa.md` (native filename kept)
**Status:** MVP specification
**Role:** Single owner of QA method: dual app + selection QA, datasets, labels, metrics, procedures, checklists, severity, templates, release blockers, cadence. Manual QA is primary; analytics is secondary.

**Ownership:**
This doc owns QA method only. It does not own selection policy, stored shapes, iCloud mechanics, perf targets, privacy rules, or analytics events. It links to those docs and does not copy them.

Related docs:

- `selection-rules.md` — what counts as good selection (duplicate, moment, quality, diversity rules)
- `data-model.md` — stored shapes and decision record fields
- `apple-frameworks.md` — PhotoKit, Vision, iCloud mechanics
- `performance.md` — perf targets and budgets; 10 owns procedure and evidence only
- `privacy.md` — privacy policy and logging redaction
- `analytics.md` — event names and aggregates

MUST invariants (only use of MUST in this doc):

- The app MUST never delete or modify an original photo through the normal curation flow.
- The repo MUST NOT add test targets, `*Test*.swift` files, or test-only architecture per repo policy.

---

## 1. What QA covers

Two test areas. Both are manual on a real iPhone. No automated test suite for MVP.

| Area | Question | Where rules live |
|---|---|---|
| App QA | Does the app work without crashes, freezes, or data harm? | This doc (procedure); 07 for API shape, 08 for targets, 09 for privacy |
| Selection QA | Does the final album keep what matters and drop the rest? | This doc (procedure); 03 for selection policy |

Quality order (highest first):

```text
1. Originals stay safe.
2. Important photos stay in the album.
3. No obviously bad picks.
4. Duplicates reduced, best shot kept.
5. Moments and subjects stay varied.
6. Processing finishes reliably and fast enough.
7. UI polish.
```

When unsure, prefer keeping one extra photo over dropping an important one. A slightly large album is fine. A lost memory is not.

---

## 2. Datasets (read first)

Keep these sets stable so runs can be compared over time. Do not retune the sets to fit the algorithm.

| ID | Name | Size | Contents | Used for |
|---|---|---|---|---|
| A | Basic Mixed | 50–100 | People, landscapes, buildings, food, indoor/outdoor, mixed orientation, a few duplicates, a few bad frames | Smoke test, daily check |
| B | Duplicate Stress | 50–150 | Same scene repeated: 10x building, 15x selfie, crops, small shifts, exposure and expression changes, frames seconds apart | Clustering, best-shot, leakage |
| C | Moment Sequence | 100–300 | Chained moments, e.g. airport > hotel > walk > lunch > museum > sunset > dinner > night street, several candidates each | Moment coverage |
| D | People and Groups | 100–200 | Singles, couples, small/large groups, closed eyes, blur, expressions, partial and back-facing faces, group retakes | Face and group handling |
| E | Landscape and Context | 100–200 | Landscapes, streets, signs, food, rooms, transport, wide shots, no faces | Checks face-heavy bias |
| F | Bad Photo Stress | small | Heavy blur, pocket shots, blocked lens, near-black, severe under/over exposure, bad framing | Quality rejection |
| G | Real Trip | 500–1,500 | Full real trip: duplicates, bursts, people, landscapes, food, transport, night, mistakes, emotional moments | Main question: would I use this album? |
| H | Large Library Stress | 1,000 / 3,000 / 5,000 | Large input | Stability, memory, cancel, progress, thermal; quality scoring optional here |
| Golden | Annotated reference | 200–500 | Fixed set with MUST_KEEP / ACCEPTABLE / REJECT labels plus moment, cluster, and best-shot notes (§3) | Regression reference for algorithm changes |

Notes:

- A is the default smoke set. G is the most important qualitative check.
- H checks system behavior, not taste. Do not hand-score all 5,000 photos.
- Test on a physical iPhone first. The simulator is for UI work only, not for pipeline proof. Cover the daily device plus an older device when available for memory and heat checks.
- Selection policy terms (moment, cluster, representative, keeper) follow 03. Stored field names follow 06.

---

## 3. Ground-truth labels and annotation

### 3.1 Labels

| Label | Meaning | Examples |
|---|---|---|
| MUST_KEEP | A good album almost always keeps this | Best group shot, unique key event, only photo of a place, strong portrait or landscape, emotional moment |
| ACCEPTABLE | Fine to keep or skip based on size and variety | Second portrait, extra landscape, second-best version of a moment |
| REJECT | A good album normally drops this | Severe blur, accident, clearly worse duplicate, bad expression with better option present, unusable frame |

Optional tags per photo: moment ID, duplicate cluster ID, best-in-cluster flag, group / landscape / portrait / context flag, known defect note.

### 3.2 Annotation order

Annotate before running the app, to avoid bias:

```text
1. Review source set without seeing app output.
2. Mark natural moments.
3. Mark duplicate groups and the best frame in each.
4. Label each photo MUST_KEEP / ACCEPTABLE / REJECT.
5. Run the app.
6. Compare output against labels.
```

---

## 4. Metrics (read second)

Use all metrics together. No single number proves quality.

| Metric | Formula | Initial MVP target | Notes |
|---|---|---|---|
| Must-Keep Recall | selected MUST_KEEP / total MUST_KEEP | ≥ 95% | Most important. Missing the single best trip photo fails even at 98%. |
| Good Selection Rate | selected (MUST_KEEP + ACCEPTABLE) / total selected | ≥ 90% | Share of final album that is reasonable. |
| Bad Pick Rate | selected REJECT / total selected | ≤ 10% | Lower is better. A few weak picks are fine; a cluster of them is not. |
| Duplicate Leakage | needless repeat selections / total selected | ≤ 5% | Manual judgment: different expressions, people, or action can justify two similar frames. |
| Best-Shot Accuracy | clusters where expected best was picked / clusters judged | ≥ 80–85% | Key for groups, portraits, bursts. |
| Moment Coverage | important moments present / total important moments | ≥ 90% | Missing a whole trip part is a major fail even if per-photo scores look good. |
| Compression Ratio | final count / input count | track only, no target | Detects behavior breaks (e.g. 1,000 → 130 becomes 1,000 → 420). Not a quality score. |
| Human Edit Rate | manual changes / final album size | track only | Split into removals (added junk) vs add-backs (lost value). Add-backs are worse. |
| Subjective score 1–5 | reviewer judgment (§6.4) | 4+ on unseen trips | 5 ready, 4 useful, 3 saves time with mistakes, 2 much work left, 1 prefer manual. |

Targets are starting points, not hard pass/fail lines. Manual review decides. A 94% recall with a borderline miss can pass; a 98% recall that drops the key photo fails.

Diversity check (visual, not a number): scan the final album for excess focus on one person, place, day, scene, or orientation. A good trip mix covers people, groups, landscapes, buildings, food, details, transport, day and night. The engine prevents one theme from taking over; it does not force quotas. Policy detail: 03.

---

## 5. App QA procedures

Short checks. Full perf numbers live in 08; privacy rules live in 09; iCloud behavior lives in 07. This doc gives steps and pass signs only.

### 5.1 Functional smoke (Dataset A)

Run after changes to loading, pipeline, review, permissions, models, concurrency, or save.

```text
Launch > grant or pick access > choose photos > start > watch progress >
finish > review album > open previews > add/remove > save > return.
```

Pass signs: no crash or lasting freeze; progress moves; counts look right; images show correctly; user edits stick; save works; originals unchanged.

### 5.2 Permissions and loading

Permissions (policy: 09): check first launch wording, full access, limited access (only allowed photos used, no false "missing" errors), denied (clear reason + recovery path, no run starts), and Settings changes (full/limited/denied switches recover on relaunch).

Loading: cover portrait, landscape, square, HEIC, JPEG, large files, edited assets, iCloud-backed assets, missing metadata, and failed assets. One bad asset skips safely; it does not abort the session.

iCloud: use a library with some assets off-device, on good and poor networks. Loading states stay clear, slow fetch never looks like a freeze, failed downloads are handled, cancel works, partial failure does not ruin the session. Mechanics: 07.

### 5.3 States, cancel, interrupt, review, save

States: idle, preparing, analyzing, clustering, selecting, completed, failed, cancelled. The UI never sticks in a working state after work ends.

Cancel at start, ~25%, ~50%, ~90%: app stays responsive, work stops, memory clears, no fake completed album, a new run can start, sources untouched.

Interrupt during a run: background, return, lock/unlock, open a heavy app. Continue, pause, resume, or clean restart are all fine if planned. Never fine: silent corruption, fake results, stuck loader, crash loop, dead workflow.

Review screen: correct count, smooth scroll, correct thumbs, full-screen preview, add/remove applies at once, state survives back-navigation, no duplicate rows from ID bugs, no memory blowup on large sets.

Save: create or add to a Photos album, keep originals intact, retry after failure, survive partial PhotoKit failure and backgrounding during save.

### 5.4 Perf, memory, privacy, errors, edges

Perf smoke (budgets: 08): try 100, 500, 1,000, and 5,000 inputs. Watch: run starts, progress moves, UI stays alive, heat stays sane, no crash, cancel works, result looks complete. Record exact times only when chasing a regression.

Memory: test large sets on device. Watch for OS kills, hangs, lost thumbs, long pauses, slowdown over time, repeat decoding. Use Instruments only when a real problem shows. No continuous profiling rig for MVP.

Privacy checklist (rules: [09](privacy.md)): run the privacy spot-check per 09 and record the result.

Error states: photo missing, iCloud failure, revoked permission, asset lost mid-run, low storage, cancel, background, analysis error, save failure. Each case: no state corruption, clear message when the user must act, retry where useful, other photos continue where possible.

Edge cases to cover over time: 1–5 photo inputs; 100 near-identical frames; zero duplicates (do not invent cuts); mostly bad photos (keep the best meaningful ones); mostly great photos (do not over-cut); no faces; all faces; mixed orientations; multi-day; wrong or missing timestamps; edited assets; iCloud-only assets; limited access; panoramas; screenshots if supported; dark night scenes; strong HDR.

Logging while testing: keep session start, input count, analyzed/skipped counts, cluster and moment counts, shortlist and final counts, stage timing, cancel, and load errors. Redaction rules: [09](privacy.md). Stored field reference: 06.

---

## 6. Selection QA procedures

### 6.1 Per-cluster and per-group checks

Duplicates (policy: 03): for each cluster ask: do these frames belong together (day vs night tower shots are not duplicates)? Is the picked frame sharper, better exposed, better framed, with open eyes and clear faces? Did needless copies leak in? Did grouping kill meaningful variants?

Groups: check face count, closed eyes, sharpness, expression, blocked faces, key people visible and looking at camera, framing, and whether two variants both deserve a slot. A slightly soft frame where everyone looks good often beats a sharp frame with closed eyes.

Landscapes: check that strong views, landmarks, sunsets, night streets, and context shots survive. An all-portrait trip album fails even with great portraits. Low-quality frames: ask quality and value separately. A weak frame of a unique moment can stay; quality ranks, moment need decides.

### 6.2 Album-level checks

Temporal scan: view the result in date order. A day with far fewer picks than its share (e.g. day 3 gets 2 of 137) needs a look. Causes can include cluster, threshold, timestamp, or balance bugs.

Review questions for each serious run:

```text
Kept the most important memories?
Anything obviously bad kept?
Obvious duplicates kept?
Best frame usually picked?
Groups handled well?
Landscapes and context kept?
All trip parts present?
One person or scene taking over?
Faster to review than the source set?
Acceptable with only small edits?
```

Blind check on a fresh set (catches overfit to Golden): take a new trip, do not pre-curate, run the app, log removals needed, missing key photos, duplicate fails, and moment fails.

Regression after scoring, threshold, clustering, diversity, face, or sizing changes: run A, B, Golden, and one real trip. Record recall, bad-pick rate, leakage, best-shot accuracy, moment coverage, final size, and notes. Never ship a change on one better number alone (e.g. leakage 5% → 1% with recall 96% → 82% is a fail). Log big calls in `decision-log.md`.

Side-by-side: build albums from old and new configs, diff which photos are only in each, which cluster pick changed, which moments were lost, how balance shifted. Numbers hide taste fails.

---

## 7. Severity, failure tags, release gates

### 7.1 Severity

| Level | Meaning | Examples | Release effect |
|---|---|---|---|
| P0 Critical | Data harm, privacy break, dead flow | Original lost or changed; privacy violated; steady crash; save corrupts; endless hang | Blocks release |
| P1 Major | Core flow broken | Common album cannot finish; permission flow dead; many key photos lost; bad clustering; review unusable; common iCloud assets fail | Normally blocks |
| P2 Moderate | Limited harm | Some weak picks, missed duplicate, rare edge fail, small perf drop, fixable UI state bug | Can ship if known and accepted |
| P3 Minor | Cosmetic or tiny taste gap | Spacing, wording, rare pick disagreement | Does not block |

### 7.2 Selection failure tags

Tag reports with one or more: `IMPORTANT_PHOTO_MISSED`, `BAD_PHOTO_SELECTED`, `DUPLICATE_LEAKAGE`, `WRONG_BEST_SHOT`, `OVER_CLUSTERING`, `UNDER_CLUSTERING`, `MOMENT_MISSING`, `PEOPLE_BIAS`, `LANDSCAPE_BIAS`, `DIVERSITY_FAILURE`, `GROUP_PHOTO_FAILURE`, `QUALITY_SCORING_FAILURE`, `ALBUM_TOO_LARGE`, `ALBUM_TOO_SMALL`, `UNKNOWN_SELECTION_FAILURE`.

### 7.3 Release validation and blockers

Before a milestone build, run: A smoke pass; Golden regression with no big surprise; one real trip that reads as useful; permission trio (full, limited, denied); 1,000-photo run without critical fail; cancel run; review add/remove; save run; privacy spot-check per 09.

Do not release with: lost or changed originals; steady crash or hang; unsavable album; cross-session photo mix-up; misleading permission behavior; privacy break; common 1,000-photo run fails; whole moments missing on tap; clearly worse picks than the last good build.

Temporary non-blockers: odd weak pick, stray duplicate, small rank dispute, small animation or layout flaw, rare metadata case, small size drift, tie between two good frames. Fix patterns first, not each taste edge.

---

## 8. Templates

### 8.1 Selection issue

```text
Dataset:
Build:
Input count / Final count:
Failure tag(s):
Expected:
Actual:
Photo IDs (format per [09](privacy.md)):
Moment / cluster:
Why human view differs:
Suspected part (quality / duplicate / face / moment / diversity / ranking / unknown):
Severity:
Screenshot or clip if useful:
```

File only recurring, severe, biased, or album-breaking issues. Skip one-off taste notes. Analytics signal definitions live in 11; manual QA stays primary.

### 8.2 Evaluation run

```text
# Selection Evaluation
Date: / Build: / Config: / Dataset:
Input: / Final: / Compression:
MUST_KEEP total / selected / recall:
Selected MUST_KEEP / ACCEPTABLE / REJECT:
Good rate: / Bad-pick rate:
Clusters judged / leakage / best-shot accuracy:
Key moments total / covered / coverage:
User removals / add-backs:
Top failures:
Notes:
Regression vs last build:
Decision: [ ] Better [ ] Neutral [ ] Worse
```

Keep major comparison notes; throwaway runs need no permanent record.

---

## 9. Cadence and done

Proportional QA by risk:

```text
Small UI-only change > run the touched flow.
Scoring change > A + Golden.
Duplicate or cluster change > B + Golden.
Big pipeline change > smoke + Golden + real trip + 1,000-photo check.
Before milestone > full release list in §7.3.
```

A selection feature is done when: it works on device; the new behavior shows; no critical regression; Golden shows no bad surprise; one real album reviewed; limits known; big calls noted in 13.

MVP is ready when: access, picking, progress, fail/cancel, review/edit, and save all work; 1,000-photo runs are steady; key photos rarely drop; bad frames mostly filtered; duplicates cut; groups, landscapes, and moments read well; originals safe; privacy holds; review effort drops clearly.

Not building for MVP: unit/UI/snapshot suites, auto image comparison, vision benchmarks, CI test gates, device farms, stats-significance rigs, annotation platforms, experiment trackers, QA backends, or a second test app target.

Core test: with hundreds or thousands of photos, does the album keep what matters and cut enough repetition and junk to save real time? Numbers guide; reviewed albums decide. Loop: build > run real photos > review misses > tag the failure > smallest fix > re-run stable sets > keep or revert.
