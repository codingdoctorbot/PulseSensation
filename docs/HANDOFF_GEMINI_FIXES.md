# Handoff: PulseSensation fixes (for Gemini)

**Written:** 2026-09-29, by the reviewer (Claude), for the agent doing the code changes.
**Baseline:** HEAD `ac3d02f` plus uncommitted work in 5 files (see §3). Line numbers below are from this baseline; they drift as you edit, so find code by function name.

---

## 1. What to read first

1. This file, in full.
2. `docs/CODE_REVIEW.md` — the findings, `CR-001` … `CR-031`. Each has *Where* (file:line), *What*, *Evidence* and *Fix direction*. The user asked for its prose in a compressed style ("Newspeak"); code, paths, numbers and probe output in it are exact. Glossary:
   - `ungood` = broken; `plusungood` = seriously broken; `doubleplusungood` = critical.
   - `plusgood` = works, not fully verified; `doubleplusgood` = verified working.
   - `goodthink` = follows the codebase's convention; `crimethink` = violates it or invites bugs.
   - `bellyfeel` = repeated from somewhere, not checked; `rectify` = fix; `unperson` = remove.
   - Labels: `[Fact]` checked; `[Inference]` reasoned; `[Rec]` recommendation; `[Unverified]` needs the live client or hardware.
3. `docs/DOCS_COMPILATION.md` §11 — the same review summarised in plain English. §4 of that file tracks the status of older known issues; §10.2 reviews the uncommitted work.

**Trust, but verify.** Before changing anything, confirm the finding against the current code. If the code disagrees with the review, the code wins: note it in the fix log (§8) and move on.

---

## 2. Environment facts (do not rediscover)

- **Client:** "WoW Forever", a classic-style game on the modern 12.x engine (`## Interface: 120100`). Retail-style APIs, classic content. The client's own UI source and API docs are in `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/` (API docs: `Interface/AddOns/Blizzard_APIDocumentationGenerated/`). Check every API or event you use there.
- **Lua 5.1 semantics.** Test with `luajit`. No `goto`, no `//`, no bitwise operators. `math.clamp` and `math.lerp` **do not exist** on this client (a confirmed crash); use the local `clamp01` helpers.
- **Secret values.** Many event payloads and API returns can be "secret" (the docs flag them with `SecretWhenUnitSpellCastRestricted`, `SecretInChatMessagingLockdown`, `SecretReturns`, and so on). Comparing, concatenating, doing arithmetic on, or using a secret as a table key errors. Guard with `issecretvalue(v)` **before** any of those. `C_Secrets.ShouldUnitSpellCastingBeSecret(unit)` exists and is unused.
- **Vibration API:** `C_GamePad.SetVibration(vibrationType, intensity)` and `C_GamePad.StopVibration()` (no arguments). `"Low"` and `"High"` work. `"LTrigger"` and `"RTrigger"` are **unconfirmed** on this client.
- **The game runs this repo directly.** `Interface/AddOns/PulseHaptics`, `PulseDebug` and `PulseChecklist` are symlinks to this working tree. Any edit is live in game after `/reload`, and a broken file breaks the user's game session.
- **Taint.** Never add callbacks into Blizzard managers (`SmartNavigation`, `EventRegistry`, `GamepadMode`), secure templates, or new `hooksecurefunc` hooks without a stated reason. `UNIT_PING_PIN_ADDED` is registration-restricted (CR-031).

---

## 3. Repository state and first decision

Uncommitted work (`git status`): `PulseHaptics/Core/CastActivity.lua`, `Core/Database.lua`, `Core/Engine.lua`, `PulseChecklist/tests/crafting-test.lua`, `tests/harness.lua`. It contains:
- the cast sweep raised from 10 s to 30 s, with protection while a cast is running;
- `RenameProfile` now notifying listeners;
- minimum step and gap durations for modes;
- an onset force-send in the engine.

Review: DOCS_COMPILATION §10.2. `crafting-test` currently fails 3 assertions, **because the test looks up the wrong key**, not because the code is wrong.

**Decision D1 (user):** keep the uncommitted work (recommended) and fix its test, or drop it. Do not discard it without asking.

