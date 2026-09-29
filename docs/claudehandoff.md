# Claude handoff: PulseSensation audit and plan review

**Written:** 2026-09-29, 20:50 CEST, at the end of the session.
**Location:** `/Users/erik2/Developer/WoW/claudehandoff.md`. This is deliberately outside the `PulseSensation` repo, so it is not versioned. It is listed in `/Users/erik2/Developer/WoW/.gitignore`, but that directory is not a git repository.
**For:** the next Claude Code session working in `/Users/erik2/Developer/WoW/PulseSensation`.

Read the whole file before acting.

---

## 1. Ground rules (user preferences, confirmed again this session)

1. **Don't edit, commit or push unless explicitly asked.** This session's audit was strictly read-only. The only files written were `Claudereview.md` (on request) and this handoff.
2. **Label every claim** as **[Fact]**, **[Inference]**, **[Rec]** or **[Unverified]**, with a repo-relative `path:line`, a commit hash or command output. Anything that needs the live client or controller hardware is [Unverified].
3. **Be honest about coverage.** The user asks "what did you base this on?". Keep a coverage ledger.
4. **Never conclude absence from truncated output.** Use `grep -c` or read the full output.
5. **Don't spawn subagents** unless asked.
6. **Ask before anything irreversible or outward-facing:** commits, pushes, deleting files, GitHub actions.
7. **Chat style:** `/newspeak` (Orwell register) was on for chat this session. Only use it if the user invokes it again. Deliverables are always plain English.
8. The user normally wants findings recorded in `docs/DOCS_COMPILATION.md`. **That has not been done for this session's work** (see §6).

## 2. Repository state at handoff (verify first)

- **Commits:** branch `main`, HEAD **`db2ffa5`** ("build: simplify release distribution to single PulseHaptics package"). Nothing was committed or pushed this session.
- **Uncommitted edits from a different, concurrent session.** Not made by this one, and still changing while this was written. Snapshot at 20:47:
  - `PulseHaptics/Core/Database.lua`, `Devices.lua`, `Engine.lua`, `Modes.lua`
  - `PulseHaptics/Modules/Locomotion.lua`
  - `PulseHaptics/UI/Panel/Panel.lua`, `Spec.lua`
  - About +310/−101 lines. It appears to be applying the fixes from `Claudereview.md` and the work packages from `implementationplan.md`.
- **Untracked files:**
  - `Claudereview.md`: this session's audit report.
  - `brainstorm.md` and `implementationplan.md`: written by the other session.
- **Stale references:** line numbers in `Claudereview.md` describe `db2ffa5` and no longer match the working tree.

**If HEAD or the dirty file list differs, tell the user before doing anything.**

## 3. What this session produced

### 3.1 Post-implementation audit of `ac3d02f..db2ffa5`: `PulseSensation/Claudereview.md`

**Overall grade C+.** `./scripts/test.sh` at `db2ffa5`: luacheck 0/0 across 51 files, all 7 suites pass. The suites nonetheless missed H1 and H2.

| ID | Severity | Finding (at `db2ffa5`) |
|---|---|---|
| H1 | High | Gallop merge stall. If a re-resolve pushes cadence above 2.387 steps/s while the trail hoof is pending (`nextStep == 2`), footfalls stop until the player stops moving. Reproduced for mounted walk→run and for on-foot → Cat Form. `Locomotion.lua:583-611`. |
| H2 | High | All 4 sweep buttons in the settings window call the undefined `Panel.Refresh()` and throw `attempt to call field 'Refresh' (a nil value)`. Reproduced. `Spec.lua:737/748/1059/1071`. |
| M1 | Medium | `splitFeet` guard removed. On single-motor schemas footfalls alternate by −20% to +57%. `Locomotion.lua:368-370`. |
| M2 | Medium | Curated profiles only apply to fresh installs or a profile Reset. Upgrading users differ by 13–74 cues per profile. All 12 built-ins are now `__exclusive`. Stale comments at `Database.lua:1473-1477` and `2013-2015`. **Needs a user decision.** |
| M3 | Medium | `SetAllCues` notifies every listener immediately, bypassing the combat deferral used by profile switches (`Database.lua:1769-1783`). |
| M4 | Medium | Tests don't discriminate. The deadband test passes against the pre-deadband engine (mutation check). The shaped-envelope test checks only a debug flag. There is no v8 migration test. |
| M5 | Medium | The v8 migration orphans `DB.modeTuning[TRIGGER_*]`. Legacy `__mode` overrides read different tuning keys and show as "Custom" in the dropdown. |
| L1–L10 | Low | Kick length depends on frame rate (`dt*1.2` clamp); 2 table allocations per footfall; absolute `cut` creates an intensity cliff; `kickTime` not validated; drift on the Low-only schema; leftover trigger code; doc mismatches (`CURSEFORGE.md:19`, `Review.lua` header, Immersion-Ranged report covers 189 cues, not 190); `PulseProfileReview/` not linted; `gaitIntensity` fallback 0.35 vs 0.28; double footfall after a frame hitch. |

