# PulseHaptics — Code Review, 2026-09-30

**Scope:** the `PulseHaptics/` addon (Core, Modules, UI). The companion addons (PulseDebug, PulseChecklist, PulseProfileReview) were only reviewed where they touch the PulseHaptics API.
**Baseline:** `ad0ef89` (2026-09-30 01:52). Commit `1ca6a24` (02:14:50) landed while this review was running. It adds the oscilloscope and changes two PulseHaptics files, `Core/Engine.lua` (new lines 1106–1149) and `UI/Panel/Panel.lua` (new `/pulse scope` command, +11 lines from line 555). Both changes are reviewed here. **All line numbers refer to `1ca6a24`.** Every other PulseHaptics file is byte-identical between the two commits (checked with `diff -rq`).
**Mode:** read-only. No source file was changed. This report is the only file written to the repository.
**Author:** Claude (Opus 5.5), at the user's request.

**Labels used on every claim**
- **[Fact]**: read in the code, or reproduced by running the real addon files offline (probes described in §9).
- **[Inference]**: reasoned from code, not executed.
- **[Rec]**: recommendation.
- **[Unverified]**: needs the live client or real hardware.

---

## 1. Summary

**Verdict:** the engine core is in better shape than at the last audit. The earlier ducking and coast-trim problems are gone, and all seven test suites plus luacheck pass. But `ad0ef89` introduced two regressions, and a third defect makes its headline migration a no-op for existing users. The offline tests catch none of the three.

| # | Severity | Finding | Status |
|---|---|---|---|
| F-01 | **P1** | The new soft breakaway floor puts four default continuous textures below the motor floor on every ERM preset, fishing's fallback signal included. The calibration advice ("raise the floor") now makes this worse. | New (regression from `ad0ef89`) |
| F-02 | **P1** | With **Crafting texture off** and **Casting texture on**, fishing, gathering and recipe crafts are completely silent: Crafting still claims the craft and Combat suppresses the cast texture. This hits the curated *Dungeon: Healer* and *Dungeon: Caster* profiles. | New |
| F-03 | **P1** | The v8→v9 "Option B" curated-profile migration never applies to real pre-curation installs, for two independent reasons. Every built-in is still stamped `__curatedVersion = 1`, so the miss can't be detected later. | New (extends earlier audit item M2) |
| F-04 | P2 | The oscilloscope always reads 0: `Engine:GetChannelOutputs` looks up `low`/`high`, but the channel keys are `Low`/`High`. | New (`1ca6a24`) |
| F-05 | P2 | The Crafting texture ▶ preview never plays its two strikes (preview-token race and a shared layer name). | New (CR-004 fix incomplete) |
| F-06 | P2 | "Instant ability used" fires on every Auto Shot arrow, on channel ticks and on item uses. Three curated profiles enable it together with "Cast succeeded", against the cue's own caveat. | New |
| F-07 | P3 | The "Coast cutoff" calibration slider is a dead control. `floorKnee` is a hidden knob with no slider or default. | New |
| F-08 | P3 | The "Default profiles" page leaves out *Raiding* and *Questing*, which the README advertises. | New |
| F-09 | P3 | Overdrive is still implemented but switched off in every preset. The problems from the synthesis critique come back if a user raises its sliders. | Known, latent |
| F-10 | P3 | The v9→10 swim migration overwrites a deliberate user choice in every profile, custom profiles included. | New |
| F-11 | P3 | Three tunable defaults sit off their slider grid, so once a slider is moved the user can't get back to the default. | New |
| F-12 | P3 | The global `issecretvalue` shim can mislead other addons on the pre-12.0 clients the TOC lists. | New |
| F-13 | P3 | Ocean-zone detection uses English substring matching with false positives. | New |
| F-14 | P3 | The weather preview passes `elapsed` into `Sine`'s phase argument. | New |
| F-15 | P3 | A Pulse dialog opened during combat can swallow keyboard input. | New, [Unverified] |
| F-16 | P3 | The heartbeat previews write to the live cue layers instead of `preview`. | New |
| F-17 | P3 | Trigger-era leftovers and a dead colour branch are still present, and the new code adds more. | Extends L6 |
| F-18 | P3 | `DB.modeTuning` and `DB.channelTuning` are not type-checked at load (CR-022 residual). | New |
| F-19 | — | Items still open from earlier reviews (table in §5). | Carry-over |

**Counts:** P0 0 · P1 3 · P2 3 · P3 12, plus the carry-over table in §5.

**The three that matter most**
- **F-02** turns off the very feature (fishing and crafting feel) the user has been chasing since CR-001/CR-003.
- **F-01** makes the quiet immersion textures unfeelable on Xbox, DS4, 8BitDo and Elite pads at the default profile intensity.
- **F-03** means nobody who installed before `04b6638` ever gets the curated profiles.

---

## 2. Baseline results

- **[Fact]** `./scripts/test.sh` at `ad0ef89` and again at `1ca6a24`, run in scratchpad snapshots made with `git archive`:
  - luacheck: `0 warnings / 0 errors in 51 files` (52 at `1ca6a24`).
  - All 7 suites pass (harness, locomotion-test, crafting-test, engine-test, cue-audit, pulsedebug-test, checklist-test).
