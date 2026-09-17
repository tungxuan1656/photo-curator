# Photos Curator — Decision Log

**Doc:** `decision-log.md` · **Status:** Living · **Updated:** 2026-09-17

**Ownership:** This doc OWNS rationale/history only (why a choice was made, append-only DEC-xxx).
It never owns current operational values — those live in owner docs (linked per entry).
Current values: selection policy → `selection-rules.md`, mechanics → `selection-engine.md`,
arch → `ios-architecture.md`, shapes → `data-model.md`, APIs → `apple-frameworks.md`,
current AI/model implementation choices → `curation-runtime-stack.md`,
budgets → `performance.md`, privacy → `privacy.md`,
QA → `manual-qa.md`, UX → `ux-flows.md`, product → `product.md`,
metrics → `analytics.md`, roadmap → `roadmap.md`.

**Rules:** Append-only. Never silently rewrite history. To change a DEC: keep old text,
mark `Superseded by DEC-xxx`, add new entry. Statuses: `Accepted / Rejected / Superseded / Deferred / Revisit`.
New entry fields: status, date, owner doc, affected docs, risk, trigger/reconsider-when. Keep English simple.

---

## 1. Status table (first — full index)

Note: `TBD`/`OPEN` prefixes are historical IDs kept append-only; the Status column governs. Promotion details: §3–§6.

### 1a. Accepted (40 kept)

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
| DEC-017 | Manual QA for selection quality | 10 (Superseded by DEC-032) |
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
| DEC-028 | G0 contract naming | 05 |
| DEC-029 | Post-MVP Curation Intelligence V2 with iOS 26 baseline + optional iOS 27 semantic tier | 03, 04, 07 |
| DEC-030 | Variant-aware clustering contract | `features/feat-021.md` |
| DEC-032 | Automated feature evidence replaces mandatory manual QA | `AGENTS.md`, `features/feat-template.md`, 10 |
| DEC-033 | Semantic moment change-point contract | `features/feat-022.md` |
| DEC-034 | Tier-C visual-embedding provider contract | `features/feat-024.md` |
| DEC-035 | Production wiring for bounded Tier-C diversity edges | `features/feat-024.md` |
| DEC-036 | Global diversity shortlist graph contract | `features/feat-023.md` |
| DEC-037 | Tier-C graph uses the exact FeaturePrint shortlist | `features/feat-023.md` |
| DEC-038 | Tier-D specialists rejected (feat-025 no-op) | `features/feat-025.md` |
| DEC-TBD-001 | Min iOS 26 | 07 |
| DEC-TBD-002 | File-based Codable persistence, no database for MVP | 05, 06 |
| DEC-TBD-005 | Export to new Photos album, non-destructive, collision-safe | 02, 07 |
| OPEN-P06 | Screenshots deprioritized, not forced | 03 |
| OPEN-P07 | Live Photo stills eligible | 03 |
| OPEN-P08 | Edited version soft bonus only | 03 |
| OPEN-P09 | Favorite soft bonus only | 03 |
| OPEN-N05 | Album clamps as quality-adaptive default starts | 03 |

### 1b. Deferred TBDs (4 kept, structured)

| ID | Topic | Owner | Status |
|---|---|---|---|
| DEC-TBD-003 | Analytics provider | 11 | Deferred |
| DEC-TBD-004 | Monetization model | 01 | Deferred |
| DEC-TBD-006 | Advanced ML models | 03, 04, 07 | Superseded by DEC-029 |
| DEC-TBD-007 | Personalization strategy | 03, 06 | Deferred |

Promoted to Accepted (values owned in linked docs, not duplicated here):
DEC-TBD-001 (min iOS 26 → 07), DEC-TBD-002 (file-based Codable persistence,
no database for MVP → 05, 06), DEC-TBD-005 (new Photos album export,
non-destructive, collision-safe → 02, 07). See §3.

### 1c. Open product questions (from 01 §57 — no answers yet)

| ID | Question | Owner | Status |
|---|---|---|---|
| OPEN-P01 | Input scope: photos vs date range vs both? | 01, 02 | Deferred |
| OPEN-P02 | Album size: exact number or S/M/L presets? | 01, 02 | Deferred |
| OPEN-P03 | Auto-suggest album size? | 01, 03 | Deferred |
| OPEN-P04 | How much alternative browsing in review? | 02 | Deferred |
| OPEN-P05 | Mandatory-include mark before curation? | 02, 03 | Deferred |
| OPEN-P10 | Feedback persistence across sessions? | 06, 03 | Deferred |

