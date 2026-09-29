# POST-IMPLEMENTATION AUDIT REPORT — PulseSensation `ac3d02f..db2ffa5`

**Date:** 2026-09-29
**HEAD audited:** `db2ffa5` (build: simplify release distribution to single PulseHaptics package)
**Auditor:** Claude (read-only audit; this file is the only output written)

**Scope:** 25 commits. Audited in depth:
- `8a67a43` (HW-TRIG + LOCO-SHAPE)
- `46e9d9e` (ENG-DEADBAND)
- `04b6638` (PROF-REVIEW)
- `194b9fe` (ORG-DOCS)
- `3f9667b`, `a79b9a1` and `db2ffa5` (docs, gitignore and packaging)

The 15 earlier CR-fix commits (`955c066` … `f37b37c`) were reviewed only where they touch these features. The coverage list is in §6.

**Method:**
- Read the diffs and the touched source files.
- Ran `./scripts/test.sh`.
- Ran five in-memory reproductions: the repo's own test harnesses loaded through `loadstring` with scenario code appended, or `Engine.lua` pulled from git with `io.popen("git show …")`. Nothing was written to disk.

**Labels:**
- **[Fact]** – verified from code or a reproduction.
- **[Inference]** – reasoned from code, not run.
- **[Rec]** – recommendation.
- **[Unverified]** – needs a live client or hardware.

---

## 1. Executive Summary & Quality Grade

**Overall grade: C+**

| Area | Grade | One-line reason |
|---|---|---|
| HW-TRIG channel removal | **B+** | No live trigger-channel path remains and the v8 migration is safe. Legacy mode tuning is orphaned. |
| Shaped engine + deadband | **B+** | The math is stable, the engine tick allocates nothing per frame, and continuous textures stay isolated (checked in simulation). Kick length depends on frame rate. |
| Locomotion | **C−** | **Reproduced: the gait stays silent for good** after an unmerged→merged gallop change. The splitFeet hardware guard was removed. |
| Profiles & sweep controls | **C−** | **Reproduced: all 4 panel sweep buttons throw a Lua error.** The curated profiles never reach existing installs. The sweep skips the combat deferral. |
| Tests & toolchain | **D+** | All green, but blind to both reproduced bugs. The deadband test also passes on the code from before the deadband (mutation check). |

The engine work is well built. Most of the problems are in the layers above it (locomotion step state, UI wiring, rollout) and in tests that don't actually check what they claim.

---

## 2. Hardware & Trigger Channel Elimination Audit

### 2.1 Verified clean

- **[Fact]** `Pulse.CHANNELS = { "Low", "High" }` (`PulseHaptics/Core/Devices.lua:27`).
  - All 4 remaining schemas route only to `Low`/`High`; the two trigger schemas were deleted in `8a67a43`.
  - A case-sensitive grep for `LTrigger|RTrigger` across all `.lua/.toc/.sh/.py/.json` files outside `docs/` finds only a comment (`Devices.lua:22`) and a stale test stub (`PulseChecklist/tests/locomotion-test.lua:157-163`).
  - No code path can hand `C_GamePad.SetVibration` a trigger channel.
- **[Fact]** No mode uses the `ltrigger`/`rtrigger` roles any more. The only role reference is the derived-info loop at `Modes.lua:406`.
  - The legacy role fallback (`Engine.lua:136`) still routes any outside caller that uses trigger roles to Low/High, so nothing can index nil.
- **[Fact]** The aliases `Pulse.Modes.TRIGGER_* = Pulse.Modes.<new>` (`Modes.lua:333-339`) are the same table objects. `/pulse test TRIGGER_CLICK` and stored per-cue mode overrides still resolve.
- **[Fact]** The v8 migration (`Database.lua:1441-1453`) is null-safe.
  - `DB` is assigned before `Migrate()` runs (`Database.lua:1251`, `1310`).
  - `Get("defaultHapticSchema")` falls back to `"standard"` for any unknown schema (`Database.lua:2100-2106`), and `Engine:_ActiveSchema()` falls back again.
  - Reproduced a v7→v8 upgrade: `version=8 schemaStored=standard schemaGet=standard`.

