# Photo Selection Rules (selection policy owner)

**Responsibility:** This file owns what the curator selects and why: moment/duplicate definitions, selection priority, quality tiers, face/group/scene rules, diversity model, album sizing, score policy, tie-breaks, reason codes, user-intent override.

**Not owned here:** product goals ([01](product.md)), UX and review copy ([02](ux-flows.md)), pipeline and orchestration ([04](../design-docs/selection-engine.md)), app architecture ([05](../design-docs/ios-architecture.md)), stored representation ([06](../design-docs/data-model.md)), PhotoKit/Vision APIs ([07](../design-docs/apple-frameworks.md)), performance budgets ([08](../ship-gates/performance.md)), privacy ([09](../ship-gates/privacy.md)), QA procedure ([10](../ship-gates/manual-qa.md)), metrics ([11](../ship-gates/analytics.md)). Where those topics appear below, this file states the rule; the linked file states the mechanism.

## 1. Decision hierarchy (read first)

Apply rules in this order. Higher rules override lower rules.

| Priority | Rule family | Section |
|---|---|---|
| 1 | Explicit user include/exclude in current session | §14 |
| 2 | Asset eligibility | §4 |
| 3 | Hard technical rejection (quality floor) | §5 |
| 4 | Exact-duplicate suppression | §6 |
| 5 | Near-duplicate and burst suppression | §7 |
| 6 | Moment representation | §8 |
| 7 | Technical and face quality | §9–§10 |
| 8 | Scene rules (landscape, landmark, food, document) | §11 |
| 9 | Meaningful variation | §12 |
| 10 | Diversity and chronological coverage | §13 |
| 11 | Album sizing toward targetCount | §14 |
| 12 | Stable tie-break | §15 |

A lower rule must not rescue an asset rejected by a higher rule with high confidence. Example: diversity never rescues a severely blurred duplicate.

Guiding tradeoff: quality gates diversity (§5); diversity beats marginal quality gaps once the floor passes (§13).

## 2. Domain definitions (canonical)

These meanings are owned here. Do not redefine them elsewhere.

| Term | Meaning |
|---|---|
| Asset | One photo from the user-selected input collection. |
| Candidate | Asset still eligible for final selection. |
| Rejected asset | Asset removed from consideration with a reason code (§16). |
| Exact-duplicate set | Assets representing effectively the same image (re-import, copy, original + identical export). |
| Near-duplicate cluster | Distinct files with almost identical visual content (retakes, micro-framing shifts, burst runs). |
| Moment | One real-world photographic event (group shot at a temple, one sunset sequence, one meal). A moment may hold several near-duplicate clusters. |
| Representative | Preferred photo speaking for a duplicate set, cluster, or moment. |
| Keeper | Representative surviving toward the final album. |
| Final album | Ranked keepers presented for review, sized per §14. |

Moment grouping combines time, visual similarity, people, scene, composition, and location when present. Time alone never defines a moment. Missing signals must not penalize quality; group with what exists.

## 3. Product rule in one paragraph

Behave like a careful human curator after a trip: remove duplicates and failed frames, keep the best frame per moment, preserve people/places/activities, suppress repetition, keep chronological story and varied compositions. Prefer coverage of the whole trip over stacking technically perfect near-identical frames. Full goal: [01](product.md).

## 4. Asset eligibility

| Class | Rule |
|---|---|
| Eligible | Accept standard photos, Live Photo stills, portraits, panoramas, edited photos, analyzable RAW derivatives. |
| Excluded by default | Exclude videos, screen recordings, non-photographic system images, undecodable assets. Record a reason code so UI can explain. |
| Deprioritized (not excluded) | Deprioritize screenshots for the curated album; never force-exclude uncertain cases (see [decision-log OPEN-P06](../design-docs/decision-log.md); scene detail in §11). |
| Hidden assets | Exclude hidden assets unless the selected source explicitly includes them. |
| Favorites | Treat favorite as soft bonus only. It never forces selection of a duplicate or unusable frame. |

