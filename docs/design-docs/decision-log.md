# Photos Curator — Decision Log

**Doc:** `decision-log.md` · **Status:** Living · **Updated:** 2026-09-23

**Current direction:** [DEC-055](#dec-055--similarity-first-photo-organization-companion) supersedes the cleanup/album-entry product model.
Current behavior owners are [product](../product-specs/product.md), [organization](../product-specs/organization-rules.md), and [review rules](../product-specs/review-rules.md).
Older tables, open questions, and philosophy below retain historical context and do not override those owners or DEC-040 verification policy.

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

### 1a. Accepted (50 kept)

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
| DEC-039 | Feat-025 readiness record keeps docs/plans/feat-025.md, no app change | `features/feat-025.md` |
| DEC-040 | Manual QA removed from feature gates; automated evidence only | `AGENTS.md`, `features/feat-template.md` |
| DEC-041 | Roadmap manual-QA residue cleanup; automated-only gates hold | `docs/exec-plans/roadmap.md` |
| DEC-042 | Feat-026 uncertainty-review and bounded-feedback contract | `features/feat-026.md` |
| DEC-043 | Feat-026 review routing and cleanup-race contract | `features/feat-026.md` |
| DEC-044 | Feat-026 uncertainty-feedback exact schema and version freeze | `features/feat-026.md` |
| DEC-045 | Feat-026 review-model ownership and hook lifecycle | `features/feat-026.md` |
| DEC-046 | Feat-026 feedback writer generation/ownership guard | `features/feat-026.md` |
| DEC-048 | Feat-027 image-backed in-place jury integration and hard timeout | `features/feat-027.md`, `docs/plans/feat-027.md` |
| DEC-049 | Feat-027 Foundation Models image-attachment SDK capability seam | `features/feat-027.md`, `docs/plans/feat-027.md` |
| DEC-051 | Feat-028 independent oracle and recall gate remediation | `features/feat-028.md`, `docs/plans/feat-028.md` |
| DEC-052 | Feat-028 proof contract completion | `features/feat-028.md`, `docs/plans/feat-028.md` |
| DEC-TBD-001 | Min iOS 26 | 07 |
| DEC-TBD-002 | File-based Codable persistence for the superseded MVP scope; workspace portion superseded by DEC-054 | 05, 06 |
| DEC-TBD-005 | Export to new Photos album remains accepted; no-original-deletion portion superseded by DEC-054 | 02, 07 |
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
with its workspace persistence portion superseded by DEC-054 → 05, 06),
DEC-TBD-005 (new Photos album export remains accepted; its no-original-deletion
portion is superseded by DEC-054 → 02, 07). See §3 and DEC-054 for replacement
owner links.

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
| DEC-050 | Feat-028 original ranker provenance wording | DEC-051 |
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

# DEC-039 - Feat-025 readiness record: keep docs/plans/feat-025.md, no application change
Status: Accepted - Date: 2026-09-17
Owner: `features/feat-025.md` - Affected: `docs/plans/feat-025.md`, feat-026 admission
Context: DEC-038 recorded the feat-025 no-op verdict with "Create no `docs/plans/feat-025.md`" under its then-known single-workspace/no-shared-contract condition. The review fix then touched >=4 tracked paths (`features/feat-025.md`, `feature_index.json`, `docs/design-docs/curation-runtime-stack.md`, `docs/design-docs/decision-log.md`, `progress.md` plus the plan itself), and AGENTS.md requires a readiness plan at that file count regardless of code impact.
Decision: Retain the DEC-038 no-op specialist outcome unchanged (three candidates individually REJECTED, nothing vendored, no benchmark without a target failure) and keep `docs/plans/feat-025.md` as the required Harness Slim readiness record (frozen trigger contract, explicit no-trigger branch, per-candidate records, repo-state verification, rollback/no-model-admission). No application/model/runtime change: no provider, Vision request, persisted field, config key, or version move.
Alternatives considered: delete the plan to match DEC-038's "create no plan" line literally (rejected - violates the AGENTS.md >=4-file rule the review fix triggered); rewrite DEC-038 (rejected - append-only history, the DEC-038 verdict stands); treat the plan as a code rollout (rejected - single workspace, no shared-contract code change, no phases, nothing to roll back beyond the docs/metadata paths).
Evidence: `docs/plans/feat-025.md` file-count rationale; `git status --porcelain` at the review fix shows five modified docs/metadata paths plus the plan, no `apps/` path; `./init.sh` PASS at the feat-025 commit; PR #52 MERGED via `55cf176753be531fa64fbab68504e5487943d0e9`.
Consequences: DEC-038's rejection verdict and reconsider condition stand; the plan exists only as the harness-required readiness record; feat-026 proceeds unaffected (depends on feat-023, done).
Reconsider when: a future feature changes the Tier-D trigger contract or admits a specialist candidate - then supersede with a new evidence-backed DEC entry before any vendoring.
---

# DEC-040 - Manual QA removed from feature gates; automated evidence only
Status: Accepted - Date: 2026-09-17
Owner: `AGENTS.md`, `features/feat-template.md` - Affected: feat-021 through feat-028 and future feature records, `docs/plans/feat-025.md`, `docs/index.md`, `init.sh`
Context: DEC-032 made manual and physical-device QA optional and non-blocking, but feature records, plans, and harness messages still carry manual-qa, hand-review, and device-QA wording that reads as a required workflow. Those inputs are unavailable and non-reproducible, while the repository supports deterministic proof binaries, Simulator builds, and automated code evidence.
Decision: Manual QA is removed from current and future feature gates. Manual QA is not required and is never an acceptance criterion, blocker, or release gate. Every behavior-changing feature MUST provide reproducible automated evidence for its acceptance criteria (Simulator-based proof permitted) and MUST pass `./init.sh`. Keep the no-test-target, no-`*Test*.swift`, and no-test-framework policy; no tests are added. `docs/ship-gates/manual-qa.md` remains only as an archival reference, never a gate.
Alternatives considered: keep manual QA as optional non-blocking guidance (rejected - residual wording still reads as a required workflow and invites manual substitution for reproducible proof); accept manual-only evidence (rejected - not restartable); remove all quality evidence (rejected - acceptance still needs objective proof); automated proof with no manual gate and an archival handbook (accepted).
Evidence: feat-021 through feat-025 closed on deterministic proof-binary plus `./init.sh` evidence with no manual-QA gate; `./init.sh` reports `SKIP [test]` per the no-tests policy; this policy update touches docs and harness paths only, with no `apps/` change.
Consequences: feat-021 through feat-028 Verify and acceptance wording uses automated evidence only; `AGENTS.md`, `features/feat-template.md`, `docs/index.md`, `docs/plans/feat-025.md`, and `init.sh` carry no manual-QA gate wording; future features follow the same automated-only gate.
Reconsider when: a release, privacy, safety, or data-integrity risk requires a separately approved manual check, or automated evidence cannot represent a newly introduced behavior - then record a new evidence-backed DEC entry before adding any manual gate.