- **[Fact]** `luacheck PulseProfileReview/` run by hand: 0/0. It is still outside `scripts/test.sh:92` (earlier audit item L8).
- **[Fact]** Green does not mean covered. The tests pass while F-01 through F-05 reproduce with the same code (see §6).

---

## 3. Findings

### F-01 [P1] The soft breakaway floor silences default continuous textures on ERM controllers

**What changed.**
- **[Fact]** `ad0ef89` replaced the continuous-cue half of `mapValue` with a smoothstep "soft floor" (`PulseHaptics/Core/Engine.lua:529-537`):

  ```
  effFloor = floor * smoothstep(v / knee)        -- knee = floorKnee or 0.20
  v        = effFloor + (1 - floor) * v
  ```

  Transients keep the hard floor `floor + (1 - floor) * v` (`Engine.lua:526-527`).
- **[Fact]** The calibration page defines the floor as *"the smallest value that makes this motor actually spin. Anything above zero is remapped into the range above this floor, so a quiet cue still moves the mass instead of dying silently"* (`Core/Devices.lua:85-91`). For continuous cues that promise no longer holds.

**Measured with the real engine.**
- **[Fact]** Method: probe `softfloor.lua` loads the shipping `Core/*.lua` and applies each device preset with `Database:ApplyDevicePreset`. It then holds one role at the authored default level for 1.5 s at 60 fps and records the last value sent to `C_GamePad.SetVibration`.
- Profile master intensity is 0.70, which is the *Default* profile's value.
- `*` marks a value below that preset's own breakaway floor.
- The last column is the same cue through the pre-change engine (`db2ffa5`).

| Cue (role, authored level) | Generic (floor 0) | Xbox (0.125) | DS4 (0.115) | 8BitDo (0.145) | Elite (0.135) | DualSense (0.025) | `db2ffa5` Xbox |
|---|---|---|---|---|---|---|---|
| waterTexture baseline (low 0.04) | 0.028 | 0.052 * | 0.047 * | 0.054 * | 0.067 * | 0.033 | 0.145 |
| castPresence, fishing fallback (low 0.06) | 0.042 | 0.082 * | 0.074 * | 0.085 * | 0.104 * | 0.051 | 0.157 |
| stealthTexture baseline (low 0.06) | 0.042 | 0.082 * | 0.074 * | 0.085 * | 0.104 * | 0.051 | 0.157 |
| taxiRide mean, 0.1 × 0.75 (low 0.075) | 0.052 | 0.105 * | 0.095 * | 0.110 * | 0.133 * | 0.064 | 0.166 |
| swimTexture peak (low 0.10) | 0.070 | 0.143 | 0.131 | 0.151 | 0.179 | 0.087 | 0.182 |
| channelHum (high 0.12) | 0.084 | 0.159 | 0.148 | 0.169 | 0.187 | 0.096 | 0.176 |
| glideThrust presenceFloor (low 0.15) | 0.105 | 0.217 | 0.200 | 0.229 | 0.259 | 0.134 | 0.212 |

- **[Fact]** At master intensity 1.00 the water, castPresence and stealth rows are *still* below the floor on Xbox, DS4 and 8BitDo (for example water 0.078 against 0.125).
- **[Fact]** The regression comes from the soft-floor formula, not from the preset retune in the same commit. With HEAD's own Xbox values (floor 0.125, gamma 0.88), the old hard formula maps water to 0.163. This was worked by hand from `Engine.lua:510-527`.

**Why raising the floor does not help, and makes it worse.**
- **[Fact, algebra]** For a sub-knee continuous value `v`, output divided by floor is `smoothstep(v/k) + (1 − f)·v/f`. At fixed `v` this *falls* as the floor `f` rises.
- So the advice in the Ramp tooltip (*"Type it into the slider below and quiet cues stop disappearing"*, `UI/Panel/Spec.lua:1700-1703`) and in the Guide (`Core/Guide.lua:49-52`, `:171-173`) now does the opposite of what it says for every continuous texture whose value sits below the knee. Above the knee, raising the floor still raises the output.
- **[Inference, computed]** On the Xbox Low preset (floor 0.125, knee 0.20, gamma 0.88), any continuous role value below about 0.088 at master 0.70 (about 0.062 at master 1.00) lands under the floor.
- Most of the "edge of perception" defaults are in that range. The commit message's own target range, "low slider settings (0.01-0.10)", covers the *authored defaults*, not only user-lowered sliders.

**Impact.**
- **[Inference]** Below its breakaway value an ERM motor does not turn, by the preset's own definition. So in practice these textures are off on Xbox, DS4, 8BitDo and Elite pads.
- **[Unverified]** Real felt behaviour on hardware.
- On the Generic preset (floor 0) the output is unchanged. On the LRA presets every row stays above the preset floor.
- **[Fact]** The preset floors are themselves "STARTING POINTS … not measurements" (`Devices.lua:180-196`). "Below the floor" here means below the preset's number. A real motor whose breakaway point is lower than its preset says could still turn. So the P1 severity rests on the preset numbers being roughly right, and that needs the hardware check in §7.1.
- Related: the fishing path through `castTexture` (`Modules/Combat.lua:520-521`) is exactly the `castPresence` row. See F-02 for when that path is even reached.

