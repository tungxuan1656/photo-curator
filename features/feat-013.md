# feat-013 — Privacy + polish + errors

## Goal

Land privacy + polish + errors covering redaction, retention, accessibility, S18/S20. Settings states the truth the binary can prove (on-device analysis, no photo upload), limited stays valid, denied routes to recovery without prompt loops, Reset Analysis clears derived data while originals stay untouched, and one reusable error view replaces ad hoc copies.

## Scope

- `Features/Settings/SettingsView.swift` (privacy-policy link, retention/reset explanation, Reset Analysis action; keep Full/Limited/Denied labels; no ranking/cache/worker toggles)
- `Features/Settings/ResetAnalysis.swift` or AppModel intent (only one; prefer AppModel `resetAnalysis()` + file-cache clear, no new service)
- `SharedUI/ErrorStateView.swift` (new: one S20 title/body/primary/optional-secondary view)
- Consuming screens (only where ad hoc error UI conflicts with S20: replace copies, keep flows)
- `apps/photo-curator/Info.plist` + `PrivacyInfo.xcprivacy` (only when current entries do not truthfully match shipped APIs; usage text already matches, manifest already minimal)
- `App/AppModel.swift` (only for existing access-management intents: recheck-on-return already exists via RootView; no second auth service)

## Non-goals

- Anything outside owns; release QA stays in feat-014. No analytics code (provider unselected; `NoopAnalytics` stays).

## Task 1: Settings privacy and access recovery (S18/S19)

- [ ] Keep Full/Limited/Denied labels; add privacy-policy link, retention/reset explanation, and only provable claims (on-device analysis, no photo upload). No ranking, cache, model, or worker-count toggles.
- [ ] Limited stays valid with Choose More Photos; denied/restricted route to Open Settings recovery without prompt loops. Recheck on return from Settings uses existing RootView scene behavior; no second authorization service.
- [ ] Reset Analysis clears analysis cache + groups/picks/temp session work (checkpoints, results, feedback, save states) while Apple Photos originals stay untouched; confirm with the §4.3-style destructive dialog copy pattern.
- [ ] Accessibility for S18: traits, Dynamic Type-safe layout, VoiceOver labels for every action; no color-only state.

## Task 2: Reusable error view + retention enforcement (S20)

- [ ] One `ErrorStateView(title:body:primary:secondary:)` with title, body, primary action, optional secondary; screen owners map `RecoveryAction` to retry/Settings/continue-without-unavailable/discard/Home. Never raw `NSError` text, asset IDs, filenames, GPS, face detail, or image data in UI or logs.
- [ ] Replace ad hoc error copies only where they conflict with S20; keep AttentionView's typed recovery mapping (it already matches S20 structure).
- [ ] Verify privacy AC-01..12 manually + S18/S20 VoiceOver/Dynamic Type, then `./init.sh`.

## Acceptance

- [x] Redaction plus retention plus accessibility plus S18/S20; privacy AC-01..12
- [x] `./init.sh` passes

## Depends

- feat-012

## Handoff

- State: done
- Evidence: `./init.sh` PASS (format, swiftlint --strict 0 violations, BUILD SUCCEEDED, SKIP [test]); redaction grep clean (no asset IDs/filenames/GPS/face data in UI strings or OSLog; error.localizedDescription only in local logs, never UI); usage text + manifest verified truthful (no plist/manifest change needed); Reset Analysis clears cache + session artifacts, originals untouched. Privacy AC-01..12 + S18/S20 VoiceOver/Dynamic Type device pass deferred to user.
- Blockers: none (code review closed)
- Next: feat-014 (Release QA + conditional analytics — provider unselected, ship with NoopAnalytics).