### 1d. Superseded recent decisions

| ID | Topic | Superseded by |
|---|---|---|
| DEC-031 | Feat-021 blocked pending physical QA inputs | DEC-032 |

Promoted to Accepted (rules owned in 03, linked not duplicated):
OPEN-P06 (screenshots deprioritized, not forced), OPEN-P07 (Live Photo stills
eligible), OPEN-P08 (edited version = soft bonus only), OPEN-P09 (Favorite =
soft bonus only). See §4.

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
| OPEN-N06 | Weight set (diversity/coverage/repetition/bonus) | 03 | 04, 10 | Deferred |
| OPEN-N07 | Batch sweet spot (16–64), concurrency caps | 08 | 04, 05 | Deferred |
| OPEN-N08 | Vision edge cases (eyes, blur intent, small faces, signs) | 03 | 07, 10 | Deferred |

Promoted to Accepted: OPEN-N05 (album clamps as quality-adaptive default
starts per 03 §14). See §6.

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

**DEC-017 — Manual QA for quality (Superseded by DEC-032).**
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

**DEC-028 — G0 contract naming (Accepted).**
Keep `PhotoCuratorApp` (matches Xcode target); canonical model `PhotoAsset` (drop `PhotoAssetRecord`
at G0); engine file `SelectionEngine.swift` holds concrete `SelectionEngine` (no protocol per DEC-015).
Owner: 05. Affected: feature_index owns, 05. Risk: later stages extend contracts via leader review only.
Reconsider when: a stage needs a name the contract cannot express.

**DEC-029 — Curation Intelligence V2 (Accepted, 2026-09-16).**
Owner: 03, 04, 07. Affected: 02, 06, 08, 09, 10, 12.
Decision: after the functional MVP baseline, improve selection quality through a tiered on-device intelligence stack. iOS 26 remains the minimum and must retain a complete native fallback. Native Vision signals come first where sufficient; replaceable Core ML representation/specialist models may be added when targeted QA proves benefit. Exact model/API choices are owned by `curation-runtime-stack.md`, not by this architectural decision. iOS 27 Foundation Models image input may act as an optional semantic jury for small ambiguous candidate sets, never as a core dependency. A custom Core ML curation ranker is gated on Golden/real-trip labels and held-out improvement.
Rationale: the current product goal requires best-shot, meaningful-variation, moment, and album-level reasoning that cannot be represented safely by one quality scalar. A staged specialist architecture can improve those decisions while preserving privacy, fallback, and debuggability.
Risk: app/model size, battery/thermal cost, licensing mistakes, semantic-model nondeterminism, and regressions hidden by extra complexity.
Trigger/reconsider when: a layer fails Golden/real-trip quality gates, violates privacy/license constraints, or costs more latency/memory/thermal budget than its measured curation gain. Architecture and gates: [curation-intelligence.md](curation-intelligence.md). Current concrete stack: [curation-runtime-stack.md](curation-runtime-stack.md).

## 2a. Feat-021 decisions

# DEC-030 — Variant-aware clustering contract
Status: Accepted · Date: 2026-09-17
Owner: `features/feat-021.md` · Affected: `DuplicateResolver`, feat-022 admission
Context: The resolver needed to stop semantic variants from collapsing through a transitive near-duplicate chain while keeping sparse analysis deterministic and preserving the frozen persisted schema.
Decision: Use closest-first canonical edge ordering and coherence-checked union. A variant veto requires positive categorical evidence on both members; unknown or nil evidence defers to the legacy-compatible merge. Keep day/night, formal/candid with the same face count, and framing-magnitude distinctions as later embedding or jury ceilings, and keep `analysisVersion` at 4 because no persisted shape changes.
Alternatives considered: first-fit/BFS ordering (rejected because it did not match the stronger deterministic contract); asymmetric unknown handling (rejected because it splits on incomplete evidence); adding new persisted facts or thresholds (rejected as unnecessary scope and migration risk).
Evidence: feat-021 proof runs on A/B/Golden were byte-identical across two runs with zero incoherent clusters; bilateral unknown cases pass; the second Codex review confirmed the implementation and plan wording after fixes.
Consequences: variant-aware behavior remains local to `DuplicateResolver`, keeps the iOS 26 native fallback, adds no model/request/dependency or migration, and intentionally defers distinctions that require richer evidence.
Reconsider when: a later feature supplies measured embedding/jury evidence or a named residual failure shows that these ceilings materially harm curation quality.