---

# DEC-041 - Roadmap manual-QA residue cleanup; automated-only gates hold
Status: Accepted - Date: 2026-09-17
Owner: `docs/exec-plans/roadmap.md` - Affected: `docs/exec-plans/roadmap.md` P4/P6 gates + deferred test-target row, `docs/design-docs/decision-log.md`, `progress.md`
Context: DEC-040 removed manual QA from current and future feature gates, but `docs/exec-plans/roadmap.md` still gated current/future work on hand QA: P4 named `manual-qa.md` as the Method, P6 accepted manual review as the saved-album confirmation fallback, and the deferred test-target row stated QA is manual. The Codex finding cites lines 49, 51, and 110 exactly. Those inputs are unavailable and non-reproducible, while the repository supports deterministic proof binaries, Simulator builds, and automated code evidence.
Decision: Reclassify those roadmap gates to reproducible automated evidence (Simulator permitted) + `./init.sh` only per DEC-040. Retain `manual-qa.md` links as explicitly archival/non-gating optional context, never an acceptance criterion, blocker, or release gate. Keep future custom-model training gated on automated Golden-shaped/trip-shaped evidence per `curation-intelligence.md`. Leave `docs/ship-gates/manual-qa.md` in place and preserve all historical progress/plan facts; no `apps/`, test, status, or dependency change.
Alternatives considered: keep P4/P6 manual wording as optional non-blocking guidance (rejected - in a phase-gate table it still reads as a required workflow and contradicts DEC-040); delete `manual-qa.md` or rewrite historical progress/plans (rejected - destroys the archival record and exceeds the Codex finding scope); remove all quality evidence from the roadmap (rejected - phases still need objective gates); reclassify the three gates to automated-only with archival links (accepted).
Evidence: `docs/exec-plans/roadmap.md` P4/P6/deferred rows rewritten to automated evidence + `./init.sh` with `manual-qa.md` labeled archival/non-gating; scans of `AGENTS.md`, `docs/index.md`, `features/feat-template.md`, `features/feat-021.md` through `features/feat-028.md`, `docs/plans/feat-025.md`, and `init.sh` show no remaining manual-QA/hand-review/device-QA requirement wording (only the DEC-040 non-requirement disclaimer and archival references remain); `python3 -c json.load(feature_index.json)` parses; `bash -n init.sh` clean; `git diff --check` clean.
Consequences: roadmap P4/P6/P8 and deferred rows carry automated-only gates; feat-021 through feat-028 Verify/acceptance wording is unchanged and already automated-only; `manual-qa.md` stays archival reference only; future features follow the same DEC-040 automated-only gate.
Reconsider when: a release, privacy, safety, or data-integrity risk requires a separately approved manual check, or automated evidence cannot represent a newly introduced behavior - then record a new evidence-backed DEC entry before adding any manual gate.

---

# DEC-042 - Feat-026 uncertainty-review and bounded-feedback contract
Status: Accepted - Date: 2026-09-17
Owner: `features/feat-026.md` - Affected: `ReviewModel`, `NeedsReview`, `SessionCheckpointStore`, `AppModel+Save`, `AppRoute`/`RootView`/`ReviewOverview`, feat-027 admission
Context: Feat-026 must expose uncertain feat-023 decisions as clear reviewable work and capture bounded feedback without changing picks, the on-device privacy promise, or any versioned contract. The shipped pipeline already emits stable reason codes plus optional scores per decision; the review layer already owns a shared model, persisted edit feedback, and recoverable routes.
Decision: Derive the Needs Review queue deterministically from persisted `Decision` reasons/scores only (priority borderlineQuality > faceTradeoff > similarAlternatives > secondMomentView > coverageCut; band 0.05 around the live `lowQualityThreshold`, cap 30 in priority/source order; `assetUnavailable`/eligibility/floor/duplicate-loser decisions never queue). Persist one versioned aggregate snapshot per session (`schemaVersion` 1: session/engine/counts per fixed reason vocabulary, no identifiers/pixels/faces/EXIF/free text) through new `uncertainty-feedback/` rows with the existing ordered-hook and delete rules. Present after the contract is fixed via the `needsReview` route off S09 (existing surfaces handle the actions; deterministic flow untouched).
Alternatives considered: score-only ranking without reason codes (rejected - opaque, no actionable copy); persisting per-photo uncertainty rows (rejected - grows the store with photo-linked data); feedback learning/taste profiles (rejected - post-MVP per DEC-020/DEC-021); rerunning the engine on review edits (rejected - violates the no-rerun review rule); a queue over live analysis reads (rejected - needs cluster/moment objects that are not persisted).
Evidence: feat-026 proof binary (REAL shipped Domain + config + FileStore verbatim, 16/16 md5-match; harness main `a5a02938…`, binary `b92580f7…`) on hand-built plus REAL-engine fixtures — named U1–U9 38 PASS / 0 FAIL, double-run byte-identical (`2f7d63f3…`), partial/unavailable excluded, store round-trip + corrupt/version/absent recovery PASS; `./init.sh` PASS (format 0/65, `swiftlint --strict` 0 violations/65 files, Simulator build SUCCEEDED, SKIP [test] per policy).
Consequences: uncertain decisions surface first with actionable reasons while deterministic picks, versions (`analysisVersion` 4, `engineVersion` 3), clusters/moments, and privacy/redaction rules hold; feat-027 inherits the admitted ambiguity vocabulary (borderlineQuality, faceTradeoff, similarAlternatives, secondMomentView, coverageCut) for its jury gate.
Reconsider when: a named residual failure shows the band, cap, or vocabulary hides a consequential ambiguity, or feat-027 jury evidence requires an admitted case the vocabulary cannot express - then record a new evidence-backed entry before changing thresholds or reasons.