Storage of eligibility flags: [06](../design-docs/data-model.md). Source access mechanics: [07](../design-docs/apple-frameworks.md). Review-surface behavior: [02](ux-flows.md).

## 5. Hard rejection (quality floor)

Reject conservatively and only on strong evidence of no curation value. Rejected assets skip diversity logic entirely.

| Reject when | Do not reject when |
|---|---|
| Blur destroys the intended subject. | Softness is mild or plausibly intentional motion. |
| Exposure failure yields black/clipped-unusable frame. | Ordinary contrast clips some highlights or shadows. |
| High-confidence accidental frame (pocket, floor, blocked lens, transitional frame). | Content is uncertain; keep uncertain cases. |
| Asset cannot decode; mark unavailable with reason code. | Asset decodes but lacks GPS/faces; missing metadata never lowers quality. |

Uncertain: reliable separation of intentional motion blur from accidental shake; conservative policy is keep-when-unsure.

## 6. Exact duplicates

| Rule |
|---|
| Keep exactly one representative per exact-duplicate set. |
| Prefer the copy with most useful photographic information: valid full resolution, then intentional user edit, then higher usable resolution, then stable identifier order. |
| Never place original and identical edited derivative together. |
| Rejected copies get reason `exactDuplicate`; survivor may get `duplicateRepresentative`. |

## 7. Near duplicates and bursts

Default: keep one best representative per cluster.

Keep a second only on meaningful difference: different expression, formal versus candid interaction, different subject state (stand versus jump), wide versus close composition, people-emphasis versus landmark-emphasis. Maximum 2 per cluster; more than 2 means the cluster was misgrouped.

Treat these as still-duplicates: head rotation of degrees, tiny crop/shift, a frame seconds later with no visible change.

Bursts: find the strongest frame, not preserve the burst. Ordinary burst keeps 1. Action burst (jump, sport, dance, animal motion) may keep 2 when frames show clearly different phases. Similar scores alone never justify keeping both.

## 8. Moments

### 8.1 Grouping guidance

| Time gap | Interpretation |
|---|---|
| 0–15 s | Very strong same-moment evidence |
| 15–45 s | Strong same-moment evidence |
| 45–180 s | Same moment only with visual/context similarity |
| >180 s | Presume a new moment |

Time windows are tunable defaults (see §17), not invariants. Confirm with shared people, scene, and composition. These ~45 s / ~180 s same-moment-evidence windows are a different concept from the engine's ~3 min / ~15 min segmentation gaps (mechanic in [04](../design-docs/selection-engine.md) §7); both numbers are kept, each defined once in its owner section.

### 8.2 Representatives per moment

| Moment type | Rule |
|---|---|
| Ordinary (single pose, one dish, one selfie attempt) | Keep 1. |
| Rich (viewpoint yielding wide + group + candid) | Keep up to 2–3, each adding distinct information. |
| High-count (many frames, people, compositions, favorites, duration) | Allow more only via measurable evidence above, never via inferred emotion. |

Uncertain: thresholds separating ordinary/rich/high-count moments; tune from manual review ([10](../ship-gates/manual-qa.md)).

## 9. Quality model and score policy

Quality is multi-dimensional. No single metric defines it. Consider sharpness, exposure, subject visibility, face quality, eye state when reliable, obstruction, composition, stability, and aesthetic signal when available.

Score formula stays conceptual; this file sets policy, not numbers:

```text
candidateValue =
    baseQuality
  + diversityBonus
  + coverageBonus
  + userIntentBonus
  - duplicatePenalty
  - repetitionPenalty
```

Rules for the formula: weights live in configuration, not code; aesthetic score is one input, never the selector (`aestheticScore != selectionScore`); tiny score gaps are noise — decide near-ties by diversity, intent, expression, or coverage (§15). Computation order and implementation: [04](../design-docs/selection-engine.md).