# DEC-031 — Feat-021 blocked pending physical QA inputs
Status: Superseded by DEC-032 · Date: 2026-09-17
Owner: `features/feat-021.md`, `docs/ship-gates/manual-qa.md` · Affected: feat-021 and its dependent chain
Context: Code and host proof passed, but the feat-021 gate requires B+Golden physical-iPhone annotated-label evidence and real-trip evidence. The acceptance record correctly leaves that box unchecked.
Decision: Keep feat-021 blocked and do not merge its PR or activate feat-022. Resume only after a physical iPhone and the required annotated Golden plus real-trip dataset are available; then rerun the owner QA gate and `./init.sh`.
Alternatives considered: relabel synthetic host proof as manual QA (rejected because it does not contain annotated labels); substitute Simulator evidence (rejected by `manual-qa.md`); lower or check the acceptance criterion (rejected because it would falsify the gate); wait for the required device and datasets (accepted recovery).
Evidence: OMP acceptance-closure Dispatch `ctx_8793451d37d5` reports all three physical iPhones unavailable via `devicectl`, no annotated Golden labels or real-trip fixtures in the repository, and Simulator substitution barred by `manual-qa.md`; Codex review Dispatch `ctx_8de70448c1c8` independently reached `BLOCKED/FIX_REQUIRED`.
Consequences: the integration worktree and code remain preserved, feat-021 remains the sole blocked feature, later features stay `todo`, and no merge commit or PR is claimed.
Reconsider when: the physical device and datasets are supplied and the complete B+Golden, real-trip, and build evidence passes without changing the acceptance bar.

# DEC-032 — Automated feature evidence replaces mandatory manual QA
Status: Accepted · Date: 2026-09-17
Owner: `AGENTS.md`, `features/feat-template.md`, `docs/ship-gates/manual-qa.md` · Affected: feat-021 through feat-028 and future feature records
Context: The current manual-qa policy makes physical-device execution, human Golden annotation, and real-trip review hard release gates. Those inputs are unavailable, while the repository already supports deterministic proof binaries, Simulator builds, and automated code evidence.
Decision: Supersede DEC-017. Manual or physical-device QA is optional and non-blocking. Every behavior-changing feature MUST provide reproducible automated evidence for its acceptance criteria, using the Simulator when appropriate, and MUST pass `./init.sh`. Keep the no-test-target, no-`*Test*.swift`, and no-test-framework policy. Feature records must not require manual-qa execution or physical-device evidence.
Alternatives considered: keep physical QA as a hard gate (rejected because it blocks reproducible repository work on unavailable external inputs); accept manual-only evidence (rejected because it is not restartable); remove all quality evidence (rejected because acceptance still needs objective proof); allow automated proof with optional manual follow-up (accepted).
Evidence: the feat-021 proof binary passed A, B, and Golden-shaped deterministic runs plus I1–I8; `./init.sh` passed; the prior blocker was exclusively unavailable physical devices and datasets, not a failing automated proof.
Consequences: feat-021 can resume from its preserved integration worktree after its acceptance record is rewritten to the automated gate; later features use automated fixture/proof evidence and remain free of physical-device blockers. Manual-qa.md remains as optional exploratory guidance and historical method documentation.
Reconsider when: a release, privacy, safety, or data-integrity risk requires a separately approved manual check, or automated evidence cannot represent a newly introduced behavior.

