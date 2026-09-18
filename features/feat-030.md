# feat-030 — Bilingual localization

## Status

- Status: `todo`
- Depends on: `feat-029` (todo; must be done before this feature starts)

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
- Reproducible automated proof for resource completeness, fallback, and live
  selection, plus `./init.sh`.

## Acceptance

- [ ] Every user-facing and accessibility string has complete English and Vietnamese
  coverage, including `InfoPlist.xcstrings`, errors, and the Settings language picker.
- [ ] System Default follows the current system locale rather than a locale captured
  when the preference was saved; explicit English or Tiếng Việt selection persists
  and takes effect immediately throughout the SwiftUI root.
- [ ] Counts, dates, and interpolated values use the active locale correctly in both
  languages, with safe catalog fallback behavior.
- [ ] No raw user-facing literals are introduced; internal identifiers, logs, and
  diagnostics are not translated, and no automatic translation service is added.
- [ ] No language beyond English and Vietnamese, behavior/flow/selection change, or
  S11 contract change is included.
- [ ] Reproducible automated localization proof and `./init.sh` pass. No test target,
  test framework, or manual-QA gate is added.

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

- Reproducible automated proof audits catalog completeness, fallback, live language
  selection, locale-aware formatting, and localized Info.plist resources.
- `./init.sh`
- No test target, `*Test*.swift` file, test framework, or manual-QA gate.

## Handoff

- State: todo
- Evidence: approved feature record and execution plan created; `feat-029` remains the
  prerequisite owner for complete S11 coverage.
- Blockers: none
- Next: user selects feat-030 after feat-029 is done, then activate it before implementation.
