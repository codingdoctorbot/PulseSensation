#!/usr/bin/env bash
# Reproduces the plan's offline verification WITHOUT touching the repository.
#
# Builds a throwaway copy of the tree in a temp directory (HEAD via git archive, plus the
# working-tree .luacheckrc and the untracked PulseProbe/ folder), applies the patches in
# order, and runs the project's own battery after each step. Exits non-zero if any step
# fails. Needs: git, luajit, luacheck; stylua optional.
#
#   bash IMPLEMENTATION_PLAN_PHASE0_1_2/verify.sh            # all steps
#   bash IMPLEMENTATION_PLAN_PHASE0_1_2/verify.sh --keep     # keep the temp copy to inspect
#
# PULSE_REPO=<path> overrides the repository location (default: the enclosing git repo).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${PULSE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}"
PATCHES="$HERE/patches"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pulse-plan-verify.XXXXXX")"
cleanup() { if [ "$KEEP" -eq 1 ]; then echo "kept: $WORK"; else rm -rf "$WORK"; fi; }
trap cleanup EXIT

FAILED=0
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

echo "baseline: $(git -C "$REPO" rev-parse --short HEAD) (+ working-tree .luacheckrc, PulseProbe/)"
git -C "$REPO" archive HEAD PulseHaptics PulseDebug PulseChecklist scripts | tar -x -C "$WORK"
cp "$REPO/.luacheckrc" "$WORK/"
[ -d "$REPO/PulseProbe" ] && cp -R "$REPO/PulseProbe" "$WORK/"

run_battery() {
	local label="$1" out
	out="$(cd "$WORK" && ./scripts/test.sh 2>&1 | strip)"
	echo
	echo "=== after $label ==="
	echo "$out" | grep -E "PASS|FAIL|Total|SUITES"
	# "NO FAILURES" contains FAIL, so key on the battery's own all-clear summary line.
	if ! echo "$out" | grep -q "PASSED CLEANLY"; then
		FAILED=1
	fi
}

run_battery "baseline (no patch)"
for patch in 01-P0.1-engine-floor 02-P0.2-probe-trace 03-P1-arbitration 04-P2-panel-and-gates; do
	echo
	if (cd "$WORK" && git apply "$PATCHES/$patch.patch"); then
		echo "applied $patch"
	else
		echo "FAILED to apply $patch"
		FAILED=1
		break
	fi
	if [ "$patch" = "02-P0.2-probe-trace" ]; then
		for target in PulseProbe scripts/probe-trace-report.lua; do
			lint="$(cd "$WORK" && luacheck "$target" --no-color 2>&1 | tail -1)"
			echo "lint $target: $lint"
			echo "$lint" | grep -q "0 warnings / 0 errors" || FAILED=1
		done
		for f in PulseProbe/Core.lua PulseProbe/Probes/Sequencer.lua scripts/probe-trace-report.lua; do
			if (cd "$WORK" && luajit -bl "$f" >/dev/null); then echo "compiles: $f"; else echo "FAILED to compile: $f"; FAILED=1; fi
		done
	fi
	run_battery "$patch"
done

if command -v stylua >/dev/null 2>&1; then
	echo
	if (cd "$WORK" && stylua --check PulseHaptics/Core/Arbiter.lua PulseHaptics/Core/Init.lua \
		PulseHaptics/Modules/World.lua PulseHaptics/Modules/Interaction.lua PulseHaptics/Modules/Inventory.lua \
		PulseChecklist/tests/arbitration-test.lua PulseChecklist/tests/phase2-test.lua >/dev/null 2>&1); then
		echo "stylua: clean"
	else
		echo "stylua: differences (run stylua --check on the files above)"
		FAILED=1
	fi
fi

echo
if [ "$FAILED" -eq 0 ]; then
	echo "VERIFY: every step green"
else
	echo "VERIFY: FAILURES above"
fi
exit "$FAILED"
