#!/usr/bin/env bash
set -euo pipefail

# PulseSensation unified QA test and lint runner
# Executes static analysis (luacheck) and all 7 offline test harnesses.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

# ── Terminal Styling ─────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Test Suite Registry (name, directory argument) ───────────────────────────
SUITES=(
  "harness PulseHaptics"
  "locomotion-test PulseHaptics"
  "crafting-test PulseHaptics"
  "engine-test PulseHaptics"
  "arbitration-test PulseHaptics"
  "phase2-test PulseHaptics"
  "cue-audit PulseHaptics"
  "pulsedebug-test PulseDebug"
  "checklist-test PulseChecklist"
  "bridge-test PulseBridge"
  "studio-test PulseStudio"
  "audio-test PulseAudio"
  "sync-test PulseSync"
  "compass-test PulseCompass"
)

# ── Flags & Mode Selection ───────────────────────────────────────────────────
SKIP_LINT=0
LINT_ONLY=0
DO_PACKAGE=0
FILTER=""

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo -e "${BOLD}PulseSensation Test & QA Runner${NC}"
      echo ""
      echo -e "Usage: ${CYAN}./scripts/test.sh${NC} [options] [suite-name]"
      echo ""
      echo "Options:"
      echo "  -f, --fast      Skip luacheck static analysis (run tests only)"
      echo "  -l, --lint      Run luacheck static analysis only"
      echo "  -p, --package   Rebuild release zip packages in dist/ if all tests pass"
      echo "  -h, --help      Display this help message"
      echo ""
      echo "Available Test Suites:"
      for entry in "${SUITES[@]}"; do
        s=$(echo "$entry" | cut -d' ' -f1)
        echo -e "  • ${s}"
      done
      exit 0
      ;;
    -f|--fast)
      SKIP_LINT=1
      ;;
    -l|--lint)
      LINT_ONLY=1
      ;;
    -p|--package)
      DO_PACKAGE=1
      ;;
    *)
      FILTER="$arg"
      ;;
  esac
done

LUA_BIN="${LUA:-}"
if [ -z "${LUA_BIN}" ]; then
  if command -v luajit >/dev/null 2>&1; then
    LUA_BIN="luajit"
  else
    LUA_BIN="lua"
  fi
fi

START_TIME=$(date +%s)

echo -e "${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              PulseSensation Developer QA Test Battery          ║${NC}"
echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Static Analysis (luacheck) ───────────────────────────────────────
if [ $SKIP_LINT -eq 0 ]; then
  echo -e "${BOLD}[1/2] Static Analysis (luacheck)${NC}"
  if command -v luacheck >/dev/null 2>&1; then
    LINT_STATUS=0
    LINT_OUT=$(luacheck PulseHaptics/ PulseDebug/ PulseChecklist/ PulseProbe/ PulseBridge/ PulseStudio/ PulseAudio/ PulseSync/ PulseCompass/ 2>&1) || LINT_STATUS=$?
    if [ $LINT_STATUS -eq 0 ]; then
      SUMMARY=$(tail -n 1 <<< "$LINT_OUT")
      echo -e "  ${GREEN}✓ PASS${NC}  ${DIM}${SUMMARY}${NC}"
    else
      echo -e "  ${RED}✗ FAIL${NC}  Luacheck reported issues:"
      sed 's/^/    /' <<< "$LINT_OUT"
      exit 1
    fi
  else
    echo -e "  ${YELLOW}⚠ SKIP${NC}  luacheck not installed on PATH"
  fi
  echo ""
fi

if [ $LINT_ONLY -eq 1 ]; then
  echo -e "${GREEN}${BOLD}Lint pass complete.${NC}"
  exit 0
fi

# ── Step 2: Offline Unit & Smoke Harnesses ───────────────────────────────────
echo -e "${BOLD}[2/2] Offline Unit & Smoke Harnesses (${LUA_BIN})${NC}"
FAILURES=0
RAN=0

for entry in "${SUITES[@]}"; do
  suite=$(echo "$entry" | cut -d' ' -f1)
  dir=$(echo "$entry" | cut -d' ' -f2)

  # Check if filter applied
  if [ -n "$FILTER" ]; then
    if [[ "$suite" != *"$FILTER"* ]]; then
      continue
    fi
  fi

  RAN=$((RAN + 1))
  printf "  %-24s " "${suite}"

  TEST_STATUS=0
  TEST_OUT=$("${LUA_BIN}" "PulseChecklist/tests/${suite}.lua" "$dir" 2>&1) || TEST_STATUS=$?

  if [ $TEST_STATUS -eq 0 ] && ! grep -q "^FAIL" <<< "$TEST_OUT"; then
    LAST_LINE=$(grep -v '^[[:space:]]*$' <<< "$TEST_OUT" | tail -n 1)
    echo -e "${GREEN}✓ PASS${NC}  ${DIM}${LAST_LINE}${NC}"
  else
    echo -e "${RED}✗ FAIL${NC}"
    sed 's/^/    /' <<< "$TEST_OUT"
    FAILURES=$((FAILURES + 1))
  fi
done

if [ $RAN -eq 0 ]; then
  echo -e "  ${YELLOW}⚠ No test suites matched filter '${FILTER}'${NC}"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${DIM}─────────────────────────────────────────────────────────────────${NC}"

if [ $FAILURES -eq 0 ] && [ $RAN -gt 0 ]; then
  echo -e "${GREEN}${BOLD}✓ ALL ${RAN} SUITES PASSED CLEANLY (${DURATION}s)${NC}"
  
  if [ $DO_PACKAGE -eq 1 ]; then
    echo ""
    echo -e "${BOLD}Building release packages in dist/...${NC}"
    ./scripts/package.sh
  fi

  exit 0
else
  echo -e "${RED}${BOLD}✗ ${FAILURES} SUITE(S) FAILED (${DURATION}s)${NC}"
  exit 1
fi
