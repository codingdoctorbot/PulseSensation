# Fix Log — PulseSensation Review Findings

| Finding ID | Commit Hash | Summary of Change | Test Suite / Regression Case | Verification Status |
|---|---|---|---|---|
| (Baseline) | `955c066` | Hearthstone 30s timeout, PlayMode step floor, Rename notification, Watchdog onset force-send | `crafting-test.lua`, `engine-test.lua`, `harness.lua` | Verified by test |
| `CR-027` | `036937e` | Test runner subshell status capture, LuaJIT default, here-strings | `scripts/test.sh` | Verified by test |
| `CR-017` | `036937e` | Align PulseDebug test mocks with real Engine API, verify 60s hard ceiling under active casting | `pulsedebug-test.lua`, `crafting-test.lua` | Verified by test |
| `CR-016` | `e8693bd` | Implement pre-allocated ring buffers in PulseDebug, debounce continuous HOLD hooks, add Cast trace view | `pulsedebug-test.lua` | Verified by test |