### Quality tiers (canonical)

| Tier | Policy |
|---|---|
| Excellent | Strong final-album candidate. |
| Good | Suitable candidate. |
| Acceptable | Selectable for coverage or diversity. |
| Poor | Reject normally. |
| Unusable | Reject. |

Map numeric cutoffs to tiers in one configuration table (§17). Never scatter thresholds through code.

## 10. Face, group, and selfie rules

Portrait preference among similar frames: sharper unobstructed face, natural expression, eyes open when posing, better light, stronger composition.

| Case | Rule |
|---|---|
| Eyes closed | Penalize only when subject poses and a better alternative exists. Never auto-reject: laughing, candid, sleeping, or downward gaze may be intentional. |
| Obstruction | Penalize finger/blocked/cropped faces. Do not penalize deliberate partial framing. |
| Repeated portraits | Suppress same person + same place/pose/composition to one. Same person across different trip parts may repeat. |
| Group scoring | Score by weakest important face, not best face. Prefer full visibility, open eyes, natural expressions, complete framing. A fully-good group beats a sharper group with one failed face. |
| Repeated group pose | Keep 1 normally; 2 only on formal-versus-candid or clearly different composition. |
| Selfies | Score like any portrait. Deduplicate same-spot selfie runs aggressively (≈20 similar frames → 1, or 2 when meaningfully different). |

Uncertain: eye-state reliability in low light and candid frames; prefer no penalty when detection confidence is low. Face pipeline details: [07](../design-docs/apple-frameworks.md).

## 11. Scene rules

| Scene | Rule |
|---|---|
| Landscape repeats | Collapse near-identical views to 1 keeper. |
| Landscape variants | Keep wide, panorama, detail, or day-versus-night versions only when each adds distinct information. Ignore zoom/crop/horizon micro-shifts and slight tilt alone. |
| Landmark | Distinguish full view, contextual view, detail, person-with-landmark, alternative perspective. Deduplicate identical facades. |
| Food and objects | Treat one dish/plate as one moment; keep whole-table plus signature-dish close-up when distinct, not five identical close-ups. |
| Document/utility (ticket, map, QR, sign) | Deprioritize for the curated album; never aggressively delete uncertain cases. |

Uncertain: classifier boundary for obvious utility versus contextual sign (e.g. historic plaque as scene detail).

Judge landscapes on sharpness, exposure, clipping, obstruction, composition, aesthetic signal. Signals computation: [04](../design-docs/selection-engine.md).

## 12. Meaningful variation

Keep both only when the second photo adds information the first lacks.

| Keep both | Keep one |
|---|---|
| Wide beach + traveler portrait on that beach | Portraits a second apart with tiny head move |
| Formal group + candid interaction | Landscapes differing by a few percent framing |
| Temple exterior + architectural detail | Group retakes with negligible expression change |
| Day skyline + night skyline | Same landmark, same light, shifted crop |
| Front landmark view + rear/alternative view | Burst frames of one static pose |

Orientation change alone never justifies both; content must differ.

## 13. Diversity and coverage model

Dimensions: temporal, scene, people, composition, subject, visual. Achieve them by duplicate suppression, moment grouping, repetition penalties, and coverage bonuses — never by fixed quotas (e.g. never "20% portraits").

| Dimension | Rule |
|---|---|
| Temporal / chronological | Represent usable photos across the trip span; promote good candidates from bare periods. Never promote Poor/Unusable frames to fill gaps. Coverage is a soft constraint. |
| Scene | Penalize overshot scenes harder than rare scenes; do not mirror source ratios mechanically. |
| People | Reduce redundant same-person runs; people diversity is redundancy control, not demographic balancing. |
| Composition | Let wide/medium/close/group/detail mix emerge from dedupe; set no quotas. |
| Day/night | Treat distinct lighting of one place as meaningful variation, stronger than framing tweaks. |
| Repetition | Penalize each additional pick from one cluster, moment, scene, or composition progressively. |