**Verified sound [Fact]:**
- No live `LTrigger`/`RTrigger` channel path remains.
- The shaped-envelope maths is stable, with no allocation in the engine tick.
- Continuous textures stay isolated from shaped footfalls (simulated: 0.300 before and after).
- The deadband can't oscillate.
- The curated override tables have 0 unknown trigger IDs.

### 3.2 How the reproductions were run (no files written)

- **Scenario appended to an existing test:** load a test file's source, append scenario code, run it with the test's own stubs:
  ```sh
  luajit -e 'local src = io.open("PulseChecklist/tests/locomotion-test.lua"):read("*a")
  src = src .. [==[ ...scenario using the test file locals (eventFrame, pollFrame, onUpdate, holdCalls, M)... ]==]
  arg = { [0] = "locomotion-test.lua", "PulseHaptics" }
  assert(loadstring(src))()'
  ```
  The same trick works on `harness.lua`: `Pulse.UI.Panel.EnsureBuilt()`, then click `kind == "button"` rows with `pcall`.
- **Mutation test:** feed an older file from git in place of the current one:
  ```sh
  luajit -e 'local src = io.popen("git show 46e9d9e^:PulseHaptics/Core/Engine.lua"):read("*a")
  local orig = loadfile; loadfile = function(p, ...) if p:match("Core/Engine%.lua$") then return load(src) end return orig(p, ...) end
  arg = { [0] = "PulseChecklist/tests/engine-test.lua", "PulseHaptics" }; dofile("PulseChecklist/tests/engine-test.lua")'
  ```
- **Standalone Engine simulation:** stub `GetTime`, `C_GamePad`, `CreateFrame`, `wipe` and `Pulse.Database`, load Modes/Devices/Standard/Engine, then drive `scripts.OnUpdate(nil, dt)` and record `SetVibration` calls.

### 3.3 Review of `brainstorm.md` and `implementationplan.md` (chat only, not written to disk)

**Verdict:**
- **Brainstorm:** the direction is reasonable, but much of the evidence is unsourced or likely invented and is presented as "verified". Examples: an SDL "0–8,000 deadband" doc, oscilloscope and teardown data, Valve firmware "mathematically identical", battery +25–35%, "acclaimed by testers". It also contradicts itself on motor frequency ranges.
- **Plan:** not implementable as written.

**Key plan defects:**
- **WP1 overdrive:** `shaped > wanted` with a nil `shaped` crashes the release path (fix: `shaped or 0`). Its expected test value (0.825) ignores smoothing and the floor remap. It is not gated on `isTransient`. It stacks on the existing footfall `kickGain`.
- **WP2 coast-down:** shortening layer duration doesn't cut voltage, because release smoothing keeps driving the motor. It uses the Low motor's `coastCoeff` for High-only layers, and cuts CLICK to 15 ms, below `MIN_STEP_DURATION`.
- **WP3 ducking:** reverses the documented policy at `Engine.lua:683` ("continuous baseline is NEVER muted or ducked"). It ducks on any transient, including UI ticks, and so hides low-health and cast textures. Its numbers are inconsistent.
- **WP4 smoothstep S-curve:** compresses the low end (0.10 → 0.028), the opposite of what it claims, and contradicts gamma 0.88. A boolean `useSCurve` can't be stored, because `SetChannelTuning` accepts numbers only and `ApplyDevicePreset` copies only `CHANNEL_DEFAULTS` keys.
- **WP6 vs WP8:** conflicting Xbox preset values.
- **WP7:** its hygiene test fails on `DRAW` (`gap 0.03`). The retune changes 74+ cues (TAP drives 50, TICK 24) right after PROF-REVIEW, and makes the High-only taps less distinct, not more.
- **WP8:** the "drop-in" block omits `steamcontroller`, `steamcontroller2` and `default`. The precision changes (0.120 → 0.125 and similar) are false precision.

**Worth keeping:**
- WP5 rate cap (drop the battery claim).
- Overdrive, but only on transients, applied after smoothing or inside the shaped lane, and default off.
- Crisper multi-pulse modes via the existing shaped lane.
- The MICRO_TAP/DEFLECT duplicate fix [Fact: both are high 0.50 × 0.06].

