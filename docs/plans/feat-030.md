# feat-030 execution plan

**Decision:** add English/Vietnamese localization with a persistent language preference
and immediate root locale override; keep System Default live and extensible.

**Scope:** inventory and localize the complete user-facing surface, add
`Localizable.xcstrings` and `InfoPlist.xcstrings` coverage for `en` and `vi`, add the
typed `AppLanguage` preference and S18 picker, and provide reproducible automated proof
plus `./init.sh`. No application code is changed by this planning record.

## Ownership and prerequisites

- `feat-029` owns the S11 inspector and must be done before feat-030 starts, so the
  localization inventory covers every screen.
- `docs/product-specs/ux-flows.md` owns screen flow, copy intent, accessibility wording,
  and user-facing error taxonomy.
- `docs/design-docs/ios-architecture.md` owns the app/root boundary, SwiftUI environment
  topology, persistence boundary, and no-test-target project constraints.
- This feature owns translation resources, locale preference state, root locale
  propagation, and S18 language selection; it does not own behavior, navigation,
  selection, or S11 interaction semantics.
- Apple localization, String Catalog, locale formatting, and localized Info.plist
  requirements are research notes/implementation constraints only; they are not
  canonical project docs and cannot override the two project documents above.

## Execution tasks

### 1. Inventory the complete localization surface

- Enumerate every screen and state in the UX flow, including S11, S18, S20, S21, and
  accessibility labels, hints, values, actions, empty states, loading states, and
  recoverable errors.
- Inventory strings created outside ordinary views: model-derived errors, permission
  explanations, notification/alert content, plural/count text, date/time presentation,
  interpolation, and any eagerly materialized user-facing values.
- Confirm the Xcode resource membership and target inclusion for `Localizable.xcstrings`
  and `InfoPlist.xcstrings`; record the inventory and uncovered-string audit inputs in
  the feature handoff.

### 2. Establish catalogs and migrate resources

- Create or update `Localizable.xcstrings` with English and Vietnamese entries,
  preserving stable keys and catalog fallback metadata.
- Create or update `InfoPlist.xcstrings` for every localized Info.plist value that is
  user-visible, including permission-facing usage descriptions.
- Migrate literals from views, accessibility modifiers, alerts, errors, and other
  user-facing resource paths to catalog-backed localization without translating
  internal identifiers, logs, or diagnostics.
- Define plural/count, date, and interpolation forms using locale-aware APIs; do not
  concatenate translated fragments or hard-code locale-specific punctuation.
- Ensure Settings copy, picker labels, current-value text, and picker accessibility
  values are themselves localized.

### 3. Add the typed language contract at the app/root boundary

- Define a typed `AppLanguage` with exactly `systemDefault`, `english`, and
  `vietnamese` cases, plus a locale-resolution rule that evaluates System Default
  against the current system locale whenever the root is built or refreshed.
- Persist only the explicit preference value at the existing small-settings
  persistence boundary. Never persist a captured system locale as the System Default
  value.
- Inject the resolved locale at the highest SwiftUI root so every screen, sheet, alert,
  accessibility value, and formatted value observes the same locale immediately after
  a selection change.
- Audit eagerly materialized strings and cached presentation values; make them derive
  from the active locale or refresh when the preference changes rather than retaining
  stale language output.
- Preserve the existing app/root dependency and state topology; do not introduce a
  global event bus, network dependency, or behavior/flow change.

### 4. Add the S18 language picker

- Add a Settings language section with System Default, English, and Tiếng Việt,
  selection state, persistence, and immediate root update.
- Preserve S18 Photos Access, Processing & Privacy, About, and existing access-management
  behavior. The picker must not expose ranking, threshold, model, cache, or thread
  controls.
- Localize the picker title, options, current selection, accessibility values, errors,
  and any confirmation or explanatory copy in both catalogs.

### 5. Add reproducible automated proof

- Add or update the established repository proof mechanism without adding a test target,
  test framework, or `*Test*.swift` file.
- Audit that every inventoried user-facing/accessibility/error key has `en` and `vi`
  entries, that `InfoPlist.xcstrings` is included, and that no newly introduced raw
  user-facing literal remains.
- Prove safe fallback for missing/unsupported locale data and prove that System Default
  resolves the current system locale rather than a saved snapshot.
- Prove live selection for all three picker values, persistence across a fresh model
  boundary, immediate root propagation, locale-aware count/date/interpolation output,
  and localized Settings/InfoPlist strings.
- Record the exact command, fixture inputs, result, and `./init.sh` output in the
  feature handoff.

### 6. Verify and close

- Run the reproducible localization proof and `./init.sh` after the final catalog and
  root-locale changes.
- Confirm the diff is limited to localization resources, app/root language plumbing,
  Settings localization, proof support, and the approved tracker records.
- Confirm no language beyond `en`/`vi`, no behavior/flow/selection change, no translated
  internal diagnostics, and no manual-QA acceptance gate.

## Rollback

Rollback is bounded to this feature: remove the English/Vietnamese catalog additions,
localized Info.plist resources, language preference/picker/root-locale plumbing, migrated
copy, and localization proof; restore the prior single-locale resource paths. Do not
revert or alter feat-029's S11 behavior, selection state, navigation contract, or other
feature-owned code. If a catalog entry is incomplete, keep the safe fallback and disable
only the incomplete locale path until the catalog/proof is repaired; never ship a
captured-locale System Default implementation.

## Verification contract

- Reproducible automated localization proof is required for completeness, fallback,
  current-system System Default, persistent explicit selection, immediate root update,
  locale-aware formatting, and InfoPlist/catalog inclusion.
- `./init.sh` is required.
- No test target, test framework, `*Test*.swift` file, or manual-QA gate is permitted.