Quality-versus-diversity test: prefer a Good unique-activity photo over an Excellent fourth copy of one landmark; reject a blurred unique photo despite its novelty. Reflect what the user shot; never invent absent categories (all-wildlife trip stays wildlife).

## 14. Album sizing and user-intent override (owned here)

Sizing is quality-adaptive and owned here; [01](product.md) states the goal only.
Album size adapts to usable-quality moment count: ~10% of input and the
30–40 minimum / 120–150 maximum clamps are DEFAULT STARTS, not quotas.
Never pad with Poor/Unusable photos to hit a number; never cut good
unique-moment photos to hit a %.

| Parameter | Default start (tunable) |
|---|---|
| Target album size | ~10% of input count, clamped to 30–40 minimum and 120–150 maximum. |
| Shortlist for review | ~2× final target, feeding the review surface ([02](ux-flows.md)). |
| Undersupply | Return fewer than target rather than promote Poor/Unusable assets. |
| Small target | Favor strongest moments, best representatives, broad coverage first; drop repeats first. |
| Large target | Add secondary rich-moment picks, alternate compositions, strong candids; never pad with obvious duplicates. |
| Protected picks (defined once, here) | The sole usable representative of a distinct moment that diversity fill must keep (unique-moment protection policy). Diversity fill adds around protected picks; it never displaces one for a redundant second pick from an already-represented moment. Mechanics mirror this term via link only — see [04](../design-docs/selection-engine.md). |

User intent:

| Signal | Rule |
|---|---|
| Explicit include/exclude in this session | Hard override; persist for the session unless asset becomes unavailable. Recomputation preserves a user-swapped representative. |
| Favorite | Soft positive bonus, never forced selection. |
| Intentional edit | Small preference over the unedited twin; never keep both. Do not judge edit aesthetics. |

Long-term personalization is out of scope; future weights may adjust ranking but must not bypass duplicate suppression.

## 15. Tie-breaks (deterministic)

When candidates are effectively tied, decide in this order: explicit user selection; stronger quality tier; higher quality score; intentional-edit preference; favorite preference; higher usable resolution; stable asset-identifier order. Identical inputs plus identical configuration produce identical output. Timestamp randomness is forbidden as a decider.

## 16. Reason codes (canonical)

Every automatic keep/reject exposes one primary reason and optional secondary reasons. Codes are stable for logs and analytics ([11](../ship-gates/analytics.md)).

| Group | Codes |
|---|---|
| Eligibility | `unsupportedAsset`, `assetUnavailable`, `corruptedAsset` |
| Quality rejection | `severeBlur`, `severeUnderexposure`, `severeOverexposure`, `accidentalFrame`, `lowQuality` |
| Duplicate handling | `exactDuplicate`, `duplicateRepresentative`, `nearDuplicate`, `nearDuplicateRepresentative`, `burstRejected`, `burstRepresentative` |
| Moment | `bestInMoment`, `secondaryMomentRepresentative` |
| People | `bestPortrait`, `bestGroupPhoto`, `betterFaceQuality` |
| Scene | `bestLandscape`, `bestSceneRepresentative` |
| Diversity/coverage | `sceneDiversity`, `peopleDiversity`, `compositionDiversity`, `temporalCoverage`, `meaningfulVariation` |
| User intent | `userSelected`, `userExcluded`, `favoriteBoost`, `editedVersionPreferred` |

Example: primary `bestGroupPhoto` with secondaries `betterFaceQuality`, `nearDuplicateRepresentative`. Stored shape: [06](../design-docs/data-model.md).

## 17. Tunable parameters (single table)

All numbers below are starting defaults. Centralize them in selection configuration; scatter no threshold in code. Score weights stay symbolic here (no invented constants); engineering sets values per [04](../design-docs/selection-engine.md) and validates per [10](../ship-gates/manual-qa.md).