**Park:**
- The smoothstep S-curve.
- The coast-down duration trim.
- Directional damage panning (there's no attacker-direction API, and `COMBAT_LOG_EVENT_UNFILTERED` is unavailable to addon frames).
- Ducking, until the user decides on the policy.

### 3.4 Answers already given to the user

- **Can git revert the code?** Yes, if each work package is its own commit.
- **Can it undo saved data?** No:
  - A DB migration or `ApplyDevicePreset` (which wipes `DB.channelTuning`, including players' Ramp calibration) changes players' `PulseDB`, and a code revert doesn't undo that.
  - Uncommitted edits have no revert point.
  - Anything uploaded to CurseForge can only be superseded.
- **Worst case:** no hardware risk, since `SetVibration` is capped at 1.0. The risks are:
  - calibration loss;
  - the addon going silent from the WP1 nil compare;
  - 74+ cues changing feel;
  - ducked information-carrying textures.
- **Best case:** modest, measured gains on Xbox (onset crispness, distinct multi-pulses, fewer sends at high FPS), with zero change for DualSense/LRA users.

## 4. Snapshot of the concurrent uncommitted work (20:47, still in flux)

Observed with `grep` only; **not reviewed**.

**Appears addressed [Fact, from grep]:**
- H2: `Panel.Refresh()` calls in `Spec.lua` are now 0.
- H1: `if isGallopMerged and nextStep == 2 then` guard at `Locomotion.lua:619`.
- M3: `SetAllCues` now defers under `InCombatLockdown`.
- M5: `DB_VERSION = 9` with `_MigrateLegacyTriggerModes`. It renames `DB.modeTuning[TRIGGER_*]` and `__mode` values and clears `LTrigger`/`RTrigger` tuning. It carries `triggerMult` along unchanged.
- WP1 nil guard: `shaped = shaped or 0` at `Engine.lua:553`.

**Plan work packages implemented, contrary to this session's recommendations:**
- **WP2** coast-down in `SetRoles`: still uses the Low motor's `coastCoeff` for all layers (`Engine.lua:294`).
- **WP3** sidechain ducking (`Engine.lua:764-773`, factor `max(0.30, 1 - trans*0.65)`): **this reverses the "never duck" policy without a recorded user decision.**
- **WP4** `useSCurve` in `mapValue` (`Engine.lua:529`): `CHANNEL_DEFAULTS.useSCurve = false` is a boolean.
- **WP8** preset recalibration: the Xbox note still claims "Mabuchi … 24mm".

**Tests at 20:47:** luacheck 0/0. `harness` FAIL 1 ("Transient layers on top of continuous baseline"), caused by the ducking. `engine-test` FAIL 4 (preset values: steamdeck gain and floor, dualsense floor, ds4 floor). The other 5 suites pass.

## 5. Open decisions for the user

1. **M2 curation rollout:** (a) document "Reset to get the curated set", (b) force it in a migration, or (c) apply it only to built-ins the user never modified. (c) is recommended.
2. **Ducking:** reverse the "never duck" policy (WP3) or not? It is already implemented in the uncommitted tree.
3. **Mode retune (WP7):** accept feel changes to 74+ cues right after PROF-REVIEW, which would require a re-review?
4. **Presets (WP8):** relabel them "starting guesses", or keep the "verified" claims? A measurement method is needed first (Ramp page plus slow-motion video or an accelerometer app).
5. **Commit `Claudereview.md`,** or keep it local? Add it to `.gitignore`?
6. **Write this session's findings into `docs/DOCS_COMPILATION.md`?**

## 6. Recommended next steps

1. Wait until the other session has finished editing, then `git status` and `git diff --stat`.
2. Review that diff against §3.1 and §3.3 before any commit. Specifically:
   - the ducking policy (needs a user decision);
   - the coast-down channel coefficient;
   - the S-curve direction;
   - `useSCurve` storage type;
   - preset completeness (`steamcontroller`, `steamcontroller2`, `default`);
   - DRAW gap vs the hygiene test;
   - the v9 migration keeping `triggerMult`;
   - the failing tests.
3. **Commit strategy** (only when asked):
   - one commit per fix or work package so each can be reverted;
   - DB migrations in their own commit;
   - the `ApplyDevicePreset` / calibration-wipe risk called out in the commit message or release notes.
4. **Add the regression tests from `Claudereview.md` §6 item 6:**
   - the gallop-transition reproductions;
   - a sweep-button click pass;
   - a discriminating deadband test;
   - shaped output values;
   - a v7→v8→v9 migration test;
   - splitFeet on single-motor schemas.
5. Don't push or upload to CurseForge until the tests pass and the user has made the §5 decisions.
