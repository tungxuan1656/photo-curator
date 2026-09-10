# Product (vision / scope / gates owner)

**Product:** Photos Curator
**Document:** `product.md` (native filename kept)
**Platform:** iPhone / iOS
**Status:** Draft for MVP

**Ownership:** This doc owns vision, scope, non-goals, product invariants,
and launch gates only: one-sentence definition, north star, target user,
core loop, MVP priority order, functional requirements list, and launch gates.

**Not owned here (link, do not duplicate):**

- User-visible flow, states, copy, review behavior → `ux-flows.md`
- Selection policy (what gets picked and why) → `selection-rules.md`
- Pipeline mechanics (stages, ordering, degradation) → `selection-engine.md`
- App structure, scheduling, concurrency → `ios-architecture.md`
- Stored shapes, session schema → `data-model.md`
- PhotoKit / Vision API mechanics, iCloud behavior → `apple-frameworks.md`
- Budgets, limits, timing targets → `performance.md`
- Privacy policy, retention, permission policy → `privacy.md`
- QA method, datasets, metrics, procedures → `manual-qa.md`
- Analytics events and aggregates → `analytics.md`
- Roadmap detail → `roadmap.md`
- Rationale, history, open decisions → `decision-log.md`

---

## 1. One-sentence definition

> Photos Curator is an on-device-first iPhone app that turns hundreds or
> thousands of personal photos into a smaller, diverse, high-quality album
> that the user can quickly review and approve.

---

## 2. North star

> How much manual photo-review work can Photos Curator remove without making
> users feel that important memories were lost?

Everything else is secondary. A faster app with worse picks is not progress.
A beautiful result that needs 50 fixes is worse than one that needs 10.

---

## 3. Target user

The primary user is an iPhone user who takes many photos during travel,
holidays, family events, celebrations, outings, or everyday life. They end
up with hundreds or thousands of photos and do not want to inspect each one.

They:

- take many photos, often several versions of the same scene;
- value memories over photographic perfection;
- want the app to make useful automatic choices;
- want control before the final result is saved.

They do not need to know photography terms.

Secondary users (not the MVP design target): enthusiast photographers who
want a shortlist, parents with many family photos, content creators who need
a quick candidate set.

---

## 4. Core loop

The whole MVP is this loop:

```text
SOURCE PHOTOS
      ↓
ANALYZE
      ↓
GROUP INTO MOMENTS / SIMILAR SETS
      ↓
RANK CANDIDATES
      ↓
BUILD DIVERSE ALBUM
      ↓
USER REVIEW + CORRECTIONS
      ↓
SAVE CURATED ALBUM
```

Conceptual screens (detail in 02):

```text
Home → Choose Photos → Configure Curation → Processing
  → Curated Result → Review / Alternatives → Save Album → Completed
```

The user should spend most time on the shortlist, not the source set.
Goal (illustrative only; sizing policy in 03): 1,000 source photos → review
roughly 50–150 picks plus a few alternatives, instead of reviewing all 1,000.

Example (illustrative): 1,024 trip photos → 80-photo proposal → user removes 4, replaces 6,
restores 2 → saves "Japan Trip — Curated" (78 photos). The other ~946
source photos stay untouched.

---

## 5. MVP scope

The MVP answers one question well:

> Can Photos Curator reliably turn a large photo set into a much smaller,
> useful album?

In scope:

- Pick source photos from the iOS Photos library (normal session: up to
  about 1,000 photos).
- Choose a target output size (exact number or Small / Medium / Large;
  interaction detail in 02, sizing policy in 03).
- Analyze, group similar photos, rank candidates, build a diverse album
  (policy in 03, mechanics in 04).
- Show a proposed album for review; let the user remove picks and choose
  alternatives from the same moment (flow in 02).
- Save the approved result as a regular album in the Photos library.
- Show processing state and handle failures without harming source photos.

Out of scope for product detail here (linked): UX copy and states (02),
selection thresholds and tie-breaks (03), pipeline order (04), perf numbers
(08), privacy controls (09), QA procedure (10), analytics events (11).

---

## 6. Product invariants (MUST only)

Requirement keywords appear only in this section. Everywhere else in this doc uses plain
language. Details live in the linked docs.

1. The app MUST never delete or modify an original photo through the normal
   curation flow. Rejecting a photo means "not in this album", never
   "delete this photo".
2. The app MUST keep core curation on-device-first for the MVP. It MUST NOT
   upload photo pixels to Photos Curator servers for normal curation.
   Privacy controls: `privacy.md`.
3. The MVP MUST NOT require a Photos Curator account, login, or custom
   backend for the core Select → Analyze → Review → Save flow.
4. The user MUST approve the final album. The engine proposes; the user
   decides. A manual add / remove / replacement must not be silently
   overwritten later in the same session (enforced in 02).
5. The app MUST NOT present an empty result as a normal success, and MUST
   NOT report a partial save as full success (enforced in 02).

---

## 7. Non-goals for MVP

Not in the MVP unless promoted through `decision-log.md`:

- Automatic photo deletion or cleanup workflows.
- Full Photos app replacement; professional RAW workflows (Lightroom,
  Capture One style culling).
- Photo editing (exposure, crop, filters, retouch, color, object removal,
  generative edits) and AI-generated images.
- Video curation (still photos first; Live Photos policy in 03).
- Social features (profiles, followers, comments, likes, feeds).
- Cloud photo storage; Android / macOS / Windows / web versions.
- Per-user trained models and complex personalization.
- Manual AI parameter controls in the UI (similarity / blur / face
  thresholds, diversity weights). Those are internal engine config (03, 04).