**Also.**
- **[Fact]** While any transient is live on a channel, that whole channel uses the hard floor (`Engine.lua:799-801`, `:577`).
- **[Inference]** So a silent texture becomes briefly felt under every transient on the same motor, then drops back to silence. It will read as "the texture only exists when something else happens".

**[Rec]** Pick one of these, and put the decision in the calibration docs:
- (a) Keep the hard floor for any continuous value at or above a small ε (for example 0.01), and fade only below ε, so that "slider at 0 = off" (the CR-008b goal) still holds.
- (b) Scale the knee with the floor (for example `knee = 0.25 * floor`), so authored defaults stay above breakaway.
- (c) Revert to the hard floor for continuous cues and solve CR-008b at the per-cue slider (0 → no hold at all).

Whichever you pick, rewrite `Devices.lua:90`, `Spec.lua:1700-1703` and `Guide.lua:49-52, 171-173` to match. Add an engine test that asserts `mapValue(authored default, preset) ≥ floor` for every continuous default on every ERM preset.

---

### F-02 [P1] Crafting texture OFF + Casting texture ON → fishing, gathering and crafts are silent

**Mechanism.**
- **[Fact]** `Modules/Crafting.lua` subscribes to CastActivity unconditionally (`:584-587`).
  - On `CHANNEL_START` for fishing, on `CAST_START` for Mining/Herbalism/Skinning (`:490-507`), and on `CRAFT_START` (`:486-489`), it calls `beginCraft`.
  - `beginCraft` sets `active = true` whether or not the `craftTexture` cue is on (`:380`). Only the bed's OnUpdate is gated on the cue (`:383-385`).
- **[Fact]** `Modules/Combat.lua:446-448` then drops every castTexture tick while `Pulse.IsCrafting()` is true. `IsCrafting()` stays true for as long as a cast or channel exists (`Crafting.lua:310-336`).
- **[Fact]** CastActivity events flow whenever castTexture is on, because Combat registers the `"combat"` consumer (`Combat.lua:558-560`). So this combination always reaches `beginCraft`.

**Reproduced.**
- **[Fact]** Probe `craft.lua` loads the real Core, Combat, Crafting and Casting and turns castTexture on and craftTexture off. It then drives CastActivity with a 20-second channel:

  ```
  (a) channel: Fishing (7620)         castTexture holds over 30 frames = 0   IsCrafting=true
  (a) channel: Mind Flay-like (15407) castTexture holds over 30 frames = 30  IsCrafting=false
  ```

- **[Inference]** Gathering casts and recipe crafts go through the same `beginCraft` line, so they are silenced the same way. Only the fishing channel was run.

**Exposure.**
- **[Fact]** The curated *Dungeon: Healer* (`Core/Database.lua:242`) and *Dungeon: Caster* (`:363`) profiles enable castTexture without craftTexture. Any custom profile with that combination is affected too.
- **[Fact]** The file header promises the opposite: *"If a gathering profession is disabled on the Crafting page, castTexture … takes over as fallback"* (`Crafting.lua:25-26`). That promise is only true when craftTexture is on and the per-profession toggle is off, and in that case the fallback is F-01's sub-floor `castPresence`.

**Combined fishing matrix (Xbox preset, master 0.70).** [Inference from the code paths, plus the F-01 numbers]

| craftTexture | Fishing toggle | castTexture | What you feel |
|---|---|---|---|
| off | — | on | **nothing** (F-02) |
| on | on | any | craft bed 0.12 on Low → ≈0.17 at the motor, just above the 0.125 floor |
| on | off | on | castPresence 0.06 → 0.082, **below the floor** (F-01) |

**[Rec]**
- Return early from `beginCraft` when `craftTexture` is not enabled, or have `M:IsCrafting()` return false unless the cue is on.
- Add a crafting-test case: castTexture on, craftTexture off, fishing channel → castTexture holds > 0.

---

### F-03 [P1] Option B (curated profiles for untouched built-ins) never fires for real upgrades

**Design.**
- **[Fact]** `Database:_MigrateCuratedProfilesOptionB` (`Core/Database.lua:1912-2060`) runs in the `DB.version < 9` block (`:1444-1447`).
- It is meant to replace the cue set of every built-in profile the user never touched.
- Before anything else, "untouched" requires **every stored tunable value to equal the current Registry default** (`:1937-1950`).

**Cause 1: tunable defaults changed in the same release.**
- **[Fact]** DB_VERSION went from 8 straight to 10 in `ad0ef89` (no commit ever had `DB_VERSION = 9`, checked with `git log -S`). So every real upgrade runs v9 and v10 in one pass, v9 first.
- **[Fact]** `ad0ef89` also changed the Registry defaults for:
  - `swimTexture.separateMotors` (true → false)
  - `swimTexture.strokeDepth` (0.55 → 0.85)
  - `castTexture.castPresence` (0.10 → 0.06)
  - `castTexture.castSwellPeak` (0.70 → 0.40)
  - `castTexture.channelHum` (0.20 → 0.12)

  (`git show ad0ef89 -- PulseHaptics/Core/Registry.lua`)
- **[Fact]** Every profile on a real v8 install carries the *old* seeded values, because `_SeedProfileTriggerDefaults` seeds every trigger's tunables into every profile (`:1397-1417`). So check 1 fails and every built-in is judged "touched".

