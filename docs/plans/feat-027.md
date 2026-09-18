# feat-027 execution plan

Goal: add an optional, bounded iOS 27 semantic jury around the deterministic selection engine. The jury may resolve a small set of approved ambiguity pairs, but every iOS 26, unavailable, invalid, cancelled, timed-out, failed, unadmitted, or unsafe result falls back to the existing deterministic selection.

## Scope and ownership

Owns the OS availability gate, `SemanticJuryProvider` protocol, request admission and limits, exact choice schema, strict response validation, bounded timeout/cancellation, diagnostics, deterministic fallback, and selection integration. The app remains on-device and does not persist jury requests, images, responses, candidate IDs, telemetry, or analytics.

Production files:

- `apps/photo-curator/Domain/Selection/SemanticJury.swift` — protocol, request/response schema, policy, Foundation Models adapter, no-op provider, validation, and engine override value.
- `apps/photo-curator/Domain/Selection/SelectionEngine.swift` — apply only validated chooseA/chooseB results within one deterministic duplicate cluster; keepBoth/abstain are safe no-ops.
- `apps/photo-curator/Services/Session/SelectionSessionCoordinator.swift` — gate before image loading, build approved requests from feat-026 decisions, run bounded jury calls, and apply validated overrides in place while preserving unrelated engine output.
- `apps/photo-curator/App/AppContainer.swift` and `App/AppModel.swift` — inject the provider without changing review/persistence ownership.
- `scripts/proof/feat-027.sh` and `scripts/proof/feat-027-proof.swift` — proof-only Golden-shaped fixtures and failure-path checks; no test target/framework.

Documentation records the frozen contract and decision in this plan, `features/feat-027.md`, `docs/design-docs/curation-runtime-stack.md`, and DEC-047/DEC-048/DEC-049.

Explicitly not in scope: new persisted analysis/result fields, engine/config/schema version bumps, cloud inference, analytics, photo-linked jury rows, model downloads or vendored weights, new dependencies, changes to feat-026 review routing/feedback, changes to deterministic iOS 26 selection, or automated test targets.

## Frozen contract

### Availability and provider

- `SemanticJuryProvider` is an async, `Sendable` seam returning an opaque JSON response; the router owns decoding and validation.
- Production construction uses the Foundation Models adapter, but both router and adapter require `#available(iOS 27.0, *)`. iOS 26 exits before candidate image loading or provider invocation.
- Foundation Models remains local-only. No alternate provider or network path exists. The no-op provider is the deterministic fallback.

### Admission and request policy

- Inputs come only from the persisted `SelectionResult` decisions plus already-persisted `PhotoAnalysis` scalar facts and in-memory `CGImage` analysis images.
- Approved ambiguity vocabulary is the feat-026 `UncertaintyReason` set. Only `faceTradeoff` and `similarAlternatives` can currently admit a pair because they expose a deterministic selected/rejected competing relation. `borderlineQuality`, `secondMomentView`, and `coverageCut` remain deterministic fallback cases until a pair can be proven without guessing.
- Candidate count is exactly 2 for current integration and never exceeds the policy ceiling of 6; IDs are unique and candidates must carry local images. At most 4 requests are attempted per selection run.
- Requests are processed in stable decision/source order. Each provider call has a 2-second timeout, checks cooperative cancellation, and never starts work after cancellation. A run is bounded to four attempts and does not block deterministic completion indefinitely.
- Diagnostics are an in-memory enum (`notAvailable`, `notAdmitted`, `invalid`, `timedOut`, `cancelled`, `failed`, `accepted`, `deterministicFallback`); diagnostics contain no IDs, pixels, prompts, model text, or raw errors and are never sent to analytics or persisted.

### Schema and fallback

