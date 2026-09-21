# feat-030 — Bilingual localization

## Status

- Status: `done`
- Depends on: `feat-029` (done)

## Goal

Localize the complete user-facing app in English and Vietnamese, with a Settings
language selector for System Default, English, and Tiếng Việt. The selected language
persists, takes effect immediately at the SwiftUI root, and leaves room for future
locale expansion.

## Contract boundary

This feature owns the localized resource catalogs, user-visible and accessibility
copy, user-facing error copy, the typed app-language preference and persistence,
root locale override, and the S18 language picker. It does not change app behavior,
flow, selection policy, or the S11 inspection contract owned by `feat-029`. The
execution detail is [`docs/plans/feat-030.md`](../docs/plans/feat-030.md).

## Scope

- `Localizable.xcstrings` with complete English and Vietnamese coverage.
- `InfoPlist.xcstrings` for localized Info.plist strings and permission-facing copy.
- All user-visible, accessibility, and user-facing error strings, including Settings
  strings themselves.
- A typed `AppLanguage` preference with System Default, English, and Tiếng Việt,
  persistent storage, and a high-root SwiftUI locale override.
- A Settings language picker that preserves the existing S18 access, privacy, and
  About requirements.
- `./init.sh` verification for resource compilation and localization changes.
- Native-first localization architecture: SwiftUI localizable literals and
  `LocalizedStringResource` at the presentation boundary; processing/session data
  remains locale-independent. No SwiftGen or R.swift dependency is added.

## Acceptance

- [x] Every user-facing and accessibility string has complete English and Vietnamese
  coverage, including `InfoPlist.xcstrings`, errors, and the Settings language picker.
- [x] System Default follows the current system locale rather than a locale captured
  when the preference was saved; explicit English or Tiếng Việt selection persists
  and takes effect immediately throughout the SwiftUI root.
- [x] Counts, dates, and interpolated values use the active locale correctly in both
  languages, with safe catalog fallback behavior.
- [x] No raw user-facing literals are introduced; internal identifiers, logs, and
  diagnostics are not translated, and no automatic translation service is added.
- [x] No language beyond English and Vietnamese, behavior/flow/selection change, or
  S11 contract change is included.
- [x] `./init.sh` passes. No test target, test framework, standalone proof file, or
  manual-QA gate is added.

## Non-goals

- Languages beyond English and Vietnamese.
- Changes to app behavior, navigation flow, selection, or review decisions.
- Translation of internal identifiers, logs, or diagnostics.
- An automatic translation service or network translation dependency.

## Relevant docs

- [`docs/plans/feat-030.md`](../docs/plans/feat-030.md)
- [`docs/product-specs/ux-flows.md`](../docs/product-specs/ux-flows.md)
- [`docs/design-docs/ios-architecture.md`](../docs/design-docs/ios-architecture.md)
- [`features/feat-029.md`](feat-029.md)
- Apple localization/resource and Info.plist constraints — research notes only, not
  canonical project docs.

## Plan

See [`docs/plans/feat-030.md`](../docs/plans/feat-030.md).

## Verify

- `./init.sh`
- No test target, `*Test*.swift` file, test framework, or manual-QA gate.

## Handoff

- State: done — follow-up localization audit and review remediation corrected runtime
  `String` values, accessibility state labels, singular review copy, and dynamic fact
  row identity across Home, Source Selection, Review, and Photo Analysis.
- Evidence: `./init.sh` passes SwiftFormat, SwiftLint strict, the Simulator build,
  and the policy test skip after the localization changes. Resource and copy
  completeness remain part of the feature review record.
- Blockers: none
- Next: none; feat-030 is complete.
