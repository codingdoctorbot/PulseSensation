# Fix Log — PulseSensation Review Findings

| Finding ID | Commit Hash | Summary of Change | Test Suite / Regression Case | Verification Status |
|---|---|---|---|---|
| (Baseline) | `955c066` | Hearthstone 30s timeout, PlayMode step floor, Rename notification, Watchdog onset force-send | `crafting-test.lua`, `engine-test.lua`, `harness.lua` | Verified by test |
| `CR-027` | `036937e` | Test runner subshell status capture, LuaJIT default, here-strings | `scripts/test.sh` | Verified by test |
| `CR-017` | `036937e` | Align PulseDebug test mocks with real Engine API, verify 60s hard ceiling under active casting | `pulsedebug-test.lua`, `crafting-test.lua` | Verified by test |
| `CR-016` | `087622f` | Implement pre-allocated ring buffers in PulseDebug, debounce continuous HOLD hooks, add Cast trace view | `pulsedebug-test.lua` | Verified by test |
| `CR-001` | `73ecfc5` | Isolate channel lifecycle: emit `CHANNEL_CONFIRMED` on channel `SUCCEEDED`, emit `CHANNEL_COMPLETE` on un-interrupted `CHANNEL_STOP` | `crafting-test.lua` | Verified by test |
| `CR-002` | `73ecfc5` | Protect `castTexture` from cross-talk teardown by matching against `activeCastGUID`/`activeSpellID`; track gather/fishing terminal spell ID | `crafting-test.lua` | Verified by test |
| `CR-003` | `73ecfc5` | Raise baseline fishing bed from 0.07 to 0.12 so rumble clears the breakaway floor | `crafting-test.lua` | Verified by test |
| `CR-013` | `219bdce` | Isolate delayed PlayMode step roles by capturing scalars to prevent role-pool aliasing corruption | `engine-test.lua` | Verified by test |
| `CR-029` | `219bdce` | Evaluate gain before breakaway floor in driveChannel so gain 0 silences the motor | `engine-test.lua` | Verified by test |
| `CR-012` | `219bdce` | Add isTransient parameter to Engine:Hold and Pulse:HoldIfEnabled for fast attack on heartbeat/breath | `engine-test.lua` | Verified by test |
| `ENG-03` | `219bdce` | Wrap raw calibration SetVibration calls in pcall and isolate calibrationError | `engine-test.lua` | Verified by test |
| `CR-025` | `219bdce` | Align Engine header comments with saturating mixer architecture | Inspection | Verified by inspection |