| Parameter | Default start |
|---|---|
| `targetCountRatio` | ~0.10 of eligible inputs (default start; adapts per §14) |
| `targetCountMin` / `targetCountMax` | 30–40 / 120–150 (default starts; adapts per §14) |
| `shortlistMultiplier` | ~2× final |
| `shortlistMultiplierRange` | 1.5×–2.5× of final target (default ~2×) |
| `exactDuplicateRepresentatives` | 1 |
| `nearDuplicateRepresentatives` / exceptional max | 1 / 2 |
| `ordinaryMomentRepresentatives` / rich max | 1 / 2–3 |
| `momentStrongWindow_s` / extended window | ~45 s / ~180 s with similarity |
| `minimumQualityThreshold` (floor: Acceptable) | configured cutoff; below rejects |
| `duplicateSimilarityThreshold`, `nearDuplicateSimilarityThreshold` | configured cutoffs |
| `diversityWeight`, `coverageWeight`, `repetitionPenalty` | symbolic weights |
| `favoriteBonus`, `editedBonus` | small soft bonuses |
| `userOverride` | hard override |

Keep the parameter count small; add new knobs only when manual evaluation proves need.

## 18. Worked expectations

| Input | Expected |
|---|---|
| 10 near-identical portraits in 12 s | 1 keeper; 2 only on formal-versus-candid split. |
| Group set: blinker, good-all, blurred, twin-of-good | Keep good-all (`bestGroupPhoto`); reject rest. |
| Viewpoint: 5 wide + panorama + traveler portrait + detail | 1 wide, plus panorama/portrait/detail only when distinct. |
| 20-frame jump burst | Best peak frame; second only on distinct phase. |
| 7-day library skewed to 3 heavy days | Cover usable days; do not mirror input ratios. |
| 30 excellent morning portraits + 5 good museum + 15 good evening | Few portraits plus museum and evening picks. |
| Only frame of a place is unusable | Reject; coverage never overrides the floor. |
| Favorite versus slightly sharper twin | Favorite wins if acceptable; usable twin wins if favorite is defective. |
| Original plus intentional edit | Keep edited twin only. |
| One landmark morning/midday/sunset/night | Keep lighting-distinct versions; drop same-light retakes. |

Evaluation libraries and pass criteria: [10](../ship-gates/manual-qa.md).

## 19. Invariants (MUST only)

- Exact duplicates MUST NOT both appear in the final album.
- Burst output must not let one sequence dominate the album.
- Severely unusable images MUST NOT appear via diversity or coverage.
- Explicit user include/exclude MUST override automatic rules within the session.
- Repeated runs on identical inputs and configuration return identical results (determinism mechanics in 04).
- Tiny score gaps MUST NOT decide over major diversity or coverage gains.
- Missing GPS, faces, or timestamps do not lower a quality score (see §4–§5).
- Diversity MUST NOT use category quotas.

## 20. Non-goals and Uncertain list

Non-goals: retouching, color correction, emotion detection, identity recognition, demographic balancing, cloud search, language understanding, long-term taste learning, generative enhancement. Roadmap: [12](../exec-plans/roadmap.md). Decisions: [13](../design-docs/decision-log.md).

Remaining Uncertain items (evidence conflicts or needs QA tuning):

1. Exact numeric cutoffs for quality tiers and similarity thresholds.
2. Temporal window boundaries for moment grouping in dense events.
3. Ordinary/rich/high-count moment boundary.
4. Eye-closed and motion-blur intent detection reliability.
5. Utility-versus-scene boundary for signs and plaques.
6. Relative weights of diversity, coverage, repetition, favorite, and edit bonuses.
7. Minimum/maximum clamp default-start edges (30–40 and 120–150) across small and very large libraries; sizing stays quality-adaptive per §14.