### 2.2 Findings

**M5 — v8 migration orphans legacy mode tuning, and mode overrides split across two tuning keys** [Fact]
- Upgrade reproduction output:
  ```
  modeTuning.TRIGGER_CLICK kept=true  SNAP tuning=nil  channelTuning.LTrigger kept=true
  autoShotFired __mode after upgrade=TRIGGER_RECOIL resolves=true
  ```
- `PlayMode` reads tuning by the literal mode ID it is handed (`Engine.lua:385-388`). A cue with a stored override of `"TRIGGER_RECOIL"` therefore reads `DB.modeTuning.TRIGGER_RECOIL`, while the Modes page tunes `RECOIL`.
- The user's old per-mode tuning can no longer be reached from the UI, and new tuning doesn't reach cues that still carry a legacy override.
- The mode dropdown shows **"Custom"** for a legacy value (`Rows.lua:501-516`, the fallback in `labelFor`).
- `triggerMult` values are now meaningless (no mode uses trigger roles), but `PlayMode` still reads them (`Engine.lua:387`).
- **[Rec]** Add a v9 step:
  - Rename `DB.modeTuning[TRIGGER_*]` to the new IDs, folding `triggerMult` into `highMult`/`lowMult` or dropping it.
  - Rewrite any per-cue mode override `TRIGGER_*` to the new ID.
  - Clear `DB.channelTuning.LTrigger/RTrigger`.

**L5 — Feel drift on the Low-motor-only schema** [Fact]
- The old Low-only schema mapped `rtrigger` → Low @ 1.0 and `ltrigger` → Low @ 0.6. The new modes use `high` (→ Low @ 0.6) and `low` (→ Low @ 1.0).
- So on Low-only, SNAP, MICRO_TAP, STACCATO, RECOIL's first step, DRAW's last step and SHUTTLE's second step are **40% quieter**. TENSION, DRAW's build and SHUTTLE's first step are **67% louder**.
- Standard, Inverted and High-only produce identical output (checked schema by schema).
- **[Inference]** The "dual-motor coordination" claim in the commit message is overstated.
  - Only DRAW, RECOIL and SHUTTLE use both motors.
  - SNAP, MICRO_TAP and STACCATO are High-only; TENSION is Low-only.
  - On Standard the change is a role rename with the same output as before.

**L6 — Leftover trigger-era code, harmless but dead** [Fact]
- The engine role list still includes `ltrigger`/`rtrigger` (`Engine.lua:60`).
- The trigger-role branches in `PlayMode` (`Engine.lua:421-444`) and the `triggerMult` read (`:387`).
- Debug views: `Engine.lua:1000-1001`, the `PulseDebug/UI.lua:216-217` and `PulseDebug/Debug.lua:166-167` columns, and `Init.lua:170`.
- `triggers = false` on every device preset.
- The `TRIGGER_*` keys in the Spec.lua mode-category table (`Spec.lua:158-165`).
- A dead colour branch for the old "Triggers & Textures" category (`Rows.lua:508`); that category was renamed, so those modes now get the default colour.
- A `rumbleAndTriggers` stub in the locomotion test.
- No nil indexing, no hardware calls, and extra allocation only in debug paths.

---

## 3. Shaped Engine & Locomotion Cadence Audit

### 3.1 Shaped envelope math (checked by simulation through the real `Engine.lua`)

Simulated Low-motor output for a BOOT footfall with low 0.35 and high 0.21:

| Setup | Low motor output over time |
|---|---|
| Default preset, 60 fps | `0ms:0.560 33ms:0.264 50ms:0.174 67ms:0.115 83ms:0.076 100ms:0.000` |
| Default preset, 30 fps | `0ms:0.560 67ms:0.180 100ms:0.078 133ms:0.000` |
| Default preset, 144 fps | kick held to ~28 ms, then a smooth decay, `97ms:0.000` |
| Xbox (ERM) preset, 60 fps | `0ms:0.613 … 83ms:0.186 100ms:0.000` (hard cut from above the floor, as designed) |
| Continuous 0.30 + footfall | continuous level `before=0.300 peak=0.692 0.5s after=0.300` |