**Cause 2: the Questing snapshot is wrong.**
- **[Fact]** `LEGACY_V8_OVERRIDES.Questing` (`:1514-1549`) lists `swimTexture = true` but not `waterTexture`.
- **[Fact]** On every such install, the v3→v4 swim split turned `waterTexture` on (`:2202-2204`). So the "matches legacy v8" check can never pass for Questing.

**Reproduced.**
- **[Fact]** Probe `migrate.lua`:
  - Creates a fresh install with the real code of `dace2ab` (v8, the last commit before curation).
  - Serialises its `PulseDB`.
  - Loads it into HEAD's code.
  - Compares each profile against a fresh HEAD install.

| Profile | Cues on (v8) | After upgrade | Curated | Cues that differ |
|---|---|---|---|---|
| Default | 53 | 53 | 53 | 0 |
| Dungeon: Tank / Healer / Melee / Caster / Hunter | 43 / 41 / 38 / 37 / 38 | unchanged | 58 / 63 / 52 / 57 / 51 | 19 / 26 / 18 / 24 / 21 |
| Immersion: Melee / Caster / Ranged | 83 / 77 / 79 | unchanged | 115 / 115 / 113 | 72 / 74 / 74 |
| PvP | 23 | 23 | 36 | 13 |
| Raiding | 68 | 68 | 42 | 40 |
| Questing | 86 | 86 | 101 | 69 |

- **[Fact]** A/B check (`migrate_ab.lua`): with the five old tunable defaults put back in memory before `Database:Init`, the same upgrade gives 0 differing cues for Tank, Immersion: Melee, PvP and Raiding. Questing still differs by 69 (cause 2, traced by `questing.lua`: its only mismatch against the legacy table is `waterTexture(on)`).
- **[Fact]** For comparison, an install created at `db2ffa5` (curation already present) upgrades with 0 differences. Only installs created before `04b6638` are affected, which [Inference] includes the live install described in earlier sessions.

**Why it stays broken.**
- **[Fact]** `profile.__curatedVersion = 1` is written for every built-in whether or not curation was applied (`:2057`, outside the `if`), and nothing reads it.
- **[Fact]** `DB.version` is now 10.
- **[Inference]** A later fix can't use either marker to find the profiles that missed curation. It needs its own detection.

**Why the test passed.**
- **[Fact]** `PulseChecklist/tests/harness.lua:1767-1835` builds its v8 profiles with `triggerSettings = {}`, which never happens on a real install, so check 1 is skipped. The test asserts the swim migration on a custom profile, but never on a seeded built-in.

**[Rec]**
- Add a v11 step that decides "untouched" on the cue on/off set alone, or compares tunables against the defaults that were current at v8 (a frozen snapshot).
- Add `waterTexture` to the legacy Questing snapshot.
- Stamp `__curatedVersion` only when curation was actually applied.
- Build the regression test from a DB generated by the real pre-curation code, not a hand-written mock.

---

### F-04 [P2] Oscilloscope telemetry is always zero (`1ca6a24`)

- **[Fact]** `Engine:GetChannelOutputs` reads `lastSetByChannel.low`, `.high`, `.ltrigger`, `.rtrigger` and `smoothedByChannel.low`/`.high` (`Core/Engine.lua:1120-1127`).
- **[Fact]** The engine keys both tables by channel name, `"Low"`/`"High"` (`Core/Devices.lua:27`; `Engine.lua:590`, `:626`).
- **[Fact]** The oscilloscope's fallback path has the same casing bug: `channels.low` and `channels.high` (`PulseDebug/Oscilloscope.lua:728-729`).
- **[Fact]** Probe `scope.lua`, real engine at `1ca6a24`, after holding low 0.5 / high 0.3:

  ```
  SetVibration sent: Low=0.349 High=0.209
  GetChannelOutputs: low=0.000 high=0.000 anyActive=false
  _DebugChannels keys: High,Low  (Oscilloscope fallback reads .low/.high: nil,nil)
  ```

- **[Fact]** `pulsedebug-test.lua:395` replaces `GetChannelOutputs` with a mock, so the suite can't see this.
- **[Rec]** Read `lastSetByChannel.Low` and `.High` (and drop the trigger fields). Test against the real engine rather than a mock.

---

### F-05 [P2] The Crafting texture ▶ preview never plays its strikes

- **[Fact]** `M:PreviewCraft` captures `Pulse:GetPreviewToken()` (`Modules/Crafting.lua:594`) and *then* calls `Pulse:StartContinuousPreview` (`:595`). That call starts with `CancelContinuousPreview`, which increments the token (`Core/Init.lua:293`, `:284`). The two strike timers (`Crafting.lua:600-609`) compare against the stale token, so they never fire.
- **[Fact]** Even with the token fixed, the strikes `PlayMode("preview", …)` into the same `preview` layer that the bed's per-frame `SetRoles("preview", …)` rewrites on the next frame (`:596-597`). The strike would last at most one frame.
- **[Fact]** Probe `craft.lua` (b): `TestCue(craftTexture)` → `THUD strikes played during 3.2 s craft preview = 0 (code schedules 2)`.
- **[Rec]** Capture the token after `StartContinuousPreview`. Play the strikes on their own layer (for example `previewStrike`) and cancel that layer in `CancelContinuousPreview`.

---

### F-06 [P2] "Instant ability used" is broader than its label, and three curated profiles double it

