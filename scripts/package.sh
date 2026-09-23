#!/usr/bin/env bash
set -euo pipefail

# PulseSensation release packaging script
# Generates clean distribution zip archives for GitHub Releases, CurseForge, and Wago.

VERSION="0.2.0-beta"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_DIR}/dist"
STAGE_DIR="${DIST_DIR}/stage"

echo "=== Packaging PulseSensation v${VERSION} ==="

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

# 2. Stage PulseDebug
echo "Staging PulseDebug..."
mkdir -p "${STAGE_DIR}/PulseDebug"
rsync -av --exclude '.DS_Store' --exclude '.*' \
  "${REPO_DIR}/PulseDebug/" "${STAGE_DIR}/PulseDebug/"
cp "${REPO_DIR}/LICENSE" "${STAGE_DIR}/PulseDebug/"

# 3. Stage PulseChecklist (exclude internal test harness)
echo "Staging PulseChecklist..."
mkdir -p "${STAGE_DIR}/PulseChecklist"
rsync -av --exclude '.DS_Store' --exclude '.*' --exclude 'tests' \
  "${REPO_DIR}/PulseChecklist/" "${STAGE_DIR}/PulseChecklist/"
cp "${REPO_DIR}/LICENSE" "${STAGE_DIR}/PulseChecklist/"

# Clean any lingering .DS_Store files in stage
find "${STAGE_DIR}" -name ".DS_Store" -delete

# 4. Create PulseHaptics standalone package
echo "Creating PulseHaptics-v${VERSION}.zip..."
(cd "${STAGE_DIR}" && zip -q -r "${DIST_DIR}/PulseHaptics-v${VERSION}.zip" PulseHaptics -x "*.DS_Store")

# 5. Create PulseSensation Suite package (all 3 addons)
echo "Creating PulseSensation-Suite-v${VERSION}.zip..."
(cd "${STAGE_DIR}" && zip -q -r "${DIST_DIR}/PulseSensation-Suite-v${VERSION}.zip" PulseHaptics PulseDebug PulseChecklist -x "*.DS_Store")

# Clean stage
rm -rf "${STAGE_DIR}"

echo ""
echo "=== Packaging Complete! ==="
echo "Distribution archives generated in ${DIST_DIR}:"
ls -lh "${DIST_DIR}"