- **[Fact]** The math is stable.
  - `exp` of a non-positive argument is bounded, and output is clamped after the mix.
  - The kick uses `value * kickGain` up to `kickTime`, then `value * exp(-(age-kickTime)/tau)`. The layer is deleted once every role falls below `cut` (`Engine.lua:626-659`).
- **[Fact]** Footfalls are isolated from continuous textures. The shaped output is blended on top of the continuous level (`Engine.lua:513-526`) and never written into the channel's smoothing state. The continuous level returns to exactly 0.300.
- **[Fact] Zero-GC in the engine tick:** the shaped branch uses only `pairs`, arithmetic and scratch tables that are wiped and reused. The shape tables (`SHAPES`/`MERGED`, `Locomotion.lua:448-468`) are built once at load.

**L1 — Kick length depends on frame rate** [Fact]
- `if kickTime < dt * 1.2 then kickTime = dt * 1.2` (`Engine.lua:631`) stretches the kick to 2 frames at 30 fps: **67 ms vs 33 ms at 60 fps**, so roughly twice the kick energy.
- The code comment says the goal is that the kick is never skipped, but stamping the start time on first evaluation (`:627`) already guarantees `age = 0 < kickTime`.
- **[Rec]** Drop the clamp.

**L2 — Two table allocations per footfall** [Fact]
- A shaped layer deletes itself at its cut (`Engine.lua:658`). The next footfall calls `SetRoles`, which allocates `{ roles = {} }` again (`:249`).
- This happens once per footfall, not once per frame: 2 small tables × 2-6 steps/s, from the locomotion frame's OnUpdate.
- **[Rec]** For strict Rule 4 compliance, keep the dead shaped layer and mark it inactive instead of setting it to nil.

**L3 — Cut threshold creates an intensity cliff** [Fact / Inference]
- `cut` is compared against the raw role value after the per-cue intensity is applied (`Engine.lua:648`).
- A footfall below `cut/kickGain` (0.0375 for BOOT) produces **no output at all**. Between 0.0375 and 0.06 it becomes a kick-only blip.
- Example with mountedOnly off: Night Elf, cloth boots, walking, cue intensity 0.5 → 0.053, a single 22-33 ms kick. At 0.35 → nothing.
- **[Rec]** Make the cut relative to the layer's peak value, or document the floor.

**L4 — The shape table isn't validated** [Fact]
- A shape table without `kickTime` makes `kickTime < dt*1.2` compare nil with a number (`Engine.lua:631`).
- The OnUpdate `pcall` catches it and calls `StopAll`, killing every haptic for that frame.
- All callers inside the addon pass `kickTime`.
- Separately, a caller that re-arms a shaped layer every tick resets its start time each time, which makes a permanent kick. That's an undocumented API contract.

### 3.2 ENG-DEADBAND (0.025 shutoff snap)

- **[Fact]** The snap applies only when `wanted == 0` (`Engine.lua:506-508`), and only to the channel's smoothing state.
  - Any positive target bypasses it. With a floor it maps to at least the floor; without one it follows the attack curve.
  - So there's no feedback loop and no hysteresis needed. Lua is single-threaded, so there are no race conditions.
- **[Inference]** A waveform texture that dips to 0 at its troughs will snap to 0 at each trough only if it was already below 0.025, which is below the breakaway threshold. Safe.
- **[Inference]** On ERM pads the motor already stalls below its calibrated floor (0.10-0.12). The fixed 0.025 only trims the 0.025→0.004 tail, while the 0.12→0.025 crawl remains.
- **[Rec]** Consider `max(SHUTOFF_DEADBAND, floor * k)` per channel.

### 3.3 Locomotion cadence & gallop merge

