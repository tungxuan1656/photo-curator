#!/usr/bin/env bash
# feat-026 proof harness (DEC-042 contract + DEC-043 guards + DEC-044 schema + DEC-045/DEC-046 ownership).
# Compiles the REAL shipped app sources verbatim (whole app dir minus the
# @main entry; every staged file md5-matched) for the iOS Simulator SDK and
# runs the binary on the booted simulator via simctl spawn. U14 drives the
# REAL shipped AppModel+Save beginReview/hook/re-entry/save-guard path plus
# scripted exporter failure/retry/interleaving. Proof-only harness fakes live
# in scripts/proof/ (NOT shipped): no test target, no *Test*.swift, no test
# framework.
# Usage: scripts/proof/feat-026.sh [--keep]   (default wipes its out/ dir first)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$ROOT/apps/photo-curator"
OUT="$HERE/out"
HARNESS_MAIN="$HERE/feat-026-proof.swift"
KEEP=0
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -f "$HARNESS_MAIN" ] || { echo "missing harness main: $HARNESS_MAIN" >&2; exit 2; }
if [ "$KEEP" -eq 0 ]; then rm -rf "$OUT"; fi
mkdir -p "$OUT/stage"
STAGE="$OUT/stage"
FILES_LIST="$OUT/staged-files.txt"
find "$SRC" -name '*.swift' ! -name 'PhotoCuratorApp.swift' | sed "s|^$SRC/||" | sort > "$FILES_LIST"
# SwiftUI Views remain excluded (need the render host; still Xcode-built via
# ./init.sh BUILD SUCCEEDED) except NeedsReview and its smallest shipped view
# dependency closure. That closure is staged verbatim so the proof compiles the
# real S22 surface and executes its shipped action-routing behavior below.
# Excluded files are listed in the proof output.
grep -v -e '^App/RootView.swift$' \
  -e '^PhotoCuratorApp.swift$' \
  -e '^Features/Onboarding/' \
  -e '^Features/Processing/ProcessingView.swift$' \
  -e '^Features/Review/ReviewOverview.swift$' \
  -e '^Features/Review/CuratedGrid.swift$' \
  -e '^Features/Review/FinalReview.swift$' \
  -e '^Features/Review/RemovedPhotos.swift$' \
  -e '^Features/Review/Completion.swift$' \
  -e '^Features/Review/Saving.swift$' \
  -e '^Features/Review/SimilarGroups.swift$' \
  -e '^Features/Settings/' \
  -e '^Features/SourceSelection/SelectionSummaryView.swift$' \
  -e '^Features/SourceSelection/SourceSelectionView.swift$' \
  "$FILES_LIST" > "$OUT/compiled-files.txt" || true
mv "$OUT/compiled-files.txt" "$FILES_LIST"
while IFS= read -r rel; do
  mkdir -p "$STAGE/$(dirname "$rel")"
  cp "$SRC/$rel" "$STAGE/$rel"
done < "$FILES_LIST"
cp "$HARNESS_MAIN" "$STAGE/proof-main.swift"
cp "$HARNESS_MAIN" "$STAGE/main.swift"
# Verbatim check: every staged shipped source must md5-match the repo file.
# STAGED count derives from the staged list (no hardcoded N).
STAGED_N=$(wc -l < "$FILES_LIST" | tr -d ' ')
if ! (cd "$ROOT" && while IFS= read -r rel; do
  a="$(md5 -q "apps/photo-curator/$rel")"
  b="$(md5 -q "$STAGE/$rel")"
  [ "$a" = "$b" ] || { echo "STAGE DRIFT: $rel ($a != $b)" >&2; exit 1; }
done < "$FILES_LIST"); then exit 1; fi
echo "STAGED-${STAGED_N}-MD5-MATCH"
{
  echo "harness-main sha256: $(shasum -a 256 "$HARNESS_MAIN" | cut -d' ' -f1)"
  echo "excluded (still Xcode-built via ./init.sh):"
  comm -23 <(find "$SRC" -name '*.swift' ! -name 'PhotoCuratorApp.swift' | sed "s|^$SRC/||" | sort) "$FILES_LIST"
  while IFS= read -r rel; do
    echo "$rel md5: $(md5 -q "$SRC/$rel")"
  done < "$FILES_LIST"
} > "$OUT/staged-hashes.txt"
SIM_TARGET="arm64-apple-ios26.5-simulator"
SIM_DEVICE="iPhone 17 Pro"
PROOF_ARGS=""
while IFS= read -r rel; do PROOF_ARGS="$PROOF_ARGS \"$STAGE/$rel\""; done < "$FILES_LIST"
eval "xcrun -sdk iphonesimulator swiftc -O -target \"$SIM_TARGET\" -o \"$OUT/feat-026-proof\" $PROOF_ARGS \"$STAGE/main.swift\""
echo "binary sha256: $(shasum -a 256 "$OUT/feat-026-proof" | cut -d' ' -f1)"
xcrun simctl spawn "$SIM_DEVICE" "$OUT/feat-026-proof" "$OUT"