- Automated test targets or test files (repo policy; validation is manual
  per 10).

---

## 8. Functional requirements

Details behind each row live in the linked doc. This table lists what the
MVP must do, not how.

| ID | Requirement | Priority | Detail in |
|----|-------------|----------|-----------|
| FR-01 | Access user-selected Photos library content | Must | 07, 09 |
| FR-02 | Create a curation session from a large photo set | Must | 02, 06 |
| FR-03 | Support about 1,000 photos in a normal session (goal; numbers in 08) | Must | 08 |
| FR-04 | Assess individual photo quality | Must | 03 |
| FR-05 | Detect duplicate and near-duplicate photos | Must | 03 |
| FR-06 | Group photos into moments or clusters | Must | 03 |
| FR-07 | Pick stronger representatives within similar groups | Must | 03 |
| FR-08 | Consider face and people-related signals | Must | 03, 09 |
| FR-09 | Preserve landscape and context photos | Must | 03 |
| FR-10 | Produce a diverse album (not just top-N scores) | Must | 03 |
| FR-11 | Let the user influence output size | Must | 02, 03 |
| FR-12 | Present the proposed album for review | Must | 02 |
| FR-13 | Let users remove selected photos | Must | 02 |
| FR-14 | Let users inspect or choose alternatives | Must | 02 |
| FR-15 | Preserve all original photos | Must | 09 |
| FR-16 | Save the final selection to a Photos album | Must | 02, 07 |
| FR-17 | Show processing progress and state | Must | 02, 08 |
| FR-18 | Handle missing / iCloud assets safely | Must | 02, 07 |
| FR-19 | Handle interruptions without harming source data | Must | 08 |
| FR-20 | Run core analysis on-device where practical | Must | 09 |
| FR-21 | Work without a Photos Curator account | Must | 09 |
| FR-22 | Work without a custom backend for core flow | Must | 09 |
| FR-23 | Keep enough selection info to support manual quality review | Should | 06, 10 |
| FR-24 | Keep suitable local feedback for future engine improvement | Should | 11 |

---

## 9. MVP priority order

When resources are limited, build in this order:

1. Reliable access to a large Photos collection
2. Duplicate / near-duplicate grouping
3. Basic photo quality assessment
4. Moment grouping
5. Candidate ranking
6. Album-level diversity selection
7. Result review
8. Alternative selection
9. Save curated album
10. Selection-quality refinement

Polish and personalization come only after the full loop works.

Trade-off order when requirements conflict: (1) protect user data,
(2) selection quality, (3) less user effort, (4) reliability,
(5) speed, (6) advanced features. Speed never beats much better picks.

---

## 10. Launch gates

All gates pass before the MVP counts as usable. Measurement method
and metric targets live in 10; timing budgets live in 08.

- **Gate 1 — Large session completes.** A representative ~1,000-photo
  session finishes on supported devices.
- **Gate 2 — Safe photo handling.** No normal workflow modifies or deletes
  original photos.
- **Gate 3 — Meaningful reduction.** A 1,000-photo set becomes a
  user-requested shortlist (illustrative range about 50–150 photos; policy in 03).
- **Gate 4 — Duplicate suppression.** Obvious near-duplicate groups do not
  dominate the final album.
- **Gate 5 — Reviewable result.** Users can understand and fix the proposal
  without re-reviewing the whole source set.
- **Gate 6 — Recoverable failure.** Permission problems, missing assets,
  and interrupted processing do not corrupt the session or library.

Product-level expectations (goals only; numbers in linked docs):

- Review feels much easier than manual review of the full set (proxy: at
  least ~80% fewer photos needing close review in common cases).
- Processing is reliable, stays responsive, gives progress feedback, and
  survives interruption (budgets: `performance.md`).
- Privacy posture holds: no account, no normal upload, no deletion, clear
  permission messaging (controls: `privacy.md`).
- Selection quality judged per `manual-qa.md`;
  usage signals (completion, save, acceptance, replacement, repeat use)
  defined in `analytics.md`.

The MVP fails if users still inspect nearly every source photo, duplicates
fill the album, key moments vanish, weak versions win obvious comparisons,
most picks get replaced, large sessions crash, users fear deletion, or
setup costs more effort than manual review.

Definition of done: a real user can open the app → pick a large set →
choose album size → curate → review → fix picks → save, without developer
help, with good quality, duplicate control, moment coverage, diversity,
safe originals, and clearly less manual work.

---

## 11. Open product questions

The 10 open product questions from former §57 (source selection shape,
album-size input, auto-suggested size, alternative browsing depth, mandatory
picks, screenshots, Live Photos, edited versions, Favorites influence,
cross-session feedback) are not resolved here. They are tracked and decided
in `decision-log.md`. Do not add new product decisions to this doc;
propose them in 13.

---

## 12. Links and Uncertain

Canonical links:

- Flow, states, copy → `ux-flows.md`
- Selection rules → `selection-rules.md`
- Engine design → `selection-engine.md`
- Budgets → `performance.md`
- Privacy → `privacy.md`
- QA method and metric targets → `manual-qa.md`
- Analytics events → `analytics.md`
- Roadmap → `roadmap.md`
- Decisions and rationale → `decision-log.md`

Uncertain (owned elsewhere, not decided here):

- Exact album-size presets and input widget (02, decided via 13).
- Screenshot / Live Photo / Favorites handling thresholds (03, via 13).
- Completion-time budgets on oldest supported device (08).
- Retention windows for derived analysis data (09).
- QA metric pass lines for release (10).
