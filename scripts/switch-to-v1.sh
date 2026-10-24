#!/usr/bin/env bash
set -euo pipefail

ADDONS_DIR="/Applications/World of Warcraft/_classic_beta_/Interface/AddOns"
V1_DIR="/home/deck/developer/wow/PulseSensation"

echo "Switching WoW client symlinks to PulseSensation (Stable)..."
ln -sfh "${V1_DIR}/PulseHaptics" "${ADDONS_DIR}/PulseHaptics"
ln -sfh "${V1_DIR}/PulseChecklist" "${ADDONS_DIR}/PulseChecklist"
ln -sfh "${V1_DIR}/PulseDebug" "${ADDONS_DIR}/PulseDebug"
ln -sfh "${V1_DIR}/PulseProfileReview" "${ADDONS_DIR}/PulseProfileReview"

echo "✓ Active client addons now point to PulseSensation (Stable)!"