# DEC-043 - Feat-026 review routing and cleanup-race contract
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-026.md` - Affected: `NeedsReview`, `SessionCheckpointStore`, `AppModel+Save`, `scripts/proof/feat-026.sh`, feat-027 admission
Context: Codex review found two runtime gaps behind the DEC-042 contract: (1) Needs Review action buttons toggled selection instead of routing to the Inspect/Similar/Compare surfaces, and (2) feedback writes from the unstructured `Task` in `AppModel+Save` could recreate `feedback/` + `uncertainty-feedback/` rows after discard/reset/finish deletes; proof claims also lacked a durable tracked harness, and the plan drifted from runtime/DEC-042 (band and snapshot schema wording).
Decision: Route each Needs Review action without mutating selection (inspect/compare-moment open the queue-scoped S11 detail pager with S21 one tap deeper; similar routes to S12; add-back routes to S13; the standalone selection toggle stays separate). Tombstone sessions in `SessionCheckpointStore` on every feedback delete (`deleteFeedback`/`deleteUncertaintyFeedback` insert first), drop `saveFeedback`/`saveUncertaintyFeedback` writes for tombstoned sessions, reopen only on a live `beginReview` re-entry, and capture the hook's own model in `AppModel+Save` so a stale entry cannot write into a newer same-process review. Keep the durable proof at `scripts/proof/feat-026.sh` (REAL shipped sources verbatim, staged md5-match) covering normal/uncertain/unavailable/recovery/reason/action/persistence/deterministic-rerun/cleanup-race. Reconcile the plan to runtime: score band 0.05 around the live `lowQualityThreshold`, feedback `schemaVersion` 1 carries sessionID/engineVersion/queueSize/resolvedByReason/totalResolved/updatedAt only (no `analysisVersion`); `analysisVersion` 4, `engineVersion` 3, `configVersion` 1 unchanged.
Alternatives considered: per-write generation counters on the hook (rejected - same guarantee with more moving parts than the store tombstone plus model capture); cancelling the unstructured Task at cleanup (rejected - the Task is fire-and-forget with no handle; the drop-at-store rule covers every late writer including actor-queued saves); routing actions through new review surfaces (rejected - S10/S11/S12/S13/S21 already own the surfaces; new routes would split the single selection source of truth).
Evidence: `scripts/proof/feat-026.sh` (REAL shipped Domain + config + FileStore + store + SaveState verbatim, 18/18 md5-match) — U1–U12 57 PASS / 0 FAIL, deterministic payload + queue double-run identical, cleanup-race (late writes drop, double-delete idempotent, reopen re-enables, disk-failure retry preserved) PASS; `./init.sh` PASS (format, `swiftlint --strict`, Simulator build, SKIP [test] per policy).
Reconsider when: a named residual failure shows a routed surface cannot resolve its action, a same-process session re-entry must keep prior tombstones, or feat-027 jury evidence requires a new action or persisted field - then record a new evidence-backed entry before changing routes, guards, or schema.

---

# DEC-044 - Feat-026 uncertainty-feedback exact schema and version freeze
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-026.md` - Affected: `UncertaintyFeedbackSnapshot`, `SessionCheckpointStore`, `ReviewModel`, `docs/design-docs/data-model.md`, feat-027 admission
Context: DEC-042 froze the bounded-feedback contract in prose ("session/engine/counts per fixed reason vocabulary") and the shipped `UncertaintyFeedbackSnapshot` carries exactly seven stored fields, but no entry pins the exact field list or states which versions do and do not move. Codex review flagged this schema/metadata drift risk: a future reader could re-add `analysisVersion` to the snapshot or persist `configVersion` inside it, breaking the counts-only and no-migration guarantees.
Decision: Freeze the exact `uncertainty-feedback/<session>.json` schema at `schemaVersion` 1 with exactly these fields and no others: `schemaVersion`, `sessionID`, `engineVersion`, `queueSize`, `resolvedByReason`, `totalResolved`, `updatedAt` (aggregate counts only; no identifiers/pixels/faces/EXIF/free text, no `analysisVersion`). Keep `configVersion` 1 unchanged and NOT persisted in the snapshot. Keep `analysisVersion` 4, `engineVersion` 3, `configVersion` 1 unchanged with no migration: old/corrupt/version-mismatched snapshots load as nil (fresh), never throw.
Alternatives considered: re-adding `analysisVersion` to the snapshot for traceability (rejected - duplicates the analysis-cache version gate, grows a counts-only row with per-run metadata, and contradicts the DEC-042 frozen schema); persisting `configVersion` inside the snapshot (rejected - the snapshot derives from a live-config threshold that is never stored, so a stored copy would drift from the value actually used); leaving the schema prose-only without a DEC entry (rejected - prose drifts, as the feat-026 plan band/schema drift showed; the freeze needs an append-only anchor).
Evidence: `scripts/proof/feat-026.sh` U6 (snapshot counts + JSON no-leak scan + outsider-excluded) and U12 (plan/domain schema reconcile: no `analysisVersion` in the snapshot struct) plus U1 pinned versions (analysis 4 / engine 3 / config 1); `./init.sh` PASS (format, `swiftlint --strict`, Simulator build, SKIP [test] per policy).
Reconsider when: feat-027 jury evidence or a named residual failure requires a new persisted uncertainty field or a version move - then record a new evidence-backed entry before changing the schema or bumping any version.

---