**H1 — Gait goes permanently silent after an unmerged→merged gallop change** [Fact, reproduced]
- The locomotion `tick()` function:
  - `Locomotion.lua:583`: the merge flag is recomputed every frame from the cadence.
  - `:602`: the trail hoof fires only when **not merged** and `nextStep == 2`.
  - `:607`: the wrap only fires when `nextStep == 1`.
- If a re-resolve pushes the cadence above **2.387 steps/s** (`0.6/(0.08π)`) while `nextStep == 2`, none of the three branches ever fires again. `nextStep` stays 2 and the phase grows without bound.
- Reproduction A, mounted walk→run with default settings:
  ```
  walk: mode=GALLOP cadence=1.980 merged=false
  after lead hoof: footfalls=1 nextStep=2 runPhase=0.104
  after re-resolve: cadence=4.032 merged=true nextStep=2
  10s later: footfalls=0 nextStep=2 runPhase=126.8 rad
  ```
- Reproduction B, running on foot then shifting to Cat Form with mountedOnly off: FOOTSTEP 2.800 → GALLOP 3.640 merged, `10s later: footfalls=0`.
- **[Inference] Exposure:**
  - About 9.5% of mounted walk→run changes (the pending-trail window is 0.6 rad of each 2π stride).
  - 50% of on-foot → Cat/Travel/Ghost Wolf shifts while moving, when mountedOnly is off.
  - Recovery comes only from a PLAYER_STOPPED_MOVING event, or from the cadence dropping back below the threshold.
  - Locomotion is on in Immersion ×3 and Questing.
- **[Rec]** Before the wrap check: `if isGallopMerged and nextStep == 2 then nextStep = 1 end`. Add both reproductions as regression tests.
- **[Fact]** Bipedal gaits never merge (merging requires GALLOP mode), so raptors and hawkstriders keep a clean alternation. Merged gallop strikes once per stride, at cadence/2 per second, as the test asserts.

**M1 — splitFeet is no longer guarded by schema or hardware** [Fact]
- `shouldSplitFeet()` is now just `setting("splitFeet", 1) == 1` (`Locomotion.lua:368-370`).
- `8a67a43` removed the device-preset and schema veto (CR-030), whose own comment warned about exactly this limp. splitFeet defaults to **on**.
- When both roles collapse onto one motor, the channel takes the max of the two roles. Resulting per-step values (before calibration mapping):

| Schema | Timbre | Step 1 | Step 2 | Asymmetry |
|---|---|---|---|---|
| Low-only | any | 1.00·I | 0.80·I | −20% every second step |
| High-only | PAW / HEAVY | 0.60·I | 0.48·I | −20% |
| High-only | HOOF | 0.60·I | 0.88·I | +47% |
| High-only | CLAW / METAL | 0.63-0.70·I | 0.99-1.10·I | +57% |

- **[Rec]** Split only when the low and high roles resolve to different channels. Fix `CURSEFORGE.md:46` and `README.md:51` ("on dual-motor gamepads"), since the code does no such check.

**L10 — Frame-hitch double fire** [Inference]
- Locomotion `tick()` uses the raw frame time with no cap, while the engine caps at 0.25 s.
- After a hitch longer than half a stride, step 2 and step 1 fire in the same frame on one layer name, so step 2 is overwritten.
- Rare; mostly after loading screens.

**L9** [Fact] `resolveGait` falls back to `gaitIntensity` 0.35 (`Locomotion.lua:299`), while the Registry default and `PreviewLocomotion` use 0.28. This only matters when the setting is unset.

---

## 4. Default Profiles & Sweep Architecture Audit

### 4.1 Data integrity: good

- **[Fact]** All 12 curated override tables were parsed and checked against the Registry.
  - `Pulse.Triggers` count: **190**.
  - **0 unknown trigger IDs** in any profile.
  - Enabled cues per profile: 36 (PvP) to 115 (Immersion Melee/Caster).
- **[Fact]** The Yes-lists in the 12 review reports match the Database tables exactly, with one exception.
  - `Immersion: Ranged` enables `bankOpened`, but its report lists it in neither Yes nor No.
  - That report's header says `112 Yes · 77 No · 0 not reviewed` = 189, not 190.