**Committing is your job** (the user's decision, 2026-09-29).
- Your first commit is docs only, `docs: add code review, compilation and fix handoff`. It contains `docs/CODE_REVIEW.md`, `docs/DOCS_COMPILATION.md`, `docs/HANDOFF_CODE_REVIEW.md` and this file, so every fix commit can cite a versioned reference.
- The uncommitted code (above) is committed only after D1, inside WP-0.
- Never commit `Ongoing Bugs/`, `ProfileReviewReports/` or `PulseProfileReview/` unless the user says so.
- Never push.

Untracked folders you must **not** modify: `Ongoing Bugs/`, `ProfileReviewReports/`, `PulseProfileReview/` (a separate tool), `docs/DevelopmentplusReference/`. Do not touch `PulseHaptics/Libs/` (third-party).

---

## 4. Rules

1. **One finding per commit.** Message style: `fix(<area>): <what> (CR-0xx)`. Do not push; the user pushes.
2. **Every fix ships with a test** that fails before the fix and passes after, in `PulseChecklist/tests/`. The review's own probe scripts lived in a temporary folder and are gone; write your own.
3. After each change, all of these must be clean:
   - `./scripts/test.sh` (exit 0);
   - each suite under LuaJIT: `luajit PulseChecklist/tests/<suite>.lua PulseHaptics` for `harness`, `locomotion-test`, `crafting-test`, `engine-test`, `cue-audit`; `luajit PulseChecklist/tests/pulsedebug-test.lua PulseDebug`; `luajit PulseChecklist/tests/checklist-test.lua PulseChecklist`;
   - `luacheck PulseHaptics PulseDebug PulseChecklist` (0 warnings).
4. **Keep existing decisions.** Do not reopen them:
   - continuous textures are never ducked or muted under alerts ("immersion-first", `Engine.lua:573`);
   - keep `MicroFlutter` until the watchdog is verified on hardware;
   - the settings window is mouse-only by design (`UI/Panel/Gamepad.lua:69`).
5. **No architecture rewrites.** Small, targeted changes. Correctness beats the zero-allocation rule (CR-013 came from pooling), but keep per-frame paths (`OnUpdate`, tick functions) free of new table or closure allocation.
6. **Do not change device preset numbers** in `Core/Devices.lua`. They need hardware measurement (CR-019, §7).
7. **Cue ids and setting keys are SavedVariables keys.** Never rename them. Any change to saved data gets a `DB_VERSION` bump plus a migration in `Core/Database.lua`, and the stored version must never go down.
8. **Stop and ask** when a step needs one of the decisions in §5.

---

## 5. Decisions that belong to the user (ask before these steps)

| ID | Decision | Blocks |
|---|---|---|
| D1 | Keep or drop the uncommitted work | WP-0 |
| D2 | Mixer policy: keep the saturating sum for continuous layers (current) or add a switch back to MAX (DOCS §6 #1) | CR-008 d |
| D3 | Per-cue Intensity law: cap each slider at its mode's ceiling, or apply intensity after mode shaping | CR-008 a |
| D4 | Replace the linear floor lift (`floor + (1-floor)*x`) with a dead-zone curve. This changes the feel on every preset | CR-008 b |
| D5 | Overall intensity: global, or per profile with the value shown next to the profile picker | CR-008 c |
| D6 | bossAbilityWarning: hide now, or rebuild on `C_EncounterTimeline` (needs in-game secrecy check V9) | CR-007 |
| D7 | "Ping placed" cue: remove, or keep and hide on Forever | CR-031 |
| D8 | Feel defaults: fishing texture level, `mountedOnly` default, Controller UI cues default on/off, weather levels | CR-003, CR-005, CR-009, CR-026 |
| D9 | Halve saved cadence values when cadence switches to real steps per second (migration) | CR-005 (4) |

---

## 6. Work packages, in order

Each package lists the findings (details in `docs/CODE_REVIEW.md`), the files, the change, and when it is done.

### WP-0 Green baseline (after D1)
- **Uncommitted work:**
  - in `crafting-test.lua:368-385`, look up `pending["g:guid-hearth-1"]` (that is how `keyFor` builds keys, `CastActivity.lua:65-70`);
  - make the 60 s ceiling assertion real: keep `UnitCastingInfo` returning a cast past 60 s, then assert removal;
  - replace the three literal `60`s in `_Sweep` (`CastActivity.lua:343`, `:349`, `:355`) with a named constant;
  - make the onset comment at `Engine.lua:477-479` match the code (`forceSend = isOnset` only).
- **Test runner** (CR-027 and the known `set -e` bug, `scripts/test.sh`):
  - capture suite exit status with `|| status=$?` so a crashing suite prints and fails;
  - add `LUA=${LUA:-luajit}`;
  - grep from a here-string instead of `echo | grep -q`.
- **Vacuous tests** (CR-017): replace each listed check with a real assertion. Make the PulseDebug test fake match the real API: no `HoldLayer`/`CancelAll`.
- **Done when:** `./scripts/test.sh` exits 0, and a deliberately broken suite makes it exit non-zero.

### WP-1 Debug tooling the user needs for in-game tests
- CR-016 (`PulseDebug/UI.lua:355-371`, `:303-322`):
  - log HOLD calls on the rising edge only (the `HOLD_LOG_GAP` pattern in `Core/Init.lua`);
  - install hooks when the window first opens;
  - use a ring buffer instead of `table.insert(t, 1, …)`.
- Add a "Cast trace" view: each `CastActivity` classification with spellID, whether a castGUID was present, and arrival order. The user will use it to settle the channel event order (V1).
- **Done when:** with one continuous texture running, FIRE lines stay visible in the log.

### WP-2 Channels and fishing (user's report Q1)
- **CR-002 first** (valid whatever the in-game test shows):
  - `Modules/Combat.lua:540-552` stops castTexture on any `INSTANT`/`FAILED`/`INTERRUPTED`/`CAST_STOPPED`/`CHANNEL_STOP`.
  - Remember the identity of the cast or channel that started the texture (castGUID, else spellID). Stop only on a terminal event for that same identity.
  - Keep the `UnitCastingInfo`/`UnitChannelInfo` nil check in `castTick` as the safety net.
- **CR-001** (`Core/CastActivity.lua`, `_OnSucceeded` and `_OnChannelStop`):
  - a SUCCEEDED during an active channel with a matching spellID (GUID optional) only confirms the channel; it must never emit `CHANNEL_COMPLETE`;
  - completion comes only from `CHANNEL_STOP` with `interruptedBy == nil`;
  - an unmatched SUCCEEDED while a channel is active must not end the channel's texture.
- **Crafting** (`Modules/Crafting.lua:482-525`): end gathering or fishing only on the tracked spell's terminal event.
- **Tests** (new `cast-test.lua`, or extend `crafting-test.lua`). Sequences:
  - `CHANNEL_START → SUCCEEDED (same GUID) → CHANNEL_STOP`;
  - the same with a different GUID;
  - channel plus an unrelated instant SUCCEEDED;
  - channel plus a tick spell's SUCCEEDED (different spellID, for example Arcane Missiles 5143 → tick 7268);
  - cast plus a FAILED from a spell pressed mid-cast.
  
  In each, assert that the texture is still holding and the classification is right.
- **CR-003** (fishing level 0.07 → about 0.049 after master) after D8.
- **Done when:** the tests pass. The user then confirms in game (V1).

### WP-3 Engine correctness
- **CR-013**, the role-pool aliasing: apply the draft in `Ongoing Bugs/eng-01-fix-draft.md` (read it; it is correct). Immediate steps may use the pool; delayed steps capture `low`/`high`/`ltrigger`/`rtrigger` as locals and build a private table when the timer fires. Test: a two-step KNOCK plus more than 16 other steps inside its window keeps its second hit on High at full strength.
- **CR-029:** Strength 0 must silence the motor. In `driveChannel` (`Engine.lua:429-444`), apply gain before the zero check so that `wanted * gain == 0` returns 0, and the floor lift never runs. Test: gain 0 on a preset with floor 0.12 gives 0.
- **CR-012:** add an `isTransient` path for short knocks built on holds: `Engine:Hold`/`HoldRoles`, and `Pulse:HoldIfEnabled`/`HoldRolesIfEnabled` (or a new `Pulse:KnockIfEnabled`). Use it for heartbeat knocks (`Modules/Health.lua`) and breath gasps (`Modules/Environment.lua`). Test: a 50 ms knock reaches at least 90 % of its target.
- **Raw calibration path** (`Engine.lua:518`, `:529`, bare `C_GamePad.SetVibration`): wrap in `pcall`. On failure, clear only that raw hold and report the error on the calibration page instead of letting it reach the `OnUpdate` recovery, which calls `StopAll` and kills every live cue. The error text also answers whether the trigger channels are accepted (CODE_REVIEW §14 #3).
- **Header text** (CR-025 part): `Engine.lua:5` and `:417-421` still say "max-blend". Layers use a saturating sum; only role→channel collisions use max.

### WP-4 Previews and sliders that ignore Intensity
- **CR-006:** heartbeat ▶ previews ignore the cue's intensity. Pass the scale into `Health` `TestHeartbeat`/`TestWarningBeat`.
- **CR-014:** craft strikes skip the cue's intensity and the master and cue gates (`Crafting.lua:408-420`). Multiply by `GetTriggerSetting(CUE, "intensity", 1)`, or route through `FireIfEnabled` with `intensityOverride`.
- **CR-018:** "Feels like" dropdown picks preview at 1.0 (`UI/Panel/Popup.lua:247-250`). Preview through the cue's own intensity; keep raw `TestMode` only for "Mode to test".
- CR-008 a–d wait for D2–D5.

### WP-5 Footsteps (user's report Q4)
- **CR-005 (1)(2)** (`Modules/Locomotion.lua`):
  - fire each footfall as a short transient at real step times, instead of a continuous sine through the slow continuous attack;
  - make cadence real steps per second;
  - GALLOP: one lead and one trail per stride.
  
  Test: footfalls per second equal the configured steps per second, on foot and mounted.
- **CR-030:** split feet only when the active schema actually routes `ltrigger`/`rtrigger` to trigger channels (`resolveRole(schema, "ltrigger").channel`). Today the preset's `triggers` flag alone turns the split on, so under the default Standard schema an Xbox preset sends left feet to Low and right feet to High. Test: no split under `standard` for any preset.
- **CR-020:** store the *applied* preset id at Apply and read that, not the dropdown label.
- Cadence migration after D9; `mountedOnly` default after D8. Choosing Low or High for footfalls on DualSense/SC2 waits for measurements (V4).

### WP-6 Continuous-texture previews (user's report Q5)
- **CR-004:** `Pulse:TestCue` plays a flat 0.45 on both motors for every continuous cue (`Core/Init.lua:239-248`, `:300-307`). Give each continuous module a `Preview(seconds, scale)` that runs its real shaping against synthetic state, the way `Health` already does. Cues: swim, water, ocean, taxi, glide, cast, craft, breath, weather, stealth, locomotion; heartbeat is done. The preview layer must be cancellable, like the existing token pattern. Test: each preview's output varies over time and uses the cue's real motors.
- **CR-026:** weatherTexture has no tunables and reaches at most about 0.06. Add tunables; default levels after D8.

### WP-7 Dead features and secret safety
- CR-007 per D6; CR-031 per D7.
- **CR-009:** in `Modules/ControllerUI.lua:50-67`, use the fallback only when `InputUtil.IsGamepadUIEnabled` is absent. When it exists, trust its answer.
- **CR-010:** drop the `unit ~= "target"` comparison (`Modules/AlertUnitWatch.lua:253-256`); frame registration already filters by unit.
- **CR-011** (`Modules/World.lua:50-61`):
  - return early if `message` or `sender` is secret;
  - escape `playerName` with `:gsub("%p", "%%%0")`;
  - the `%f[%a]` frontier pattern never matches names that start with a non-ASCII letter (one of the user's characters). Use a boundary check that treats bytes ≥ 0x80 as letters, or a plain `find` plus a manual boundary test.
- **Secret guards:** `keyFor` (`CastActivity.lua:65-70`) and the `_Sweep` truthiness tests (`:334-339`).
- **CR-015:** `PulseChecklist/Checklist.lua:756-772` detects section status keywords only on `^#+` header lines.
- **CR-024:**
  - remove `"PING_PIN_ADDED"` (absent on Forever);
  - remove the dead `LEARNED_SPELL_IN_TAB` branch;
  - guard `/pdebug watch` registration;
  - add both tool frames to `UISpecialFrames`.
- PulseDebug "Hold 2s" button (`PulseDebug/UI.lua:731-739`) must use a real engine call.

### WP-8 P3 sweep
- **CR-021:** set `lastResolved` after rename or delete.
- **CR-022:** validate SavedVariables types at load, quarantining bad subtables.
- **CR-023:** skip `SetPropagateKeyboardInput` in combat.
- **CR-025:** text sweep, including the Ramp tooltip "half power over eight seconds" (really 0.40 over about 16 s).
- **CR-028** nits.
- **CR-019 extension:** move `"8bitdo"`/`"sn30"` ahead of `"xbox"`/`"xinput"` in `NAME_PATTERNS` (`Devices.lua:342-362`).
- **Known docs items:** README says "202 triggers, 21 categories"; the real count is 190 cues. Also the Registry header, and the tests README.

---

## 7. Not for you

- **Device preset numbers, and footfall channel choice on LRA pads** (CR-019, CR-005 (3)). They need the user's Ramp measurements on the real DualSense and Steam Controller 2.
- **In-game checks** V1–V12 (`docs/CODE_REVIEW.md` §8). Only the user can run them. The most urgent:
  - **V1:** channel event order, using WP-1's cast trace;
  - **V12:** which preset was applied, and whether Steam Input was on, during the DualSense/SC2 tests. The saved settings show the Xbox preset applied.
- **Claims already checked and rejected** (do not "fix"):
  - MicroFlutter phase precision — doubles are fine;
  - the watchdog "drops input equal to the decayed value" — the output already matches;
  - priority ducking — contradicts the immersion-first decision.

---

## 8. Reporting

Keep `docs/FIX_LOG.md`: one row per finding with CR id, commit hash, test name, and "verified by test" or "needs in-game check". Note any finding whose premise the code contradicted. Do not edit `docs/CODE_REVIEW.md`; its findings are the reference.