# DEC-045 - Feat-026 review-model ownership and hook lifecycle
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-026.md` - Affected: `AppModel+Save`, `ReviewModel`, `SessionCheckpointStore`, `scripts/proof/feat-026.sh`, feat-027 admission
Context: Codex review found `beginReview` never assigned the built ReviewModel (`reviewModel = model` missing), so `beginReview` returned true while RootView review destinations rendered `ReviewLoadFailedView` and `saveAlbum` guards failed; the installed hook also captured only `weak persist`, so feedback/checkpoint writes silently dropped once the local actor deallocated. The fix must restore a strong lifecycle-safe owner without a retain cycle and without breaking DEC-043 cleanup/tombstone behavior.
Decision: Assign the model (`reviewModel = model`) before routing so the same model backs RootView destinations and save guards. Own the `PersistLatest` actor strongly from the installed hook closure (closure owned by the model, model owned by `reviewModel`), capture the model weakly to avoid a model -> hook -> model cycle, derive the uncertainty snapshot synchronously on the model before hopping to the persistence Task, and keep DEC-043 semantics (cleanup releases `reviewModel` first, then the store tombstone drops late writes; live re-entry reopens). Extend the proof to 21 staged files plus U13 (shipped hook source checks + live REAL ReviewModel hook/re-entry/same-model behavior).
Alternatives considered: capturing the model strongly in the hook (rejected - model -> hook -> model retain cycle keeps review state alive after cleanup); keeping weak-only persist (rejected - the writes it was built to order silently never fire); per-write generation counters or Task cancellation (rejected - more moving parts than the owner + tombstone rule DEC-043 already provides).
Evidence: `scripts/proof/feat-026.sh` (REAL shipped sources verbatim, STAGED-21-MD5-MATCH) — U13 shipped-hook source checks + live REAL ReviewModel hook/re-entry/same-model PASS; full suite 70 PASS / 0 FAIL; `./init.sh` PASS (format, `swiftlint --strict`, Simulator build, SKIP [test] per policy).
Reconsider when: a named residual failure shows the hook lifecycle drops live writes, leaks review state after cleanup, or resurrects tombstoned rows - then record a new evidence-backed entry before changing ownership, capture, or guards.

---

# DEC-046 - Feat-026 feedback writer generation/ownership guard
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-026.md` - Affected: `SessionCheckpointStore`, `AppModel+Save`, `UncertaintyFeedbackSnapshot`, `scripts/proof/feat-026.sh`, feat-027 admission
Context: Codex review found two gaps behind DEC-043/DEC-045: (1) the seven-key uncertainty snapshot schema is not strict on read because synthesized Codable decoding ignores unknown top-level keys, so payloads carrying `configVersion` or arbitrary extra keys decode instead of returning nil per DEC-044; (2) the unstructured hook Task can retain the old `PersistLatest` actor and write an already-derived snapshot after cleanup and same-process reopen, so a stale old-session writer can enter the reopened session even though the tombstone cleared.
Decision: Decode `UncertaintyFeedbackSnapshot` with a custom strict decoder that enumerates top-level keys through an open key type (a `StrictKeys`-keyed container hides unknown keys by design) and throws unless the key set equals exactly the DEC-044 seven; the store's nil-on-any-failure read keeps returning nil (fresh), never throwing. Guard writer lifecycle with a session generation owner: `reopenSession` mints and returns a new UInt64 generation in the same actor call, `beginReview` captures it into the installed `PersistLatest`, every feedback save pins that generation and applies only when it still equals the session's current generation at apply time, and every delete path retires the session (tombstone plus generation bump past every captured writer). Keep DEC-043 semantics (ordinary save failure still throws so the next mutation retries; deletes stay idempotent; live re-entry reopens and a fresh entry installs a fresh hook).
Alternatives considered: leaving synthesized Codable plus an emitted-keys comparison (rejected - it proves what we write, not what we refuse to read); cancelling the unstructured Task at cleanup (rejected - fire-and-forget with no handle, and the actor-queued save is the real stale writer); awaiting/draining old writers before reopen (rejected - no handle to drain, and the generation pin covers every late writer including already-derived snapshots with no rendezvous).
Evidence: `scripts/proof/feat-026.sh` (REAL shipped sources verbatim, STAGED-42-MD5-MATCH) — U6 strict rejected-input cases (`configVersion` + `debugNote` decode-throw) and U9 store-level extra-key rows load nil; U10 stale-generation interleaving (stale pinned writer drops after delete + reopen, fresh retry succeeds with identical totals); U14 live REAL shipped `AppModel` beginReview/hook/re-entry/save-guard plus scripted exporter failure/retry/interleaving; full suite 92 PASS / 0 FAIL; `./init.sh` PASS (format, `swiftlint --strict`, Simulator build, SKIP [test] per policy).
Reconsider when: a named residual failure shows the strict read rejects a legitimate future schema version without a migration entry, or the generation guard drops a live write - then record a new evidence-backed entry before changing decoding, ownership, or guards.

