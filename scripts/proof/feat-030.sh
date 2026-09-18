#!/usr/bin/env bash
# feat-030 proof harness: audit String Catalog coverage and compile the native
# language contract without adding a test target or test framework.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CATALOG="$ROOT_DIR/apps/photo-curator/Localizable.xcstrings"
INFOPLIST_CATALOG="$ROOT_DIR/apps/photo-curator/InfoPlist.xcstrings"
TRANSLATIONS="$ROOT_DIR/scripts/proof/feat-030-translations.json"
INFOPLIST_TRANSLATIONS="$ROOT_DIR/scripts/proof/feat-030-infoplist-translations.json"
LANGUAGE_SOURCE="$ROOT_DIR/apps/photo-curator/Configuration/AppLanguage.swift"
LANGUAGE_PROOF="$ROOT_DIR/scripts/proof/feat-030-language-proof.swift"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "MISSING-FILE $path" >&2
        exit 1
    fi
}

require_source() {
    local source="$1"
    local pattern="$2"
    local label="$3"
    if ! rg -q --fixed-strings "$pattern" "$source"; then
        echo "$label FAIL" >&2
        exit 1
    fi
}

require_file "$CATALOG"
require_file "$INFOPLIST_CATALOG"
require_file "$TRANSLATIONS"
require_file "$INFOPLIST_TRANSLATIONS"
require_file "$LANGUAGE_SOURCE"
require_file "$LANGUAGE_PROOF"

python3 - "$CATALOG" "$TRANSLATIONS" "$INFOPLIST_CATALOG" "$INFOPLIST_TRANSLATIONS" <<'PY'
import json
import re
import sys
from pathlib import Path

catalog_path, translations_path, infoplist_path, infoplist_translations_path = sys.argv[1:]
placeholder_pattern = re.compile(r"%(?:\d+\$)?(lld|@)")


def load(path):
    return json.loads(Path(path).read_text())


def placeholders(value):
    return placeholder_pattern.findall(value)


def assert_catalog(path, expected_path):
    catalog = load(path)
    expected = load(expected_path)
    assert catalog.get("sourceLanguage") == "en", f"{path}: source language is not en"
    strings = catalog.get("strings", {})
    assert set(strings) == set(expected), f"{path}: catalog keys do not match proof inventory"

    for key, expected_vietnamese in expected.items():
        entry = strings[key]
        localizations = entry.get("localizations", {})
        assert set(localizations) <= {"en", "vi"}, f"{path}: unsupported locale in {key!r}"
        assert "en" in localizations and "vi" in localizations, f"{path}: incomplete locale coverage for {key!r}"

        english = localizations["en"].get("stringUnit", {}).get("value")
        vietnamese = localizations["vi"].get("stringUnit", {}).get("value")
        assert english, f"{path}: empty English value for {key!r}"
        assert vietnamese == expected_vietnamese, f"{path}: Vietnamese value drift for {key!r}"
        assert placeholders(key) == placeholders(english), f"{path}: English placeholder drift for {key!r}"
        assert placeholders(key) == placeholders(vietnamese), f"{path}: Vietnamese placeholder drift for {key!r}"

        serialized = json.dumps(entry, ensure_ascii=False)
        assert "defaultValue" not in serialized, f"{path}: defaultValue is not allowed in {key!r}"


assert_catalog(catalog_path, translations_path)
assert_catalog(infoplist_path, infoplist_translations_path)
print("CATALOG-COVERAGE PASS")
print("PLACEHOLDERS PASS")
print("INFO-PLIST-COVERAGE PASS")
PY

if rg -n 'defaultValue:|"defaultValue"' "$ROOT_DIR/apps/photo-curator" --glob '*.swift' --glob '*.xcstrings'; then
    echo "DEFAULT-VALUE FAIL" >&2
    exit 1
fi
echo "NO-DEFAULT-VALUE PASS"

if rg -n 'AppLocalization|LocalizedStringResource|stageDescription|userPhase|title: LocalizedStringResource|message: LocalizedStringResource' \
    "$ROOT_DIR/apps/photo-curator/App" "$ROOT_DIR/apps/photo-curator/Services/Session" --glob '*.swift'; then
    echo "DOMAIN-LOCALIZATION-BOUNDARY FAIL" >&2
    exit 1
fi
echo "DOMAIN-LOCALIZATION-BOUNDARY PASS"

require_source "$ROOT_DIR/apps/photo-curator/PhotoCuratorApp.swift" '.environment(\.locale, appModel.appLanguage.locale)' "ROOT-LOCALE"
require_source "$ROOT_DIR/apps/photo-curator/App/AppModel.swift" 'UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageKey)' "PERSISTENCE-WRITE"
require_source "$ROOT_DIR/apps/photo-curator/App/AppModel.swift" 'UserDefaults.standard.string(forKey: Self.appLanguageKey)' "PERSISTENCE-READ"
require_source "$ROOT_DIR/apps/photo-curator/Features/Settings/SettingsView.swift" 'Picker("Language", selection: $appModel.appLanguage)' "LANGUAGE-PICKER"
echo "ROOT-LOCALE-AND-PERSISTENCE PASS"

SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios26.5-simulator"
xcrun --sdk iphonesimulator swiftc \
    -O -target "$TARGET" -sdk "$SDK" \
    "$LANGUAGE_SOURCE" "$LANGUAGE_PROOF" \
    -o "$OUT_DIR/feat-030-language-proof"

DEVICE="iPhone 17 Pro"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl spawn "$DEVICE" "$OUT_DIR/feat-030-language-proof"