- **[Fact]** CastActivity emits `INSTANT` for *any* player `UNIT_SPELLCAST_SUCCEEDED` that has no pending START and doesn't match the active channel (`Core/CastActivity.lua:192-194`). Casting maps that to `selfCastInstant` (`Modules/Casting.lua:29-34`).
- **[Inference]** The same condition matches Auto Shot, which fires SUCCEEDED spell 75 once per arrow (`Core/Registry.lua:686-693`, `Modules/Combat.lua:669-689`). It also matches wand shots, channel "tick" spells that carry a different spellID, and item or trinket uses.
- **[Unverified]** Whether Auto Shot and wands really arrive without a START event on this client.
- **[Fact]** The cue's own caveat says *"Leave 'Cast succeeded' off if you want only one of the two"* (`Registry.lua:2589`). Yet three curated profiles enable both `selfCastInstant` and `selfCastSucceeded`:
  - *Dungeon: Healer* (`Database.lua:288`, `:290`)
  - *Dungeon: Caster* (`:402`, `:404`)
  - *Immersion: Caster* (`:673`, `:675`)
- **[Fact, from the code]** Every instant cast fires two cues in those profiles:
  - `selfCastSucceeded` is a generic watcher on every player `UNIT_SPELLCAST_SUCCEEDED` (`Registry.lua:1238-1247`, registered by `AlertGeneric.lua:38`).
  - `selfCastInstant` fires on the subset CastActivity calls INSTANT.
  - Not run in game.
- **[Fact]** *Immersion: Ranged* enables both `autoShotFired` (`:711`) and `selfCastInstant` (`:792`). [Inference] That means a RECOIL plus a CLICK on every arrow.
- **[Rec]** Drop one of the pair from each curated profile. Exclude spell 75 (and the wand Shoot spell) from `INSTANT`, or document the behaviour in the caveat.

---

### F-07 [P3] Dead and hidden calibration controls

- **[Fact]** `coastCoeff` is declared as a default, as a "Coast cutoff" slider, and in every preset (`Core/Devices.lua:69`, `:140-147`, `:210`, `:221`, `:232`). `ApplyDevicePreset` writes it. No engine code reads it: a full-tree grep finds it only in `Devices.lua`.
  - The coast trim was removed after the synthesis critique, but the control was left on the calibration page (rendered by `UI/Panel/Spec.lua:1731-1764`).
- **[Fact]** `floorKnee` sets the new soft-floor shape (`Engine.lua:533`). It is not in `CHANNEL_DEFAULTS` or `CHANNEL_TUNABLES`, so it has no slider and no preset sets it. The only way to change it is editing SavedVariables, and any such value is then erased by "Reset calibration" or by applying a preset, because both replace the whole `DB.channelTuning` table (`Database.lua:2965`, `:3017`).
  - *Correction, 2026-09-30:* the first version of this report said "Reset calibration" does not reset it. That was wrong.
- **[Rec]** Remove the Coast slider and key, or re-implement them. Decide whether `floorKnee` is a user knob (tie this to F-01).

---

### F-08 [P3] The "Default profiles" page omits Raiding and Questing

- **[Fact]** `Pulse.DEFAULT_PROFILE_METADATA` has 10 entries (`Core/Database.lua:69-170`). There are 12 built-ins (`:54-67`).
- **[Fact]** `Spec.BuildDefaultProfilesPage` lists only profiles with metadata (`UI/Panel/Spec.lua:1112-1113`). So *Raiding* and *Questing* never appear on that page.
- **[Fact]** Those two also get no recommended master intensity; they fall back to 0.70.
- **[Fact]** README.md:45-46 and CURSEFORGE.md:40-41 present both as curated defaults.
- **[Rec]** Add metadata for both profiles, or document that they are legacy slots.

---

### F-09 [P3] Overdrive is inert but still fragile

- **[Fact]** Every preset ships `overdriveBoost = 1.00` and `overdriveDuration = 0.000` (`Devices.lua:203-235`), so `driveChannel`'s overdrive branch (`Engine.lua:551-575`) never fires by default. The sliders are still exposed.
- **[Inference]** A user who raises them gets back the problems documented in `docs/HAPTIC_SYNTHESIS_CRITIQUE.md`:
  - The kick length is quantised to frames.
  - The boost is applied before the attack filter, and to the continuous baseline too.
  - The trigger looks at command history (`prevWanted == 0` or a jump greater than 0.40), not at the rotor's actual state.
- **[Rec]** Hide the two sliders until overdrive is reworked, or mark them experimental in their tooltips.

---

### F-10 [P3] The swim migration overwrites deliberate choices

- **[Fact]** `_MigrateSwimSettings` (`Database.lua:2064-2094`) sets `separateMotors = 0` wherever it was 1. It does this in every profile, custom profiles included (asserted by `harness.lua:1841-1845`). It can't tell the old default apart from a deliberate choice.
- **[Fact]** It sets `strokeDepth = 0.85` wherever the stored value is 0.55.
- **[Rec]** Accept this as policy but say so in the release notes, or restrict the migration to built-ins that are untouched.

---

### F-11 [P3] Tunable defaults off their slider grid