# DEC-047 - Bounded iOS 27 semantic jury contract
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-027.md`, `docs/plans/feat-027.md` - Affected: `SemanticJury`, `SelectionEngine`, `SelectionSessionCoordinator`, `AppContainer`, `curation-runtime-stack.md`
Context: Feat-026 exposes a deterministic Needs Review queue using the fixed uncertainty vocabulary, while the remaining documented quality ceilings include ambiguous group/near-duplicate choices. The optional semantic jury must not become a core dependency, bypass deterministic album invariants, add photo-linked persistence, or make the iOS 26 path nondeterministic. The current SDK exposes Foundation Models for local structured generation; the feature therefore needs an isolated provider seam and a product iOS 27 gate independent of the minimum iOS 26 deployment target.
Decision: Add a `SemanticJuryProvider` seam with an opaque response validated by an exact one-key schema whose only accepted choice values are `chooseA`, `chooseB`, `keepBoth`, and `abstain`. Admit only bounded `faceTradeoff` and `similarAlternatives` pairs that expose a deterministic selected/rejected competing relation; cap candidates at 6 (current integration uses 2), attempts at 4, and each request at 2 seconds with cooperative cancellation. Require iOS 27 availability before image loading/provider invocation; use only on-device Foundation Models, never analytics/network/cloud. Apply `chooseA`/`chooseB` only when both candidates are usable members of one deterministic cluster; keepBoth and abstain, plus every unavailable/invalid/timeout/cancel/failure/unadmitted case, return the unchanged deterministic result. Keep engine version 3 and add no persisted field or jury row.
Alternatives considered: call Foundation Models on every photo (rejected - unbounded cost and violates tier routing); run it on iOS 26 (rejected - baseline must remain deterministic and complete); allow free-form/extra response fields (rejected - unsafe schema and candidate confusion); let keepBoth bypass cluster/album invariants (rejected - model output cannot override deterministic rules); persist prompts/responses or photo-linked jury rows (rejected - unnecessary privacy and retention risk); add a new dependency/model download/cloud provider (rejected - native on-device stack is sufficient).
Evidence: feat-026 DEC-042/043/044/045/046 freeze the uncertainty vocabulary, review ownership, exact aggregate-only persistence, and generation guards. `FoundationModels.framework` is present in the installed SDK; its structured `LanguageModelSession` API compiles for the iOS 26 deployment target while the production adapter is explicitly gated to iOS 27. The feat-027 focused proof and final `./init.sh` provide deterministic Golden-shaped, strict-schema, timeout/cancellation/failure, and iOS 26 zero-provider-call evidence.
Consequences: iOS 26 and all failure paths retain the prior deterministic picks; iOS 27 may improve only admitted high-impact comparisons and only through validated outputs. Jury requests/responses/images remain run-local and diagnostics are aggregate enum values with no identifiers or raw errors. No migration, model artifact, cloud path, analytics event, or new persistent contract is introduced.
Reconsider when: a reproducible residual failure shows the admitted vocabulary or pair relation misses a consequential ambiguity, iOS 27 evidence shows a safe benefit beyond the current cap, or a future SDK exposes a richer image-input contract requiring a new adapter decision; then add a new evidence-backed DEC before changing admission, schema, timeout, persistence, or OS gate.

# DEC-048 - Feat-027 image-backed in-place integration and hard timeout
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-027.md`, `docs/plans/feat-027.md` - Affected: `SemanticJury`, `SelectionEngine`, `SelectionSessionCoordinator`, `scripts/proof/feat-027.sh`, `scripts/proof/feat-027-proof.swift`
Context: Review found that the Foundation Models adapter only described candidate images in text, the coordinator reran global selection after a jury result, the proof did not compile the real engine/coordinator boundary, the timeout task-group scope could wait for a provider that ignored cancellation, and the diagnostics plan omitted `deterministicFallback`.
Decision: Keep the existing run-local `CGImage` loading in the coordinator and attach each candidate image to the iOS 27 Foundation Models multimodal prompt; never downgrade to text-only input. Apply validated `chooseA`/`chooseB` results through an in-place engine seam that revalidates one deterministic duplicate cluster, requires a usable replacement, and swaps only the compared selected/rejected pair while preserving every unrelated selected ID. Replace the task-group timeout with a hard-bounded continuation race that cancels losing work without waiting for a non-cooperative provider; retain the four-request cap and all deterministic fallbacks. Add the omitted `deterministicFallback` diagnostic to the plan/runtime contract and make the proof compile/exercise the real integration boundary.
Alternatives considered: rerun `SelectionEngine.select` with jury feedback (rejected - global diversity can change unrelated selections); keep text-only model prompts (rejected - the jury would not inspect candidate pixels); retain task-group timeout (rejected - structured scope waits for non-cooperative children); add persistence or telemetry (rejected - outside scope and privacy contract).
Evidence: `scripts/proof/feat-027.sh` EXIT 0 with `STAGED-MATCH 26`, real engine/coordinator source compilation, request ordering, iOS 26 `providerCalls=0 imageLoads=0`, image-backed iOS 27 requests, same-cluster-only and unrelated-preservation checks, generic provider failure, strict schema, non-cooperative timeout, cancellation, bounds, and Golden-shaped deterministic checks; `./init.sh` EXIT 0; no test artifacts/framework.
Consequences: iOS 26 remains deterministic and performs no jury image loads/provider calls; iOS 27 jury output can affect only the compared deterministic cluster; timed-out provider work is cancelled and never blocks result completion; no persisted schema, model artifact, network path, analytics, or dependency is introduced.
Reconsider when: a future SDK changes the image-attachment API, a provider cannot be stopped after cancellation, or fixture evidence shows that preserving unrelated picks is insufficient for a new jury behavior; add a new evidence-backed DEC before changing the seam or bounds.

# DEC-049 - Feat-027 Foundation Models image-attachment SDK capability seam
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-027.md`, `docs/plans/feat-027.md` - Affected: `SemanticJury`
Context: The supported workstation uses Apple Swift 6.3.3 with the installed iOS 26.5 SDK. That SDK imports `FoundationModels` and exposes `LanguageModelSession`, but its module interface has no `Attachment`; Apple documents `Attachment` as iOS 27.0+. A `#if compiler(>=6.4)` guard therefore made the real image path unavailable by compiler version, while removing it would make the current SDK fail to compile.
Decision: Keep the adapter available and executable on the current toolchain, but select the typed image-input branch by the explicit `FOUNDATION_MODELS_IMAGE_ATTACHMENTS` SDK capability condition, not a compiler-version condition. The current SDK branch throws typed `SemanticJuryError.unavailable` after the iOS 27 availability gate and never sends a text-only request; an iOS 27 SDK build that defines the condition compiles the real `Attachment(CGImage)` prompt path and sends the coordinator's run-local pixels. Deterministic fallback, the iOS 26 gate, privacy boundary, and minimum deployment target remain unchanged.
Alternatives considered: retain `#if compiler(>=6.4)` (rejected - couples behavior to compiler version and leaves supported Swift 6.3.3 without an executable adapter seam); downgrade to text-only prompting on the current SDK (rejected - violates image-backed jury contract); use runtime reflection or private symbols for `Attachment` (rejected - unsafe, unverifiable, and not an SDK-supported API); lower the deployment target (rejected - DEC-TBD-001).
Evidence: `xcrun swiftc --version` reports Apple Swift 6.3.3; `xcrun --sdk iphonesimulator --show-sdk-version` reports 26.5; the installed `FoundationModels.swiftinterface` contains `LanguageModelSession` but no `Attachment`; Apple Foundation Models documentation marks `Attachment` iOS 27.0+. `scripts/proof/feat-027.sh` EXIT 0 compiles the current typed-unavailable seam and separately proves coordinator-loaded in-memory images reach the provider boundary; `./init.sh` remains required for final verification.
Consequences: Current builds remain compile-safe and deterministic when the iOS 27 image-input SDK is unavailable. An iOS 27 SDK build must define the capability condition in its SDK-specific configuration to activate the real multimodal adapter; no source or API fallback may silently turn it into text-only inference. Reconsider when the repository adopts an iOS 27 SDK/toolchain and can record a real-device or Simulator image-backed Foundation Models run.