- **[Fact]** `SetAllCues` (`Database.lua:2182-2205`):
  - It writes only boolean values into `prof.triggers`, iterates `Pulse.Triggers` with `ipairs`, and returns 0 for an unknown profile.
  - It notifies listeners only when the target is the active profile.
  - The writes land in `PulseDB` (SavedVariables), so they persist.
  - It also flips the category masters (`ccMaster`, `controllerUIMaster`) and dev/experimental cues. That's likely intended for debugging, but the tooltip should say so.

### 4.2 Findings

**H2 — All four settings-window sweep buttons throw a Lua error** [Fact, reproduced]
- `Panel.Refresh` is never defined anywhere in the repo. A grep over all Lua files finds only call sites.
- The four buttons call it without a guard (`Spec.lua:737`, `:748`, `:1059`, `:1071`), and the button OnClick handler calls the row's handler directly with no `pcall` (`Rows.lua:644-646`).
- Harness reproduction:
  ```
  [cueIndex] Enable all cues             ok=false PulseHaptics/UI/Panel/Spec.lua:737: attempt to call field 'Refresh' (a nil value)
  [cueIndex] Disable all cues            ok=false PulseHaptics/UI/Panel/Spec.lua:748: attempt to call field 'Refresh' (a nil value)
  [profiles] Enable all cues in profile  ok=false PulseHaptics/UI/Panel/Spec.lua:1059: attempt to call field 'Refresh' (a nil value)
  [profiles] Disable all cues in profile ok=false PulseHaptics/UI/Panel/Spec.lua:1071: attempt to call field 'Refresh' (a nil value)
  ```
- **[Inference] Impact:** the database write and the chat message finish before the error, and the panel still refreshes through its database subscriptions. The user sees a script error on every click. This is not taint.
- The slash commands (`Panel.lua:552-574`) check `if Panel.Refresh` first, so they work, but their refresh line is dead code.
- luacheck can't catch this, because field access on a module table isn't checked.
- The harness clicks only `kind == "index"` rows (`harness.lua:801-812`), never `button` rows.
- **[Rec]** Replace the calls with `Panel.MarkDirty()`. Add a harness pass that clicks every `button` row, at least the sweep rows.

**M3 — The sweep skips the combat deferral** [Fact / Inference]
- Profile switches are deliberately deferred during combat, with the rationale "tearing that down and rebuilding it mid-pull is the kind of thing that goes wrong once and never reproduces" (`Database.lua:1769-1783`).
- `SetAllCues` on the active profile notifies every cue listener immediately (`Database.lua:2201-2203`). That re-runs every module's re-sync (`Init.lua:376-382`; 22 module files call it), unregistering and re-registering events for ~190 cues mid-pull.
- **[Fact]** Taint: a grep of Core/ and Modules/ for protected APIs (`SetOverrideBinding`, `RegisterStateDriver`, `SetAttribute`, secure handlers, `FrameShown`) found nothing. The UI uses Pulse's own popups, not StaticPopup (toc comment). The sweep is **taint-safe** but breaks the codebase's own "no rebuild mid-pull" rule.
- Note: a single-cue toggle (`SetCue`) also notifies immediately. That's pre-existing behaviour; the sweep just does it 190 times at once.
- **[Unverified]** In-game behaviour of a mass re-sync during combat.
- **[Rec]** In combat, either refuse the sweep with a chat message, or route it through the same pending-notify flag the profile switch uses.

**M2 — The curated profiles never reach existing installs** [Fact] — *needs a product decision*
- Seeding fills only nil entries (`Database.lua:1376`), and v8 has no curation step (`Database.lua:1421-1445`).
- Computed: what an upgrading user's built-in profile keeps, compared with the new curated table (Registry unchanged since `04b6638^`, checked with `git log`):

| Profile | Upgraded (old seed) cues on | Curated cues on | Cues that differ |
|---|---|---|---|
| Default | 53 | 53 | 0 |
| Dungeon: Tank / Healer / Melee / Caster / Hunter | 38-43 | 51-63 | 18-26 |
| Immersion: Melee / Caster / Ranged | 77-83 | 113-115 | 72-74 |
| Questing | 85 | 101 | 68 |
| Raiding | 68 | 42 | 40 |
| PvP | 23 | 36 | 13 |

