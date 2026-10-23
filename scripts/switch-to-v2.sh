#!/usr/bin/env bash
set -euo pipefail

ADDONS_DIR="/Applications/World of Warcraft/_classic_beta_/Interface/AddOns"
V2_DIR="/home/deck/developer/PulseSensation2"

echo "Switching WoW client symlinks to PulseSensation2 (Experimental)..."
ln -sfh "${V2_DIR}/PulseHaptics" "${ADDONS_DIR}/PulseHaptics"
ln -sfh "${V2_DIR}/PulseChecklist" "${ADDONS_DIR}/PulseChecklist"
ln -sfh "${V2_DIR}/PulseDebug" "${ADDONS_DIR}/PulseDebug"
ln -sfh "${V2_DIR}/PulseProfileReview" "${ADDONS_DIR}/PulseProfileReview"

echo "✓ Active client addons now point to PulseSensation2!"
