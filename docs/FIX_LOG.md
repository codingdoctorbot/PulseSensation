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
| `CR-013` | `ddb8312` | Isolate delayed PlayMode step roles by capturing scalars to prevent role-pool aliasing corruption | `engine-test.lua` | Verified by test |
| `CR-029` | `ddb8312` | Evaluate gain before breakaway floor in driveChannel so gain 0 silences the motor | `engine-test.lua` | Verified by test |
| `CR-012` | `ddb8312` | Add isTransient parameter to Engine:Hold and Pulse:HoldIfEnabled for fast attack on heartbeat/breath | `engine-test.lua` | Verified by test |
| `ENG-03` | `ddb8312` | Wrap raw calibration SetVibration calls in pcall and isolate calibrationError | `engine-test.lua` | Verified by test |
| `CR-025` | `ddb8312` | Align Engine header comments with saturating mixer architecture | Inspection | Verified by inspection |
| `CR-006` | `1a34d9e` | Pass configured cue intensity into heartbeat and warningbeat previews; use isTransient for fast attack | `harness.lua` | Verified by test |
| `CR-014` | `1a34d9e` | Scale crafting anvil strike strength by configured trigger intensity setting | `crafting-test.lua` | Verified by test |
| `CR-018` | `1a34d9e` | Dropdown mode selection previews scale by active cue configured intensity | `harness.lua` | Verified by test |
| `CR-005` | `1f90f27` | Discrete transient footfall taps (45ms, isTransient=true), real steps/s cadence, single lead+trail per GALLOP stride | `locomotion-test.lua` | Verified by test |
| `CR-030` | `1f90f27` | Split feet only when active schema routes trigger roles to trigger channels (prevent Xbox split on Standard) | `locomotion-test.lua` | Verified by test |
| `CR-020` | `1f90f27` | Read applied preset from appliedDevicePreset instead of unapplied dropdown selection | `locomotion-test.lua` | Verified by test |
| `CR-004` | `a8054ab` | Module-driven bespoke continuous previews across Movement, PlayerState, Flight, Combat, Crafting, Environment, Locomotion | `harness.lua` | Verified by test |
| `CR-026` | `a8054ab` | Expose weatherTexture tunables (rainLevel, snowLevel, stormLevel, patterRate) in Registry and modulate in Environment | `harness.lua` | Verified by test |
| `CR-009` | `5a2c17e` | Trust InputUtil.IsGamepadUIEnabled() when available; only use gamepad enabled fallbacks when API is nil | `harness.lua` | Verified by test |
| `CR-010` | `5a2c17e` | Remove redundant unit comparison in AlertUnitWatch targetBigDefensive handler; guard spellID against secrets | `harness.lua` | Verified by test |
| `CR-011` | `5a2c17e` | Guard CHAT_MSG_TEXT_EMOTE message/sender against secrets; escape playerName special characters; guard CastActivity:keyFor | `harness.lua` | Verified by test |
| `CR-031` | `5a2c17e` | Clear events list on pingPinAdded to prevent registration of restricted UNIT_PING_PIN_ADDED | `harness.lua`, `cue-audit.lua` | Verified by test |
| `CR-024` | `5a2c17e` | Add PulseDebugUIFrame and PulseChecklistFrame to UISpecialFrames; remove dead LEARNED_SPELL_IN_TAB; pcall-guard pdebug watch | `pulsedebug-test.lua`, `checklist-test.lua` | Verified by test |
| `CR-015` | `5a2c17e` | Match section status keywords only on header lines (^#+); accept work as needswork in compact import | `checklist-test.lua` | Verified by test |
| `CR-021` | `b5fc335` | Update lastResolved immediately upon profile rename and deletion to eliminate redundant re-sync on PLAYER_REGEN_ENABLED | `harness.lua` | Verified by test |
| `CR-022` | `b5fc335` | Validate table structures and types in Database:Init, quarantining malformed entries to __corrupt | `harness.lua` | Verified by test |
| `CR-023` | `b5fc335` | Guard SetPropagateKeyboardInput in Popup dialog against InCombatLockdown; dismiss dialog on PLAYER_REGEN_DISABLED | `Popup.lua` | Verified by inspection |
| `CR-019` | `b5fc335` | Reorder NAME_PATTERNS in Devices.lua to prioritize 8BitDo models over generic XInput/Xbox | `harness.lua` | Verified by test |
| `CR-025` | `b5fc335` | Dynamically calculate Ramp tooltip duration (~16s) and 40% peak; align showAdvancedCueControls default; sync cue and mode counts | `Spec.lua`, `Guide.lua`, `Modes.lua`, `Registry.lua`, `harness.lua` | Verified by test |
| `CR-028` | `b5fc335` | Guard GetMoney in MERCHANT_SHOW; allow minimap master toggle during combat; require active connected device for status badge | `Interaction.lua`, `Minimap.lua`, `Panel.lua`, `harness.lua` | Verified by test |
| `HW-TRIG` | `8a67a43` | Eliminate phantom trigger channels (LTrigger/RTrigger) across engine, devices, schemas; reprogram 7 trigger modes to SNAP, DRAW, MICRO_TAP, STACCATO, RECOIL, SHUTTLE, TENSION with backward-compatibility aliases; retire RumbleAndTriggers & TriggerEmphasis schemas with DB_VERSION 8 migration fallback | `engine-test.lua`, `harness.lua` | Verified by test |
| `LOCO-SHAPE` | `8a67a43` | Implement shaped layers in Engine (exponential decay envelope, kick gain, zero-smoothing bypass) and shaped locomotion footfalls with 6 surface/mount timbres, stereo pan splitFeet, and gallop pair merge under 80ms | `locomotion-test.lua`, `engine-test.lua` | Verified by test |
| `ENG-DEADBAND` | `46e9d9e` | Snap decaying continuous rumble to 0 below 0.025 on shutoff to eliminate mechanical stall whine and watchdog traffic | `engine-test.lua` | Verified by test |
| `PROF-REVIEW` | `04b6638` | Curate all 190 cues across 12 default profiles, add sweep enable/disable buttons to Spec/Panel/PulseProfileReview, and generate review reports | `harness.lua` | Verified by test |