- Only "Reset this profile" applies the curation. The README ("curated default profiles vetted across all 190 cues", `README.md:34`) is true only for fresh installs.
- **[Fact]** Policy change: all 12 built-ins are now `__exclusive` (6 before `04b6638`), and `Default` is now a key in the curated table (`Database.lua:1012`).
  - Consequence [Inference]: the Registry's `default` field no longer affects any built-in profile. Any cue added later ships **off** in all 12 unless the curated tables are edited.
  - The comments at `Database.lua:1473-1477` and `2013-2015` still say Default isn't in the table and are now false.
- **[Rec]** Pick a rollout. Option (c) is recommended:
  - (a) Leave as is and document "Reset to get the curated set".
  - (b) Force the curated sets in a v9 migration. This overwrites user choices, the same thing the v2→3 migration did.
  - (c) Apply the curation only to built-ins whose cue state still equals the old seed, i.e. never touched by the user.

**L7 — Docs and tool claims don't match the code** [Fact]
- `CURSEFORGE.md:19` lists the 6 timbres as "Walk, Run, Sprint, Mount Gallop, Swimming, Glide". The code has BOOT/HOOF/PAW/HEAVY/CLAW/METAL, and swimming and gliding produce **no** footfalls (`hasGroundContact`).
- `PulseProfileReview/Review.lua:2` ("It only writes PulseProfileReviewDB") and the toc Notes ("without changing Pulse settings") contradict `Review.lua:381-384` and `411-414`, which write `PulseDB` through `SetAllCues`.

**L8** [Fact]
- `PulseProfileReview/` is outside test.sh's luacheck scope (it lints only `PulseHaptics/ PulseDebug/ PulseChecklist/`). Run by hand: 0 warnings, 0 errors.
- It isn't packaged (`scripts/package.sh` stages only PulseHaptics), which matches the README distribution table.

### 4.3 ORG-DOCS & packaging

- **[Fact]** `194b9fe` moved the 12 reports with pure renames (history kept).
- **[Fact]** The new `.gitignore` lines `docs/Fix Locomotion Proposed/` and `docs/Ongoing Bugs/` mean those notes aren't under version control. They weren't tracked before either, so nothing was lost, but they have no backup.
- **[Fact]** `scripts/package.sh`: version `0.2.0-beta` matches the toc; only `dist/` is removed; macOS metadata is excluded. Clean.

---

## 5. Edge Case Analysis & Residual Risks

### 5.1 Test run

- **[Fact]** `./scripts/test.sh`: luacheck `0 warnings / 0 errors in 51 files`. All 7 suites **PASS** (harness, locomotion-test, crafting-test, engine-test, cue-audit, pulsedebug-test, checklist-test).

### 5.2 How strong the tests actually are

| New behaviour | Test present | Actually checks the behaviour? |
|---|---|---|
| Deadband snap | `engine-test.lua:572-594` | **No.** The mutation run passes on the code from before the deadband (`46e9d9e^`): `shutoff_test snapped cleanly to zero 0 ok`. The old silence gate reaches 0 inside the 400 ms window anyway. |
| Shaped envelope | `engine-test.lua:242-262` | **No.** Asserts only a debug flag and that `StopAll` clears it. No output values, decay, cut, blend or yield checks. |
| Trigger aliases / role info | engine-test | Yes, for SNAP and RECOIL only; 5 of 7 aliases untested. |
| Gallop merge | locomotion-test Part 5 | Only the steady state. Doesn't test the transition, so **H1** slipped through. |
| splitFeet | locomotion-test Part 3 | Standard schema only. Single-motor schemas untested (**M1**). |
| Sweep | `harness.lua:1675-1681` | Database level only. Button click paths untested, so **H2** slipped through. |
| v8 migration | none | No test. |
| Combat deferral of the sweep | none | No test. |
| PulseProfileReview | none | Not linted by test.sh and not tested. |