# DEC-050 - Feat-028 closes V2 with the deterministic ranker
Status: Superseded by DEC-051 · Date: 2026-09-18
Owner: `features/feat-028.md`, `docs/plans/feat-028.md` - Affected: `curation-runtime-stack.md`, ranker evaluation gate
Context: The ranker gate requires a frozen deterministic baseline, label provenance, prohibited-data boundary, disjoint evaluation splits, metrics, thresholds, rollback, and reproducible smoke/Golden-shaped/trip-shaped/1k evidence. A learned ranker is allowed only when the current baseline exposes a material measurable gap; no admissible user-data labels or named residual baseline failure exists in this repository.
Decision: Retain the shipped deterministic `QualityScorer` and close the V2 ranker phase. Freeze `analysisVersion 4`, `engineVersion 3`, `configVersion 1`, the current centralized selection configuration, and deterministic tie-breaks. Use only `deterministic-synthetic-v1` structural labels for this gate, with no fit or calibration split and no persisted labels. Do not evaluate, vendor, or route a learning-to-rank model; add no model artifact, dependency, field, migration, network path, telemetry, or fallback adapter.
Alternatives considered: evaluate a candidate from synthetic labels (rejected - those labels are structural proof inputs, not production taste or approved global-training data); accept a ranker without a named baseline gap (rejected - adds privacy, license, size, latency, thermal, and rollback risk without measured benefit); lower existing quality gates (rejected - would falsify the product contract); keep the deterministic baseline (accepted - all ranker-admission metrics pass on the disjoint focused proof shapes and replay is byte-stable).
Evidence: `./scripts/proof/feat-028.sh` EXIT 0 with `STAGED-MATCH 17`; smoke 60, Golden-shaped 200, trip-shaped 150, and H-1000 1,000 all pass exact deterministic replay, good-selection `1.000`, bad-pick `0.000`, duplicate leakage `0.000`, best-shot `1.000`, and moment coverage `1.000`; outputs and synthetic-label caveat are recorded in `docs/plans/feat-028.md` and `features/feat-028.md`. Prior feat-023/026/027 proof records preserve the same deterministic engine and show no unresolved named baseline failure. Final `./init.sh` evidence is recorded in the feature handoff.
Consequences: V2 remains on-device and deterministic on iOS 26, with the optional iOS 27 semantic jury and its deterministic fallback unchanged. No ranker migration or runtime rollback is needed; rollback is limited to the feature/plan/decision/runtime-status/proof records. A future ranker requires a new decision after a named residual failure, an approved non-user label source, and the full quality/privacy/license/performance/version/fallback gate.
Reconsider when: a newly frozen admissible label set shows a repeatable residual failure after deterministic and jury paths, and a specific candidate demonstrates a material gain without violating existing recall, coverage, privacy, license, performance, or fallback gates.
# DEC-051 - Feat-028 independent oracle and recall gate remediation
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-028.md`, `docs/plans/feat-028.md` - Affected: `scripts/proof/feat-028-proof.swift`, ranker evaluation gate
Context: Review found that feat-028 derived `MUST_KEEP`/`ACCEPTABLE`/`REJECT` from the same scalar rank facts used to build `PhotoAnalysis`, so the prior perfect metrics were not independent evidence. The owner contract also requires the `manual-qa.md` Must-Keep Recall reference target (`>=95%`), while the prior proof reported sub-target compression ratios and did not assert Recall.
Decision: Keep DEC-050's no-ranker product decision, but replace the label source with `fixture-oracle-v2`, a repository-local static annotation manifest that never reads analyses, scalar scores, rank order, or engine output. Use the same manifest semantics across disjoint Smoke 60 (15 groups x 4), Golden-shaped 200 (20 x 10), Trip-shaped 150 (30 x 5), and H-1000 (1,000; 50 x 20) fixtures; assert full label coverage, cross-split asset-ID disjointness, complete frozen selection configuration, frozen weights/bonuses, tie-break policy, oracle/rank disagreement, and Must-Keep Recall `>=95%` before the remaining quality gates. No external benchmark, user data, app code, model, dependency, persistence, network path, telemetry, or test artifact is introduced.
Alternatives considered: retain rank-derived labels (rejected - permits circular perfect metrics); lower or omit the owner Recall target (rejected - falsifies the owner contract); claim an approved exception (rejected - the corrected fixture shape makes the existing target directly assertable); admit a learned ranker (rejected - no named residual baseline gap or approved label source).
Evidence: `./scripts/proof/feat-028.sh` EXIT 0 with `STAGED-MATCH 17`; independent oracle/config/split gates PASS; Smoke `60→15`, Golden-shaped `200→20`, Trip-shaped `150→30`, H-1000 `1,000→50`, each Recall/Good Selection/Best-Shot/Moment Coverage `1.000`, Bad Pick/Duplicate Leakage `0.000`, exact deterministic double replay; no external benchmark result is claimed. `./init.sh` EXIT 0 — SwiftFormat PASS (`2/87` files formatted), SwiftLint strict PASS (`0` violations in `66` files), Simulator build `BUILD SUCCEEDED`, tests `SKIP` by DEC-040; `git diff --check` clean and no `*Test*.swift` files found.
Consequences: DEC-050's deterministic no-ranker outcome remains unchanged, but its evidence is now independent and Recall is an asserted owner gate rather than compression context. Reconsider only after a named residual failure and a newly approved non-user label source satisfy the full quality/privacy/license/performance/version/fallback gate.
Reconsider when: a future admissible annotation set or named residual failure requires a different oracle, split, or metric contract; add a new evidence-backed decision before changing the gate.

# DEC-052 - Feat-028 proof contract completion
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-028.md`, `docs/plans/feat-028.md` - Affected: `scripts/proof/feat-028-proof.swift`, ranker evaluation gate, metric ledger
Context: Follow-up review found four remaining evidence-contract gaps: the authored oracle still made every MUST_KEEP row the rank winner; tie-break values were printed but not behaviorally exercised; Duplicate Leakage used selected groups rather than the owner denominator of total selected; and DEC-050 retained stale provenance wording after DEC-051.
Decision: Keep DEC-050's no-ranker product outcome and DEC-051's independent-evidence direction. Version the repository-local oracle as `fixture-oracle-v3` with authored rows and an explicit H-1000 MUST_KEEP-vs-rank mismatch/selection case; execute equal-score fixtures that assert edited > favorite > pixel-area > asset-ID under reversed input order; compute Duplicate Leakage as needless repeat selections / total selected and assert that denominator; and keep DEC-050 historical text append-only while marking it Superseded by DEC-051. No owner gate is lowered.
Alternatives considered: retain a rank-winner-only MUST_KEEP row (rejected - circular evidence remains); print tie-break configuration without exercising behavior (rejected - values are not proof); retain selected-group denominator (rejected - contradicts the owner metric contract); rewrite DEC-050 history (rejected - violates append-only decision-log rules).
Evidence: `./scripts/proof/feat-028.sh` EXIT 0 (`STAGED-MATCH 17`): explicit H-1000 rank-winner/MUST_KEEP mismatch and selection assertion PASS; four equal-score tie-break fixtures and reversed-input replay PASS; Smoke/Golden/Trip/H-1000 Recall `1.000/1.000/1.000/0.980`, Good Selection `1.000/1.000/1.000/0.980`, Bad Pick `0.000/0.000/0.000/0.020`, Duplicate Leakage `0.000` with selected-output denominators `15/20/30/50`, Best-Shot `1.000/1.000/1.000/0.980`, Moment Coverage `1.000` all; `./init.sh` EXIT 0 (format PASS, SwiftLint strict PASS, Simulator build SUCCEEDED, tests SKIP by DEC-040). No app code, user data, model, dependency, persistence, network path, telemetry, or test artifact is introduced.
Consequences: deterministic no-ranker behavior and all existing Recall, Good Selection, Bad Pick, Duplicate Leakage, Best-Shot, Moment Coverage, smoke/Golden/trip/H-1000, privacy, split, and no-test gates remain unchanged; only proof/docs evidence is corrected.
Reconsider when: a future admissible annotation set or named residual failure requires a new oracle, metric contract, or ranker decision; add another evidence-backed decision before changing these gates.