- The only accepted choice strings are exactly `chooseA`, `chooseB`, `keepBoth`, and `abstain`.
- The response object has exactly one top-level key, `choice`; unknown/missing keys, invalid strings, malformed JSON, incomplete output, and candidate-set mismatches are invalid.
- `chooseA`/`chooseB` become an override only when both IDs belong to the same deterministic duplicate cluster and the chosen candidate is usable. `keepBoth` cannot bypass duplicate/moment/album invariants and therefore falls back in this pair integration; `abstain` is always deterministic fallback.
- Any unavailable/invalid/timeout/cancel/failure/unadmitted/unsafe response leaves the original engine result byte-for-byte equivalent in selected/rejected IDs and decisions. Engine version remains 3 because no persisted schema or deterministic baseline changes.

### Foundation Models adapter

The adapter asks one narrow comparison question and requests the strict one-field response with greedy sampling and a small response-token cap. The coordinator supplies each candidate's in-memory `CGImage`; when the iOS 27 SDK exposes the typed image-input API, the adapter attaches those pixels with Foundation Models `Attachment` values in the prompt and never falls back to a text-only jury request. The current iOS 26.5 SDK exposes Foundation Models but not `Attachment`, so the compile-safe adapter seam throws typed unavailable until an iOS 27 SDK build enables `FOUNDATION_MODELS_IMAGE_ATTACHMENTS`; this is an SDK capability boundary, not a compiler-version gate. Candidate images stay in memory in the provider request; no image or response is stored. The adapter uses only on-device Foundation Models and throws typed unavailable/failure errors when the model cannot answer; the router maps every error to deterministic fallback.

## Integration sequence

1. Activate feat-027 and record DEC-047 before source edits.
2. Add the isolated protocol/policy/schema/adapter and proof seam.
3. Add optional jury overrides to `SelectionEngine`, preserving existing defaults and invariants.
4. Gate the coordinator before image loading, invoke only admitted requests, and apply validated overrides through the in-place engine seam.
5. Inject the provider in the live container; keep iOS 26 on the existing path.
6. Run the focused proof once, then `./init.sh` once after implementation. Record exact commands, fixture shape, PASS/FAIL totals, fallback and iOS 26 evidence, clean diff, no-test evidence, acceptance, handoff, and next action.

## Verification and rollback

The focused proof compiles the real shipped jury, policy, request factory, `SelectionEngine`, and `SelectionSessionCoordinator` integration boundary verbatim for the Simulator. It exercises request-factory source ordering, coordinator iOS 26 zero-call/image-load gating, in-memory candidate images reaching the provider, validated same-cluster swaps with unrelated selected-ID preservation, cross-cluster no-op behavior, generic provider failure fallback, strict schema rejection, safe choices, unavailable/timeout/cancellation fallback, candidate bounds, and repeat determinism. Timeout proof uses an ignoring-cancellation provider, asserts elapsed time below 2.75 seconds for the 2-second policy bound, and verifies timed-out request image leases are released. `./init.sh` must pass with no test target, framework, or `*Test*.swift` file.

Rollback removes the jury source/injection and reverts the optional engine parameter/coordinator call; the default empty override preserves the pre-feature deterministic path. No persisted migration is needed.

## Verification record

- `scripts/proof/feat-027.sh` EXIT 0: `STAGED-MATCH 26`, real shipped `SelectionEngine` + `SelectionSessionCoordinator` sources, Simulator `simctl spawn`; request factory ordering PASS; iOS 26 `providerCalls=0 imageLoads=0`; iOS 27 coordinator accepted two image-backed `chooseB` requests and preserved unrelated `b0`; cross-cluster and generic provider-failure deterministic fallback PASS; strict schema four invalid rows; safe `keepBoth`/`abstain`, bounds, unavailable, cancellation, and Golden-shaped `candidates=200 requests=100 attempts=4` all PASS. Non-cooperative timeout returned in 2,073 ms (<2.75 s) and confirmed image cleanup; `NATIVE adapter iOS27-gated current-SDK fallback PASS`; `RESULT PASS`. The real `Attachment` branch is enabled only by the iOS 27 SDK capability flag.
- `./init.sh` EXIT 0: format PASS, `swiftlint --strict` PASS, Simulator build SUCCEEDED, test SKIP under DEC-040.
- `git diff --check` PASS; no `*Test*.swift` files; no test target/framework. No blockers. Rollback remains the source/injection revert described above.