# DEC-033 — Semantic moment change-point contract
Status: Accepted · Date: 2026-09-17
Owner: `features/feat-022.md` · Affected: `MomentBuilder`, feat-023/feat-024 admission
Context: The moment middle band needed semantic boundaries beyond scene-only grouping without new signals, while sparse evidence had to keep deterministic legacy grouping and dense bursts had to stay together.
Decision: Use conservative middle-band change-points (people-presence, bilateral document/framing, known-scene) checked only after close-visual-edge continuity; sub-soft-gap density never splits; hard-gap always splits; nil/unknown evidence continues the moment (legacy fallback). Single-vs-group counts and orientation alone never split. Keep `analysisVersion` at 4 (no persisted-shape change, no migration); keep sub-soft-gap activity transitions and day/night + formal/candid + framing-magnitude distinctions as feat-024/feat-027 ceilings.
Alternatives considered: dense-timeline splitting (rejected — needs embedding/jury evidence); asymmetric unknown handling (rejected — splits on incomplete evidence); new persisted facts or thresholds (rejected — unnecessary scope and migration risk).
Evidence: feat-022 proof runs (Smoke 60→6, Golden 200→15, Trip 150→10, H 1000→56, all double-run byte-identical) plus named cases M1–M7 ALL PASS with M6 legacy-oracle identity; `./init.sh` PASS (format, `swiftlint --strict` 0 violations/61 files, BUILD SUCCEEDED, SKIP [test] per policy).
Consequences: moment policy stays local to `MomentBuilder`, keeps the iOS 26 native fallback, adds no model/request/dependency or migration, and feeds feat-024/feat-027 only the measured ceilings.
Reconsider when: a named residual failure shows the ceilings materially harm curation quality, or measured embedding/jury evidence justifies dense-timeline splitting.

---

# DEC-034 — Tier-C visual-embedding provider contract
Status: Accepted · Date: 2026-09-17
Owner: `features/feat-024.md` · Affected: `SelectionEngine`, `curation-runtime-stack.md`, feat-023 admission
Context: Global diversity (feat-023) needs a bounded Tier-C representation signal, but no measured failure yet justifies vendoring a Core ML model with its license/size/latency cost, and Tier-C work must never silently cover every photo.
Decision: Ship the capability abstraction (`VisualEmbeddingProvider`), the bounded router (shortlist-scale only: refuses > 250 assets, caps at 4,000 canonical pairs), the native derived embedding as the selected production representation (8-dim persisted-scalar vector, transient, no model/pixels/request/weights), the noop fallback provider, and the union-min edge merge feeding diversity novelty only (clusters + moments stay FeaturePrint-only). Keep FastViT headless benchmark-only (not vendored; license re-review + checksum + size/latency/memory/thermal evidence required before any inclusion). Keep `analysisVersion` at 4 (no persisted-shape change, no migration); keep pixel-level distinctions (day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity) as ceilings.
Alternatives considered: vendoring FastViT now (rejected — no measured failure, no license/checksum evidence, unnecessary size/latency cost); running Tier-C on every photo (rejected — unbounded cost, violates tier principles); feeding Tier-C into clusters/moments (rejected — would change feat-021/feat-022 frozen contracts without evidence); new persisted embedding fields or version bump (rejected — unnecessary scope and migration risk).
Evidence: feat-024 proof runs (Golden-shaped 200→15 + H 1000→56 identical across fallback/noop/tierc arms, all double-run byte-identical) plus 14 named cases ALL PASS (R1–R4 router bounds, P1–P5 provider contract, E1–E3 merge, N1–N2 engine isolation); `./init.sh` PASS (format, `swiftlint --strict` 0 violations, BUILD SUCCEEDED, SKIP [test] per policy).
Consequences: Tier-C stays local to the new file + one engine parameter, keeps the iOS 26 native fallback (default `[]` is exactly the pre-feat-024 path), adds no model/request/dependency/migration/license burden, and admits feat-023 with a bounded shortlist-scale consumer contract.
Reconsider when: a named residual failure shows persisted facts call two frames identical but diversity needs them separated, with fixture evidence that a pixel-level embedding moves picks — then run the FastViT benchmark gate before any vendoring.

---

