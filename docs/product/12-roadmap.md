# 12 — Roadmap (phases owner)

**Responsibility:** This file owns build order only: phases P0–P8, exit gates, MVP boundary, and deferred work.

**Not owned here:** product goals ([01](01-product.md)), selection policy ([03](03-photo-selection-rules.md)), pipeline design ([04](04-selection-engine-design.md)), perf budgets ([08](08-performance-spec.md)), QA method ([10](10-manual-qa-and-selection-evaluation.md)), metrics ([11](11-analytics-and-metrics.md)). Where those topics appear below, this file states the phase; the linked file states the rule.

Related docs:

- `01-product.md` — what the product must do and MVP scope
- `03-photo-selection-rules.md` — what counts as a good pick
- `04-selection-engine-design.md` — pipeline order
- `08-performance-spec.md` — perf targets and budgets
- `10-manual-qa-and-selection-evaluation.md` — QA steps
- `11-analytics-and-metrics.md` — event names

Execution work does not live here. Tracked work lives in `features/feature_index.json` and `docs/plans/feat-<id>.md` per `AGENTS.md`.

---

## 1. Build order (read first)

Build a small complete pipeline first, then make it good.

```text
P0 foundation → P1 analysis → P2 engine → P3 MVP
  → P4 quality → P5 reliability → P6 beta
  → P7 personalization → P8 future
```

Rules:

- Selection quality comes before polish. A pretty app with bad picks is a failure.
- Prefer simple clear rules before smart AI. See [03](03-photo-selection-rules.md).
- Stay on-device. No backend until a real need forces it.
- Keep engine settings in one place so weights and thresholds are easy to change.

---

## 2. Phases

| Phase | Goal | Core question | Done when |
|---|---|---|---|
| P0 — Foundation | Runnable app shell, permission flow, basic screens | Can we build on it? | App runs on a real iPhone; photo permission works; photo model exists |
| P1 — Analysis prototype | Read real photos with PhotoKit + Vision | Can we read 1,000 photos? | 100–2,000 real assets analyzed without memory failure; each asset has signals for [03](03-photo-selection-rules.md) |
| P2 — Engine prototype | First full pipeline: exclude → moments → duplicates → score → shortlist → album | Can we curate? | 1,000 photos → sensible album with no help; clearly better than random or every-Nth-photo |
| P3 — Functional MVP | Normal user completes Select → Analyze → Review → Save | Can a normal user use it? | New user completes full flow alone: pick, process, review, fix mistakes, save. Scope: [01](01-product.md) |
| P4 — Quality hardening | Fix worst real failure modes | Is the result actually good? | Most albums need small fixes, not rebuilds. Method: [10](10-manual-qa-and-selection-evaluation.md) |
| P5 — Reliability | Handle large libraries, interruptions, memory | Can it handle real libraries? | Targets in [08](08-performance-spec.md) pass; no crashes, lost state, or stuck progress |
| P6 — Beta | Real users outside the team | Do users trust it? | Curation completes; corrections are small; saved albums confirmed by [11](11-analytics-and-metrics.md) |
| P7 — Personalization | Learn per-user taste from corrections | Can it learn this user? | Repeat corrections fall over sessions; bad photos never beat sharp ones on taste alone |
| P8 — Future intelligence | Story-aware albums, language controls | Can it curate stories? | Only after P0–P6 pass. No gate defined yet |

Do not skip phases. If P2 output still looks random, stay in P2. Do not cover it with UI polish.

---

## 3. Decision gates

Stop and check before doing more work.

| Gate | After | Question | If no, do this first |
|---|---|---|---|
| G1 — On-device works | P1 | Can the phone handle the load? | Tune image size, batching, Vision load per [08](08-performance-spec.md). Do not add a backend |
| G2 — Albums useful | P2 | Is output better than random? | Fix moments, duplicates, scoring, diversity per [03](03-photo-selection-rules.md). Do not polish UI |
| G3 — Corrections small | P6 | Do users rebuild every album? | Study removed vs restored photos; fix scoring, duplicates, or moments before adding AI |
| G4 — Taste needed | P6 | Do users show steady personal taste? | Only then add P7. Generic engine must be good first |
| G5 — Backend needed | Any | Does a need force a server? | Needs: sync, accounts, sharing, server-only feature. "Maybe later" is not enough |

---

## 4. MVP boundary

MVP contains only this. Anything else needs a written reason.

```text
Photo permission + input pick + on-device analysis
  + moments + duplicate handling + quality ranking
  + diverse album + progress + review (remove / restore)
  + save + basic failure recovery
```

MVP success: a user gives a large messy set and keeps the small album with only small fixes. If that fails, keep fixing the engine. Do not add scope.

Post-MVP, ask three questions before adding a feature:

1. Does it make picks better?
2. Does it save the user real effort?
3. Does real use show users need it?

If none is yes, keep it deferred.

---

## 5. Deferred and non-goals

Not in MVP. Detailed execution, if ever approved, moves to `features/feature_index.json` + `docs/plans/feat-<id>.md`.

| Item | Status |
|---|---|
| Backend server, user accounts, cloud sync | Deferred |
| Shared or joint albums | Deferred |
| macOS / web app | Deferred |
| Custom model training, server image work, search | Deferred |
| Subscriptions, paywall | Deferred until money plan is set |
| Social feed, photo editor, auto-delete of rejects, full library manager | Out of scope |
| Android app | Out of scope |
| Test targets, `*Test*.swift`, test-only code | Not allowed per repo policy; QA is manual per [10](10-manual-qa-and-selection-evaluation.md) |

Do not build deferred items to "save time later." Timing matters more than the idea.

---

## 6. Where execution lives

This doc stays thin and stable. It never holds task lists, file changes, or dates.

- Current and planned work: `features/feature_index.json`
- Bounded work (1–3 files, <200 lines): plan inside `features/feat-<id>.md`
- Large work (4+ files, migration, phases, rollback): `docs/plans/feat-<id>.md`, linked from the feature file