# DEC-053 - Feat-031 bounded local Qwen quality mode
Status: Accepted - Date: 2026-09-18
Owner: `features/feat-031.md`, `docs/plans/feat-031.md` - Affected: quality-mode policy, MLX runtime, selection runner, model delivery, review provenance
Context: The shipped native engine protects large-set throughput and deterministic fallback, but the accepted feat-031 target requires better coverage and best-shot choices for 1–100 photos using actual image evidence.
Decision: Add an explicit quality-mode route for at most 100 available assets. Analyze all available assets before pruning, keep coverage and retake groups separate, use revision-pinned local MLX Swift LM/MLXVLM Qwen artifacts only after manifest and image-sensitive gates, and preserve `qualityNative` as the complete degraded route. Keep the legacy native route and iOS 27 Foundation Models jury unchanged outside this mode. Store only compact execution metadata; keep images, prompts, raw output, tensors, and pair judgments transient.
Alternatives considered: route every source through Qwen (rejected - breaks large-set budgets); replace the native engine (rejected - removes rollback); use text-only Qwen or prerecorded answers (rejected - cannot establish image inference); download implicitly during Analyze (rejected - violates disclosure and offline review).
Reconsider when: independent corpus evidence fails to show incremental value, the admitted runtime cannot meet its resource envelope, or a future Apple/local API provides a lower-cost equivalent.

## 3. Deferred TBDs (structured — no answers invented)

**DEC-TBD-001 — Min iOS 26 (Accepted).**
Owner: 07. Affected: 05, 08. Decision: MVP targets iOS 26 minimum, per needed
Vision/SwiftUI/PhotoKit APIs and store distribution evidence in original docs.
Rationale: avoids API gaps from targeting lower; values/APIs owned in 07.
Risk: lost users on older OS. Reconsider when: device-matrix data says otherwise.

**DEC-TBD-002 — File-based Codable persistence, no database for MVP
(Superseded by DEC-054 for the pivot workspace).**
Owner: 05, 06. Historical decision: simplest persistence that fit the former
MVP volume and lifecycle; no SwiftData/Core Data/tiny DB for that scope.
DEC-054 replaces its workspace portion with SwiftData `ReviewScope`,
workspace-item state, and migration marker/store infrastructure. Replacement
owners: [`data-model.md`](data-model.md),
[`ios-architecture.md`](ios-architecture.md), and
[`docs/plans/feat-033.md`](../plans/feat-033.md). Its file/cache treatment of
analyses, thumbnails, checkpoints, and model artifacts remains current.
Risk and history are preserved; do not reinterpret this entry as prohibiting
the explicitly migrated feat-035/036 operation entities.

**DEC-TBD-003 — Analytics provider (Deferred).**
Owner: 11. Options: none → Apple metrics → light custom → third-party. Must satisfy 09 + DEC-018.
Risk: privacy breach. Trigger: first metrics need.

**DEC-TBD-004 — Monetization (Deferred).**
Owner: 01. Options: paid / unlock / sub / freemium / free-cap. Must not warp MVP arch.
Risk: paywall rework. Trigger: pre-launch.

