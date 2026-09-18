#!/usr/bin/env bash
# feat-031 deterministic model-delivery and response-contract proof; no network or model weights.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

xcrun swiftc \
    -O \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/ModelManifest.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/ModelInstallationService.swift" \
    "$ROOT_DIR/scripts/proof/feat-031-installation-proof.swift" \
    -o "$OUT_DIR/feat-031-installation-proof"

"$OUT_DIR/feat-031-installation-proof"

xcrun swiftc \
    -O \
    "$ROOT_DIR/apps/photo-curator/Configuration/QualityCurationPolicy.swift" \
    "$ROOT_DIR/apps/photo-curator/Domain/Models/AssetIDs.swift" \
    "$ROOT_DIR/apps/photo-curator/Domain/Models/PhotoAsset.swift" \
    "$ROOT_DIR/apps/photo-curator/Domain/Selection/QualityCurationEvidence.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/QwenPairResponseValidator.swift" \
    "$ROOT_DIR/scripts/proof/feat-031-response-proof.swift" \
    -o "$OUT_DIR/feat-031-response-proof"

"$OUT_DIR/feat-031-response-proof"

xcrun swiftc \
    -O \
    "$ROOT_DIR/apps/photo-curator/Configuration/QualityCurationPolicy.swift" \
    "$ROOT_DIR/apps/photo-curator/Domain/Models/AssetIDs.swift" \
    "$ROOT_DIR/apps/photo-curator/Domain/Selection/QualityCurationEvidence.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/ModelManifest.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/ModelInstallationService.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/QwenPairResponseValidator.swift" \
    "$ROOT_DIR/apps/photo-curator/Services/Intelligence/QwenPairJudge.swift" \
    "$ROOT_DIR/scripts/proof/feat-031-pair-judge-proof.swift" \
    -o "$OUT_DIR/feat-031-pair-judge-proof"

"$OUT_DIR/feat-031-pair-judge-proof"
