#!/usr/bin/env bash
# Re-runs every probe and check behind PULSEHAPTICS_CODE_REVIEW_2026-09-30.md.
#
# Read-only against the repository: each compared commit is extracted with `git archive`
# into a temporary directory and the probes load the addon from there, never from the
# working tree. Output goes to one text file per topic.
#
# Usage: docs/review-2026-09-30/run.sh [output-dir]
#   output-dir defaults to a fresh temp directory, so the recorded evidence/ is never
#   overwritten by accident. Pass docs/review-2026-09-30/evidence to refresh it on purpose.
# Needs: git, luajit (or LUA=...), luacheck for the lint line of the test runs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
LUA_BIN="${LUA:-luajit}"

SNAP="$(mktemp -d)"
trap 'rm -rf "$SNAP"' EXIT
export PROBE_SNAPSHOTS="$SNAP"

OUT="${1:-$(mktemp -d)}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# The four commits the review compares.
#   head = ad0ef89  review baseline (soft floor, DB_VERSION 10)
#   h2   = 1ca6a24  HEAD when the report was written (oscilloscope)
#   pre  = db2ffa5  last commit before ad0ef89 (hard floor)
#   v8   = dace2ab  last commit before profile curation (04b6638), DB_VERSION 8
extract() {
	mkdir -p "$SNAP/$1"
	git -C "$REPO" archive "$2" -- PulseHaptics PulseChecklist PulseDebug PulseProfileReview scripts .luacheckrc 2>/dev/null |
		tar -x -C "$SNAP/$1" ||
		git -C "$REPO" archive "$2" -- PulseHaptics PulseChecklist | tar -x -C "$SNAP/$1"
}
extract head ad0ef89
extract h2 1ca6a24
extract pre db2ffa5
extract v8 dace2ab

strip() { sed $'s/\x1b\\[[0-9;]*m//g'; }
section() { printf '\n===== %s =====\n' "$*"; }

cd "$HERE/probes"

{
	for tree in head h2; do
		section "scripts/test.sh in snapshot '$tree' ($(git -C "$REPO" rev-parse --short "$([ "$tree" = head ] && echo ad0ef89 || echo 1ca6a24)"))"
		(cd "$SNAP/$tree" && LUA="$LUA_BIN" ./scripts/test.sh 2>&1 | strip) || true
	done
	section "luacheck PulseProfileReview/ (outside test.sh) at 1ca6a24"
	(cd "$SNAP/h2" && luacheck PulseProfileReview/ 2>&1 | strip | tail -n 1) || true
} >"$OUT/tests.txt"

{
	section "softfloor.lua pre (db2ffa5, hard floor) master 0.70"
	"$LUA_BIN" softfloor.lua pre 0.7
	section "softfloor.lua head (ad0ef89, soft floor) master 0.70"
	"$LUA_BIN" softfloor.lua head 0.7
	section "softfloor.lua head (ad0ef89, soft floor) master 1.00"
	"$LUA_BIN" softfloor.lua head 1.0
} >"$OUT/F-01-softfloor.txt" 2>&1

{
	section "craft.lua (ad0ef89): (a) castTexture ON + craftTexture OFF; (b) PreviewCraft strikes"
	"$LUA_BIN" craft.lua
} >"$OUT/F-02-F-05-crafting.txt" 2>&1

{
	section "migrate.lua make-v8: fresh install with dace2ab code (pre-curation, DB_VERSION 8)"
	"$LUA_BIN" migrate.lua make-v8
	section "migrate.lua make-head: fresh install with ad0ef89 code (the curated reference)"
	"$LUA_BIN" migrate.lua make-head
	section "migrate.lua upgrade: v8 DB loaded into ad0ef89 code"
	"$LUA_BIN" migrate.lua upgrade
	section "migrate_ab.lua: same upgrade with the five pre-ad0ef89 tunable defaults restored in memory"
	"$LUA_BIN" migrate_ab.lua
	section "questing.lua: v8 profiles vs LEGACY_V8_OVERRIDES (why Questing still fails)"
	"$LUA_BIN" questing.lua
	section "control: fresh install with db2ffa5 code (v8, curation already present), upgraded the same way"
	"$LUA_BIN" migrate.lua make-v8 pre
	"$LUA_BIN" migrate.lua upgrade
} >"$OUT/F-03-migration.txt" 2>&1