- **[Fact]** Probe `registry.lua` found three defaults that don't sit on their slider's step grid:
  - `glideThrust.presenceFloor` 0.15 with step 0.02 (`Registry.lua:406-411`)
  - `castTexture.channelHum` 0.12 with step 0.05 (`:496-501`)
  - `locomotion.gaitIntensity` 0.28 with step 0.05 (`:2683-2686`)
- **[Inference]** Once a slider is moved, the default value can't be selected again.
- **[Rec]** Align the step to the default, or the default to the step.

---

### F-12 [P3] The global `issecretvalue` shim

- **[Fact]** `Core/Init.lua:12-16` defines `_G.issecretvalue` (always returning false) when the client lacks it.
- **[Fact]** The TOC declares 110200 and 110100 alongside 120100 (`PulseHaptics.toc:1`).
- **[Inference]** On those clients, other addons that feature-detect with `if issecretvalue then` would wrongly conclude the Secret Values API exists.
- **[Rec]** Keep a file-local `local issecretvalue = _G.issecretvalue or function() return false end` in each file instead.

---

### F-13 [P3] Ocean-zone detection

- **[Fact]** `Modules/Movement.lua:49-81` sets `isOceanZone` from English substrings of the zone texts, using unanchored `find` on patterns such as `"sea"`, `"deep"`, `"port"`, `"sound"`, `"channel"`, `"cape"`.
- **[Inference]** This produces false positives:
  - "Searing Gorge", "Seat of…" (`sea`)
  - "Deeprun Tram", "Blackfathom Deeps" (`deep`)
  - any "Portal" (`port`)
- **[Inference]** Non-English clients only ever match the fatigue-water fallback.
- **[Rec]** Use map IDs (`C_Map.GetBestMapForUnit`), or at least word-anchored patterns.

---

### F-14 [P3] Weather preview passes the wrong argument

- **[Fact]** `Modules/Environment.lua:351` calls `Pulse.Waves.Sine(rainLevel, patterRate, 0.45, elapsed)`. The signature is `(baseline, frequency, depth, phase, time, …)` (`Core/Waves.lua:68`), so `elapsed` lands in `phase` and the wave runs on `GetTime()`. The effect is cosmetic: about 4.16 Hz instead of 4 Hz.
- **[Rec]** Call `Sine(rainLevel, patterRate, 0.45, 0, elapsed)`, as `PreviewWater` does.

---

### F-15 [P3, Unverified] A Pulse dialog opened in combat can swallow keyboard input

- **[Fact]** In combat, the dialog's `OnKeyDown` returns without calling `SetPropagateKeyboardInput` (`UI/Panel/Popup.lua:622-628`). The dialog calls `EnableKeyboard(true)` (`:620`).
- **[Fact]** The dialog is closed when combat *starts* (`:638-643`), but not when it is *opened* during combat.
- **[Unverified]** A keyboard-enabled frame does not propagate keys by default, and the last value set before combat persists. If so, every key press while the dialog is open in combat is eaten.
- **[Rec]** Refuse to open `Confirm`/`Prompt` while `InCombatLockdown()`, and print a message instead.

---

### F-16 [P3] The heartbeat previews bypass the preview layer

- **[Fact]** `M:TestHeartbeat` and `M:TestWarningBeat` write to the live `lowHealthTexture`/`lowHealthWarning` layers (`Modules/Health.lua:271-273`, `:287-289`), not to `preview`.
- **[Inference]** They are not cancelled by `CancelContinuousPreview` (`Init.lua:283-290`), and at low health they clash with the real cue.
- **[Rec]** Use the `preview` layer.

---

### F-17 [P3] Trigger-era leftovers (extends earlier item L6)

- **[Fact]** Code that still refers to trigger roles that no longer exist:
  - `ROLES_LIST` still includes `ltrigger`/`rtrigger` (`Engine.lua:63`).
  - `PlayMode` still reads `triggerMult` and branches on trigger roles (`:422`, `:456-457`, `:476-479`).
  - `HoldRolesIfEnabled`'s debug print lists them (`Init.lua:170`).
  - The panel subscribes to `triggerMult` (`Panel.lua:108`).
  - The new `GetChannelOutputs` fills `ltrigger`/`rtrigger` (`Engine.lua:1124-1127`).
- **[Fact]** Dead colour branch: the dropdown and list colour code still tests for a category called `"Triggers & Textures"` (`Rows.lua:508`; `Popup.lua:362-363`, `:471-472`). The Spec now names it `"Textures & Patterns"` (`Spec.lua:151-170`), so that category gets no colour.
- **[Fact]** `Modes.lua:3` still says "The 21-mode vocabulary". There are 35 modes.

---

### F-18 [P3] Residual of CR-022: calibration tables not validated at load

- **[Fact]** `Database:Init` type-checks profiles, rules, `device` and `minimap` (`Database.lua:1246-1306`), but not `DB.modeTuning` or `DB.channelTuning`.
- **[Inference]** A corrupted `channelTuning` that is a number makes `GetChannelTuning` throw inside the engine tick. The OnUpdate `pcall` then calls `StopAll` on every frame (`Engine.lua:875-890`), so all haptics die silently.
- **[Rec]** Quarantine these two tables the same way as the others.

---

## 4. Items confirmed fixed since the last audit (`docs/Claudereview.md`, HEAD `db2ffa5`)