### 5.3 Residual risks

**[Unverified]**
- Real-hardware feel of the kick/decay timbres.
- Whether the 0.025 snap is audible on voice-coil pads (DualSense floor 0.030).
- In-combat behaviour of a mass module re-sync.
- Which OnUpdate runs first within a frame, the locomotion frame's or the engine frame's (up to one frame of added latency).

**[Inference]** Footfalls stay on the frame-based smoothing path, so SetVibration traffic per footfall scales with frame rate: about 6 sends per channel at 60 fps, about 14 at 144 fps. Acceptable, but it runs against the goal stated in ENG-DEADBAND's commit message of cutting watchdog/telemetry traffic.

---

## 6. Final Verdict & Next Steps for the Pair-Programming Agent

**Verdict: NOT release-ready as tagged `0.2.0-beta`.** Two reproduced functional bugs (H1, H2) should be fixed first. Both are small, local fixes. The engine layer (shaped lanes, deadband, trigger removal) is sound and can stay as is.

### Fix order

1. **H1** `Locomotion.lua:583-611`: clear the pending trail when merged. Add reproductions A and B as tests.
2. **H2** `Spec.lua:737/748/1059/1071`: change `Panel.Refresh()` to `Panel.MarkDirty()`. Add a harness pass that clicks button rows.
3. **M3** Add a combat gate to `SetAllCues` (refuse, or defer the notify).
4. **M1** Put back a schema guard on `shouldSplitFeet` (split only when low and high resolve to different channels). Fix the README/CURSEFORGE claims.
5. **M5** v9 migration: rename the `DB.modeTuning` entries and per-cue mode overrides from `TRIGGER_*`, and clear the `LTrigger`/`RTrigger` channel tuning.
6. **M4** Make the tests actually check the behaviour:
   - Deadband: assert the snap frame with the ERM `releaseTau` 0.060, where the pre-deadband code would still be above the silence gate.
   - Shaped output: kick level, monotonic decay, cut to 0, continuous level unchanged, and the yield factor.
   - Migration: v7→v8 upgrade.
   - splitFeet on Low-only and High-only.
7. **L-items:**
   - Drop the `dt*1.2` kick clamp.
   - Validate `shape.kickTime`.
   - Consider a relative cut.
   - Keep dead shaped layers instead of reallocating them.
   - Clean up the leftover trigger code.
   - Fix `CURSEFORGE.md:19`, the Review.lua header and the Immersion-Ranged report (190th cue).
   - Update the stale comments at `Database.lua:1473-1477` and `2013-2015`.
   - Add `PulseProfileReview/` to luacheck.

### Decision needed from the project owner

- **M2 rollout:** existing users currently keep their pre-curation cue states. Choose (a) document "Reset to get curated", (b) force the curated sets, or (c) apply them only to profiles the user never touched (recommended).

### Coverage ledger

**Read in full:**
- `Engine.lua` 1-800 and the debug section
- `Locomotion.lua` (788/788)
- `Panel.lua`, `Content.lua`
- `locomotion-test.lua`
- `scripts/test.sh`, `scripts/package.sh`

**Read in part:**
- `Spec.lua`: 1-260 and 560-1100 of 1903
- `Database.lua`: 160-250, 1195-1500, 1766-1810, 2008-2042, 2090-2240 and 2415-2446 of 2449. The curated tables were checked by parsing, not by eye.
- `Rows.lua`: 498-520 and 625-720
- `Init.lua`: 92-132 and 376-413
- `Modes.lua`: 380-420 plus the diff
- `Review.lua`: 1-40, 370-430 and 484-537
- `engine-test.lua`: stubs plus the diffs
- `harness.lua`: 695-830 and the tail

**Not audited:**
- The 15 CR-fix commits except where they overlap these features
- Modules other than Locomotion
- The rest of the Spec.lua calibration page
- `Guide.lua` beyond the diff
- The PulseDebug/PulseChecklist changes
- `generate_profile_reviews.py` logic
- The content of `docs/` beyond checking claims