**DEC-TBD-005 — Export to new Photos album, non-destructive, collision-safe
(Accepted in part; no-original-deletion portion superseded by DEC-054).**
Owner: 02, 07. The accepted album-save portion remains: save the approved
result as a new collision-safe Photos album without modifying originals;
mechanics are owned by [`apple-frameworks.md`](apple-frameworks.md),
[`ux-flows.md`](../product-specs/ux-flows.md), and feat-035. DEC-054
supersedes only the former no-original-deletion portion by admitting a
separate, user-confirmed cleanup deletion lane governed by
[`review-rules.md`](../product-specs/review-rules.md),
[`apple-frameworks.md`](apple-frameworks.md), and
[`docs/plans/feat-036.md`](../plans/feat-036.md). Risk: permission surprise.

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

---

# DEC-054 — Assisted review and cleanup pivot

**Superseded in part by DEC-055:** entry intents and shared-workspace product priority.
Independent choices, exact-set deletion, and retained migration/operation evidence remain applicable.

**Status:** Accepted · **Date:** 2026-09-21
**Owner:** [`product.md`](../product-specs/product.md), [`review-rules.md`](../product-specs/review-rules.md), [`data-model.md`](data-model.md), [`ios-architecture.md`](ios-architecture.md)
**Affected:** `ux-flows.md`, `ui-copy.md`, `photo-intelligence.md`, `apple-frameworks.md`, `privacy.md`, `performance.md`, `roadmap.md`, feat-031–037

The product is now assisted photo review/classification/grouping. Cleanup and
album are entry intents into one shared workspace. Cleanup disposition, album
membership, review progress, and immutable analysis facts/suggestions are
independent; suggestions never mutate choices. Original deletion is a separate
explicit operation requiring an exact reviewed set, full Photos read-write
access, confirmation, persisted digest, and per-ID outcomes. Limited access may
review/stage but cannot begin deletion. Album save is separate and never clears
cleanup state.

The file-only persistence constraint in DEC-TBD-002 is superseded for the
durable workspace: SwiftData owns `ReviewScope`, workspace-item state, and the
migration marker/store; files/cache remain the home for analyses, thumbnails,
checkpoints, and model artifacts. Album-save operation state is owned by
feat-035 and deletion operation state by feat-036, each through its own
explicit SwiftData schema migration. Replacement owners are
[`data-model.md`](data-model.md), [`ios-architecture.md`](ios-architecture.md),
[`review-rules.md`](../product-specs/review-rules.md), and the linked
feature plans.

The no-original-deletion portion of DEC-TBD-005 is superseded: the accepted
replacement permits only the separately gated, user-confirmed deletion flow in
[`review-rules.md`](../product-specs/review-rules.md) and
[`apple-frameworks.md`](apple-frameworks.md). DEC-TBD-005's new,
non-destructive album-save portion remains accepted and is owned by
[`apple-frameworks.md`](apple-frameworks.md) and feat-035.

Legacy selected/restored imports as album included; rejected/removed imports as
album excluded; cleanup is undecided and progress unseen. The legacy source
remains until a migration commit marker.

This supersedes the active behavior implications of earlier auto-curation and
no-deletion wording for the new pivot, while preserving those entries as
history. It does not admit Qwen or any new model. Reconsider on a safety,
privacy, license, runtime, or evidence-backed product change.

## DEC-054 clarification — review actions and interruption

**Status:** Accepted by the user · **Date:** 2026-09-21

The approved clarification makes action effects explicit instead of deriving
them from entry intent. Unstage returns to undecided; reviewed progress requires
Mark Reviewed. Pair actions name their dimension, and suggestion acceptance
previews its exact proposal without staging deletion. See the canonical
[action transitions](../product-specs/review-rules.md#review-action-transitions).

feat-034 owns the minimal native suggestion adapter/consumer contract;
feat-037 extends it rather than blocking the earlier review feature. See
[shared review input](photo-intelligence.md#shared-review-input-contract).

Lost deletion completion remains uncertain; missing assets do not prove app
deletion. Changed pre-start sets require new confirmation. See the
[operation state machine](data-model.md#deletion-operation-state-machine).
These choices favor explicit user control and truthful outcomes over implicit
undo history, automatic review completion, or inferred deletion success.

## DEC-055 — Similarity-first photo organization companion

**Status:** Accepted direction by the user · **Date:** 2026-09-23.
**Owners:** [product](../product-specs/product.md), [organization rules](../product-specs/organization-rules.md), [architecture](ios-architecture.md).
**Affected:** Current owner documents, README, AGENTS, roadmap, feat-039–047.

### Context

User evaluation found mixed cleanup/album intent, unclear analysis results, invisible grouping, and unreliable access to photo inspection.
The current session-based architecture has reusable services but does not provide a continuous organization catalog.
Completed builds and historical feature records do not establish useful grouping or label accuracy.

### Decision

Build a companion to Apple Photos, not an editor or a full replacement photo manager.
Prioritize comparison groups, then useful overlapping labels and combined filters.
Duplicates/near-copies and comparable same-scene retakes form comparison groups.
Shared topics across unrelated scenes connect through labels instead.

Index authorized Photos references and enrich them incrementally without copying originals.
Users inspect and select photos before choosing label, album, or cleanup actions.
Automatic evidence and durable user corrections remain separate.
Existing explicit deletion safeguards and independent operation recovery remain required.

### Alternatives

| Alternative | Reason not selected |
|---|---|
| Patch the shared review screen only | Leaves session picks and mixed intent as the product center |
| Separate cleanup and album products | Organizes around the action before helping users find the relevant photos |
| Replace Apple Photos | Expands into editing and everyday management outside the user's goal |

### Consequences and limits

The pivot needs a persistent catalog, incremental jobs, independent grouping, taxonomy/corrections, discovery, and exact-set action integration.
feat-039 records contracts; feat-040–047 implement them after approval.
Detailed proposed schema/provider choices remain owned by their readiness plans.
No model, taxonomy completeness, or numeric accuracy claim is admitted by this decision.
Qwen remains frozen. Current local-only and verification policies remain unchanged.

**Risk:** Broad labels or false comparison groups can mislead user decisions.
**Reconsider when:** Evidence shows the group/label distinction or local runtime cannot support the intended organization tasks.