| Earlier item | Now | Evidence |
|---|---|---|
| H1: gallop goes permanently silent after an unmerged→merged change | **Fixed** [Fact] | `Modules/Locomotion.lua:619-621` clears the pending trail step when merged |
| H2: sweep buttons called the missing `Panel.Refresh` | **Fixed** [Fact] | `Spec.lua:737`, `:748`, `:1059`, `:1071` call `Panel.MarkDirty`; `Panel.lua:76` aliases `Refresh` |
| M1: splitFeet not guarded by schema | **Fixed** [Fact] | `Locomotion.lua:369-384` |
| M3: sweep skipped the combat deferral | **Fixed** [Fact] | `Database.lua:2850-2856` |
| M5: legacy `TRIGGER_*` tuning orphaned | **Fixed** [Fact] | `_MigrateLegacyTriggerModes`, `Database.lua:1456-1493` |
| M2: curated profiles never reach existing installs | **Attempted, ineffective** | F-03 |
| L1: kick clamp `dt*1.2` | **Fixed** [Fact] | `Engine.lua:710-715`, no clamp |
| L2: table allocations per footfall | **Fixed** [Fact] | `layerPool` recycle, `Engine.lua:66-75`, `:270-277` |
| L4: `shape.kickTime` not validated | **Fixed** [Fact] | default `or 0.025`, `Engine.lua:714` |
| L7: CURSEFORGE timbre names | **Fixed** [Fact] | `CURSEFORGE.md:19` |
| Synthesis critique: same-motor ducking | **Removed** [Fact] | `Engine.lua:767-779` now `clamp01(cont + trans)` |
| Synthesis critique: coast trim holes | **Removed from the engine** [Fact] | the control is left behind, F-07 |

---

## 5. Still open from earlier reviews (F-19)

| Item | Where | Note |
|---|---|---|
| CR-007: bossAbilityWarning uses `C_EncounterEvents.HasEventsForEncounter`/`GetEventsForEncounter` | `Modules/Encounter.lua:35-41` | Unchanged. [Unverified] whether the API exists on Forever; the earlier review said it does not. |
| CR-019 residual: any pad under Steam Input suggests the Steam Deck LRA preset | `Devices.lua:394`, `:457`, `:468` | Detection only suggests a preset, but it suggests LRA values for ERM pads. |
| L3: shaped-footfall cut is absolute (0.06), so quiet steps vanish | `Engine.lua:715`, `:729` | Unchanged. |
| L8: PulseProfileReview not linted by `test.sh` | `scripts/test.sh:92` | Unchanged; lints clean by hand. |
| L9: `gaitIntensity` fallback 0.35 vs Registry/preview 0.28 | `Locomotion.lua:299` vs `:750`, `Registry.lua:2685` | Only matters for an unseeded profile. |
| L10: locomotion `dt` uncapped (hitch → double step) | `Locomotion.lua:606` | Unchanged. |
| Settings window cannot be driven by the controller | `UI/Panel/Gamepad.lua:30-69` | Documented and deliberate (taint); still a headline gap for a controller addon. |
| Device preset notes state unmeasured hardware specifics as fact | `Devices.lua:278-370` | For example, "Quad-LRA" for Steam Controller 2 and chassis masses. `docs/HAPTIC_SYNTHESIS_VERIFICATION.md` item 11 already flags some. |

**Checked and dropped:**
- **[Fact]** `Modules/ControllerUI.lua:14-16` warns that registering SmartNavigation callbacks runs addon code inside Blizzard's stack. The Blizzard source in `docs/DevelopmentplusReference/…/Blizzard_SharedXMLBase/CallbackRegistry.lua:184-214` dispatches callbacks through `securecallfunction`/`secureexecuterange`, which isolates callback taint.
- So the curated Immersion profiles enabling `uiNavigateEdge` is not raised as a taint finding. [Unverified] that Forever ships the same `CallbackRegistry`.

---

## 6. Test gaps behind these findings

| Finding | Why the suite stayed green | Test that should exist |
|---|---|---|
| F-01 | No test compares continuous output against the preset floor | For each ERM preset × each continuous cue's authored default: the steady `SetVibration` value is ≥ floor (with a stated master intensity) |
| F-02 | crafting-test always runs with craftTexture enabled | castTexture on, craftTexture off, fishing / gather / recipe → castTexture holds > 0 |
| F-03 | `harness.lua:1767-1835` mocks v8 profiles with empty `triggerSettings` | Generate a v8 DB from the real pre-curation code and upgrade it (the method of probe `migrate.lua`) |
| F-04 | `pulsedebug-test.lua:395` mocks `GetChannelOutputs` | Call the real `Engine:GetChannelOutputs` after a `Hold` and compare with `SetVibration` |
| F-05 | The harness checks only that `TestCue` returns true | Drive timers and count strike `PlayMode` calls during `PreviewCraft` |
| F-06 | none | CastActivity: SUCCEEDED spell 75 with no START → assert the chosen classification |

---

## 7. Needs the client or hardware [Unverified]