# DEC-035 — Production wiring for bounded Tier-C diversity edges
Status: Accepted · Date: 2026-09-17
Owner: `features/feat-024.md` · Affected: `SelectionSessionCoordinator`, `AppContainer`, `SelectionEngine`, feat-023 admission
Context: Review found that DEC-034 and the feat-024 plan called the native derived provider selected/default-on, but the shipped selection session passed no Tier-C edges and `AppContainer` constructed no provider. The feature contract includes pipeline integration, and feat-023 depends on a real bounded consumer contract.
Decision: Wire `VisualEmbeddingRouter` and `NativeDerivedEmbeddingProvider` into both production selection paths. Use the `NoopVisualEmbeddingProvider` fallback when the router refuses oversized input or no usable Tier-C edges are produced. Pass only the merged Tier-C edges to `SelectionEngine` for diversity novelty; keep duplicate clustering and moment construction on FeaturePrint edges only. Keep `analysisVersion` at 4 and ship no model or new persisted field.
Alternatives considered: downgrade the runtime docs and defer wiring to feat-023 (rejected — leaves the selected/default-on claim false and violates feat-024's pipeline-integration boundary); route all assets (rejected — unbounded work and violates Tier-C limits); vendor FastViT now (rejected — no measured failure or license/checksum evidence).
Evidence: Codex review found the production-path omission while the exact snapshot passed `./init.sh` and the provider proof; the existing router caps input at 250 assets and 4,000 canonical pairs, so production wiring can remain bounded and deterministic.
Consequences: production selection now exercises the selected native provider at shortlist scale with a deterministic fallback; feat-023 receives a live bounded contract; no cloud processing, model dependency, persisted schema, or migration is added.
Reconsider when: a named production residual failure or benchmark shows the native representation cannot improve diversity safely; then update the runtime record and repeat the FastViT license/checksum/size/latency/memory/thermal gate before changing the provider.

---
# DEC-036 - Global diversity shortlist graph contract
Status: Accepted - Date: 2026-09-17
Owner: `features/feat-023.md` - Affected: `GlobalDiversityGraph`, `DiversitySelector`, `QualityScorer`, `SelectionEngine`, `FinalAlbumBuilder`, `SelectionSessionCoordinator`, feat-025/feat-026 admission
Context: Album-level redundancy (repeated landmark/portrait/composition across time) escapes the windowed duplicate pass, but a full-library all-pairs graph would break the 1k-photo budget and Tier-C routing bounds, and any graph change must preserve the quality floor, duplicate/moment contracts, and deterministic fallback.
Decision: Scope merged FeaturePrint + Tier-C edges to the exact shortlist the selector consumes via `GlobalDiversityGraph` (canonical member order, member pairs only, 4,000-pair cap); cap `QualityScorer.shortlist` pools above 250 in shortlist order with no sub-150 padding; route production Tier-C pairs over `SelectionEngine.shortlistScope` (same shortlist, non-overlapping with the duplicate-candidate source); change only the visual-novelty input inside the unchanged protected/core/greedy phases with unchanged weights and `QualityScorer.compareRank` tie-breaks; bump `engineVersion` 2 to 3 (choice change per data-model; `analysisVersion` stays 4, no persisted-shape change, no migration); add no config key, model, request, quota, or persisted field.
Alternatives considered: full-library graph (rejected - unbounded pairs, breaks Tier-C bounds and 1k budget); per-category quotas (rejected - selection-rules forbids fixed quotas); feeding the graph into clusters/moments (rejected - would change feat-021/feat-022 frozen contracts without evidence); padding sub-150 pools to 150 (rejected - selection-rules forbids inventing candidates); new config keys for the 150/250 window (rejected - small-knob rule, policy constants beside the router constants).
Evidence: feat-023 proof runs (Smoke 60->6, Golden 200->15, Trip 150->24, H 1000->56; fallback==noop picks exactly all shapes; double-run byte-identical all 24 files; graph bounds hold: members <= 159, edges <= 4000) plus 12 named cases ALL PASS (N0-N4 novelty, S1-S3 saturation, F1-F3 fallback/determinism, G1 bounds); `./init.sh` PASS (format, `swiftlint --strict` 0 violations, BUILD SUCCEEDED, SKIP [test] per policy).
Consequences: cross-time redundancy now resolves in the bounded graph while the quality floor, duplicate/moment contracts, Tier-C bounds, FeaturePrint-only clusters/moments, originals/privacy/on-device behavior, and fallback identity hold; stale `engineVersion` 2 decisions re-rank from stored analyses per the standard rule; feat-025/feat-026 inherit the live graph consumer contract.
Reconsider when: a named residual failure shows the graph misses a redundancy the fixtures can represent, or pixel-level evidence moves picks - then run the FastViT benchmark gate before any provider change, or adjust the window only with fixture evidence and a new DEC entry.

---

# DEC-037 - Tier-C graph uses the exact FeaturePrint shortlist
Status: Accepted - Date: 2026-09-17
Owner: `features/feat-023.md` - Affected: `SelectionEngine`, `SelectionSessionCoordinator`, `GlobalDiversityGraph`, feat-025/feat-026 admission
Context: Codex review found that production Tier-C edges were computed before `SelectionEngine.select` and that the independent scope calculation used no FeaturePrint edges. Duplicate and moment pruning could therefore produce a different shortlist and discard valid Tier-C graph edges.
Decision: Make `SelectionEngine.shortlistScope` accept the same FeaturePrint edges used by `select`. Both production paths compute their bounded FeaturePrint edges first, pass them into shortlist scope, and route Tier-C pairs only over that exact resulting shortlist. Keep the existing ≤250 asset and ≤4,000 pair limits, deterministic ordering, Noop fallback, diversity-only graph input, and FeaturePrint-only duplicate/moment stages.
Alternatives considered: retain the edge-free independent scope (rejected - it can diverge from the selector shortlist); route Tier-C before FeaturePrint pruning (rejected - graph work can be discarded and violates exact-shortlist intent); refactor `select` into a multi-stage public transaction (rejected - larger API and rollback surface than the minimal parameter correction).
Evidence: Codex review identified the scope divergence as the sole High finding; existing feat-023 proof and `./init.sh` passed otherwise, and the corrected path is covered by the same deterministic graph/selection evidence.
Consequences: every production Tier-C edge is now eligible for the exact shortlist consumed by global diversity; earlier duplicate/moment contracts and all bounds remain unchanged; no model, persisted field, schema migration, cloud path, or new quota is introduced.
Reconsider when: a future selection-stage change adds feedback or another pruning input that can make shortlist scope diverge again; then update this contract and add a new evidence-backed DEC entry before changing routing.

---

# DEC-038 - Tier-D specialists rejected: no triggering residual failure (feat-025 no-op)
Status: Accepted - Date: 2026-09-17
Owner: `features/feat-025.md` - Affected: `curation-runtime-stack.md` §7, feat-026/feat-028 admission
Context: Feat-025 may evaluate a difficult-only specialist only when a residual feat-023 failure exists with no cheaper accepted remedy, must decide each candidate individually (never DETR/depth/SAM as a bundle), and may integrate only an accepted candidate with bounded on-device licensed evidenced rollback-safe routing. Feat-023 closed with all 12 named cases passing and deterministic fallback proven; its only documented ceilings are pixel-level distinctions (day/night, formal/candid same-face-count, framing magnitude, dense-timeline activity) whose recorded reconsider path is FastViT Tier-C pixel evidence or the feat-027 jury first.
Decision: Record feat-025 as a documented no-op: reject DETR-style object/layout, Depth Anything V2 Small depth/context, and SAM 2.1 Tiny precision segmentation individually for lack of a triggering residual failure with cheaper remedies exhausted. Ship no model, runtime dependency, provider, Vision request, persisted field, config key, or version move. Mark the three runtime-stack §7 rows REJECTED with this DEC pointer. Create no `docs/plans/feat-025.md` (no shared-contract change, single workspace, nothing to roll back).
Alternatives considered: vendoring any candidate without a target failure (rejected - unlicensed unmeasured size/latency/memory cost, violates the feature gate); bundling all three as one decision (rejected - contract requires per-candidate verdicts); running benchmarks without a triggering failure (rejected - numbers without a target failure cannot justify cost); inventing a residual failure to force integration (rejected - falsifies the gate).
Evidence: feat-023 proof (Smoke 60->6, Golden 200->15, Trip 150->24, H 1000->56; 12 named cases ALL PASS; fallback==noop exactly; double-run byte-identical) plus repo-state proof (`find` shows no `.mlmodel*`/`.mlpackage*`/`.coreml*`; `apps/` grep shows no Tier-D names vendored); `./init.sh` PASS at the feat-025 commit; `git diff --name-only` shows tracker/decision records only, no `apps/` path.
Consequences: the iOS 26 native path stays complete with zero specialist cost; feat-026/feat-028 proceed unaffected (feat-028 explicitly does not depend on feat-025); no license/checksum/size/latency burden is added.
Reconsider when: a named residual failure shows cheaper remedies (native Tier-B facts, Tier-C embedding, feat-027 jury) exhausted with fixture evidence that a specific Tier-D candidate moves picks - then run that candidate's full gate (license re-review + checksum + size/latency/memory/thermal + quality delta + bounded difficult-only routing + rollback) before any vendoring.

---

## 3. Deferred TBDs (structured — no answers invented)

**DEC-TBD-001 — Min iOS 26 (Accepted).**
Owner: 07. Affected: 05, 08. Decision: MVP targets iOS 26 minimum, per needed
Vision/SwiftUI/PhotoKit APIs and store distribution evidence in original docs.
Rationale: avoids API gaps from targeting lower; values/APIs owned in 07.
Risk: lost users on older OS. Reconsider when: device-matrix data says otherwise.

**DEC-TBD-002 — File-based Codable persistence, no database for MVP (Accepted).**
Owner: 05, 06. Decision: simplest persistence that fits MVP volume +
lifecycle; no SwiftData/Core Data/tiny DB for MVP. Rationale: evidence-backed
from original docs — over-build risk outweighs benefit at MVP scale; shapes
owned in 06. Risk: migration later if volume forces it. Reconsider when:
persistence need outgrows files.

**DEC-TBD-003 — Analytics provider (Deferred).**
Owner: 11. Options: none → Apple metrics → light custom → third-party. Must satisfy 09 + DEC-018.
Risk: privacy breach. Trigger: first metrics need.

**DEC-TBD-004 — Monetization (Deferred).**
Owner: 01. Options: paid / unlock / sub / freemium / free-cap. Must not warp MVP arch.
Risk: paywall rework. Trigger: pre-launch.

**DEC-TBD-005 — Export to new Photos album, non-destructive, collision-safe (Accepted).**
Owner: 02, 07. Decision: save the approved result as a new Photos album;
never modify/delete originals; handle name collisions safely. Rationale:
evidence-backed from original docs — matches MVP save flow and DEC-005/026
trust posture; mechanics owned in 02, 07. Risk: permission surprise.
Reconsider when: save-flow build proves otherwise.

**DEC-TBD-006 — Advanced ML (Superseded by DEC-029).**
Owner: 03, 04, 07. Original options: custom quality/aesthetic model, embeddings, expression analysis.
Original gate remains useful: Apple/native baseline must be QA-measured before heavier models become default-on.
Superseded by DEC-029, which accepts a staged post-MVP intelligence program while retaining quality, license, performance, privacy, and fallback gates.

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

**OPEN-P06 — Screenshots deprioritized, not forced (Accepted).** Owner 03.
Decision: deprioritize screenshots for the curated album; never force-exclude
uncertain cases. Rationale: evidence-backed from original docs — avoids junk
keepers without losing context. Rule owned in 03 §4/§11. Risk: junk keepers
or lost context. Reconsider when: QA on mixed libraries says otherwise.

**OPEN-P07 — Live Photo stills eligible (Accepted).** Owner 03 (mech 02, 07).
Decision: Live Photo stills are eligible inputs like standard photos.
Rationale: evidence-backed from original docs; representation/badge behavior
owned in 02, 07. Risk: API/perf cost. Reconsider when: asset-type pass says
otherwise.

**OPEN-P08 — Prefer edited twin, soft bonus only (Accepted).** Owner 03.
Decision: intentional edit earns a small preference over the unedited twin;
never keep both. Rationale: evidence-backed from original docs; rule owned in
03 §6/§14. Risk: double-keeping twins. Reconsider when: QA on edited sets
says otherwise.

**OPEN-P09 — Favorites are a soft bonus only (Accepted).** Owner 03.
Decision: Apple Photos favorite boosts rank slightly; never forces selection
of a duplicate or unusable frame. Rationale: evidence-backed from original
docs; weight owned in 03 §14/§17. Risk: bias vs delight. Reconsider when: QA
says otherwise.

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

**OPEN-N05 — Album clamps as quality-adaptive default starts (Accepted).** Owner 03 (04, 10).
Decision: ratio ~10% with min 30–40 / max 120–150 are default starts only;
album size adapts to usable-quality moment count per 03 §14 — never pad with
poor photos, never cut good unique photos. Values owned in 03; this log holds
state only.
Risk: tiny inputs padded, huge inputs starved. Reconsider when: small/large
library QA says otherwise.

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