{
	section "scope.lua (1ca6a24): real engine output vs GetChannelOutputs / _DebugChannels"
	"$LUA_BIN" scope.lua
} >"$OUT/F-04-oscilloscope.txt" 2>&1

{
	section "registry.lua (ad0ef89): Registry consistency, throttles, off-grid defaults"
	"$LUA_BIN" registry.lua
	section "pages.lua (1ca6a24): page placement and 'Default profiles' catalogue"
	"$LUA_BIN" pages.lua
} >"$OUT/registry-and-pages.txt" 2>&1

{
	section "F-03: no commit ever had DB_VERSION = 9 (git log -S)"
	git -C "$REPO" log --format='%h %s' -S'DB_VERSION = 9' -- PulseHaptics/Core/Database.lua || true
	echo "(empty output above = never committed)"
	git -C "$REPO" show db2ffa5:PulseHaptics/Core/Database.lua | grep -n 'local DB_VERSION'
	git -C "$REPO" show ad0ef89:PulseHaptics/Core/Database.lua | grep -n 'local DB_VERSION'
	section "F-03: tunable defaults changed by ad0ef89 in Core/Registry.lua"
	git -C "$REPO" show ad0ef89 -- PulseHaptics/Core/Registry.lua |
		awk '/^[ +-][[:space:]]+key = /{k=$0; sub(/^[ +-][[:space:]]+/, "", k)} /^[-+][[:space:]]+default = /{d=$0; sub(/^[-+][[:space:]]+/, "", d); print substr($0,1,1) " " k " " d}'
	section "F-03: __curatedVersion is written unconditionally and never read"
	git -C "$REPO" grep -n '__curatedVersion' 1ca6a24 -- PulseHaptics PulseDebug PulseChecklist || true
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Database.lua | sed -n '2045,2060p'
	section "F-03: LEGACY_V8_OVERRIDES.Questing has swimTexture but no waterTexture; the swim split turns waterTexture on"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Database.lua | sed -n '1514,1549p' | grep -n 'swimTexture\|waterTexture' || true
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Database.lua | sed -n '2202,2204p'

	section "F-04: channel keys are capitalised; GetChannelOutputs reads lowercase"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Devices.lua | sed -n '27p'
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Engine.lua | sed -n '1120,1127p'
	git -C "$REPO" show 1ca6a24:PulseDebug/Oscilloscope.lua | sed -n '723,731p'
	echo "--- the test replaces the function with a mock:"
	git -C "$REPO" show 1ca6a24:PulseChecklist/tests/pulsedebug-test.lua | sed -n '393,400p'

	section "F-06: curated profiles enabling selfCastInstant together with selfCastSucceeded / autoShotFired"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Database.lua | awk 'NR>=175 && NR<=1068' |
		awk '/^\t\[?"?[A-Za-z: ]+"?\]? = \{/{p=$0} /selfCastInstant|selfCastSucceeded|autoShotFired/{print p " :: " $0}'

	section "F-07: coastCoeff appears only in Devices.lua (no engine reader)"
	git -C "$REPO" grep -n 'coastCoeff' 1ca6a24 -- PulseHaptics || true
	section "F-07: floorKnee is read by the engine but has no default or tunable"
	git -C "$REPO" grep -n 'floorKnee' 1ca6a24 -- PulseHaptics || true

	section "F-02: beginCraft sets active before/without the cue gate; Combat suppresses castTexture while crafting"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Modules/Crafting.lua | sed -n '365,390p'
	git -C "$REPO" show 1ca6a24:PulseHaptics/Modules/Combat.lua | sed -n '443,448p'
	section "F-02: curated profiles with castTexture on (craftTexture on only where listed)"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Database.lua | awk 'NR>=175 && NR<=1068' |
		awk '/^\t\[?"?[A-Za-z: ]+"?\]? = \{/{p=$0} /castTexture = true|craftTexture = true/{print p " :: " $0}'

	section "F-05: token captured before StartContinuousPreview, which bumps it"
	git -C "$REPO" show 1ca6a24:PulseHaptics/Modules/Crafting.lua | sed -n '589,612p'
	git -C "$REPO" show 1ca6a24:PulseHaptics/Core/Init.lua | sed -n '283,302p'
} >"$OUT/static-checks.txt" 2>&1

echo "Probe outputs written to: $OUT"
ls -1 "$OUT"