1. Whether a motor commanded below the preset floor is really imperceptible on Xbox, DS4 and 8BitDo pads (F-01). A 30-second check: enable *In water* on the Xbox preset at the default intensity and swim.
2. Whether Auto Shot, wand Shoot and channel tick spells arrive as SUCCEEDED without a START (F-06). Use `/pdebug cast`.
3. The default keyboard-propagation state of a keyboard-enabled frame, and whether a Pulse dialog opened mid-combat swallows keys (F-15).
4. Whether `StaticPopup1..4` still exist on 12.x Forever (`Modules/PlayerState.lua:126-154`), and whether `C_Weather.GetCurrentWeather` and `LowHealthFrame` exist there. The code already assumes all of these.
5. The order of C_Timer callbacks versus OnUpdate within a frame. It decides whether contiguous multi-step modes get a one-frame dip at each step boundary (`Engine.lua:483-495` vs `:705-707`).

---

## 8. Suggested fix order

1. **F-02**: a one-line guard in `beginCraft` plus a regression test. It restores fishing and crafting for Healer and Caster profiles right away.
2. **F-01**: decide the floor policy (options a, b or c), then fix the three help texts. It blocks tuning of every immersion texture on ERM pads.
3. **F-03**: a v11 migration with a real-DB test. Decide first whether curated sets should be forced for everyone (the same product decision as the earlier item M2).
4. **F-04, F-05**: small local fixes; the oscilloscope is the tool for verifying F-01 in game.
5. **F-06**: profile curation edits plus the INSTANT filter.
6. The P3 sweep: F-07, F-08, F-10 to F-18.

---

## 9. Coverage ledger

**Read in full, line by line** (at `ad0ef89`, with the `1ca6a24` deltas re-read):
- **Core:** `Init.lua` (453), `Engine.lua` (1149), `Devices.lua` (538), `Modes.lua` (421), `Waves.lua` (184), `CastActivity.lua` (526), `Guide.lua` (175), `Schemas/*.lua` (4 files)
- **Modules (all 21):** Movement, Flight, Combat, Environment, World, Inventory, Encounter, Health, Casting, Locomotion, PlayerState, Crafting, Interaction, AlertGeneric, AlertLossOfControl, AlertThreat, AlertUnitWatch, AlertSocial, AlertWorld, AlertDevice, AlertExperimental, ControllerUI
- **UI:** `Settings.lua`, `Minimap.lua`, `Panel/Theme.lua`, `Popup.lua`, `Rows.lua`, `Sidebar.lua`, `Gamepad.lua`, `Content.lua`, `Spec.lua` (1919), `Panel.lua`
- `PulseHaptics.toc`

**Read in part, rest checked by script:**
- `Core/Database.lua` (3108):
  - All code read (1–174, 1068–1495, 1908–3108).
  - The curated profile tables (175–1068) and `LEGACY_V8_OVERRIDES` (1496–1908) were checked by probe and targeted grep, not read entry by entry.
- `Core/Registry.lua` (3307):
  - 1–700 and 3195–3308 read.
  - All 190 triggers checked by probe `registry.lua`: duplicates, modes, kinds, tunable ranges and grids, throttles of 30 selected cues, cue-id literals used in code, tunable fallbacks in code against Registry defaults.
  - Page placement checked by `pages.lua`: 188 placements, 0 duplicates; the 2 category masters are intentionally unplaced.
  - Trigger texts (desc, caveat) outside 1–700 were not proof-read.

**Read only where they touch PulseHaptics:**
- The `1ca6a24` diffs of `PulseDebug/Debug.lua`, `UI.lua`, `PulseDebug.toc`
- `PulseDebug/Oscilloscope.lua:723-731`
- `PulseChecklist/tests/harness.lua:1-640` and `:1760-1905`
- `pulsedebug-test.lua:395` (by grep)
- `scripts/test.sh`

**Context documents read (for status, not re-reviewed):**
- `docs/FIX_LOG.md`, `docs/Claudereview.md`, `docs/HAPTIC_SYNTHESIS_VERIFICATION.md`, the heading index of `docs/CODE_REVIEW.md`
- README and CURSEFORGE claims checked by grep

**Not reviewed:** `Libs/` (third-party), `Media/`, the rest of PulseDebug, PulseChecklist, PulseProfileReview, `scripts/` other than `test.sh`, and other documents under `docs/`.

**Probes and evidence.** Saved in `docs/review-2026-09-30/`:
- `probes/`: the scripts.
- `evidence/`: the recorded outputs, one file per topic, plus `tests.txt` and `static-checks.txt`.
- `run.sh`: re-runs everything.
- `README.md`: maps each finding to its evidence file.

The probes load the real addon files from `git archive` snapshots of `ad0ef89`, `1ca6a24`, `db2ffa5` and `dace2ab` through the stub WoW API in `harness.lua`. They never read the working tree and write nothing to the repo.

| Probe | Used for |
|---|---|
| `env.lua` | Shared loader and serialiser |
| `migrate.lua` + `migrate_ab.lua` + `questing.lua` | F-03 |
| `craft.lua` | F-02, F-05 |
| `softfloor.lua` | F-01 (run against `db2ffa5` and HEAD, at master 0.7 and 1.0) |
| `scope.lua` | F-04 (against `1ca6a24`) |
| `registry.lua`, `pages.lua` | F-11, the Registry checks |

**Repository state during the review:**
- Began at `ad0ef89` with uncommitted PulseDebug/Engine edits.
- Those were committed as `1ca6a24` at 02:14:50.
- At the time of writing the tree is clean at `1ca6a24`, apart from this report.
