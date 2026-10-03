#!/usr/bin/env bash
set -euo pipefail

# PulseHaptics release packaging script
# Generates a clean distribution zip archive for CurseForge, Wago, and GitHub Releases.

VERSION="0.3.2-beta"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_DIR}/dist"
STAGE_DIR="${DIST_DIR}/stage"

echo "=== Packaging PulseHaptics v${VERSION} ==="

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}" "${STAGE_DIR}"

# 1. Stage PulseHaptics (Core Addon)
echo "Staging PulseHaptics..."
mkdir -p "${STAGE_DIR}/PulseHaptics"
rsync -av --exclude '.DS_Store' --exclude '.*' \
  "${REPO_DIR}/PulseHaptics/" "${STAGE_DIR}/PulseHaptics/"

# Copy LICENSE and README into PulseHaptics
cp "${REPO_DIR}/LICENSE" "${STAGE_DIR}/PulseHaptics/"
cp "${REPO_DIR}/README.md" "${STAGE_DIR}/PulseHaptics/"

# Disable macOS AppleDouble resource forks (._* files)
export COPYFILE_DISABLE=1

# Clean any lingering Mac metadata in stage
find "${STAGE_DIR}" \( -name ".DS_Store" -o -name "._*" \) -delete

# 2. Create clean PulseHaptics distribution package
echo "Creating PulseHaptics-v${VERSION}.zip..."
(cd "${STAGE_DIR}" && zip -q -r -X "${DIST_DIR}/PulseHaptics-v${VERSION}.zip" PulseHaptics \
  -x "*.DS_Store" -x "__MACOSX*" -x "*/__MACOSX*" -x "._*" -x "*/._*")

# Clean stage
rm -rf "${STAGE_DIR}"

echo ""
echo "=== Packaging Complete! ==="
echo "Distribution archive generated in ${DIST_DIR}:"
ls -lh "${DIST_DIR}"
