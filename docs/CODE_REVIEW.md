# PulseSensation — Code Review (xhigh), Newspeak register

**Register notice.** User ordered this report in Newspeak (overrides handoff §1.9 plain-English rule for this file). Commentary is Newspeak; C vocabulary — paths, identifiers, API names, code, probe output, numbers — is byte-exact. Where compression risked ambiguity, sentence stays whole.

Glossary (B vocabulary): *doubleplusgood* = verified working · *plusgood* = works, unfullverified · *ungood* = broken · *plusungood* = broken, user feels it · *doubleplusungood* = critical/blocking · *goodthink* = follows codebase convention · *crimethink* = violates convention, invites bugs · *oldthink* = deprecated · *bellyfeel* = claim repeated, uncrosschecked · *rectify* = fix · *unperson* = remove.
Labels: **[Fact]** verified from file/command/Git · **[Inference]** reasoned, unproven · **[Rec]** recommendation · **[Unverified]** needs live client or hardware.

---

## 1. Header

- **Date:** 2026-09-28
- **HEAD:** `ac3d02f98da6720e54521f63219850f3dc3d6474` (branch `main`, remote `origin` → `github.com/codingdoctorbot/PulseSensation`). Matches handoff §3.
- **Dirty tree (in scope, reviewed as current code, each finding flags "uncommitted"):** `PulseChecklist/tests/crafting-test.lua`, `PulseChecklist/tests/harness.lua`, `PulseHaptics/Core/CastActivity.lua`, `PulseHaptics/Core/Database.lua`, `PulseHaptics/Core/Engine.lua`. Untracked: `PulseProfileReview/`, `ProfileReviewReports/`, `docs/DOCS_COMPILATION.md`, `docs/HANDOFF_CODE_REVIEW.md`, this file. Matches handoff §3.
- **Level:** xhigh. Read-only for code. No subagents. No commits.
- **Target client:** WoW "Forever" (`_classic_beta_`, TOC `## Interface: 120100`). Reference source in repo: `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/` (`version.txt` = `1.60.1.69913`; Blizzard TOCs carry `## AllowLoadGameType: camelot`). Below, **`FOREVER/`** abbreviates `…/wow-ui-source-forever/Interface/AddOns/`.

### 1.1 Method

1. Every in-scope file read in full, line by line (ledger §2).
2. Uncommitted work read whitespace-blind: `git diff -w -- PulseHaptics/` (68 insertions, 9 deletions over 5 files).
3. Forever API cross-check, scripted (this session):
   - **Events:** every upper-case string literal in `PulseHaptics/Core`, `Modules`, `UI`, `PulseDebug`, `PulseChecklist/Checklist.lua`, `PulseProfileReview/Review.lua` (259 strings) diffed against every `LiteralName` in `FOREVER/Blizzard_APIDocumentationGenerated/` (1,802 events). [Fact] Only two event names are absent: `PING_PIN_ADDED`, `LEARNED_SPELL_IN_TAB` (CR-024). Everything else registered exists.
   - **`C_*` calls:** each `C_Namespace.Function` looked up in its namespace's doc file. [Fact] Absent: `C_EncounterEvents.GetEventsForEncounter`, `C_EncounterEvents.HasEventsForEncounter` (CR-007); `C_PlayerInfo.GetGlidingInfo` (absent from generated docs but used by Blizzard's own `FOREVER/Blizzard_FrameXML/MotionSickness.lua:99` → exists, plusgood); `C_Spell.IsSpellKnownOrOverridesKnown` (absent; `Locomotion.lua:182-189` falls back to global `IsSpellKnown`, defined in `FOREVER/Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua:16` → riding tier still resolves, plusgood).
4. Offline probes (LuaJIT, real addon files, stub API) in session scratchpad `scratchpad/`: `channel-probe.lua`, `gait-probe.lua`, `intensity-probe.lua`, `pool-probe.lua`, `import-probe.lua`. Unrepo; may be cleaned.
5. Every finding checked against handoff §5 and DOCS_COMPILATION §4, §9, §10 (this file §6). Git history NOT re-walked this session — history claims come from DOCS_COMPILATION §9 and are marked bellyfeel where repeated.

### 1.2 Baseline command results (this session)

| Command | Result |
|---|---|
| `git rev-parse HEAD` | `ac3d02f98da6720e54521f63219850f3dc3d6474` |
| `git status --porcelain` | 5 modified + 4 untracked, as handoff |
| `./scripts/test.sh` | luacheck `0 warnings / 0 errors in 53 files`; harness, locomotion-test, engine-test, cue-audit, pulsedebug-test, checklist-test ✓ PASS; crafting-test ✗ FAIL (`FAILURES: 3`: `hearthstone cast is pending`, `hearthstone cast preserved past 10s…`, `active player cast protected…`); `✗ 1 SUITE(S) FAILED (5s)`; exit 1 |
| same 7 suites under `luajit` | identical: 6 pass, crafting-test `FAILURES: 3` |
| `luacheck PulseProfileReview` | `4 warnings / 0 errors in 1 file` (`GameTooltip_Hide` undefined `:199`; `PulseProfileReviewDB` global `:326-327`) |
| Tools | Lua 5.5.1 · LuaJIT 2.1.1788856981 · Luacheck 1.2.0 |

Baseline verdict: goodthink with handoff expectations, fullwise.

### 1.3 Counts

| Severity | Count | IDs |
|---|---:|---|
| P0 | 0 | — (no crash, stuck vibration, taint block or data loss found in code; see §8 for what only the client can settle) |
| P1 | 6 | CR-001, CR-002, CR-004, CR-005, CR-008, CR-013 (CR-013 = known issue re-confirmed and widened) |
| P2 | 14 | CR-003, CR-006, CR-007, CR-009, CR-010, CR-011, CR-012, CR-014, CR-015, CR-016, CR-017, CR-019, CR-026, CR-029 (§12) |
| P3 | 11 | CR-018, CR-020, CR-021, CR-022, CR-023, CR-024, CR-025, CR-027, CR-028, CR-030 (§13), CR-031 (§13) |
| **Total** | **31** | 20 wholly new (CR-029 added in §12; CR-030, CR-031 in §13) · 9 extend an earlier document (CR-005, CR-008, CR-011, CR-012, CR-017, CR-019, CR-024, CR-025, CR-027) · 2 known, re-confirmed (CR-013 widened, CR-022 now checked) — corrected after reading DOCS §3 (A7) |

---

## 2. Coverage ledger

"Fully read" = every line read this session via the Read tool or `cat -n`. Line counts from `wc -l`.

### 2.1 In scope

| File | Lines | Status |
|---|---:|---|
| `PulseHaptics/Core/CastActivity.lua` (uncommitted) | 464 | fully read |
| `PulseHaptics/Core/Database.lua` (uncommitted) | 1850 | fully read |
| `PulseHaptics/Core/Devices.lua` | 492 | fully read |
| `PulseHaptics/Core/Engine.lua` (uncommitted) | 872 | fully read |
| `PulseHaptics/Core/Guide.lua` | 179 | fully read |
| `PulseHaptics/Core/Init.lua` | 391 | fully read |
| `PulseHaptics/Core/Modes.lua` | 415 | fully read |
| `PulseHaptics/Core/Registry.lua` | 3274 | fully read |
| `PulseHaptics/Core/Schemas/HighOnly.lua` | 26 | fully read |
| `PulseHaptics/Core/Schemas/Inverted.lua` | 20 | fully read |
| `PulseHaptics/Core/Schemas/LowOnly.lua` | 23 | fully read |
| `PulseHaptics/Core/Schemas/RumbleAndTriggers.lua` | 30 | fully read |
| `PulseHaptics/Core/Schemas/Standard.lua` | 31 | fully read |
| `PulseHaptics/Core/Schemas/TriggerEmphasis.lua` | 23 | fully read |
| `PulseHaptics/Core/Waves.lua` | 184 | fully read |
| **Core subtotal** | **8274** | 15/15 fully read |
| `PulseHaptics/Modules/AlertDevice.lua` | 118 | fully read |
| `PulseHaptics/Modules/AlertExperimental.lua` | 183 | fully read |
| `PulseHaptics/Modules/AlertGeneric.lua` | 87 | fully read |
| `PulseHaptics/Modules/AlertLossOfControl.lua` | 105 | fully read |
| `PulseHaptics/Modules/AlertSocial.lua` | 49 | fully read |
| `PulseHaptics/Modules/AlertThreat.lua` | 72 | fully read |
| `PulseHaptics/Modules/AlertUnitWatch.lua` | 273 | fully read |
| `PulseHaptics/Modules/AlertWorld.lua` | 55 | fully read |
| `PulseHaptics/Modules/Casting.lua` | 59 | fully read |
| `PulseHaptics/Modules/Combat.lua` | 995 | fully read |
| `PulseHaptics/Modules/ControllerUI.lua` | 554 | fully read |
| `PulseHaptics/Modules/Crafting.lua` | 593 | fully read |
| `PulseHaptics/Modules/Encounter.lua` | 138 | fully read |
| `PulseHaptics/Modules/Environment.lua` | 334 | fully read |
| `PulseHaptics/Modules/Flight.lua` | 140 | fully read |
| `PulseHaptics/Modules/Health.lua` | 297 | fully read |
| `PulseHaptics/Modules/Interaction.lua` | 287 | fully read |
| `PulseHaptics/Modules/Inventory.lua` | 163 | fully read |
| `PulseHaptics/Modules/Locomotion.lua` | 664 | fully read |
| `PulseHaptics/Modules/Movement.lua` | 523 | fully read |
| `PulseHaptics/Modules/PlayerState.lua` | 193 | fully read |
| `PulseHaptics/Modules/World.lua` | 65 | fully read |
| **Modules subtotal** | **5947** | 22/22 fully read |
| `PulseHaptics/UI/Minimap.lua` | 349 | fully read |
| `PulseHaptics/UI/Settings.lua` | 300 | fully read |
| `PulseHaptics/UI/Panel/Content.lua` | 280 | fully read |
| `PulseHaptics/UI/Panel/Gamepad.lua` | 546 | fully read |
| `PulseHaptics/UI/Panel/Panel.lua` | 601 | fully read |
| `PulseHaptics/UI/Panel/Popup.lua` | 672 | fully read |
| `PulseHaptics/UI/Panel/Rows.lua` | 762 | fully read |
| `PulseHaptics/UI/Panel/Sidebar.lua` | 233 | fully read |
| `PulseHaptics/UI/Panel/Spec.lua` | 1861 | fully read |
| `PulseHaptics/UI/Panel/Theme.lua` | 284 | fully read |
| **UI subtotal** | **5888** | 10/10 fully read |
| `PulseHaptics/PulseHaptics.toc` | 131 | fully read |
| `PulseDebug/Debug.lua` | 491 | fully read |
| `PulseDebug/UI.lua` | 821 | fully read |
| `PulseDebug/PulseDebug.toc` | 14 | fully read |
| `PulseChecklist/Checklist.lua` | 928 | fully read |
| `PulseChecklist/PulseChecklist.toc` | 17 | fully read |
| `PulseChecklist/tests/harness.lua` (uncommitted) | 1319 | fully read |
| `PulseChecklist/tests/crafting-test.lua` (uncommitted) | 387 | fully read |
| `PulseChecklist/tests/engine-test.lua` | 410 | fully read |
| `PulseChecklist/tests/locomotion-test.lua` | 101 | fully read |
| `PulseChecklist/tests/cue-audit.lua` | 168 | fully read |
| `PulseChecklist/tests/checklist-test.lua` | 311 | fully read |
| `PulseChecklist/tests/pulsedebug-test.lua` | 565 | fully read |
| `PulseProfileReview/Review.lua` | 347 | fully read |
| `PulseProfileReview/PulseProfileReview.toc` | 10 | fully read |
| `PulseProfileReview/README.md` | 21 | fully read |
| `scripts/test.sh` | 158 | fully read |
| `scripts/package.sh` | 63 | fully read |
| `.luacheckrc` | 202 | fully read |
| **Total in scope** | **26573** | **68/68 fully read** |

### 2.2 Out of scope / partial (honest list)

| Item | Status |
|---|---|
| `PulseHaptics/Libs/` | not read (third-party, out of scope) |
| `ProfileReviewReports/Immersion-Ranged-Cue-Review.md` (97) | fully read in A6 |
| `README.md` (123) | fully read; `PulseChecklist/tests/README.md` (58) fully read; `CURSEFORGE.md` (162) fully read in A7 |
| `docs/HANDOFF_CODE_REVIEW.md` | fully read |
| `docs/DOCS_COMPILATION.md` | fully read (§1–§3 and Appendices in A7; line numbers shifted +49 after §11 was added) |
| Forever reference files | partial, targeted: `GamePadDocumentation.lua` 1-400; `UnitDocumentation.lua` spellcast/mirror-timer/UNIT_TARGET payload blocks; `Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua` grep + 1-20; `Blizzard_CombatAudioAlerts/…Manager.lua` 100-160; `EncounterEventsDocumentation.lua` 1-54 + name list; `EncounterEventsSharedDocumentation.lua` 32-51; `WeatherScriptDocumentation.lua` full; `WeatherConstantsDocumentation.lua` enum; `MirrorTimerDocumentation.lua` names; `PlayerInteractionManagerConstantsDocumentation.lua` 23 enum values; `Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua` mixin section; `Blizzard_SharedXML/Mainline/InputUtil.lua` 1-17; `SimpleFrameAPIDocumentation.lua` two entries; `LossOfControlDocumentation.lua` two entries; `SecretPredicateAPIDocumentation.lua` grep; `ChatInfoDocumentation.lua` grep |
| Other project docs | fully read in §13.3: all 13 files in `docs/dev-notes/` (`Luaerrorissues.rtf` via `textutil`), `Cooking/midnight_controller_haptics_event_findings.md` (1552), `Cooking/Overhual casting detectioncraftingetc.lua` (367). The other ~45 files in `Developer Documents/Cooking/` are **not read** (design notes, drafts, screenshots) |
| Live install (outside repo, read-only) | §13: AddOns folder links, `WTF/Account/…/SavedVariables/PulseHaptics.lua` (10,624 lines, parsed and diffed by script, not read line by line), `Logs/` (all names; `taint.log`, `FrameXML.log` in full; the rest grepped), `Errors/` (6 dumps: headers, session fields, stacks; the long module lists grepped), `WTF/Config.wtf`, `GamePadConfig_Default.json`, `gamecontrollerdb.txt` (grepped / parsed) |
| QA addons in the install (`Interface/AddOns/QA/`) | §13.4: all 7 files read (the `.md` copy by diff against the `.lua`) |
| `Ongoing Bugs/` (untracked) | §14: all 12 report files read in full; the 968 KB repo snapshot `.txt` header only; `WoWAddonAPIAgents-main/` and `wow-addon-dev-main/` (third-party reference kits) not read |
| Git history | not re-walked; DOCS_COMPILATION §9 bellyfeel for commit attributions |

---

## 3. Findings (most severe first)

IDs = stable handles in discovery order; list sorted by severity, so IDs are unsequential.

### CR-001 [P1] Channel lifecycle misclassified: `UNIT_SPELLCAST_SUCCEEDED` at channel start ends fishing texture or kills channel hum
- **Verdict:** plusungood. Primary root cause of QA report "channeling, including fishing, is broken".
- Where: `PulseHaptics/Core/CastActivity.lua:117-182` (`_OnSucceeded`), `:102-113`, `:285-298`; consumers `PulseHaptics/Modules/Combat.lua:525-553`, `PulseHaptics/Modules/Crafting.lua:482-525`, `PulseHaptics/Modules/Casting.lua:29-34`. Uncommitted: no. Channel model since `110cebc`; fishing path since `d44badf`; channel hum exposed to it since `b39e6a6` (A5). Same assumption lives in prototype `docs/DevelopmentplusReference/Developer Documents/Cooking/Overhual casting detectioncraftingetc.lua:155-176` (bellyfeel ported, uncrosschecked).
- What:
  - [Fact] Code assumes SUCCEEDED marks channel END (comment `CastActivity.lua:158-159`: "A channel that reached its end").
  - [Inference, high confidence; Unverified on Forever] On retail-engine clients SUCCEEDED fires once when channel BEGINS. Forever runs 12.x engine; channel payloads identical to retail (`FOREVER/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:4594-4610`).
  - Same castGUID on both → `CHANNEL_COMPLETE` at start → `Crafting.lua:506-510` `endCraft(true)` → fishing bed dies immediately; generic hum takes over.
  - Different/unmatched GUID → `INSTANT` → `Combat.lua:540-552` nils castTexture OnUpdate → **silence for whole channel**; `selfCastInstant` misfires (`Casting.lua:33`).
  - `CHANNEL_STOP.completed` (`CastActivity.lua:295`) true from start → never real completion semantics.
- Failure scenario: fishing (7620) with castTexture + craftTexture on → generic hum or 0.049 bed (CR-003); Arcane Missiles/Drain Life-class channel with GUID mismatch → nothing.
- Evidence: `channel-probe.lua` (real `CastActivity.lua`, `Combat.lua`, `Casting.lua`, `Crafting.lua`):
  ```
  1b fishing: + SUCCEEDED same GUID, 30 frames   combat.isChanneling=true  craft.active=false ... classes=CHANNEL_START,CHANNEL_COMPLETE
  2  fishing: SUCCEEDED different GUID           combat.isChanneling=false craft.active=true  holds(last)=craftTexture low=0.070 classes=CHANNEL_START,INSTANT fired=selfCastInstant
  4  generic channel: SUCCEEDED different GUID   combat.isChanneling=false craft.active=false holds(last)=-  classes=CHANNEL_START,INSTANT fired=selfCastInstant
  ```
  [Fact] Test gap: `PulseChecklist/tests/crafting-test.lua:323-336` drives fishing as `CHANNEL_START → CHANNEL_STOP`, no SUCCEEDED — suite passes, live order breaks. [Fact] Blizzard's own cast bar ignores castID on CHANNEL_STOP (`FOREVER/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua:449-450`) — hint channel GUIDs are unreliable keys.
- Related: none in DOCS §4 (new). DOCS §7 "Casting/crafting … channel" backlog covers live check.
- Fix direction: [Rec] (1) `_OnSucceeded`: while `activeChannel` exists and spellID matches (GUID optional), set `confirmed = true`, emit `CHANNEL_CONFIRMED` (or nothing) — never COMPLETE. (2) Completion only from `CHANNEL_STOP` with `interruptedBy == nil` (pattern `CastingBarFrame.lua:136-138`). (3) Crafting ends gathering only on terminal event of the tracked spell. (4) New test sequences `CHANNEL_START → SUCCEEDED → CHANNEL_STOP`, same and different GUID. (5) Capture real order with `/etrace` first (§8).

### CR-002 [P1] castTexture torn down by events of OTHER casts (spam-press FAILED, unrelated instant SUCCEEDED)
- **Verdict:** plusungood. Latent for casts; live for channels.
- Where: `PulseHaptics/Modules/Combat.lua:540-552`; emitters `PulseHaptics/Core/CastActivity.lua:181`, `:210-238`. Uncommitted: no. Introduced in `b39e6a6` (INSTANT stop); FAILED stop older (A5).
- What: [Fact] Listener stops texture on ANY `INSTANT`, `FAILED`, `INTERRUPTED`, `CAST_STOPPED`, `CHANNEL_STOP`, never checking the event belongs to the textured cast. `_OnFailed` emits for any failed attempt; `_OnSucceeded` emits `INSTANT` for any unmatched success.
- Failure scenario: mid-Frostbolt, player presses another spell → `UNIT_SPELLCAST_FAILED` (other GUID) → texture dead rest of cast. During a channel, an off-GCD instant or Auto Shot (spell 75, `Combat.lua:611`) succeeds → dead rest of channel.
- Evidence: `channel-probe.lua`:
  ```
  5b cast: + FAILED for a different (spammed) spell   combat.isChanneling=false isCasting=false ... classes=CAST_START,FAILED
  6  channel + unrelated instant SUCCEEDED            combat.isChanneling=false isCasting=false ... classes=CHANNEL_START,INSTANT
  ```
  [Unverified] whether Forever fires FAILED for input pressed mid-cast (retail does outside spell-queue window).
- Related: CR-001 (same listener). DOCS §4.2 castTexture row (PARTIAL) — new detail.
- Fix direction: [Rec] Track `currentCastGUID`/`currentSpellID` from CAST_START/CHANNEL_START; stop only on terminal event with same identity (GUID when both present, else spellID). Keep `castTick`'s `UnitCastingInfo`/`UnitChannelInfo` nil check as safety net (`Combat.lua:453-461`, `:484-491`) — goodthink, ends stale texture within one frame.

### CR-004 [P1] Continuous-cue ▶ preview = flat 0.45 hold on BOTH motors — "only intense rumble"
- **Verdict:** plusungood. Direct root cause of QA report "replay on many continuous textures … only intensive rumble".
- Where: `PulseHaptics/Core/Init.lua:239-248`, `:300-307`. Uncommitted: no.
- What: [Fact] `Pulse:TestCue` for any `continuous` cue (except two heartbeat cues routed to `Modules/Health.lua`, `Init.lua:253-256`) calls `Engine:Set("preview", 0.45*scale, 0.45*scale, 3.5)`: same level low AND high, no modulation, no tunables read. [Fact] Real textures far quieter and shaped: `waterTexture.baseline` 0.04 (`Registry.lua:214`), `stealthTexture.baseline` 0.06 (`:2596`), `swimTexture.peak` 0.10 (`:156`), `taxiRide.windAmplitude` 0.1 (`:323`), `oceanTexture.swellStrength` 0.14 (`:264`), castTexture 0.1 low + 0.2 high (`:480`, `:498`), craft bed 0.06–0.16 (`Crafting.lua:75-88`). Preview 3–11× louder, wrong motor for single-motor textures, rhythmless.
- Failure scenario: ▶ on "In water", "Stealth texture", "Swimming resistance", "Ocean waves", "Weather texture", "Footfalls and gait", "Crafting texture", "Casting texture", "Riding a flight path", "Dragonriding thrust", "Underwater breath texture" → all identical 3.5 s dual-motor buzz. Same button used by PulseChecklist ▶ (`Checklist.lua:390-398`) and Continuous textures page "Feel this texture" (`Spec.lua:1775-1778`).
- Evidence: code read; comment `Init.lua:244-247` admits flat value; tooltip admits it (`UI/Panel/Spec.lua:309-311`).
- Related: none in §4 (new). CR-006, CR-014, CR-018 (preview fidelity theme T2).
- Fix direction: [Rec] Each continuous module exposes `Preview(seconds, scale)` running its own shaping function against synthetic state (swim-speed ramp, 3 s cast progress, walk→run gait, rain intensity), as Health already does. Fallback: first tunable's default level on the cue's real role, never 0.45 on both.

### CR-005 [P1] Footfalls blur into buzz: cadence unit doubled, GALLOP quadrupled, continuous smoothing rounds every step
- **Verdict:** plusungood. Root cause of QA report "footsteps could be more crispy, distinct".
- Where: `PulseHaptics/Modules/Locomotion.lua:226-252` (`gaitWaveform`), `:513-536` (emit), `:283-345` (cadence); `PulseHaptics/Core/Engine.lua:449-453` (continuous attack); labels `PulseHaptics/Core/Registry.lua:2659-2675`. Uncommitted: no.
- What:
  - [Fact] One 2π cycle yields one LEFT and one RIGHT pulse (`max(0, sin φ)`, `max(0, -sin φ)`) → `runCadence`/`walkCadence` are STRIDES/s; labels say "steps/s". Real footfalls/s = 2 × setting. GALLOP uses `|sin φ|` (period π) for lead AND trail → 4 bumps per cycle.
  - [Fact] Footfalls = continuous `HoldIfEnabled` (`isTransient = false`) → each step rides `attackTau` (Generic 0.075 s). A ~90 ms step never reaches target; onset = sin^4 ramp, unimpact.
  - [Fact] Unsplit path puts both feet on LOW role (`:535`); DualSense and Steam Controller 2 presets have `triggers = false` (`Devices.lua:238`, `:307`) → `shouldSplitFeet()` (`:373-382`) vetoes split → footfalls on heavy/slow channel, least crisp.
  - [Fact] `mountedOnly` default ON (`Registry.lua:2636-2641`) → on-foot footsteps silent until user unticks it.
- Failure scenario: Human running (speed 7.0) → 5.5 footfalls/s (real run ≈ 2.7–3/s). Human on 60 % mount (11.2) → 14 bumps/s, ~50 % modulation on Generic = continuous grumble, no hoofbeats.
- Evidence: `gait-probe.lua` (real `Devices.lua`, `Standard.lua`, `Engine.lua`, `Locomotion.lua`; masterIntensity 0.7; `mountedOnly` forced 0):
  ```
  on foot, running (7.0)  preset=default           fps= 60 cadence=2.80 mode=FOOTSTEP peaks/s=  5.5  Low min=0.012 max=0.128  depth=90%
  on foot, running (7.0)  preset=dualsense         fps= 60 cadence=2.80 mode=FOOTSTEP peaks/s=  5.5  Low min=0.011 max=0.280  depth=96%
  on foot, running (7.0)  preset=steamcontroller2  fps= 60 cadence=2.80 mode=FOOTSTEP peaks/s=  5.5  Low min=0.018 max=0.260  depth=93%
  on foot, walking (2.5)  preset=default           fps= 60 cadence=1.80 mode=FOOTSTEP peaks/s=  3.5  Low min=0.005 max=0.100  depth=95%
  mounted 60% (11.2)      preset=default           fps= 60 cadence=7.26 mode=GALLOP   peaks/s= 14.0  Low min=0.092 max=0.192  depth=52%
  mounted 60% (11.2)      preset=dualsense         fps= 60 cadence=7.26 mode=GALLOP   peaks/s= 14.0  Low min=0.090 max=0.387  depth=77%
  ```
  Same at 144 fps (frame-rate independent — goodthink). Generic target peak 0.245, delivered 0.128 → ~48 % lost to continuous attack.
- Related: DOCS §4.4 "Gait cadence units | #19 1.2 | OPEN / UNVERIFIED" → **now [Fact]: units wrong**. §4.4 "Gait cadence cap FIXED" — cap 8.0 is strides → up to 16 steps/s, 32 GALLOP bumps/s.
- Fix direction: [Rec] (1) Schedule each footfall as discrete transient (`SetRoles(..., isTransient = true)` or short TAP/THUD 30–60 ms) at real step times. Keep continuous path only for optional low "weight" bed. (2) Cadence in real steps/s; GALLOP 1 lead + 1 trail per stride. (3) On symmetric-actuator pads (DualSense: two identical voice coils — [Inference] SDL maps low→left, high→right; [Unverified] on Forever/macOS) allow L/R split onto Low/High; default footfalls to High (fast) channel on LRA presets. (4) Migrate saved cadence values (halve) with a DB_VERSION bump. (5) locomotion-test asserts footfalls/s = configured steps/s.

### CR-008 [P1] Intensity sliders incoherent by construction: dead bottom on Generic, dead top on strong modes, range compressed by presets, felt strength depends on what else plays
- **Verdict:** plusungood. Primary root cause of QA report "intensity sliders very inconsistent … feel broken on DualSense / Steam Controller 2". Every slider stores and reads doubleplusgood (harness round-trip, §7); the ungood part is what the value DOES.
- Where: `PulseHaptics/Core/Engine.lua:378` (`clamp01(relIntensity*scale)`), `:579-581` (transient over continuous), `:602` (master after blend), `:429-439` (gain → gamma → floor lift); `PulseHaptics/UI/Panel/Spec.lua:199-218` (per-cue Intensity 0–1.5), `:435-448` (Overall intensity, per profile); `PulseHaptics/Core/Devices.lua:186-188`, `:227-325` (preset floors). Uncommitted: no.
- What (all [Fact], probe below):
  1. **Dead top.** Slider reaches 1.5 but `clamp01(relIntensity × scale)` saturates at `1/relIntensity`: HEAVY, IMPACT, RISING, FALLING, SURGE, CRACK, PULSE_BEAT at 1.0; THUD at 1.18. Last third of slider does nothing there; TICK (0.2) still climbs. Same knob, different law per mode.
  2. **Dead bottom on Generic.** Floor 0 default → TICK at slider 1.0 peaks 0.131, at 0.5 → 0.066; below plausible ERM breakaway ([Unverified] per pad). Much of slider = silence, then it "turns on".
  3. **Range compression on presets.** Floor lift `floor + (1−floor)·x` → slider 0.1→1.5 spans TICK 0.097→0.224 on DS4 (2.3×) vs 0.013→0.197 on Generic (15×); DualSense/SC2 ~5–6×. Same travel, very different felt range per device.
  4. **Context dependence.** Transients ride `cont + trans·(1−cont)`; with castTexture holding High 0.49, THUD's felt step drops 0.594 → 0.303.
  5. **Overall intensity per profile** (`Database.lua:48-50`; built-ins seeded 0.65–0.80, `:69-170`, `:785-790`) → a spec/character rule switching profile silently rescales everything.
  6. **Intermittent collapse** of multi-step cues' later steps — CR-013, the "sometimes break" part.
- Evidence: `intensity-probe.lua` (real `Modes.lua`, `Devices.lua`, `Standard.lua`, `Engine.lua`; master 0.7; 60 fps; cell = peak SetVibration on mode's channel):
  ```
  preset=default    0.10   0.25   0.50   0.75   1.00   1.25   1.50
  TICK/Low         0.013  0.033  0.066  0.098  0.131  0.164  0.197
  CLICK/High       0.020  0.049  0.098  0.148  0.197  0.246  0.295
  THUD/High        0.059  0.148  0.296  0.446  0.594  0.699  0.699
  HEAVY/High       0.070  0.175  0.350  0.525  0.700  0.700  0.700
  preset=ds4
  TICK/Low         0.097  0.111  0.134  0.156  0.179  0.202  0.224
  preset=dualsense
  TICK/Low         0.045  0.069  0.108  0.147  0.185  0.224  0.263
  HEAVY/High       0.101  0.208  0.386  0.565  0.743  0.743  0.743
  preset=steamcontroller2
  TICK/Low         0.050  0.072  0.109  0.146  0.183  0.220  0.257
  HEAVY/High       0.106  0.212  0.390  0.567  0.744  0.744  0.744
  Context (Generic): THUD alone peak=0.594 | with texture: texture level=0.342, peak=0.645, felt step above texture=0.303
  Frame-rate: 35 ms CLICK/High peak 0.197 / 0.197 / 0.198 at 30 / 60 / 144 fps   (goodthink)
  ```
- Related: DOCS §4.1 "Floor linear lift → dead-zone curve | #29 H7 | OPEN" (item 3 = its felt consequence); "Mixer beyond MAX … IMPLEMENTED" (item 4); §6 #1 mixer decision. Items 1, 2, 5 new; the absence of a loudness model was named by review #29 (DOCS §3). See also CR-006, CR-012, CR-014, CR-018, CR-019.
- Fix direction: [Rec] (a) Cap each per-cue slider at its mode's ceiling (Motor & Timing already derives it, `Modes.lua:385-414`) or apply per-cue intensity as a perceptual gain after mode shaping with headroom. (b) Replace linear floor lift with dead-zone curve (#29 H7); Generic ships a measured small floor. (c) Make Overall intensity global, or show profile's value beside the picker. (d) Decide mixer (§6 #1); consider ducking continuous under transients instead of `(1−cont)` compression. (e) Engine table test: per mode, slider monotonic, non-saturating inside its range.

### CR-013 [P1] (known, re-confirmed + widened) Role-table ring pool: later steps of multi-step cues take another cue's role and strength
- **Verdict:** doubleplusungood for multi-step cues under load; the "sometimes break" in QA.
- Where: `PulseHaptics/Core/Engine.lua:200-212`, `:379`, `:405-410`. Since `f447944` (bellyfeel, DOCS §9.3). Uncommitted: no.
- What: [Fact] Every step — synchronous ones included — takes a slot from a 16-table ring; delayed steps capture the table by reference; 16 later allocations wipe and refill it before the timer fires.
- Failure scenario (new, realistic): KNOCK's second hit (High 0.9 × 0.7) with UI-navigation ticks in between → becomes a Low 0.048 tick. Fires whenever ≥16 steps are allocated inside a multi-step cue's span (uiNavigate TICK throttle 0.03 s allows ~33/s).
- Evidence: `pool-probe.lua`:
  ```
  KNOCK alone                                        second KNOCK hit: High peak=0.629 Low peak=0.000
  KNOCK + 16 uiNavigate TICKs (0.35) within 0.25 s   second KNOCK hit: High peak=0.007 Low peak=0.048
  KNOCK + 8 radialTick TICKs + 8 damageTaken TICKs   second KNOCK hit: High peak=0.007 Low peak=0.041
  KNOCK + 3 DOUBLE_TAP cues (6 steps) + 10 TICKs     second KNOCK hit: High peak=0.007 Low peak=0.251
  ```
- Related: DOCS §4.1 "Pooled role tables overwritten … OPEN (bug)" — confirmed. Adds: role swapped too (High→Low); synchronous path also consumes slots.
- Fix direction: [Rec] Capture step roles as per-step upvalues (`local low, high, lt, rt = …`) or a table owned by the closure. Correctness over zero-GC.

### CR-003 [P2] Fishing texture near-imperceptible even when classification works; castTexture suppressed for it
- **Verdict:** ungood. Compounds CR-001.
- Where: `PulseHaptics/Modules/Crafting.lua:87` (`bed = 0.07`, `cadence = 0`), `:454-458`; `PulseHaptics/Modules/Combat.lua:444-446`. Uncommitted: no.
- What: [Fact] Fishing → bed 0.07, no strikes, no bite cue. Delivered = 0.07 × gain 1.0 × bedGain 1.0 × masterIntensity (Default 0.7, `Database.lua:49`) = 0.049 on Low for whole channel, while `Pulse.IsCrafting()` suppresses castTexture's hum (0.1/0.2).
- Failure scenario: fishing, both cues on → 0.049 Low hold, under breakaway on ERM pads with Generic floor 0 → silence reads as "fishing broken".
- Evidence: arithmetic from cited constants; `channel-probe.lua` scenario 2 `craftTexture low=0.070` pre-master.
- Related: CR-001, CR-004, CR-008 item 2.
- Fix direction: [Rec] Give Fishing a signature (line-tension bed ≥ 0.12 plus cast-splash transient). If Forever has no bite signal, say so in caveat. Consider not suppressing castTexture for gathering/fishing when the profession row is quiet.

### CR-006 [P2] Heartbeat ▶ previews ignore the per-cue Intensity slider
- **Verdict:** ungood — slider "does nothing" in preview.
- Where: `PulseHaptics/Core/Init.lua:276-282` (returns bespoke preview before `scale` is read at `:289`); `PulseHaptics/Modules/Health.lua:265-290`. Uncommitted: no.
- What: [Fact] `TestCue("lowHealthWarning"|"lowHealthTexture")` → `TestWarningBeat()`/`TestHeartbeat()` play fixed `LUB_INTENSITY 0.7`/`DUB_INTENSITY 0.2` (`Health.lua:44-45`) or `warningKnockShape()`, no `intensity`. Live path scales by it (`Init.lua:113`, `:130`).
- Failure scenario: Intensity 1.0 → 0.2, press ▶ → identical strength.
- Related: CR-004, CR-008, CR-018.
- Fix direction: [Rec] `health[method](health, scale)`; multiply lub/dub by scale.

### CR-007 [P2] bossAbilityWarning dead on Forever: `C_EncounterEvents.HasEventsForEncounter` / `GetEventsForEncounter` do not exist
- **Verdict:** ungood feature, silent. Answers "broken features?".
- Where: `PulseHaptics/Modules/Encounter.lua:35-62`. Uncommitted: no.
- What: [Fact] Forever `C_EncounterEvents` exposes `GetEventColor`, `GetEventInfo`, `GetEventList`, `GetEventSound`, `HasEventInfo`, `PlayEventSound`, `SetEventColor`, `SetEventSound` only (`FOREVER/Blizzard_APIDocumentationGenerated/EncounterEventsDocumentation.lua`). `EncounterEventInfo` = `encounterEventID, enabled, spellID, iconFileID, severity, icons` — no `timeOffset`, no `severityLevel` (`EncounterEventsSharedDocumentation.lua:32-41`). Guard `type(...) ~= "function"` returns at `:37` every time.
- Failure scenario: cue on (Raiding forces it ON, `Database.lua:177`) → never fires.
- Evidence: scripted C_ API check (§1.1).
- Related: none in DOCS §4 (new).
- Fix direction: [Rec] Rebuild on `C_EncounterTimeline` + `ENCOUNTER_TIMELINE_EVENT_ADDED` / `_STATE_CHANGED` (`FOREVER/Blizzard_APIDocumentationGenerated/EncounterTimelineDocumentation.lua:458-550`) after checking payload secret flags; or hide cue with caveat until rebuilt.

### CR-009 [P2] "Controller-only" UI cues fire on mouse & keyboard: `gamepadUIActive()` fallbacks defeat the primary test
- **Verdict:** crimethink gating.
- Where: `PulseHaptics/Modules/ControllerUI.lua:50-67`; consumers `:113`, `:255`, `:347`. Uncommitted: no.
- What: [Fact] Comment (`:46-49`) says no cue here fires on M+KB. Code: when `InputUtil.IsGamepadUIEnabled()` answers FALSE, it falls through to `C_GamePad.IsEnabled()` (true whenever `GamePadEnable` is 1) and `Engine:IsDeviceReady()`. [Fact] `InputUtil.IsGamepadUIEnabled` exists on Forever (`FOREVER/Blizzard_SharedXML/Mainline/InputUtil.lua:11-13`), so the fallback runs exactly when it must not.
- Failure scenario: pad plugged, player opens Character sheet by mouse → `panelOpen`, `uiTabChanged`, `popupShown` fire (14 of 20 CONTROLLER_UI cues default ON — re-confirmed, §6).
- Related: DOCS §4.5 "Controller UI cues default ON" (decision) — separate gating defect, new.
- Fix direction: [Rec] Use the fallback only when `InputUtil`/`IsGamepadUIEnabled` is absent; when present, trust its answer.

### CR-010 [P2] targetBigDefensive handler compares spellcast event's unit token, which the same file says can be secret
- **Verdict:** crimethink by the file's own rule.
- Where: `PulseHaptics/Modules/AlertUnitWatch.lua:253-256` (`if unit ~= "target"` on `UNIT_SPELLCAST_SUCCEEDED` / `UNIT_AURA`). Uncommitted: no.
- What: [Fact] Header (`:3-6`): "spellcast payload for a non-player unit is secret up to and including arg1's unit token … never a branch on arg1". [Fact] `UNIT_SPELLCAST_SUCCEEDED` carries `SecretWhenUnitSpellCastRestricted = true`; its `unitTarget` lacks `NeverSecret` (`FOREVER/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`, SUCCEEDED block). [Inference] In a restricted context the comparison errors. Frame already `RegisterUnitEvent(…, "target")` → check redundant.
- Failure scenario: cue default ON (`Registry.lua:1450`); enemy target casts in restricted instance → Lua error per cast. [Unverified] live.
- Related: CR-011 (same class). New.
- Fix direction: [Rec] Drop `unit` comparison (frame identity filters), matching `_WatchUnit` (`:38-44`). Optional: `C_Secrets.ShouldUnitSpellCastingBeSecret` (`FOREVER/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua:372`) as pre-check.

### CR-011 [P2] Emote cue compares/pattern-matches chat payload flagged `SecretInChatMessagingLockdown`
- **Verdict:** crimethink secret discipline.
- Where: `PulseHaptics/Modules/World.lua:50-61`. Uncommitted: no.
- What: [Fact] `CHAT_MSG_TEXT_EMOTE` carries `SecretInChatMessagingLockdown = true` (`FOREVER/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua`). Handler runs `Ambiguate(sender)`, `senderName == playerName`, `message:find(pattern)` unguarded. [Inference] errors during chat lockdown (encounters). Pattern built from `playerName` unescaped (known M-03).
- Failure scenario: emote cue on (`Immersion: Melee` forces it ON, `Database.lua:466`) → error per emote in lockdown.
- Related: DOCS §4.4 "Emote frontier pattern and UTF-8 names | #14 M-03 | OPEN" (pattern part known; secret part new).
- Fix direction: [Rec] `if issecretvalue(message) or issecretvalue(sender) then return end` first; escape `playerName` with `:gsub("%p", "%%%0")`.

### CR-012 [P2] Transient "knocks" built on `Hold` get continuous (slow) attack — breath gasps, heartbeats reach ~half strength on Generic
- **Verdict:** ungood; device-dependent feel (feeds CR-008).
- Where: `PulseHaptics/Core/Engine.lua:214-218` (`Set` passes `isTransient` only if given), `:255-260` (`Hold` hard-codes `false`), `:449-453`; callers `Modules/Health.lua:116-118`, `:146-148`, `:270-287`; `Modules/Environment.lua:84`, `:95`, `:152-155`; `Modules/Locomotion.lua:522`, `:535`. Uncommitted: no.
- What: [Fact] 50 ms knocks use `attackTau` 0.075 s (Generic) instead of `transientAttackTau` 0.012 s. 1 − e^(−0.05/0.075) ≈ 0.49 → a 0.7 lub peaks near 0.34 × master. No `HoldIfEnabled` path can mark a hold transient.
- Failure scenario: Generic/ERM users feel heartbeats and gasps as soft swells; LRA presets (attack 0.012–0.020) feel them sharp. Same slider, different result per device.
- Evidence: arithmetic from `Devices.lua:78-80`, `Health.lua:43-45`; footfall analogue measured in CR-005.
- Added in §14 (post-implementation review 09-24, item 2): the reverse case. One transient layer switches its **whole physical channel** to `transientAttackTau` (`Engine.lua:449-450`, `:608-610`), so a continuous baseline rising under an impact snaps up too. The lanes are split per channel, not per signal.
- Related: CR-005, CR-008. Extends review #29 (DOCS §3: "one smoothing filter for everything softens transients"): `ea0368a` added the transient lane for `PlayMode` only → DOCS §4.1 "Separate transient/continuous attack | FIXED" should read **PARTIAL** (A7).
- Fix direction: [Rec] `isTransient` parameter on `Engine:Hold`/`HoldRoles` and `Pulse:HoldIfEnabled`/`HoldRolesIfEnabled` (or a `Pulse:KnockIfEnabled`); use it for knocks, strikes, footfalls.

### CR-014 [P2] craftTexture Intensity scales bed but not strikes; strikes bypass master/cue gates and preview
- **Verdict:** ungood slider coherence.
- Where: `PulseHaptics/Modules/Crafting.lua:408-420` (`Pulse.Engine:PlayMode(STRIKE_LAYER, work.mode, strength)`), bed `:454-458`. Uncommitted: no.
- What: [Fact] Strikes call engine directly with `work.strike × gain × strikeGain`; cue's generic `intensity` (`Spec.lua:199-218`) and `masterEnabled`/cue checks skipped (comment `:416-418` relies on tick guard). Bed goes through `HoldRolesIfEnabled` → scaled.
- Failure scenario: "Crafting texture → Intensity" 0.2 → hum quieter, hammer blows unchanged.
- Related: CR-008. New.
- Fix direction: [Rec] Multiply strike strength by `GetTriggerSetting(CUE, "intensity", 1)` or route through `FireIfEnabled` with `intensityOverride`.

### CR-015 [P2] PulseChecklist import assigns wrong statuses: section keywords matched inside comment text of every line
- **Verdict:** ungood; corrupts QA records the next phase depends on.
- Where: `PulseChecklist/Checklist.lua:756-772` (status keywords scanned on every non-empty line, before item parsing `:775-827`). Uncommitted: no.
- What: [Fact] "needs work", "non-functioning", "failed", "functioning", "untested" (and emoji) switch `currentStatus` wherever they appear, including a bullet's comment. Header context then leaks to following items. `compactStatus == "work"` branch (`:802`) unreachable (not in accepted list `:790-799`).
- Failure scenario / Evidence: `import-probe.lua` (real `Checklist.lua` under `checklist-test.lua` stubs):
  ```
  #### ⚠️ Needs Work (3)
  - `damageTaken`: failed twice in raid, fine solo
  - `deflect`: too weak
  - `critLanded`: functioning but mushy on DualSense
  ->
  damageTaken  imported as nonfunctioning   (listed under Needs Work)
  deflect      imported as nonfunctioning   (listed under Needs Work)
  critLanded   imported as functioning   (listed under Needs Work)
  ```
- Related: DOCS §4.6 "PulseChecklist … never code-reviewed" → now reviewed. New.
- Fix direction: [Rec] Detect section status only on `^#+` header lines; parse bullet comment verbatim. Add checklist-test case above.

### CR-016 [P2] PulseDebug hooks log every frame of every continuous cue — log and sticky HUD flooded, allocation per frame even with window closed
- **Verdict:** ungood debug tool exactly where the next phase needs it (channel/footfall diagnosis).
- Where: `PulseDebug/UI.lua:355-371` (HOLD hooks), `:303-322` (`recordEvent`: new table + `string.format` + `table.insert(eventLog, 1, …)`), `:786-788` (hooks installed at load whenever Pulse present). Uncommitted: no.
- What: [Fact] `HoldIfEnabled`/`HoldRolesIfEnabled` run every frame per active continuous cue; each call records a HOLD entry. `MAX_LOG_ENTRIES` 50 (`:277`) and sticky HUD 3 (`:315-318`) → with one texture at 60 fps the log holds <1 s and discrete FIREs vanish from HUD within a frame. Hook cost paid by every player with PulseDebug enabled, window open or not.
- Failure scenario: debugging fishing with castTexture/craftTexture on → FIRE/MODE rows for selfCastInstant etc. scroll away instantly.
- Related: DOCS §4.6 "PulseDebug sticky HUD … FIXED (reported)" — HUD exists but defeated under load. New.
- Fix direction: [Rec] Record HOLD rising edges only (Init's `HOLD_LOG_GAP` pattern, `Init.lua:47-50`, `:114-129`); install hooks on first window open; ring buffer instead of `table.insert(…, 1, …)`.

### CR-017 [P2] Tests that cannot fail, or assert weaker than their names
- **Verdict:** crimethink test hygiene; hides CR-001, CR-013 class bugs.
- Where / What ([Fact] each):
  - `PulseChecklist/tests/harness.lua:1313` `check("Decayed channel below silence gate safely zeroed…", true, true)` — vacuous.
  - `harness.lua:1191-1206` "Valid big defensive should fire" — fires handler, never asserts `firedCount`.
  - `harness.lua:1180-1189` malformed `updateInfo` wrapped in `pcall`, no assertion.
  - `harness.lua:863-871` "master on" liveness printed, never asserted.
  - `harness.lua:1211-1219` takes FIRST frame with an OnUpdate as "engine" — fragile identity.
  - `pulsedebug-test.lua:541-547` "ticks safely under repeat render" — Live never switched on, so `UI.lua:759-761` returns at once; nothing rendered.
  - `pulsedebug-test.lua:511-516` "Stop All button calls CancelAll" — fake `StopAll` sets the same flag (`:324-326`), cannot distinguish (known fake divergence).
  - `cue-audit.lua:150-166` WatchCategory warnings and "direct module reference" counts never fail.
  - `crafting-test.lua:323-336` fishing omits SUCCEEDED (CR-001). `engine-test.lua` asserts no magnitudes anywhere (CR-008, CR-013 invisible). `locomotion-test.lua` covers ground contact only (CR-005 invisible).
- Related: DOCS §4.2/§10.2 hearthstone key (known, re-confirmed §6); §4.6 fake `HoldLayer`/`CancelAll` (known).
- Fix direction: [Rec] Replace each with a real assertion (list in §7); forbid literal-constant `check` via a lint grep in `test.sh`.

### CR-019 [P2] DualSense / Steam Controller 2 path rests on unmeasured presets, likely mis-detection under Steam Input, and contradictory trigger claims
- **Verdict:** bellyfeel constants shipped as facts; feeds CR-005 and CR-008 on exactly the two pads the user named.
- Where: `PulseHaptics/Core/Devices.lua:160-188` (preset classes; comment itself says "STARTING POINTS … not measurements"), `:235-244` (dualsense), `:305-314` (steamcontroller2), `:348`, `:411-413`, `:422` (Valve detection); `PulseChecklist/tests/engine-test.lua:282-284`, `:347-349` (tests assert table entries, not reality); claims `PulseHaptics/Core/Guide.lua:69-79`, `PulseHaptics/Core/Registry.lua:2647`. Uncommitted: no.
- What:
  - [Fact] Steam Controller 2 PIDs `0x1201`/`0x1202` carry no source; tests only mirror the table. [Unverified].
  - [Fact] `"steam virtual gamepad"` name, PID `0x11FF`, and unknown Valve PIDs all map to `steamdeck`. [Inference] SC2 under Steam Input is likely seen as a virtual gamepad (→ Steam Deck preset) or as an emulated Xbox pad (`0x045E` → `xbox` ERM preset: floors 0.12/0.10, attack 90/50 ms, `triggers = true`). The xbox path would enable split footfalls, which under Standard fall back to Low/High — the "limp" `Locomotion.lua:365-370` warns about.
  - [Fact] `dualsense.triggers = false` with note "SDL gamepad layer does not drive them" (`Devices.lua:238-239`), yet Guide says DualSense has trigger actuators served by "Rumble + Triggers" (`Guide.lua:69-79`) and splitFeet desc says "of the listed hardware only Xbox and DualSense do" (`Registry.lua:2647`).
  - [Fact] Detection only suggests; values apply only on Apply (`Spec.lua:1566-1590`). An unapplied user stays on Generic (floor 0, attack 75 ms) — the worst row in CR-008 for quiet cues.
- Failure scenario: SC2 user presses Detect → "Steam Deck" or "Xbox" suggestion → applies wrong actuator class → floors/attacks mismatch → sliders and footsteps feel wrong in ways no slider can fix.
- Related: DOCS §4.8 "Trigger-hardware claims too strong … OPEN" (claims part known; SC2/Steam Input part new); review #29 "device defaults are hypotheses" (DOCS §3).
- Added in §14: `NAME_PATTERNS` tests `"xbox"`/`"xinput"` before `"8bitdo"` (`Devices.lua:356-361`). Low impact, because vendor+product matching runs first (`:461-466`).
- Fix direction: [Rec] (1) `/pdebug state` prints `DetectDevice()` raw name/VID/PID; collect from real DualSense and SC2 (with and without Steam Input). (2) Ramp each channel on both pads; replace preset numbers with measurements (tracked file). (3) Add preset fields `actuator = "lra"|"erm"`, `symmetric = true|false`; drive split-feet and footfall channel from them, not from `triggers`. (4) Reconcile Guide/Registry trigger text with `Devices.lua`.

### CR-026 [P2] weatherTexture near-inaudible and untunable
- **Verdict:** ungood feature (answers "broken features?").
- Where: `PulseHaptics/Modules/Environment.lua:236-269` (amplitudes: rain `0.04·intensity` 8 Hz depth 0.4 on High; snow 0.02; sandstorm 0.06/0.042; misc 0.03); `PulseHaptics/Core/Registry.lua:905-913` (`devTuning = true`, NO `tunables`); `PulseHaptics/UI/Panel/Spec.lua:1760` (Continuous textures page requires `tunables` → weather absent). Uncommitted: no.
- What: [Fact] Max reachable = 0.04 × 1.4 × per-cue 1.5 × master 0.7 ≈ 0.059 peak for heavy rain; snow ≈ 0.025. 8 Hz modulation passes through 75 ms attack/28 ms release smoothing (Generic) → mostly flattened. [Fact] `C_Weather` shape verified: `WeatherInfo {type, intensity}`, enum Clear 0 … Miscellaneous 4 (`FOREVER/Blizzard_APIDocumentationGenerated/WeatherScriptDocumentation.lua`, `WeatherConstantsDocumentation.lua:13-17`) — goodthink.
- Failure scenario: storm in Elwynn with texture on → nothing felt on Generic preset.
- Related: none (new). §6 notes ocean/water are also sub-0.15 by design.
- Fix direction: [Rec] Add tunables (per-type level, patter rate); raise defaults to perceptible after hardware Ramp; use transient patter (short Low/High blips) instead of an 8 Hz sine the smoother erases.

### CR-018 [P3] Picking a mode in any dropdown auto-plays it at full scale — "Feels like" preview ignores the cue's own Intensity
- **Verdict:** ungood preview fidelity (minor).
- Where: `PulseHaptics/UI/Panel/Popup.lua:247-250`; affected rows `Spec.lua:221-242` ("Feels like"), `:521-532` ("Mode to test", intended). Uncommitted: no.
- What: [Fact] Entry OnClick runs `Pulse:TestMode(value)` whenever `value` names a mode → `PlayMode("preview", modeID, 1.0)`. For a cue whose Intensity is 0.3 (`damageTaken`, `Registry.lua:584`), the pick previews 3.3× stronger than the cue will ever play.
- Related: CR-006, CR-008.
- Fix direction: [Rec] "Feels like" rows preview through `TestCue` semantics (cue's intensity) after `set`; keep raw TestMode only for "Mode to test".

### CR-020 [P3] Split-footfall routing follows the preset dropdown label, even unapplied
- Where: `PulseHaptics/Modules/Locomotion.lua:377`; `PulseHaptics/UI/Panel/Spec.lua:1545-1547` (dropdown `set` = `SetDevicePreset`, label only); values written only by Apply (`Database.lua:1754-1776`). Uncommitted: no.
- What: [Fact] Selecting "Xbox" without Apply flips `shouldSplitFeet()` to true while calibration stays Generic.
- **Verdict:** crimethink state split.
- Fix direction: [Rec] Store an "applied preset" id at Apply and read that; or read actuator fields (CR-019).

### CR-021 [P3] Rename/Delete leave `lastResolved` stale → second full module re-sync at next combat end (rename part uncommitted)
- Where: `PulseHaptics/Core/Database.lua:1253-1270` (`RefreshActiveProfile` compares `lastResolved`), `:1449-1453` (uncommitted rename notify), `:1489-1531` (delete); trigger `:687-711` (runs on every `PLAYER_REGEN_ENABLED`).
- What: [Fact] `SetProfileForScope`/`ClearProfileForScope` update `lastResolved` (`:1292`, `:1313`); Rename/Delete do not. Next `PLAYER_REGEN_ENABLED` sees a changed name and calls `notifyProfileSwitch()` again — every module re-syncs once more.
- **Verdict:** plusgood behaviour, ungood bookkeeping. Violates DOCS §10.4 "notifies listeners once" in spirit; harness asserts only `notifies > 0` (`harness.lua:1052`).
- Fix direction: [Rec] Set `lastResolved = self:GetActiveProfileName()` after invalidation in both; harness asserts exactly one notify across a combat toggle.

### CR-022 [P3] Malformed SavedVariables kill the whole addon at load
- Where: `PulseHaptics/Core/Database.lua:765-772`, `:774-792`, `:879-900`; bootstrap `PulseHaptics/Core/Init.lua:366-391`.
- What: [Fact] No type checks: non-table `PulseDB` → assignment to `DB.version` errors; string `DB.version` → `<` compare errors; non-table `DB.profiles` → index error. Init aborts before `Engine:Init` and every `OnEnable` → silent dead addon.
- **Verdict:** ungood robustness; needs hand-edited/corrupt SV, hence P3.
- Related: DOCS §4.3 "Malformed SavedVariables crash Init | NOT CHECKED" (reported by RC review #18) → **now checked: OPEN**.
- Fix direction: [Rec] Validate `PulseDB`, `version`, `profiles`, `charProfile`, `specProfile`, `customProfiles` types; quarantine bad subtables (`DB.__corrupt = old`), then re-seed.

### CR-023 [P3] Pulse dialog keyboard handling uses restricted API — keypress in combat may be blocked
- Where: `PulseHaptics/UI/Panel/Popup.lua:607-617`.
- What: [Fact] `EnableKeyboard` is `IsProtectedFunction = true` and `SetPropagateKeyboardInput` is `HasRestrictions = true` in `FOREVER/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:247-249`, `:1424-1427`. [Inference] With a Pulse confirm/prompt open in combat (panel is usable in combat), a keypress calls `SetPropagateKeyboardInput` → possible ADDON_ACTION_BLOCKED. [Unverified].
- **Verdict:** plusgood out of combat; unverified in combat.
- Fix direction: [Rec] Skip the propagation toggle under `InCombatLockdown()`, or close dialogs on `PLAYER_REGEN_DISABLED`.

### CR-024 [P3] Dead event names and small PulseDebug gaps
- Where / What ([Fact]):
  - `Registry.lua:1737` lists `"PING_PIN_ADDED"` — absent on Forever (§1.1). Generic watcher pcall-guards registration (`Init.lua:338-340`), but `/pdebug watch pingPinAdded` registers unguarded (`PulseDebug/Debug.lua:456-462`) → "Attempt to register unknown event" error (same message class as `docs/dev-notes/Luaerrorissues.rtf` lines 4, 65, 124).
  - `Locomotion.lua:557` handles `LEARNED_SPELL_IN_TAB`, absent on Forever and not in `EVENTS` (`:596-606`) → dead branch.
  - `PulseDebugUIFrame` (`PulseDebug/UI.lua:59`) and `PulseChecklistFrame` (`Checklist.lua:228`) are not in `UISpecialFrames` → Escape does not close them (Pulse's own window is, `Panel.lua:407`).
- **Verdict:** ungood nits.
- Fix direction: [Rec] Unperson `PING_PIN_ADDED` and the dead branch; pcall/`C_EventUtils.IsEventValid` in `/pdebug watch`; `tinsert(UISpecialFrames, …)` for both tools.

### CR-025 [P3] Stale or contradictory texts (tooltips, comments, guide)
- **Verdict:** crimethink drift; each misleads a tester.
- [Fact] each:
  - Ramp tooltip "slowly from silence to half power over eight seconds" (`Spec.lua:1657-1662`) vs 0.40 peak, 0.01 step, 0.4 s/step = 16 s (`Devices.lua:149-151`; engine prints real figures `Engine.lua:714-721`).
  - "Show per-cue detail controls … Off by default" (`Spec.lua:453-456`) vs `showAdvancedCueControls = true` (`Database.lua:36`).
  - PulseDebug tooltips "40ms THUD", "12ms TICK" (`PulseDebug/UI.lua:710`, `:725`) vs 0.16 s and 0.05 s (`Modes.lua:93`, `:107`).
  - Guide "press **Play it**" (`Guide.lua:42`) vs button "Play" (`Spec.lua:537`).
  - Guide + Registry DualSense trigger claims vs `Devices.lua:238-239` (CR-019).
  - `ControllerUI.lua:18-22` "Zero callbacks, zero hooks inside Blizzard managers" vs `SmartNavigation.RegisterCallback` (`:134`) and `hooksecurefunc` on `GamepadRadial`/`TabSystemMixin` (`:205`, `:231`, `:269-283`).
  - `Sidebar.lua:12-17` "about seventeen rows" vs 21 pages (`Spec.lua:1813-1861`); `Checklist.lua:11` "~103 rows", `:186` "110 cues" vs 190.
  - Known ones re-confirmed in §6: `Registry.lua:8` "21 … shapes", `Registry.lua:2225-2229` "All shipped OFF".
  - Added in §14: `Engine.lua:5` header "named layers, max-blend" and the `:417-421` comment ("via max, same as two layers colliding") vs the saturating sum for layers (`:562-564`); only role→channel collisions are max (`:605-607`).
- Fix direction: [Rec] One text sweep; add a harness check comparing Ramp tooltip numbers to `Pulse.RAMP_*`.

### CR-027 [P3] Test runner blind spots beyond the known `set -e` defect
- Where: `scripts/test.sh:122` (runs `lua`, i.e. 5.5, not `luajit`); `.luacheckrc:199-201` (tests excluded from lint); `.luacheckrc:13` (ignores `431` shadowing upvalue); `scripts/test.sh:125` (`echo … | grep -q` under `pipefail`).
- What: [Fact] WoW is Lua 5.1 semantics; default run uses 5.5 — LuaJIT parity is manual (handoff §3). [Fact] Test files never linted. [Inference] `grep -q` exits early; with `pipefail` an `echo` SIGPIPE on >64 KB output would turn a FAIL into PASS (latent; current outputs small).
- **Verdict:** ungood tooling margins.
- Related: DOCS §4.6 test.sh row (known `set -e` part).
- Fix direction: [Rec] `LUA=${LUA:-luajit}`; lint tests with a relaxed profile; `grep -q … <<<"$TEST_OUT"` instead of a pipe.

### CR-028 [P3] Minor inconsistencies
- [Fact] Minimap right-click refuses master toggle in combat (`Minimap.lua:91-102`) while the panel checkbox (`Spec.lua:382-393`) and `/pulse stop` act in combat.
- [Fact] `Interaction.lua:168-171` MERCHANT_SHOW reads `GetMoney()` unguarded while sibling branches guard (`:121-127`, `:182-196`).
- [Inference] Checklist export EditBox fixed 470×260 (`Checklist.lua:627-635`) — long reports likely unscrollable (copy still works); PulseProfileReview sizes its box to text (`Review.lua:301`) — goodthink there.
- [Fact] Panel status badge says "Gamepad Active" from CVar/`IsEnabled` alone, even with no pad connected (`Panel.lua:252-289`).
- **Verdict:** ungood nits.

---

## 4. User QA reports — root-cause analysis

| # | User report | Verdict | Root causes (this review) | Confidence |
|---|---|---|---|---|
| Q1 | "Channeling, including fishing, is broken" | plusungood, explained | **CR-001** (SUCCEEDED-at-channel-start misread as completion/instant), **CR-002** (unrelated events stop hum), **CR-003** (fishing bed 0.049, hum suppressed) | Code path [Fact] via probe; event order [Inference, high]; live [Unverified] — `/etrace` settles which of two failure modes (§8 V1) |
| Q2 | "Casting, craft casts working now" | plusgood, consistent | Cast path START → SUCCEEDED matches `pending` key (`CastActivity.lua:166-177`); craft fix `580e69f` (bellyfeel, DOCS §9). Latent: CR-002 on spam-press; known craft fallback risk (DOCS §4.2) | [Fact] code; [Unverified] spam case |
| Q3 | "Intensity sliders very inconsistent, feel broken esp. DualSense / Steam Controller 2. Do all work? Sometimes break?" | plusungood, explained | **All sliders store/read correctly** ([Fact]: harness round-trips every row, 0 failures). What they DO is incoherent: **CR-008** (dead top, dead bottom, preset compression, context, per-profile master), **CR-013** (intermittent collapse = "sometimes break"), **CR-012** (device-dependent knock sharpness), **CR-006/CR-014/CR-018** (previews ignore slider), **CR-019** (DualSense/SC2 presets unmeasured; SC2 likely mis-detected under Steam Input), CR-026 (weather slider can never reach perception) | [Fact] probes; pad response [Unverified] |
| Q3b | (if "broken" means operating sliders WITH the pad) | by design, DECIDED | Settings window is mouse-only: `DRIVE_BLIZZARD_NAVIGATION = false` (`UI/Panel/Gamepad.lua:69`), DOCS §4.7 DECIDED. Controller cannot step sliders until Pulse owns input (`Gamepad.lua:61-66`) | [Fact] |
| Q4 | "Footsteps could be more crispy, distinct, esp. Steam Controller / DualSense" | plusungood, explained | **CR-005** (2×/4× rate, continuous smoothing, Low channel on LRA pads), CR-012 (same mechanism), CR-019 (split-feet driven by wrong field), `mountedOnly` default ON | [Fact] probe; feel [Unverified] |
| Q5 | "Replay on many continuous textures seems broken, only intensive rumble" | plusungood, explained | **CR-004** (flat 0.45 both motors, 3.5 s), CR-006 (heartbeat previews ignore intensity) | [Fact] |
| Q6 | "Broken features?" | list | Dead: bossAbilityWarning (CR-007). Imperceptible: weatherTexture (CR-026), fishing bed (CR-003). Broken logic: channel texture (CR-001/002), Checklist import (CR-015), Controller UI M+KB gating (CR-009). Known, still broken: PulseDebug "Hold 2s" (DOCS §4.6), checklist baseline orphans 30/59 (§6), SmartNavigation edge cue self-described forbidden (§6). Dead event: `PING_PIN_ADDED` (harmless, CR-024) | [Fact] |

Extra, outside the addon: [Unverified] client CVar `GamePadVibrationStrength` (read by `/pdebug state`, `PulseDebug/Debug.lua:99`) may scale all output — one more intensity layer the addon neither sets nor explains. No Blizzard Lua in FOREVER references it (grep, this session).

---

## 5. Cross-cutting themes

- **T1 Model-shaped tests.** Tests encode the author's event model, not the client's: fishing without SUCCEEDED (CR-001), no magnitude assertions (CR-008, CR-013), vacuous checks (CR-017). Crimethink pattern; recurs across four suites.
- **T2 Preview ≠ product.** Four preview paths diverge from live behaviour: flat continuous hold (CR-004), heartbeat without intensity (CR-006), strikes without intensity (CR-014), mode picker at 1.0 (CR-018). Users tune by preview, so every tuning session is ungood-informed.
- **T3 Continuous vs transient conflated.** `isTransient` reachable only via `PlayMode`/`Set(..., true)`; knocks, gasps, footfalls ride `Hold` → soft onsets (CR-005, CR-012).
- **T4 Unmodelled gain chain.** relIntensity × cue intensity × mode mult × masterIntensity × schema intensity × channel gain → gamma → floor lift, with `clamp01` at three points (`Engine.lua:378`, `:382-389`, `:602`, `:430`). No perceptual model, no headroom rule (CR-008).
- **T5 Secret-value discipline uneven.** File headers state rules the handlers break (CR-010, CR-011); known `keyFor` and sweep truthiness unguarded. Forever offers `C_Secrets.ShouldUnitSpellCastingBeSecret` — unused.
- **T6 Bellyfeel constants as facts.** Device PIDs and presets (CR-019), trigger claims (CR-025), checklist "pre-verified" baseline incl. `fishStart … verified` (§6), gather spell-ID tables (`Crafting.lua:178-210`, unverified on Forever).
- **T7 Comment/text drift.** CR-025 plus known §4.8 items.
- **T8 Zero-GC above correctness.** Role pool (CR-013) is the sharp case; PulseDebug per-frame logging (CR-016) is the opposite failure (allocation where unneeded).

---

## 6. Known issues re-confirmed or corrected (handoff §5 / DOCS §4)

| Known issue | Status now | Evidence / delta |
|---|---|---|
| Pooled role tables overwritten (DOCS §4.1) | **re-confirmed, widened** | CR-013: role swap High→Low; sync steps consume slots |
| Hearthstone test wrong key; last assertion vacuous (§4.2, §10.2) | re-confirmed | baseline `FAILURES: 3`; `crafting-test.lua:368-385` looks up `"player:guid-hearth-1"`, `keyFor` builds `"g:…"` (`CastActivity.lua:65-70`) |
| Uncommitted engine: onset comment ≠ code, dead spacing guard, MIN_GAP rhythm change | re-confirmed | `Engine.lua:367-396`, `:472-480`; comment `:479` "Transients and new onsets" vs `forceSend = isOnset` `:475` |
| Uncommitted sweep: magic 60 ×3, one player-wide flag, silent clears, no secret guard | re-confirmed | `CastActivity.lua:331-359`; option: `C_Secrets.ShouldUnitSpellCastingBeSecret` exists (`FOREVER/…/SecretPredicateAPIDocumentation.lua:372`) |
| `test.sh` exits silently on crash / luacheck warning | re-confirmed | `scripts/test.sh:2`, `:82-83`, `:122-123`; note FAIL detection relies on output lines starting `FAIL` (`:125`) — "FAILURES:" satisfies it. New margins: CR-027 |
| Saturating-sum mixer default, no MAX switch | re-confirmed | `Engine.lua:537-588`; CR-008 item 4 quantifies cost (THUD contrast halved) |
| PulseDebug "Hold 2s" does nothing; fake defines `HoldLayer`/`CancelAll` | re-confirmed | `PulseDebug/UI.lua:731-739`, `:689`; fake `pulsedebug-test.lua:321`, `:343` |
| 30/59 checklist baseline IDs never existed | re-confirmed | script this session: `baseline 59, orphans 30: jumpAscend jumpLand mountSummon mountDismount mineStart herbStart skinStart fishStart combatExit targetDeath killExperience autoAttackSwing selfCastSuccess selfCastInterrupt lowHealthHeartbeat deathScreen afkStart afkClear restedStart restedExit bagOpen bagClose itemPickup itemDrop merchantOpen merchantClose bankOpen questAccept lootWindowOpen lootWindowClosed`. Note `fishStart` claims "Fishing channel bobber rumble verified" — contradicts Q1 |
| SmartNavigation edge callback reachable though called forbidden | re-confirmed | `ControllerUI.lua:119-142`, register `:134` |
| Craft-matching fallback may end/complete on unrelated cast | re-confirmed, widened | `CastActivity.lua:128-140`, `:190-192`, `:222-224`; same "any cast" fallback also in `_OnStop` `:250-262` |
| `keyFor` unguarded GUID key | re-confirmed | `CastActivity.lua:65-70` |
| `_G.issecretvalue` global stub | re-confirmed | `Init.lua:12-16` |
| Raw-hold `SetVibration` bare | re-confirmed | `Engine.lua:518`, `:529` |
| Missing Raiding/Questing metadata; downward version stamp; legacy `GetSpellInfo` | re-confirmed, widened | 10 metadata entries `Database.lua:69-170`; **consequence new:** Raiding and Questing never appear on the Default profiles page (`Spec.lua:1057-1058` iterates metadata only). Stamp `Database.lua:899`. `Crafting.lua:266-271` |
| Breath "dub" untokened; ocean English substrings; `clamp01` ×6 | re-confirmed, widened | `Environment.lua:153-155`; **same untokened pattern** `Health.lua:117-119`, `:147-149`. Ocean list `Movement.lua:56-80` includes "port", "sound", "deep", "channel", "bay", "cape", "tide" (false-positive magnets). `clamp01` in Engine, Waves, Combat, Movement, Flight, Crafting = 6 |
| 14 of 20 Controller UI cues default ON; minimap border `TOPLEFT` | re-confirmed | awk count this session: `14 default = true`, `6 default = false`; `Registry.lua:2225-2229` still says "All shipped OFF"; `Minimap.lua:161-165` |
| PulseProfileReview frames per refresh; reads write SV | re-confirmed | `Review.lua:166-225` (rows + font strings recreated, old regions only hidden `:169`), `:27-35`, `:138-147`; lint 4 warnings |
| Public docs 202 cues / 36 modes | re-confirmed | `README.md` "202 distinct triggers and 21 categories"; Registry `id =` lines 202 = 190 cues + 12 page ids |

**Proposed DOCS_COMPILATION §4 status changes:**
- §4.4 "Gait cadence units | OPEN / UNVERIFIED" → **OPEN (bug confirmed, CR-005)**.
- §4.3 "Malformed SavedVariables crash Init | NOT CHECKED" → **OPEN (CR-022)**.
- §4.5 "`hookRadial` guard; tab-mixin hook timing | NOT CHECKED" → **CHECKED, no new defect**: `radialHooked` flag (`ControllerUI.lua:168`, `:192-203`) makes repeated `installHooks` (`:546-553`, every ADDON_LOADED/PEW) idempotent; tab hooks reach only mixin frames created later — already disclosed in `Registry.lua:2315`.
- §4.6 "PulseChecklist and PulseDebug never code-reviewed | OPEN" → **REVIEWED** (CR-015, CR-016, CR-017, CR-024).
- §4.2 add rows CR-001, CR-002, CR-003; §4.4 add CR-007, CR-009–CR-012, CR-026; §4.1 add CR-008, CR-012.

---

## 7. Test-coverage gaps (tests that should exist)

1. **cast-test.lua (new):** realistic sequences through real CastActivity + Combat + Crafting + Casting — instant; cast; cast + spam FAILED (other GUID); channel with SUCCEEDED at start (same GUID / different GUID / nil GUID); channel + unrelated INSTANT; fishing; gathering; bench craft; craft + unrelated cast (known fallback). Assert textures stay live and classifications are right. (CR-001, CR-002)
2. **engine-test additions:** pool aliasing (KNOCK + 16 steps keeps High 0.9·scale); per-mode slider table monotonic and unsaturated below ceiling; Hold with transient flag reaches ≥90 % in 50 ms; uncommitted MIN_GAP/onset behaviour at `durMult = 1` unchanged. (CR-008, CR-012, CR-013)
3. **preview-test (new):** every continuous cue's ▶ output varies over time and uses the cue's real roles; heartbeat/craft previews scale with intensity. (CR-004, CR-006, CR-014)
4. **locomotion-test additions:** footfalls/s equals configured steps/s on foot and mounted; split routing chosen from actuator fields. (CR-005, CR-020)
5. **api-manifest check in `test.sh`:** scripted diff of registered events and `C_*` calls against FOREVER docs (method §1.1) — fails on new unknowns. (CR-007, CR-024)
6. **secret-path tests:** harness `issecretvalue` sentinel returns true for payloads of events flagged `SecretWhen*` / `SecretInChatMessagingLockdown`; handlers must not error. (CR-010, CR-011)
7. **checklist-test additions:** comments containing status keywords; baseline IDs ⊆ Registry. (CR-015, known orphans)
8. **pulsedebug-test fixes:** Live actually on; fake API = real API (no `HoldLayer`/`CancelAll`). (CR-017, known)
9. **harness fixes:** replace vacuous checks (CR-017); rename notifies exactly once across a combat toggle (CR-021); malformed SV load (CR-022); load all modules (known).

---

## 8. [Unverified] items needing client or hardware (feed DOCS §7)

- **V1** Channel event order and GUID equality on Forever: `/etrace`, filter `UNIT_SPELLCAST_*`, cast Fishing and one other channel; record order and castGUIDs. Decides CR-001 variant.
- **V2** Does `UNIT_SPELLCAST_FAILED` fire for a spell pressed mid-cast? (CR-002)
- **V3** Is `unitTarget` of target spellcast events secret-wrapped in instances? Is `CHAT_MSG_TEXT_EMOTE` secret during encounters? (CR-010, CR-011)
- **V4** DualSense and Steam Controller 2 on this Mac: `DetectDevice()` name/VID/PID with and without Steam Input; Ramp breakaway per channel; do Low/High map to left/right actuators; firmware smoothing of pulses <50 ms. (CR-005, CR-008, CR-019)
- **V5** `GamePadVibrationStrength` CVar effect on output. (§4)
- **V6** Perceived footfalls after rework at walk/run/mount. (CR-005)
- **V7** Fishing: channel length on Forever; any bite signal (event, sound kit, bobber state). (CR-003)
- **V8** `SetPropagateKeyboardInput` in combat with Pulse dialog open. (CR-023)
- **V9** `C_EncounterTimeline` payload secrecy for boss timers. (CR-007)
- **V10** Weather intensity range seen live; texture perceptible after retune. (CR-026)
- **V11** Lifetime of one `C_GamePad.SetVibration(ch, v)` with no follow-up call, and any client minimum pulse length (A2: DBM never stops its full-power call). Bounds how crisp 35–60 ms transients can be (CR-005, CR-012).
- **V12** Which preset was applied, and whether WoW was started through Steam (Steam Input on), during each DualSense / Steam Controller 2 test. The saved file says Xbox at 2026-09-28 22:41 (§12.2); the crash log says Steam launched WoW on 2026-09-27 (§13.2). Decides how much of Q2/Q3 is settings rather than code.
- Plus DOCS §7 existing list (taint log — now read, §13.2; triggers actuation, watchdog vs MicroFlutter, drowning, cooldownReady, questDetail, minimap).

---

## 9. Implementation plan

Order = dependency order, user-QA weight first after a green floor. Size: S (<½ day), M (½–2 days), L (>2 days). Every step ships with its test (§7). All items [Rec].

### Phase 0 — Green floor and eyes (S–M, blocks everything)
| Step | Work | Files | Done when |
|---|---|---|---|
| 0.1 | Settle uncommitted work: fix Hearthstone key to `"g:guid-hearth-1"`, real 60 s ceiling assertion, name the 60 constant, align onset comment, decide `MIN_GAP_DURATION`; commit separately or drop | `CastActivity.lua`, `Engine.lua`, `crafting-test.lua` | `./scripts/test.sh` exit 0 |
| 0.2 | Runner: `|| status=$?` capture, `LUA=${LUA:-luajit}`, here-string grep, lint tests (relaxed), API-manifest check | `scripts/test.sh`, `.luacheckrc` | crashing suite prints and FAILs |
| 0.3 | Kill vacuous tests (CR-017); PulseDebug fake parity | tests | each check can fail |
| 0.4 | PulseDebug: HOLD rising-edge logging, lazy hooks (CR-016); add "Cast trace" view (classification, spellID, GUID present, order) | `PulseDebug/UI.lua`, `Debug.lua` | log shows FIREs under a live texture |
| 0.5 | In-game capture V1, V2, V4 (device ids), V5 using 0.4 | — | results in a tracked file |

### Phase 1 — Channels and fishing (Q1) (M)
| Step | Work | Done when |
|---|---|---|
| 1.1 | CastActivity channel state machine: START → SUCCEEDED(confirm) → STOP(complete iff `interruptedBy == nil`); identity match by spellID when GUIDs differ; no COMPLETE on SUCCEEDED (CR-001) | cast-test channel cases pass |
| 1.2 | Combat listener identity check (CR-002) | spam/unrelated-instant cases keep texture |
| 1.3 | Crafting ends gathering/fishing only on tracked spell's terminal event | fishing bed lasts whole channel |
| 1.4 | Fishing signature + caveat (CR-003) | perceptible on Generic in V-test |

### Phase 2 — Engine correctness and intensity coherence (Q3) (L)
| Step | Work | Done when |
|---|---|---|
| 2.1 | Role-pool fix (CR-013) | pool test passes |
| 2.2 | `isTransient` through Hold/HoldRoles/HoldIfEnabled (CR-012) | knock reaches ≥90 % in 50 ms |
| 2.3 | Mixer decision (§6 #1 DOCS) + legacy MAX switch; per-mode slider ceiling or post-shape gain (CR-008 a, d) | slider table test |
| 2.4 | Dead-zone curve replaces linear floor lift (CR-008 b, #29 H7) | range ratio similar across presets |
| 2.5 | Overall intensity global or displayed with profile (CR-008 c) | UX decision recorded |
| 2.6 | Previews honour intensity: heartbeat, craft strikes, "Feels like" (CR-006, CR-014, CR-018) | preview-test |
| 2.7 | Hardware calibration on DualSense + SC2 (V4): measured presets, `actuator`/`symmetric` fields, detection fix for Steam Input, reconcile trigger texts (CR-019, CR-025) | presets cite measurements |

### Phase 3 — Crisp footsteps (Q4) (M; needs 2.2, 2.7)
| Step | Work | Done when |
|---|---|---|
| 3.1 | Event-scheduled footfall transients; real steps/s; GALLOP 1+1 per stride (CR-005) | locomotion-test rate check |
| 3.2 | Channel/split from actuator fields; High (fast) channel default on LRA; L/R split on symmetric pads (CR-005, CR-020) | routing test per preset |
| 3.3 | Optional low weight bed; relabel tunables; migrate saved cadence (halve) with DB_VERSION 8 and non-downward stamp (known) | migration test |
| 3.4 | Reconsider `mountedOnly` default after feel test (V6) | decision recorded |

### Phase 4 — Faithful continuous previews (Q5) (M; needs 2.6)
| Step | Work | Done when |
|---|---|---|
| 4.1 | `Preview(seconds, scale)` per continuous module (13 cues: swim, water, ocean, taxi, glide, cast, craft, breath, weather, lowHealthWarning, lowHealthTexture, stealth, locomotion) driving real shaping with synthetic state; token-cancelled preview layer | preview-test: non-flat, correct roles |
| 4.2 | weatherTexture tunables + perceptible defaults; patter as transient blips (CR-026) | V10 |

### Phase 5 — Dead features and secret safety (Q6) (M)
| Step | Work | Done when |
|---|---|---|
| 5.1 | bossAbilityWarning on `C_EncounterTimeline` or hidden (CR-007) | API-manifest passes; V9 |
| 5.2 | Secret guards: CR-010, CR-011, `keyFor`, sweep truthiness (known); use `C_Secrets` predicates | secret-path tests |
| 5.3 | ControllerUI gating (CR-009); take defaults decision (DOCS §6 #3) | M+KB test |
| 5.4 | Checklist import parser (CR-015); remap/drop 30 orphan baseline IDs (known) | checklist-test |
| 5.5 | PulseDebug Hold 2s through a real path (known); `/pdebug watch` guard; UISpecialFrames (CR-024) | pulsedebug-test |

### Phase 6 — P3 sweep and docs (S–M)
CR-020–CR-025, CR-027, CR-028; known docs items (202/36 counts, taint/GC claims, TOC licence line, tests README, QA_TEST_PLAN, Registry header); PulseProfileReview frame reuse if kept (known).

### Phase 7 — In-game verification pass (M)
Run §8 V1–V10 plus DOCS §7; record in a tracked results file; re-grade CR-001…CR-028 statuses.

**Critical path:** 0 → 1 (parallel with 2.1–2.2) → 2.7 → 3 → 4. Phases 5–6 fill gaps; Phase 7 closes. Engine architecture work (Output/Mixer extraction, priority/ducking) stays after Phase 7, as DOCS §10.3 item 10 says.

---

## 10. Addendum — second pass (2026-09-28, same session, user ordered "do it all")

Seven extra reviews, each appended when done. New findings continue the CR numbering; §1.3 counts are updated at the end of the addendum.

| # | Item | Status |
|---|---|---|
| A1 | Secret-value stress probe across all modules | done |
| A2 | Reference addons (`GamepadVibration`, ConsolePort) vs Pulse's vibration practice | done |
| A3 | `dist/` release zips vs HEAD | done |
| A4 | Hot-path allocation (GC) measurement | done |
| A5 | Git history of large feature commits (whitespace-blind) | done |
| A6 | `ProfileReviewReports/` vs profile defaults | done |
| A7 | Unread docs: `CURSEFORGE.md`, DOCS_COMPILATION §1–3 + appendices, `QA_TEST_PLAN.md` | done |

### A1 — Secret-value stress probe (done)

**Method.** `secret-stress.lua` (scratchpad) loads all Core + Module files in TOC order under stubs where every game API returns `SECRET` — a userdata that errors on arithmetic, ordering, concatenation, indexing and calls, as secrets do. `UnitName`, `GetRealmName`, `GetTime`, `InCombatLockdown`, `C_GamePad` device calls, `C_Timer`, `CreateFrame` and `Enum` stay real. All 190 cues switched on. Then every registered event handler is fired with secret payloads (twice: all-secret, and with a real `"player"`/`"target"` first argument), every OnUpdate runs 5 frames, every queued timer runs, every secure hook is called with secret arguments.
**Blind spots (Lua, not WoW):** `secret == "x"` returns false silently; a secret table key works silently; truth tests on secret booleans do not error. These were covered by a second, documentary pass: scripts listed every API and event the addon uses that carries a `Secret*` flag in `FOREVER/Blizzard_APIDocumentationGenerated/`, and each use site was read.

**Run:** `frames 126, event deliveries 392, timers run 63, hooks 8, distinct errors 5`
```
PulseHaptics/Modules/AlertSocial.lua:39        OnEvent UPDATE_BATTLEFIELD_STATUS   'for' limit must be a number
PulseHaptics/Modules/ControllerUI.lua:181      hook BeginSelection                 attempt to index local 'list' (a function value)
PulseHaptics/Modules/ControllerUI.lua:88       OnUpdate (nil)                      attempt to index local 'button' (a userdata value)
PulseHaptics/Modules/Environment.lua:184       Environment:OnEnable                attempt to compare number with userdata
PulseHaptics/Modules/World.lua:58              OnEvent CHAT_MSG_TEXT_EMOTE         attempt to index local 'message' (a userdata value)
```
**Triage** ([Fact] from doc flags):
- `World.lua:58` — **real**. `CHAT_MSG_TEXT_EMOTE` is `SecretInChatMessagingLockdown`. CR-011 now confirmed dynamically, not only by reading. Verdict: ungood, stays P2.
- `AlertSocial.lua:39` (`GetMaxBattlefieldID`), `Environment.lua:184` (`GetMirrorTimerProgress`) — false positives; neither API carries any secret flag. Plusgood.
- `ControllerUI.lua:88`, `:181` — probe artefacts (SmartNavigation/GamepadRadial Lua fields are plain Lua values, never secret-wrapped). Plusgood.

**Documentary pass — flagged APIs and events the addon touches:**

| Source | Secret flag | Use site | Verdict |
|---|---|---|---|
| `C_Spell.GetSpellCooldown` | `SecretWhenCooldownsRestricted` | `Combat.lua:43-45`, `:137-139` guarded | goodthink |
| `GetUnitSpeed` | `SecretWhenUnitStatsRestricted` | `Movement.lua:176-185`, `Locomotion.lua:273-275` guarded | goodthink |
| `UnitPower`/`UnitPowerMax` | `SecretWhenUnitPower(Max)Restricted` | `Combat.lua:395-406`, `AlertExperimental.lua:34-35`, `:85-87`, `:114-118` guarded | goodthink |
| `UnitThreatSituation` | `SecretWhenUnitThreatStateRestricted` | `AlertThreat.lua:53-56` guarded | goodthink |
| `UnitIsAFK`/`UnitIsDND` | `SecretInChatMessagingLockdown` | `AlertWorld.lua:17-22` guarded | goodthink |
| `UnitIsUnit` | `SecretWhenUnitComparisonRestricted` | `AlertUnitWatch.lua:154-157` guarded | goodthink |
| `UnitCastingInfo`/`UnitChannelInfo` | `SecretWhenUnitSpellCastRestricted` (only `isTradeskill`, `castBarID`, `delayTimeMs`, `isEmpowered`, `numEmpowerStages` NeverSecret) | times guarded `Combat.lua:462-468`, `Crafting.lua:441-443`; **unguarded:** `spellId` → table key `Crafting.lua:237-241` via `sync()` `:544-560` | [Inference] low risk for `"player"`; widens known `keyFor` issue |
| `UnitName` | `SecretWhenUnitNameIdentityRestricted` | `Database.lua:665-667` concat, `World.lua:51` | [Inference] player's own name unrestricted |
| `IsShown`/`IsEnabled`/`GetAlpha` | `SecretReturnsForAspect` | `LowHealthFrame` guarded (`Health.lua:171-199`); truth tests unguarded on `GamepadRadial:IsShown()` (`ControllerUI.lua:358`), segment/button `IsEnabled` (`:88-92`, `:185-189`), StaticPopups (`PlayerState.lua:147-149`), merchant/bank frames (`Inventory.lua:44-61`) | [Inference] low: only frames Blizzard marks secret-aspected |
| `UNIT_SPELLCAST_*` payload (player) | `SecretWhenUnitSpellCastRestricted` | `CastActivity.lua:72-74` (`unit == "player"`), `:65-70` (keyFor concat), `Combat.lua:627-628` (`spellID == 75`), `Crafting.lua:239` (spellID key) | [Inference] low for player; **widens** known P1-04 `keyFor` row |
| `UNIT_SPELLCAST_*` / `UNIT_AURA` payload (target) | `SecretWhenUnitSpellCastRestricted` / `SecretWhenAurasRestricted` | `AlertUnitWatch.lua:253-256` | CR-010, confirmed by flag |
| `CHAT_MSG_*` (8 events) | `SecretInChatMessagingLockdown` | all handlers except World's ignore payload (`Encounter.lua:121-125`, generic `Init.lua:345-347`) | goodthink |
| `PLAYER_SOFT_INTERACT_CHANGED` | `SecretWhenUnitIdentityRestricted` | payload unread (`ControllerUI.lua:514-528`) | goodthink |

**A1 outcome:** no new finding above P3. CR-011 confirmed dynamically. CR-010 confirmed by doc flag. The known `keyFor` secret-key issue (DOCS §4.2) widens to `Crafting.lua:237-241`, `:544-560` and `Combat.lua:627-628`. **[Rec]** Guard player spellcast payloads with `issecretvalue` or a single `C_Secrets.ShouldUnitSpellCastingBeSecret("player")` check per event; add `secret-stress.lua` (with the equality/key audit list) to `PulseChecklist/tests/` as a standing suite.

### A2 — Reference addons vs Pulse (done)

**Read:** `docs/DevelopmentplusReference/Reference addons/GamepadVibration/GamepadVibration.lua` lines 1-130, 380-640, 790-840 + grep of all vibration/cast sites (`## Interface: 120007`, v1.4.2); `DBM-Core-12/DBM-Core/DBM-Core.lua:4524-4530`; ConsolePort-3.2.5 grep: **no** `SetVibration`, rumble or haptic code at all (it is a navigation addon — nothing to compare).

| Topic | GamepadVibration / DBM | Pulse | Verdict for Pulse |
|---|---|---|---|
| Preview | Options call the SAME `PlayVibration(name, intensity, duration, lowRatio)` with the configured values (`GamepadVibration.lua:417-424`) → preview = product | Four divergent preview paths (CR-004, CR-006, CR-014, CR-018) | Pulse crimethink; GV pattern supports CR-004 Rec |
| Channels | `"Low"`/`"High"` only (`:621-623`); DBM `"High"` only | Adds unconfirmed `LTrigger`/`RTrigger` | Neither reference drives triggers — consistent with DOCS §4.8 "trigger claims too strong" (bellyfeel remains) |
| Master strength | `overallStrength` 0.1–3.0, clamp per motor (`:403-412`) — headroom to boost weak pads | `masterIntensity` 0–1.0; boost only via per-channel `gain` ≤ 2.0 | Pulse fine; but CR-008 c/(a) apply |
| Motor mix | One intensity split by `lowRatio` per event (`:409-412`) | Mode steps pick role per step | Different design; both goodthink |
| Smoothing | Fixed `lerp 0.15` per frame (`:607-613`) — frame-rate dependent | Time-constant `tau` (`Engine.lua:97-107`) | Pulse doubleplusgood here |
| Silence | `StopVibration` when both < 0.005 (`:618-627`) | Per-channel zero + `StopVibration` when all quiet (`Engine.lua:456-467`, `:639-647`) | Both goodthink |
| Channels/casts | `UNIT_SPELLCAST_SUCCEEDED` → `isCasting = false` (`:799-805`); FAILED also clears (`:795-797`) | CR-001, CR-002 | Same flaws in the reference: its channel rumble also dies at the start-of-channel SUCCEEDED. No reference implements channels right; Blizzard's cast bar ends channels only on `CHANNEL_STOP` (`FOREVER/…/CastingBarFrame.lua:136-139`, `:449-450`) — the model to copy |
| Output lifetime | DBM: one `SetVibration("High", 1)` per alert, **never stopped** (`DBM-Core.lua:4524-4530`) | 250 ms watchdog re-send (`Engine.lua:58`, `:480`) | [Inference] Widely used DBM never stopping a full-power call implies the client times a `SetVibration` out by itself (otherwise DBM users would report stuck rumble). Pulse's watchdog is consistent with that. Consequence to verify: the client may impose its own minimum/maximum pulse length, which bounds how crisp a 35–60 ms transient can be (new **V11**) |

**A2 outcome:** no new CR. Strengthens CR-001 (same bug in a public addon; copy Blizzard's cast-bar model), CR-004 (preview = product pattern exists), CR-005 (possible client pulse timing), DOCS §4.8 (no one drives trigger channels). **New unverified V11:** on Forever, how long does one `SetVibration(ch, v)` last without a follow-up call, and is there a minimum pulse length? Test: `/run C_GamePad.SetVibration("High", 0.8)` once, time the buzz; repeat with a `C_Timer.After(0.03, …, 0)` stop.

### A3 — `dist/` release zips vs HEAD (done)

**Method:** both zips unpacked to scratchpad; every file compared byte-for-byte (`cmp`) with `git show HEAD:<path>` (zip `*/LICENSE`, `*/README.md` against the repo-root copies `scripts/package.sh:24-25`, `:32`, `:39` put there); `git ls-files` of the three addons (minus `tests/`) checked for anything missing.

**Result** ([Fact]):
```
same=82 diff=0 notInHead=0
--- git files missing from suite zip:        (none)
--- standalone vs suite PulseHaptics:        identical-list, no byte differences
```
- `PulseHaptics-v0.2.0-beta.zip` (75 files) and `PulseSensation-Suite-v0.2.0-beta.zip` (82 files), built 2026-09-24 23:09 = HEAD `ac3d02f` commit time: **byte-identical to HEAD**. Packaging doubleplusgood.
- `tests/` excluded (0 paths); no `.DS_Store`, `__MACOSX`, `._*`. Goodthink.
- Therefore the shipped zips contain **every** finding in this report (CR-001…CR-028) and **none** of the uncommitted work. `PulseHaptics/README.md` inside the zip carries the "202 … triggers" claim (known, DOCS §4.8). `PulseProfileReview/` is not packaged (by design, `scripts/package.sh:17-39`).

**A3 outcome:** no new CR. DOCS §10.1 "[Unverified] their contents" → **verified: equal to HEAD**. [Rec] Do not ship these zips as a fix release; rebuild after Phase 1–4 of §9.

### A4 — Hot-path allocation (done)

**Method:** `gc-probe.lua` (scratchpad): real Core + 10 texture-bearing modules under LuaJIT with `jit.off()` (interpreter, closer to WoW's PUC-5.1). Stubs return pre-allocated values, so only addon allocation counts. Per scenario: 1 s settle, then 600 frames (10 s at 60 fps) with `collectgarbage("stop")`; `collectgarbage("count")` delta. Activity checked separately (SetVibration calls, live layers) so the counter itself allocates nothing. Two identical runs.

```
idle (nothing active)                            0.02 KB/s       0.3 bytes/frame   SetVibration calls    0  max layers 0
casting (castTexture swell)                      0.02 KB/s       0.3 bytes/frame   SetVibration calls   74  max layers 1
channeling (castTexture hum)                     0.02 KB/s       0.3 bytes/frame   SetVibration calls  317  max layers 1
swimming (swim+water+ocean)                      0.02 KB/s       0.3 bytes/frame   SetVibration calls  790  max layers 3
taxi ride                                        0.02 KB/s       0.3 bytes/frame   SetVibration calls  540  max layers 1
gliding                                          0.02 KB/s       0.3 bytes/frame   SetVibration calls   75  max layers 1
stealth                                          0.02 KB/s       0.3 bytes/frame   SetVibration calls  170  max layers 1
rain (weatherTexture)                            0.02 KB/s       0.3 bytes/frame   SetVibration calls  370  max layers 1
running on foot (locomotion)                     0.02 KB/s       0.3 bytes/frame   SetVibration calls  938  max layers 2
mounted (locomotion)                             0.02 KB/s       0.3 bytes/frame   SetVibration calls  962  max layers 2
low health (both heartbeat cues)                 1.45 KB/s      24.7 bytes/frame   SetVibration calls  873  max layers 2
+PulseDebug hooks: running + channeling        134.70 KB/s    2298.9 bytes/frame   SetVibration calls  968  max layers 3
```
(0.3 bytes/frame = harness floor, identical when idle.)

**Findings** ([Fact] for the probe; WoW allocator sizes differ, zero-vs-nonzero holds):
- **Every continuous texture and the engine tick are allocation-free.** README "Zero-GC … continuous oscillators" (`README.md:31`) — **doubleplusgood** for textures, now measured. DOCS §4.8 "Zero-GC (0 FPS Drops) OPEN (overclaim)": the texture half verified; discrete cues still allocate per fire (a closure per delayed `PlayMode` step, `Engine.lua:405-410`) — expected, bounded by cue rate.
- **Heartbeats:** 1.45 KB/s from per-beat `C_Timer.After` closures (`Health.lua:117-119`, `:147-149`). Negligible; plusgood.
- **PulseDebug installed:** +134.7 KB/s with one texture + locomotion running, window CLOSED. Quantifies **CR-016** (per-frame `recordEvent` table + strings). Ungood for anyone leaving PulseDebug enabled; stays P2.
- `SetVibration` rate: up to ~96 calls/s (running, both channels most frames). [Unverified] cost per call on the client; watchdog/epsilon logic is working as designed.

**A4 outcome:** no new CR. CR-016 quantified. Proposed DOCS §4.8 change: "Zero-GC" → **PARTIAL (textures verified allocation-free offline; discrete cues allocate per fire; PulseDebug hooks allocate heavily)**.

### A5 — Git history of the large commits, whitespace-blind (done)

**Method:** `git show -w --ignore-cr-at-eol --shortstat` for the 15 large commits DOCS §9.1 lists as never read line by line; then `git log --reverse -S '<construct>'` (no path filter — a path filter lands on rename commit `fd41c1b`, which moved `Pulse/` → `PulseHaptics/`) to date the code behind each major finding; then targeted `git show -w` of the introducing hunks. **Not done:** reading all 15 historical diffs line by line (~10,000 real changed lines). The current code, fully read (§2), supersedes them; history is used here only to date defects.

**Real (whitespace-blind) size of the 15 commits** — `3fb5a0f` +2684/−682 · `ef8d118` +871/−296 · `85d639e` +1373/−257 · `b39e6a6` +2352/−184 (64 files) · `c137c07` +273/−15 · `68f96d0` +275/−4 · `d68ceaa` +163/−33 · `1142c11` +198/−370 · `6b2d126` +185/−62 · `6d0b323` +202/−745 · `a88fcc0` +478/−341 · `fc21210` +445/−162 · `3f3d7ec` +434/−47 · `da734ca` +190/−2 · `6cfe986` +289/−4.

**When each major finding entered** ([Fact], pickaxe):

| Finding | First commit | Note |
|---|---|---|
| CR-001 CastActivity channel model (`CHANNEL_COMPLETE`, `activeChannel.key == key`) | `110cebc` 2026-09-22 (initial import) | dormant until consumers used it |
| CR-001 Crafting ends fishing on `CHANNEL_COMPLETE` | `d44badf` 2026-09-23 "add gathering and fishing" | fishing never ran through a start-of-channel SUCCEEDED correctly |
| **CR-002 + channel hum death** — Combat stops on `INSTANT` | **`b39e6a6` 2026-09-22 23:48** "casting failure pipeline" | see below |
| CR-004 flat preview, CR-006 bespoke preview, CR-005 gait waveform + "steps/s" label, CR-007 encounter API, CR-008 slider 1.5 + linear floor lift, CR-009 gating, CR-014 strikes, CR-019 SC2 preset, CR-011 emote handler | `110cebc` initial import | pre-repo design; never reworked |
| CR-008 saturating sum; `isTransient` two-lane attack | `ea0368a` 2026-09-24 | known (DOCS §9.3) |
| CR-012 `Hold` → `SetRoles(…, false)` explicit | `f447944` 2026-09-24 | same behaviour as before (nil → false) |
| CR-013 role pool | `f447944` 2026-09-24 | known |
| CR-010 target defensives (`unit ~= "target"`) | `68f96d0` 2026-09-23 | |
| CR-026 weather texture levels | `3fb5a0f` 2026-09-22 | constants unchanged since |
| CR-015 import parser | `6cfe986` 2026-09-23 | together with the 30 orphan baseline IDs (known) |
| CR-016 PulseDebug HOLD hooks | `239619c` 2026-09-24 "resolve ghost hooks" | the fix that made hooks real also made them flood |

**Channel regression — dated.** Before `b39e6a6`, castTexture ran on its own frame and never listened to `UNIT_SPELLCAST_SUCCEEDED` (`git show b39e6a6^:Pulse/Modules/Combat.lua:371-382`):
```lua
castFrame:SetScript("OnEvent", function(_, event)
    if event == "UNIT_SPELLCAST_START" then
        isCasting = true
        isChanneling = false
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        isCasting = false
        isChanneling = true
    else
        isCasting = false
        isChanneling = false
    end
end)
```
registered for START, CHANNEL_START, STOP, CHANNEL_STOP, FAILED, INTERRUPTED only (`b39e6a6^` lines removed in diff: `RegisterUnitEvent("UNIT_SPELLCAST_START" … "UNIT_SPELLCAST_INTERRUPTED", "player")`). `b39e6a6` moved it onto CastActivity and added `c == "INSTANT"` to the stop list (`Combat.lua:540-552` today). [Inference, high] From that commit, the start-of-channel SUCCEEDED (classified `INSTANT` when GUIDs differ) kills the channel hum — matching the user's "channeling broken" while casts work. The FAILED-kills-texture half of CR-002 is older (pre-`b39e6a6` `else` branch). **CR-001/CR-002 "Where" now also carry: regression introduced in `b39e6a6`; fishing path in `d44badf`.**

**A5 outcome:** no new CR; dates added. [Rec] Phase 1 fix may reuse the pre-`b39e6a6` rule for channels: a channel ends only on `CHANNEL_STOP` (or `INTERRUPTED` of the same spell), never on SUCCEEDED.

### A6 — `ProfileReviewReports/` vs profile defaults (done)

**Read:** `ProfileReviewReports/Immersion-Ranged-Cue-Review.md` (97 lines, fully). **Method:** `profile-probe.lua` loads real `Init.lua`, `Database.lua`, `Modes.lua`, `Registry.lua`, seeds a fresh DB, activates `Immersion: Ranged`, reads `GetCue` for all 190 cues, diffs against the report's Yes/No tables. (First run mis-parsed "## Notes" as the No section; fixed — result below is the corrected run.)

```
cues 190 | review yes 112 no 77 | unreviewed: bankOpened
ON by default but review says No (20): achievement, breathWarning, combatLeave, glideThrust, oceanTexture, padBattery, padDisconnected, popupHidden, popupShown, procGlow, resting, softTargetInteraction, swimTexture, targetBigDefensive, targetChannelStart, threatAggro, threatRising, waterTexture, weatherChanged, weatherTexture
OFF by default but review says Yes (53): auctionHouseShow, bagItemUsed, bnWhisper, breathTexture, castTexture, ccDisarm, ccPacify, cursorDrop, cursorPickup, damageTaken, debuffReceived, duelRequest, gossipShow, guildBankOpened, guildInvite, healCrit, healReceived, interactionWindow, interactionWindowClosed, itemTextBegin, lootConfirm, lootOpened, lootReceived, lootRoll, lowHealthTexture, merchantBuy, merchantSell, partyInvite, playerAlive, questAccepted, radialBlocked, radialCancel, recipeLearned, rolePoll, selfCastInstant, skillUp, softEnemyChanged, softFriendChanged, softInteractChanged, spellLearned, spiritHealerShow, stableShow, summonRequest, targetChanged, tradeRequest, tradeSkillShow, trainerShow, uiFocusIn, uiFocusOut, uiInfoMessage, uiNavigateEdge, uiSelectionDisabled, whisper
```

**Findings** ([Fact]):
- DOCS §4.3 "20 ON-but-No, 53 OFF-but-Yes" — **re-confirmed exactly**. `bankOpened` still unreviewed (DOCS §8). Review header counts (112/77) correct. The decision (DOCS §6 #9) is still open. Seeding only fills gaps (`Database.lua:832-844`), so applying it to existing installs needs a migration (known).
- **Review vs this report's defects** — several accepted cues are currently defective, so applying the review now would ship known-bad feel:
  - `castTexture` Yes → CR-001/CR-002 (channel hum dies); `selfCastInstant` Yes → misfires at every channel start (CR-001).
  - `uiNavigateEdge` Yes → the SmartNavigation callback the code itself calls forbidden (known, DOCS §6 #4).
  - `damageTaken`, `healReceived` Yes → TICK at intensity 0.3 peaks ≈ 0.039 on Generic (CR-008 table: TICK row × 0.3) — likely imperceptible.
  - `lowHealthTexture` Yes → preview ignores intensity (CR-006).
  - `uiFocusIn`/`uiFocusOut`/`radialBlocked`/`radialCancel`/`uiSelectionDisabled` Yes → fire on mouse & keyboard too (CR-009).
- Review No agrees with defects found: `weatherTexture` No (CR-026 inaudible), `targetBigDefensive` No (CR-010 secret-compare risk), water textures No ("not refined", report lines 15-16).

**A6 outcome:** no new CR. [Rec] Apply the review only after §9 Phases 1–2, via a DB_VERSION 8 migration that sets these 73 cue states for `Immersion: Ranged` once, and review `bankOpened`.

### A7 — Previously unread documents (done)

**Read in full:** `CURSEFORGE.md` (162), `docs/dev-notes/QA_TEST_PLAN.md` (130), `docs/DOCS_COMPILATION.md` §1–§3 (lines 37–340) and Appendices A–B (lines 741–932). Ledger §2.2 is now complete for project docs except `Libs/` (out of scope).

**Provenance corrections to this report** (from DOCS §3 summaries of the older reviews):
- **CR-005** — the 2× cadence-unit half was reported by code review #19 item 1.2; DOCS §4.4 tracked it as UNVERIFIED. This review confirms it; the GALLOP ×4, continuous-smoothing and Low-channel halves are new.
- **CR-012** — extends review #29 ("one smoothing filter for everything softens transients"). `ea0368a` split the lanes for `PlayMode` only, so **DOCS §4.1 "Separate transient/continuous attack | FIXED" → PARTIAL**.
- **CR-008** — review #29 already named "no loudness model" and the floor dead-zone (H7); items 1, 2, 5 (dead top, dead bottom, per-profile master) are new.
- **CR-019** — review #29 already said "device defaults are hypotheses"; the Steam Controller 2 / Steam Input detection part is new.
- **CR-022** — reported by RC review #18; DOCS §4.3 carried it NOT CHECKED. Now checked.
- **CR-011** — pattern half known (#5 item 6, #14 M-03); secret half new.
- §1.3 counts corrected: 17 wholly new, 9 extensions, 2 known.

**`CURSEFORGE.md` vs code** (beyond the known 202/36 counts, DOCS §4.8):
- `:39` lists "Continuous textures such as HUM, THRUM, WAVE, PATTER, and DRIFT" as a feature. [Fact] No cue uses them; they exist only for the mode tester (`Modes.lua:291-294`). Overclaim.
- `:72` "Test haptic modes and individual cues directly" — true for discrete cues; continuous cues preview as a flat buzz (CR-004).
- `:47` "Controller-specific device presets" — unmeasured starting points (`Devices.lua:160-162`, CR-019).
- `:76` "PulseDebug — live event and cue troubleshooting" — log flooded under any texture (CR-016).
- `:113-122` command table lacks `/pulse stop` and `/pulse minimap` (stop part known).
- `:99` `/console GamePadVibration 1` — [Unverified] CVar name; Blizzard Lua in FOREVER never references it (grep).
Verdict: crimethink marketing drift; folds into CR-025 (P3).

**`QA_TEST_PLAN.md` vs this review** (beyond known staleness `/pulsedebug`, icon, `Pulse` path, "112 tests", DOCS §4.8):
- [Fact] None of the user's QA areas are in the plan: no channel/fishing test, no intensity-slider test, no footstep test, no continuous-preview test.
- [Fact] Test 1.2 (`:23-35`) expects gathering to feel like `castTexture` ("current architecture") — stale since `d44badf` routed gathering/fishing to `craftTexture`.
- [Fact] Test 1.2 step 4 asks PulseDebug's Log to show `CAST_START`/`CRAFT_START`. The log records FIRE/HOLD/MODE/STOP only (`PulseDebug/UI.lua:303-417`); CastActivity classifications are never shown. The step cannot be performed as written → supports §9 Phase 0.4 (cast-trace view).
- Test 3.1 (`:85-92`) assumes controller navigation cues only fire on the pad — CR-009 says otherwise with mouse input.
[Rec] Rewrite the plan around §4 Q1–Q6 and §8 V1–V11, and record results in a tracked file.

**Appendix A / B:** no new defect. Appendix A.5's acceptance line "Renaming the active profile notifies listeners exactly once" is violated by CR-021 (second notify at next combat end). A.4 risk "dist zips [Unverified] contents" is closed by A3.

**A7 outcome:** no new CR; provenance and counts corrected; CURSEFORGE items added to CR-025's scope; QA plan gaps recorded.

### Addendum summary

| Item | New CR | Main result |
|---|---|---|
| A1 | — | CR-011 confirmed dynamically; CR-010 by doc flag; `keyFor` secret-key issue widened to `Crafting.lua:237-241`, `Combat.lua:627-628` |
| A2 | — | Reference addon has the same channel bug; its preview = product pattern; DBM implies client-timed pulses → V11 |
| A3 | — | Release zips byte-identical to HEAD (82/82) |
| A4 | — | Textures allocation-free (verified); PulseDebug hooks +134.7 KB/s (CR-016) |
| A5 | — | Channel-hum regression dated to `b39e6a6`; fishing path `d44badf`; most other findings date to `110cebc` |
| A6 | — | 20/53 profile mismatch re-confirmed; several reviewed-Yes cues are currently defective |
| A7 | — | Provenance corrected (17 new / 9 extend / 2 known); DOCS §4.1 transient-attack row → PARTIAL; QA plan misses every user QA area |

Counts after the addendum: unchanged at 28 findings (P0 0 · P1 6 · P2 13 · P3 9). New unverified item: **V11** (client pulse lifetime of a single `SetVibration`). Proposed DOCS §4 status changes added by the addendum: §4.1 transient/continuous attack FIXED → PARTIAL; §4.8 Zero-GC → PARTIAL (textures verified); §10.1 dist zip contents → verified equal to HEAD.

### A8 — In-game observation from the user (2026-09-29) and what it proves

**User report:** "The channeling goes off and is registered in debug but then goes silent after 1 second."

**Explanation** ([Inference, high]; offline-reproduced): many channels fire a separate *triggered* spell per tick (e.g. Arcane Missiles 5143 fires missile spell 7268 about once a second; Blizzard, Volley, Hurricane, Tranquility work the same way). Each tick raises `UNIT_SPELLCAST_SUCCEEDED` for `"player"` with a different spellID and castGUID. `CastActivity._OnSucceeded` finds no pending cast and no matching channel key → emits `INSTANT` (`CastActivity.lua:181`) → Combat's listener treats any `INSTANT` as "cast over" and removes castTexture's OnUpdate (`Combat.lua:540-552`) → the last hold expires after `REFRESH_WINDOW` 0.35 s (`Engine.lua:71`). This is **CR-002** exactly (probe scenario 6), now matching a live symptom.

**Evidence:** `tick-probe.lua` (scratchpad; real `Engine.lua`, `CastActivity.lua`, `Combat.lua`, `Casting.lua`, `Crafting.lua`; castTexture on, master 0.7):
```
t=0.90 channel running (same-GUID SUCCEEDED at 0.10)       High now=0.141  last audible at t=0.92 s
t=3.00 after first tick SUCCEEDED (spell 7268) at 1.00     High now=0.000  last audible at t=1.37 s
channel still active per UnitChannelInfo: true
```

**What the observation rules out:** the hum was audible for about a second, so for this spell the start-of-channel SUCCEEDED either carried the same castGUID or did not arrive. The mismatched-GUID variant of CR-001 would have silenced it at once. CR-001's fishing half is unaffected: while fishing the bed stays at 0.049 (CR-003), or ends at channel start when the SUCCEEDED carries the same GUID.

**Confirming it in game** (one line, under the 255-character chat limit):
```
/run local f=CreateFrame("Frame")for _,e in pairs({"SUCCEEDED","CHANNEL_START","CHANNEL_STOP"})do f:RegisterUnitEvent("UNIT_SPELLCAST_"..e,"player")end f:SetScript("OnEvent",function(_,e,_,g,s)print(GetTime(),e,s,g)end)
```
Then channel the spell. Expected if the explanation is right: `CHANNEL_START 5143`, then a `SUCCEEDED` line with another spellID about a second later, and silence from that moment. A channel with no triggered ticks (Drain Life, Mind Flay) should keep humming to the end, unless its start-of-channel SUCCEEDED carries a different GUID (CR-001).

**Severity:** CR-002 stays P1; status "latent" → **matches an in-game symptom**. Fix unchanged (§9 Phase 1.2): stop the texture only on a terminal event carrying the textured spell's own identity; a channel ends only on `CHANNEL_STOP`. The fix can be written and tested offline (both event orders, tick spells).

### A9 — Bisect of the channel break vs the user's "stopped after the watchdog / engine overhaul" (2026-09-29)

**User report:** channeling "stopped working after watchdog fix/engine change, engine overhaul" (i.e. `ea0368a` / `a97acb7` / `f447944`, 2026-09-24).

**Method:** `git archive` of 14 revisions from `b39e6a6^` to `ac3d02f` plus the working tree into scratchpad (read-only for the repo). `bisect-probe.lua` loads each revision's `Modes`, `Devices`, `Waves`, `Standard`, `Engine`, `CastActivity`, `Combat`, `Casting`, `Crafting` and sends real events to every frame registered for them (so pre-`b39e6a6` Combat, which had its own cast frame, is exercised too). Scenarios: 2.4 s cast; channel with no SUCCEEDED; channel + same-GUID SUCCEEDED at 0.1 s; channel + different-GUID SUCCEEDED at 0.1 s; channel + tick-spell SUCCEEDED (7268) at 1.0 s. Metric: last time the High channel is above 0.004. First run was invalid: before `f447944`, CastActivity registered events only `if UnitIsUnit then` (`git show 790ce76:PulseHaptics/Core/CastActivity.lua:312`), and the probe lacked that global; the real client has it. Rerun with the stub:

```
== b39e6a6p  cast H=2.40s chan_plain H=4.00s chan_same H=4.00s chan_diff H=4.00s chan_tick H=4.00s
== b39e6a6   cast H=2.40s chan_plain H=4.00s chan_same H=4.00s chan_diff H=0.53s chan_tick H=1.43s
== 11622b7   … identical to b39e6a6 …
== 2fd5c92   … identical …
== 974d49f   … identical …
== d44badf   … identical …
== 2d16063   … identical …
== 990a765   … identical …
== ea0368a   cast H=2.40s chan_plain H=4.00s chan_same H=4.00s chan_diff H=0.53s chan_tick H=1.43s
== a97acb7   … identical …
== 790ce76   … identical …
== f447944   … identical …
== 580e69f   … identical …
== ac3d02f   … identical …
== worktree  cast H=2.40s chan_plain H=4.00s chan_same H=4.00s chan_diff H=0.53s chan_tick H=1.43s
```
Steady-hum output stream (channel, no SUCCEEDED, t = 1–4 s, Generic preset) is also byte-for-byte the same in every revision tested:
```
b39e6a6p / b39e6a6 / 990a765 / ea0368a / a97acb7 / f447944 / ac3d02f / worktree:
High sends t=1..4s: 84 (28.0/s)  range 0.1352..0.1411
```
(`f447944`'s only `Waves.lua` change wraps the MicroFlutter phase in `% TWO_PI` — numerically the same.)

**Findings:**
- [Fact, offline] The tick/mismatched-SUCCEEDED silence begins at **`b39e6a6`** (2026-09-22 23:48) and is **unchanged by the engine overhaul**. Before `b39e6a6` every channel scenario hums for the full 4 s.
- [Fact, offline] The engine overhaul did not change the hum's output for a steady channel.
- [Unverified] What the probe cannot see: the client's and the controller's handling of `SetVibration` (V11 — pulse lifetime, firmware behaviour on the DualSense and Steam Controller 2). If on real hardware the hum dies with **no** SUCCEEDED arriving at that moment, the cause is outside CR-002, and the engine/hardware path becomes the suspect.
- [Inference] The two accounts can both be true if channels were not exercised in game with a ticking spell between 09-22 23:48 and 09-24 (or the installed build lagged the repo). Git cannot show which build was installed when.

**Decisive in-game test** — unchanged from A8: the one-line `/run` event printer. A `SUCCEEDED` line with a different spell ID at the moment the rumble stops → CR-002 (`b39e6a6`). Rumble stopping with no event → engine/hardware cause (§8 V11), and this review's attribution would be wrong.

---

## 11. Channel silence — working theory and debug checklist (2026-09-29)

Written for the next in-game session. Commentary Newspeak; the steps to run are plain English.

### 11.1 Symptom (user, 2026-09-29)
A channelled spell starts, the channel hum is felt and shows in debug, then it goes silent after about one second while the channel is still running. User recollection: it broke after the watchdog / engine overhaul.

### 11.2 Primary theory — T1: a tick spell's SUCCEEDED ends the texture (CR-002)
Chain, step by step ([Fact] for the code, [Inference, high] for the client event):
1. Channel starts → `UNIT_SPELLCAST_CHANNEL_START` → `CastActivity:_OnChannelStart` stores `activeChannel` (`CastActivity.lua:102-113`) → emits `CHANNEL_START` → Combat sets `isChanneling = true`, attaches `castTick` (`Combat.lua:534-539`). Hum plays (`Combat.lua:476-495`).
2. About 1 s later the first tick fires. Many channels cast a separate *triggered* spell per tick (Arcane Missiles 5143 → missile 7268; also Blizzard, Volley, Hurricane, Tranquility and similar). The client raises `UNIT_SPELLCAST_SUCCEEDED` for `"player"` with that tick spell's own ID and castGUID. [Inference: retail behaviour; unconfirmed on Forever.]
3. `CastActivity:_OnSucceeded` finds no pending cast and a channel key that does not match → emits `INSTANT` (`CastActivity.lua:160-181`).
4. Combat's listener treats every `INSTANT` as "the cast is over": `isChanneling = false`, OnUpdate removed (`Combat.lua:540-552`). It never checks which spell the event belongs to.
5. The last hold expires after `REFRESH_WINDOW` 0.35 s (`Engine.lua:71`) → silence at ≈ 1.35–1.45 s.

Offline reproduction: `tick-probe.lua` → last audible 1.37 s; bisect: starts at `b39e6a6` (the commit that moved castTexture onto CastActivity), identical in every later revision (§10 A5, A8, A9).

**T1 predicts:**
- P1 — The silence starts 0.35–0.45 s after a `SUCCEEDED` line carrying a **different spell ID** from the channel.
- P2 — Only channels with triggered tick spells die early. Channels made of periodic ticks on an aura (Drain Life, Mind Flay, Health Funnel) keep humming to the end.
- P3 — If "Instant ability used" (`selfCastInstant`) is on, it fires at that same moment (`Casting.lua:33`).
- P4 — PulseDebug's log stops showing `HOLD castTexture` rows at that moment.
- P5 — Other steady textures (water, stealth, taxi, glide) do **not** die after 1 s.

### 11.3 Competing theories and how they would show
| ID | Theory | Where | Would look like |
|---|---|---|---|
| T2 | The start-of-channel SUCCEEDED carries a different castGUID → `INSTANT` at once (CR-001) | `CastActivity.lua:160-181` | Silence ~0.4–0.6 s after start, right after a `SUCCEEDED` with the **same** spell ID but a different GUID. The ~1 s of hum the user felt argues against it, unless latency is high. |
| T3 | Client or controller drops a steady rumble after ~1 s (V11), exposed by the engine overhaul | engine / hardware | Silence with **no** event line at that moment, and other steady textures (P5) die after ~1 s too. Offline the hum's output stream is the same before and after the overhaul (A9), so this would be hardware/client-side. |
| T4 | `UnitChannelInfo("player")` returns nil mid-channel on Forever → `castTick` stops itself | `Combat.lua:484-491` | Silence with no event line; the check in step 4 below prints `nil` while the channel bar is still up. |
| T5 | Fishing only: texture is the 0.049 craft bed, or ends at channel start (CR-001/CR-003) | `Crafting.lua:87`, `:506-510` | Fishing feels near-silent from the start rather than after 1 s. |
| T6 | Stale craft flag suppresses castTexture (dev-notes regression reports, 2026-09-23) | `Combat.lua:444-446`, `Crafting.lua:310-335` | Silence from the **start** of the channel, not after ~1 s. Unlikely: `IsCrafting()` clears itself 0.5 s after no cast or channel is running, and while it is stuck the texture never starts. Added in §13.3. |

### 11.4 Debug checklist (in game, about 10 minutes)
1. Type `/pulse debug` so Pulse prints cue firings to chat.
2. Paste this into chat and press Enter (prints each cast event with time, spell ID and GUID):
   ```
   /run local f=CreateFrame("Frame")for _,e in pairs({"SUCCEEDED","CHANNEL_START","CHANNEL_STOP"})do f:RegisterUnitEvent("UNIT_SPELLCAST_"..e,"player")end f:SetScript("OnEvent",function(_,e,_,g,s)print(GetTime(),e,s,g)end)
   ```
3. Channel the spell that goes silent. Note the time the rumble stops, and look for a `SUCCEEDED` line just before it.
4. Channel it again. About 2 seconds in, while the bar is still up, run:
   ```
   /run print(UnitChannelInfo("player"))
   ```
   A spell name means the client still reports the channel; `nil` supports T4.
5. If possible, channel a spell with no tick spell (Drain Life, Mind Flay, or a long channel on your class) and compare (P2).
6. Stand in water, or stealth, for 5 seconds with that texture on: does it keep going (P5)?
7. Write down which spell, which controller (DualSense / Steam Controller 2), and whether Steam Input was running.

### 11.5 Reading the result
| Observation | Verdict | Next step |
|---|---|---|
| A `SUCCEEDED` with a different spell ID just before the silence; non-tick channels fine | T1 confirmed (CR-002) | Offline fix, §9 Phase 1.2: stop the texture only on a terminal event of the same spell; a channel ends only on `CHANNEL_STOP` |
| A `SUCCEEDED` with the channel's own spell ID but a different GUID, early | T2 (CR-001) | Same fix; match by spell ID when GUIDs differ |
| No event at the silence; step 4 prints a name; other steady textures also die | T3 — the review's attribution is wrong for this symptom | Run V11 (single `SetVibration` lifetime); compare with the pre-overhaul build (below) |
| No event; step 4 prints `nil` | T4 | Make `castTick` trust CastActivity's channel state instead of the `UnitChannelInfo` nil check |
| Fishing only | T5 (CR-001/CR-003) | Phase 1.3–1.4 |

**Optional A/B test of the "engine overhaul" claim:** install the build from just before the overhaul (`990a765`, 2026-09-24 20:28) in place of the current one, channel the same spell, then switch back. The offline prediction (A9) is that `990a765` behaves exactly like HEAD. If `990a765` hums through and HEAD does not, the overhaul is implicated after all and T3 moves to the top. (This replaces the installed addon folder — back it up first.)

### 11.6 If T3 is right (client or controller drops a steady rumble)

**What it would mean** ([Inference]): the addon keeps sending — the steady hum goes out about 28 times a second, and the 250 ms watchdog re-sends even an unchanged value (`Engine.lua:58`, `:480`) — but something between `C_GamePad.SetVibration` and the motor stops the rumble after about a second. Candidate layers, none visible from the repo: the WoW client (it may give each call a fixed lifetime, or skip calls whose value has not changed after rounding); SDL or the macOS GameController haptics path; Steam Input (for the Steam Controller 2); the controller firmware.

**What it would not mean:** the engine overhaul causing it. A9 shows the values sent for a steady channel hum are identical in every revision from `b39e6a6^` to the working tree. `ea0368a` only added sends (the watchdog). `Devices.lua` gained only `transientAttackTau` (`git show -w ea0368a -- PulseHaptics/Core/Devices.lua`). If T3 holds, the "after the overhaul" timing would come from outside the code: another pad or connection (USB vs Bluetooth), Steam Input on or off, a client patch, or a newly applied device preset. [Inference]

**Cheap cross-check, no debug tools:** press ▶ on any continuous texture (e.g. "In water"). That preview holds one unchanging level on both motors for 3.5 s (`Init.lua:242`, `:305`), refreshed only by the watchdog with the same value. If it buzzes the full 3.5 s on that controller, steady rumble survives there → T3 is effectively ruled out for that pad. If it cuts out after about a second → T3 is live.

**Measuring it (V11), Pulse switched off first so nothing else drives the motors** — each line pasted into chat on its own:
1. One call, no refresh — how long does it last? Stop it afterwards with the second line.
   ```
   /run C_GamePad.SetVibration("High",0.5)
   /run C_GamePad.StopVibration()
   ```
2. Same value re-sent every 0.25 s for 5 s — does it survive?
   ```
   /run C_Timer.NewTicker(0.25,function() C_GamePad.SetVibration("High",0.5) end,20) C_Timer.After(5.1,function() C_GamePad.StopVibration() end)
   ```
3. Value alternating 0.50 / 0.51 every 0.25 s for 5 s — does a tiny change keep it alive where test 2 failed?
   ```
   /run local n=0 C_Timer.NewTicker(0.25,function() n=n+1 C_GamePad.SetVibration("High",0.5+(n%2)*0.01) end,20) C_Timer.After(5.1,function() C_GamePad.StopVibration() end)
   ```
Run each on the DualSense and on the Steam Controller 2 (with and without Steam Input).

**Fix by outcome** ([Rec]; all in the engine's output stage, `Engine.lua:424-488`, testable offline once the rule is known):
| Test result | Meaning | Fix |
|---|---|---|
| 1 dies after ~1 s, 2 survives | Each call has a lifetime; re-sending refreshes it | Nothing to fix for the hum (the watchdog already refreshes). Look elsewhere (T1/T4). |
| 2 dies, 3 survives | The client skips repeated identical values | Make the watchdog keep-alive send a value that differs by one step (dither by ±0.004–0.01 at the watchdog), instead of the identical value. MicroFlutter becomes unnecessary (DOCS §4.1). |
| 2 and 3 both die | A new call does not restart an expired effect | Keep-alive must re-trigger: at the watchdog, send 0 for one frame then the value; measure whether that one-frame gap can be felt. |
| Only the Steam Controller 2 with Steam Input fails | Steam Input's translation times out | Document "turn Steam Input off for WoW", or apply the dither/re-trigger only when that device is detected. |

Whatever T3's outcome, CR-002 stays a real bug. In code, a tick spell's SUCCEEDED does stop the texture; only its share of this symptom depends on the tests.

### 11.7 Update from the live-install pass (§13, 2026-09-29)
- [Fact] `Interface/AddOns/PulseHaptics` has been a symlink to this repo since 2026-09-23 12:40, so from then on the game ran the working tree as it stood. A9's "the installed build lagged the repo" is ruled out from that moment on. Before it the folder was named `Pulse` (taint.log paths), and whether that was a copy is unknowable now.
- [Fact] Your debug output already contains the T1 test. `FireIfEnabled` prints `Pulse: <label> fired -> <MODE> (intensity x)` while `/pulse debug` is on (`Init.lua:86-88`). Both non-Default profiles in use have **"Your cast succeeded"** (fires on every player `UNIT_SPELLCAST_SUCCEEDED`, `Registry.lua:1199-1210`) and **"Instant ability used"** switched on. If one of those lines appears at the moment the hum stops, a SUCCEEDED arrived then → T1/T2. Channel on the character using the `Default` profile (both cues off there) and you get plain silence, as reported. A simple check: channel once on each character.
- [Inference] The saved castTexture settings ("Immersion: Caster": intensity 0.55, presence 0.07, master 1.0) keep both motor targets well above zero; settings cannot produce the silence.

---

## 12. Intensity sliders on the DualSense and Steam Controller 2 presets (2026-09-29)

**Question (user):** do the intensity sliders work on the DualSense / Steam Controller 2 presets — they "do not seem to modulate intensity that well, or break"?

**Method:** `slider-probe.lua` (scratchpad): real `Modes.lua`, `Devices.lua`, `Standard.lua`, `Engine.lua`; preset values applied exactly as `Database:ApplyDevicePreset` writes them (`Database.lua:1754-1776`); 60 fps; peak value sent per cue (discrete) or settled value (continuous). Every strength-related slider swept.

```
===== preset dualsense (applied)  =====
per-cue Intensity (master 0.70)      0.00   0.25   0.50   0.75   1.00   1.25   1.50
  TICK  (uiNavigate, damageTaken) Low  0.000  0.069  0.108  0.147  0.185  0.224  0.263   flat steps 0/6
  TAP   Low                         0.000  0.147  0.263  0.380  0.498  0.615  0.733   flat steps 0/6
  THUD  High                        0.000  0.181  0.332  0.484  0.636  0.743  0.743   flat steps 1/6
  HEAVY High                        0.000  0.208  0.386  0.565  0.743  0.743  0.743   flat steps 2/6
  channel hum (castTexture) High    0.000  0.066  0.101  0.137  0.173  0.208  0.244   flat steps 0/6
  In water (baseline 0.04) Low      0.000  0.038  0.046  0.053  0.061  0.069  0.077   flat steps 0/6
Overall intensity (cue 1.0)          0.10   0.25   0.50   0.70   0.85   1.00
  THUD High                         0.116  0.245  0.463  0.636  0.766  0.896   flat steps 0/5
  HEAVY High                        0.132  0.285  0.539  0.743  0.896  1.000   flat steps 0/5
High Strength/gain (THUD, cue 1.0)   0.00   0.50   1.00   1.50   2.00
  THUD High                         0.030  0.317  0.607  0.896  1.000   flat steps 0/4
Low Breakaway floor (TICK cue 0.3)   0.00   0.05   0.10   0.20   0.30   0.40
  TICK Low                          0.048  0.096  0.143  0.238  0.333  0.427   flat steps 0/5
Low Response curve (TICK cue 1.0)    0.40   0.70   1.00   1.50   2.00   2.50
  TICK Low                          0.495  0.299  0.185  0.092  0.055  0.040   flat steps 0/5
===== preset steamcontroller2 (applied) =====  (within ±0.01 of the DualSense rows; full output in scratchpad run)
  TICK Low 0.000 0.072 0.109 0.146 0.183 0.220 0.257 · THUD High … 0.638 0.744 0.744 · HEAVY High … 0.744 0.744 0.744
  In water Low 0.000 0.042 0.050 0.057 0.065 0.072 0.080 · Strength 0 → THUD High 0.035
```

**Verdict ([Fact] offline):** in code, every slider works on both presets — each one moves the output up or down steadily; none breaks. Why it still feels weak or broken:
1. **Dead top** on strong modes: HEAVY stops changing above 1.0, THUD above ~1.2 (CR-008 item 1).
2. **Small cues stay small:** TICK-based cues (uiNavigate, damageTaken, radialTick) reach at most 0.26 even at 1.5; each slider notch moves them by ~0.04.
3. **Continuous textures barely respond to their Intensity slider:** "In water" spans 0.038 → 0.077 across the whole slider on DualSense, because the preset's floor (0.030) dominates tiny values. The real knobs are the texture's own settings on the Continuous textures page (e.g. "Water presence").
4. **Intermittent breaks:** multi-step cues collapse under load (CR-013); ▶ previews of heartbeats, craft strikes and "Feels like" picks ignore the slider (CR-006, CR-014, CR-018); a profile switch changes Overall intensity (CR-008 item 5).
5. **New — CR-029 below:** Strength 0 does not silence a motor.
6. **[Unverified] hardware:** the DualSense and Steam Controller 2 preset numbers are guesses (`Devices.lua:160-162`, CR-019). If the pad's own rumble emulation squeezes the range (felt: "nothing … nothing … everything"), no slider maps well until the floor is measured with Ramp and the Response curve is set to match (§8 V4).
7. If "sliders" means moving them *with the controller*: the settings window is mouse-only by design (`UI/Panel/Gamepad.lua:69`, DOCS §4.7).

**What the user can do today, no code change** ([Rec]): use **Overall intensity** as the main strength knob (clean and steady from 0.1 to 1.0 on both presets); keep per-cue Intensity ≤ 1.0 on THUD/HEAVY-type cues; tune textures on the Continuous textures page; if quiet cues vanish and strong ones all feel alike, run **Ramp** on each motor and enter the breakaway value, then try **Response curve** 0.7 (lifts quiet cues: TICK 0.185 → 0.299 on DualSense).

### CR-029 [P2] A motor's Strength at 0 does not silence it — output sits at the breakaway floor
- **Verdict:** ungood; "Strength 0" reads as off but still vibrates on every cue using that motor.
- Where: `PulseHaptics/Core/Engine.lua:429-439`. Uncommitted: no. Since `110cebc` (calibration layer).
- What: [Fact] For any wanted value > 0: `wanted = clamp01(wanted * gain)` → 0 when gain is 0; then `floor + (1 − floor) * 0` = floor. The zero-in/zero-out guard (`:440-444`) checks the value *before* gain, so gain 0 cannot reach it.
- Evidence: `gain0-probe.lua`, Strength 0 on both motors, cue intensity 1.0:
  ```
  default           Strength 0 on both motors -> THUD High 0.000   TAP Low 0.000
  dualsense         Strength 0 on both motors -> THUD High 0.030   TAP Low 0.030
  steamcontroller2  Strength 0 on both motors -> THUD High 0.035   TAP Low 0.035
  ds4               Strength 0 on both motors -> THUD High 0.100   TAP Low 0.118
  xbox              Strength 0 on both motors -> THUD High 0.100   TAP Low 0.118
  8bitdo            Strength 0 on both motors -> THUD High 0.120   TAP Low 0.137
  ```
- Failure scenario: an Xbox/DS4/8BitDo user sets the High motor's Strength to 0 to mute it → every High cue still buzzes at 10–12 %, the same level whatever the cue. On the LRA presets (0.03) it is probably below feel ([Unverified]).
- Related: CR-008 (floor lift), DOCS §4.1 "Floor linear lift → dead-zone curve". New.
- Fix direction: [Rec] Return 0 when `wanted * gain` is 0 (apply gain before the zero check); or treat Strength 0 as channel-off; add an engine-test row.

**Counts after §12:** P0 0 · P1 6 · **P2 14** · P3 9 · **total 29** (18 wholly new, 9 extend earlier documents, 2 known).

### 12.1 In-game observation: low Overall intensity (user, 2026-09-29)

**User report:** "Adjusting intensity to 0.05 master, cue intensity slider did not meaningfully change the strength on Steam Controller 2 and DualSense. Dropping it to 0 silences it though."

**What the engine sends** (`lowmaster-probe.lua`; real engine, preset values as applied; peak per cue; cue intensity 0.10 / 0.50 / 1.00 / 1.50):
```
dualsense  master 0.05  preset floor    TICK 0.031 0.035 0.041 0.047 · TAP 0.033 0.047 0.063 0.080 · THUD 0.034 0.051 0.073 0.081
dualsense  master 0.05  floor set to 0  TICK 0.001 0.005 0.011 0.016 · TAP 0.003 0.016 0.034 0.052 · THUD 0.004 0.021 0.044 0.052
dualsense  master 0.70  preset floor    TICK 0.045 0.108 0.185 0.263 · TAP 0.077 0.263 0.498 0.733 · THUD 0.090 0.332 0.636 0.743
steamcontroller2  master 0.05  preset floor    TICK 0.036 0.040 0.045 0.051 · TAP 0.038 0.051 0.067 0.082 · THUD 0.039 0.056 0.078 0.085
steamcontroller2  master 0.70  preset floor    TICK 0.050 0.109 0.183 0.257 · TAP 0.079 0.257 0.481 0.704 · THUD 0.095 0.335 0.638 0.744
```
(master 0.20 rows and the Steam Controller 2 floor-0 rows are in the scratchpad run; same pattern.)

**Reading ([Fact] for the numbers, [Inference] for the feel):**
1. **At master 0.05 the cue slider is squeezed by design.** Overall intensity multiplies everything (`Engine.lua:602`), so every cue lands between 0.03 and 0.085 and the whole cue slider moves a cue by only 0.015–0.048. The preset floor (0.030/0.035) makes it worse relative to the band: the band starts at the floor, so the slider changes a TICK by ×1.5 instead of ×15 with floor 0. Removing the floor does not widen the band in absolute terms.
2. **"0 silences it"** matches the code, whichever slider "it" was: cue Intensity 0 makes the mode scale 0 (`Init.lua:82` → `PlayMode`), Overall intensity 0 makes `channelMag` 0 (`Engine.lua:602-603`); either way the channel gets no target, `driveChannel` takes the `wanted > 0` false branch (`Engine.lua:429`) and the floor lift never runs. 0.01 would already be lifted to ≥ the floor. A motor's Strength at 0 does not reach 0 (CR-029).
3. **If moving Overall intensity itself from ~0.7 down to 0.05 also felt about the same** — the engine drops a THUD from 0.636 to 0.073 (≈ 9×) and a TAP from 0.498 to 0.063 (≈ 8×). A pad that feels those as nearly equal is compressing its own range: nearly any non-zero rumble is played at a similar strength. That is on the controller/driver side (DualSense rumble emulation, Steam Controller 2 haptics, Steam Input), not a slider bug, and it matches the unmeasured presets (CR-019, §8 V4). [Unverified]

**Diagnosis on the pad** (with the Controller calibration page open), plain steps:
1. Set Overall intensity to 0.7 and test one cue at Intensity 0.25 and 1.0. Clearly different → the sliders work, and 0.05 was simply too low to leave room (point 1). About the same → point 3.
2. Press **Ramp** on each motor. Note the first value you feel (threshold) and the value where it stops getting stronger (saturation). Ramp climbs in 0.01 steps to 0.40 (`Devices.lua:149-151`) and sends raw values that skip Strength, floor and curve (`Engine.lua:425`), so the printed numbers are what the pad received. If it is still getting stronger at 0.40, saturation is above 0.40; skip step 4.
3. Enter the threshold as that motor's **Breakaway floor**.
4. If saturation is low (for example 0.20), set that motor's **Strength** to roughly the saturation value (0.2), so full-strength cues land at the pad's top instead of far past it; then raise Overall intensity back towards 1.0.
5. Steam Controller 2: repeat once with Steam Input disabled for WoW, and check Steam's own controller rumble/haptics strength setting.

**Fix direction** ([Rec], offline-codeable once 2–4 give numbers): per-channel calibration needs a *ceiling* (saturation point) as well as a floor, and a curve that maps 0–1 onto [threshold, saturation] — today `gain` stands in for the ceiling and the linear floor lift compresses the low end (CR-008 b). Presets should store measured threshold and saturation per pad. Add an engine-test asserting that cue output scales in proportion to Overall intensity down to 0.05 (no floor intrusion), or document that the floor is a deliberate minimum.

### 12.2 Live install and SavedVariables snapshot (read-only, 2026-09-29)

**Install ([Fact]):** `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/` holds `PulseHaptics`, `PulseDebug` and `PulseChecklist` as symlinks into this repo (created 2026-09-22/23), so the game runs the working tree — HEAD `ac3d02f` plus the uncommitted WIP — which is the tree this review read. `PulseProfileReview` there is a plain copy, `diff -rq` identical to the repo's untracked `PulseProfileReview/`. Also installed, not in the repo: `QA/WoWForeverGamepadQA`, `QA/WoWForeverRadialQA` (unread).

**Settings ([Fact]):** `WTF/Account/<account>/SavedVariables/PulseHaptics.lua`, last written 2026-09-28 22:41, holds `devicePreset = "xbox"` and a global `channelTuning` equal value-for-value to the Xbox preset (`Devices.lua:186-187, 246-257`):

| Channel | floor | gain | attackTau | transientAttackTau | releaseTau | DualSense preset for comparison |
|---|---:|---:|---:|---:|---:|---|
| Low | 0.12 | 1 | 0.090 | 0.025 | 0.060 | floor 0.030, gain 1.15, attack 0.015, transient 0.006, release 0.012 |
| High | 0.10 | 1 | 0.050 | 0.012 | 0.035 | floor 0.030, gain 1.05, attack 0.012, transient 0.006, release 0.010 |
| L/RTrigger | 0.15 | 1.2 | 0.040 | 0.012 | 0.030 | — (DualSense preset has no trigger channels) |

Profile `masterIntensity` values in the file: 0.7 (most), 0.65, 1 — no 0.05, so the §12.1 test happened after this write (SavedVariables are written only on logout, `/reload` or exit). **Which preset was applied during the user's DualSense/Steam Controller 2 tests is therefore [Unverified]**; the file only shows it was Xbox at 22:41 on 2026-09-28. Detection never applies a preset by itself (`Spec.lua:1592-1627`), so Xbox was applied by hand. Under Steam Input both pads can report as an Xbox controller (CR-019), which would make "Xbox" the row Detect suggests. [Inference]

**Same probe as §12.1 with the Xbox tuning** (`lowmaster-xbox-probe.lua`; cue Intensity 0.10 / 0.50 / 1.00 / 1.50):
```
xbox  master 0.05   TICK Low 0.089 0.092 0.095 0.098 · TAP Low 0.120 0.131 0.144 0.157 · THUD High 0.104 0.119 0.138 0.144
xbox  master 0.20   TICK Low 0.091 0.101 0.114 0.127 · TAP Low 0.128 0.171 0.223 0.276 · THUD High 0.115 0.176 0.252 0.279
xbox  master 0.70   TICK Low 0.097 0.134 0.179 0.224 · TAP Low 0.154 0.302 0.485 0.668 · THUD High 0.153 0.366 0.635 0.729
```
At master 0.05 the whole cue slider moves a TICK by 0.009 (the Low channel's 0.025 s transient attack never lets a TICK reach even the 0.12 floor), versus 0.016 with the DualSense preset. Every cue at master 0.05 sits at 0.09–0.16, three to four times the DualSense values.

**Consequences if Xbox tuning was live during the QA ([Inference]):**
- Q2 (sliders "very inconsistent" on DualSense / Steam Controller 2): the ERM floors (0.10–0.12) are 3–4× the LRA ones, so the §12.1 squeeze is much stronger — the user's report matches this table better than the DualSense one.
- Q3 (footsteps not crisp): the Low motor's continuous attack is 0.090 s instead of 0.015 s (6× slower), and the transient attack 0.025 s instead of 0.006 s. Footfalls ride the continuous smoothing path (CR-005), so each step rises about 6× more slowly than it would with the DualSense preset.
- None of this touches Q1 (channel silence): the castTexture teardown in CR-002 does not depend on tuning.

**Action for the user:** say which preset was applied during each test. If it was Xbox on the DualSense or Steam Controller 2, apply the matching preset, `/reload`, and repeat the §12.1 steps before judging sliders or footsteps.

---

## 13. Third pass — live settings, client logs, old notes, QA addons (2026-09-29, user ordered items 1, 2, 4, 3)

Read-only throughout. Nothing in the game folder was changed; probes in the session scratchpad (`sv-diff.lua`, `sv-cues.lua`, `sv-defect.lua`, `gait-user-probe.lua`, `gait-split-probe.lua`, `doc-events.lua`, `utf8-probe.lua`). Personal details from the game folder (account id, character names) are left out on purpose.

| # | Item | Status | Result |
|---|---|---|---|
| 1 | Live `PulseHaptics.lua` SavedVariables | done | Xbox preset (§12.2); low locomotion intensity; T1 test already in the debug output (§11.7); CR-030 |
| 2 | Client logs, crash dumps, config | done | taint.log explained → CR-031; no crash involves Pulse; Steam launched WoW on 09-27 |
| 4 | Unread old notes | done | no new defect; every checked item fixed or tracked; T6 added and ruled unlikely |
| 3 | QA addons in the install | done | neither is loaded; no vibration measurements in them; V11 stays open |

### 13.1 Live settings (item 1)
**Method.** `sv-diff.lua` loads the real `Init`/`Database`/`Registry`, seeds a fresh database from current code, loads the saved file into a sandbox and diffs every profile (cue on/off, every tunable, mode overrides).

**Integrity ([Fact]).** `version = 7` (current `DB_VERSION`). In all 13 profiles, no cue id is unknown to the Registry and none is missing. Nine profiles equal the current seed exactly. One orphan key: `craftTexture.p6_gain = 1.35` in "Immersion: Caster" — no code reads it, so it is harmless. The migrations are goodthink.

**Who uses what.** Three characters: one on `Default` (Overall 0.7), one on "Immersion: Caster" (Overall **1.0**), one on the custom "Immersion: Ranged actual" (Overall 0.65). Global: `devicePreset = "xbox"` with Xbox tuning (§12.2), schema `standard`, `locomotionProfile` = Skyborne / riding tier 0 / armour 0.6 (barefoot). The locomotion profile is account-wide and rewritten by whichever character logged in last. The built-in "Immersion: Ranged" differs from its seed by 38 cues switched on and 17 off — user edits, which a Reset would discard.

**User changes that matter for the QA reports:**

| Profile | Cue | Saved | Stock |
|---|---|---|---|
| Immersion: Caster | castTexture | intensity 0.55, castPresence 0.07, castSwellPeak 0.9 | 1.0, 0.1, 0.7 |
| Immersion: Caster | locomotion | intensity **0.15**, gaitIntensity 1.0, mountedOnly 0 | 1.0, 0.35, 1 |
| Immersion: Ranged actual | locomotion | intensity **0.15**, gaitIntensity **0.2**, mountIntensity 0.45, mountedOnly 0 | 1.0, 0.35, 1.2, 1 |
| both | selfCastSucceeded / selfCastInstant | on (TRIPLE_TAP ×1.4 / CRACK) | off |
| Immersion: Ranged actual | waterTexture | intensity 0.05 (cue off) | 1.0 |

**Footsteps with these settings** (`gait-user-probe.lua`; real `Devices`, `Standard`, `Engine`, `Locomotion`; Skyborne, barefoot, running 7.0, 60 fps; per-cue intensity applied as `Init.lua` does):
```
Immersion: Caster        running  xbox             Low 2.7/s 0.006..0.129 | High 2.7/s 0.000..0.137
Immersion: Caster        running  dualsense        Low 5.3/s 0.031..0.108 | High —
Immersion: Caster        running  steamcontroller2 Low 5.3/s 0.036..0.106 | High —
Immersion: Ranged actual running  xbox             Low 2.7/s 0.000..0.110 | High 3.0/s 0.000..0.100
Immersion: Ranged actual running  dualsense        Low 5.3/s 0.030..0.040 | High —
Immersion: Ranged actual running  steamcontroller2 Low 5.3/s 0.035..0.044 | High —
```
Reading:
- [Fact] With the DualSense preset, "Immersion: Ranged actual" footfalls move between 0.030 and 0.040. That is a buzz at the floor with a 0.010 bump on top, five times a second. The stock-settings run in CR-005 moves between 0.011 and 0.280.
- [Inference] On DualSense and Steam Controller 2, "not crisp" is therefore three things stacked: CR-005 (doubled cadence, slow continuous attack), the floor lift keeping the motor on between steps (CR-008 b), and the saved locomotion intensity of 0.15.
- [Fact] With the Xbox preset, the feet split across Low and High and each motor drops to 0 between its own steps (CR-030). That is more on/off than the DualSense preset, but with unequal feet.

**Emote cue ([Fact]).** The emote-mention pattern `%f[%a]<name>%f[%A]` (`World.lua:57-58`) never matches a name whose first letter is non-ASCII. That is true of one of the three characters (`utf8-probe.lua`: false under both LuaJIT and Lua 5.4; a plain substring search matches). The issue is already tracked in DOCS §3 as the "UTF-8 frontier pattern" minor; now it is known to hit this account.

**Cues from known findings that are on in the profiles in use** (`sv-defect.lua`): CR-009 UI cues (`popupShown`, `panelOpen`, `uiTabChanged`) in all three; `targetBigDefensive` (CR-010) in two; `castTexture` (CR-001/002) and `craftTexture` (CR-014) in all three; `locomotion` (CR-005), `breathTexture` (CR-012) and `lowHealthTexture` (CR-006) in the two Immersion profiles; `weatherTexture` (CR-026) and `lowHealthWarning` (CR-006) in "Immersion: Caster". None of the profiles has `bossAbilityWarning` (CR-007) or `emote` (CR-011) on.

### CR-030 [P3] Split footfalls follow the preset's trigger flag, not the schema: with an Xbox preset on the default Standard schema, left feet go to Low and right feet to High
- Where:
  - `PulseHaptics/Modules/Locomotion.lua:373-382`: `shouldSplitFeet` reads `preset.triggers` only;
  - `Locomotion.lua:517-522`: `ltrigger`/`rtrigger` roles;
  - `PulseHaptics/Core/Engine.lua:127`: `ROLE_FALLBACK` maps `ltrigger → low`, `rtrigger → high`, applied in `resolveRole` (`:129-140`);
  - `PulseHaptics/Core/Schemas/Standard.lua`: roles `low`/`high` only.
  
  The module's own comment (`Locomotion.lua:365-369`) calls this outcome "a limp rather than a gait, worse than not splitting". Uncommitted: no.
- What: [Fact] `xbox` and `xbox_elite` have `triggers = true`. Under the default `standard` schema the split turns on, and both trigger roles fall back to the rumble pair. `gait-split-probe.lua` (stock settings, Human, running 7.0, Overall 0.7):
  ```
  default     Low 5.3/s 0.012..0.128 | High —
  xbox        Low 2.7/s 0.007..0.193 | High 2.7/s 0.000..0.229
  xbox_elite  Low 2.7/s 0.007..0.193 | High 2.7/s 0.000..0.229
  dualsense   Low 5.3/s 0.011..0.280 | High —
  ```
  The right foot hits about 19 % harder on the signal alone, before any difference between the heavy and light motors. The user's saved state is exactly this combination (§12.2).
- Differs from CR-020, where the preset is only selected in the dropdown. Here the preset is applied, but the active schema does not route trigger roles to trigger motors. Apply shows a tip to switch schema (`Spec.lua:1577-1580`), but it only advises and is easy to miss.
- **Verdict:** crimethink — the veto checks the hardware, but not the routing it depends on.
- Fix direction: [Rec] Split only when `resolveRole(schema, "ltrigger").channel` is a trigger channel. Otherwise send both feet to one role, or deliberately onto Low/High for symmetric pads (CR-005 fix 3). Add a locomotion-test case: no split under `standard` for any preset.

### 13.2 Client logs, crash dumps, config (item 2)
**taint.log** (only entries 2026-09-23 08:41, build still named `Pulse`, before the rename):
- 4 × `An action was blocked because of taint from Pulse - Frame:RegisterEvent()` at `Core/Init.lua:309` (the generic watcher's `frame:RegisterEvent(event)` at that revision, `3f6bdd3`), reached from three places:
  - `AlertSocial` `OnEnable` at load;
  - a profile switch (`RefreshActiveProfile`);
  - the minimap master toggle, twice.
- 1 × `Execution tainted by Pulse while reading field RawChannel … hooksecurefunc() PulseDebug/UI.lua:299`: benign (a hook on an addon table).

Cause → CR-031. `taintLog` is not set in `Config.wtf` now, so nothing has been logged since. The absence of later entries says nothing.

**FrameXML.log:** one line, 2026-09-21: `WoWForeverRadialQA.toc:6 Error loading … WoWForeverRadialQA.lua` (§13.4). Not Pulse.

**Crash and error dumps (6 files) — none involves Pulse ([Fact]):**

| File | What | Pulse? |
|---|---|---|
| `2026-09-21 09.02.42 Crash.txt` (install root) | Battle.net launcher bootstrapper, SIGTERM hang | no (launcher) |
| `…_09-21_10.15.26_Crash_44311` | SIGTERM [HANG] | no stack; no evidence |
| `…_09-23_00.58.36_Error_16910` | ERROR #109 freeze, 20 s | no stack; no evidence |
| `…_09-24_21.53.06_Error_52050` | `ASSERTSAFE` in `SmallMemAllocator.cpp:905` | `<Addons.HasAny.Loaded> No`, `CharLogins 0`, time in world 0 → before any addon loaded |
| `…_09-25_07.25.20_Error_56756` | same assert, `:920` | same → before addons |
| `…_09-27_21.09.06_Crash_74156` | `SIGINT: Interrupt from com.valvesoftware.steam` | no. [Fact] Steam started (and stopped) WoW that evening → Steam Input was probably in the path (V12, CR-019) |
| `…_09-27_21.41.24_Error_76985` | main thread frozen 20 s in IOKit → `AppleSyntheticGameControllerLib`, 44 s after launch | addons not loaded. [Inference] A virtual (synthetic) game controller was present, and its driver hung the client at start-up. Not Pulse, but relevant to the Steam Controller 2 / Steam Input setup |

**Config:**
- no saved `GamePad*` vibration CVar (V5: default strength);
- `GamePadConfig_Default.json` holds only the generic "All Devices" config;
- `gamecontrollerdb.txt` has the header only.

### CR-031 [P3] "Ping placed" can never fire on Forever: its only real event is registration-restricted, and switching it on produces blocked-action messages
- Where:
  - `PulseHaptics/Core/Registry.lua:1728-1739` (`events = { "UNIT_PING_PIN_ADDED", "PING_PIN_ADDED" }`);
  - `PulseHaptics/Core/Init.lua:325-350` (`WatchTrigger` sync; registration wrapped in `pcall`).
  
  Forever: `Blizzard_APIDocumentationGenerated/PingManagerSecureDocumentation.lua:251-255` (`UNIT_PING_PIN_ADDED`, `HasRestrictions = true`, documented in the *Secure* ping manager). Uncommitted: no.
- What:
  - [Fact] A parse of every Forever event doc (`doc-events.lua`) finds 7 events with `HasRestrictions`. `UNIT_PING_PIN_ADDED` is the only one Pulse uses.
  - [Fact] `PING_PIN_ADDED` does not exist on Forever (CR-024).
  - [Fact] At `3f6bdd3`, the only restricted event in `ALERT_SOCIAL` was `UNIT_PING_PIN_ADDED`, and taint.log shows exactly that registration line being blocked.
  - [Inference] The client refuses the registration. `pcall` cannot help, because a blocked action is not a Lua error. The client prints "Interface action failed because of an AddOn" and marks Pulse in the AddOn tooltip (`Blizzard_Game/Mainline/EventImplementation.lua:375-378` → `DisplayInterfaceActionBlockedMessage`).
- Impact:
  - The cue is dead whenever it is on.
  - It is off by default and off in all 13 of the user's profiles → no effect today.
  - It explains the 09-22/23 report "blocked action when turning haptics ON from the minimap". This is the runtime evidence `docs/dev-notes/Pulse Minimap Button — Forbidden Action and Rendering Investigation.md` §7/§16 asked for: only the ON path re-registers events.
  - The `4c5991e` removal of `pingPinAdded` from five profiles is why the message stopped. The `pcall` guard (`dffdb83`) is not.
  - Whether the popup the user saw on 09-22 ("blocked from an action only available to the Blizzard UI", i.e. FORBIDDEN rather than BLOCKED) came from this or from the SmartNavigation callbacks (`d9f590f`, §13.4) is [Unverified].
- **Verdict:** ungood (dead feature), low severity.
- Fix direction: [Rec] Remove the cue, or mark it unavailable on Forever and skip registration. Teach `cue-audit` to flag events documented with `HasRestrictions` (and the other 6 found).

### 13.3 Old notes (item 4)
**Read in full:** all 13 files in `docs/dev-notes/`, including the 204-line `Luaerrorissues.rtf` (via `textutil`), plus `Cooking/midnight_controller_haptics_event_findings.md` (1,552 lines) and `Cooking/Overhual casting detectioncraftingetc.lua` (367 lines). The other ~45 files in `Cooking/` are not read.

**Result:** no new defect. Every concrete claim spot-checked against current code is fixed or already tracked in DOCS:

| Claim (source) | Now |
|---|---|
| `threatLost` lost when threat → nil (Iterative QA I-03) | fixed: `AlertThreat.lua:58` treats nil as 0; transitions checked at `:63-68` |
| emote cross-realm sender (Code-Review 5.1) | fixed: `Ambiguate`, `World.lua:52` |
| swing-range secret guard (Audit T-01) | fixed: `Combat.lua:943` |
| Encounter `sync` wipes live state (cloud #4) | fixed: only when disabled, `Encounter.lua:72-75` |
| Flight never reseeds mount state (cloud #8) | fixed: `Flight.lua:28-29` |
| `LowOnly` not mirroring `HighOnly` (cloud #2) | fixed: `high` 0.6, `LowOnly.lua:19` |
| `CastActivity:SetActive` refcount (cloud #1/#5) | fixed: keyed consumers (DOCS §4) |
| `TRADE_SKILL_CRAFT_BEGIN` "unknown event" (Luaerrorissues errors 1–3, 09-22) | fixed: plain `RegisterEvent` (`CastActivity.lua:421`); event exists on Forever |
| breath "dub" timer untokened (Iterative QA M-02) | still open, `Environment.lua:153`; tracked in DOCS |
| UTF-8 frontier pattern (Iterative QA M-03) | still open; now shown to hit this account (§13.1) |
| `isTradeskill` is `NeverSecret` on both cast APIs (Verification 7.1) | used: `Crafting.lua:542-559` |

**Three contributions:**
1. The minimap investigation's missing evidence is taint.log → CR-031.
2. The stale-craft hypothesis (Regression Investigation §4; Crafting/Casting Assessment) is now T6 in §11.3 and ruled unlikely.
3. The overhaul prototype is where the channel model came from; its `OnSucceeded` (`:155-194`) has the same fall-through to INSTANT for an unmatched SUCCEEDED (already cited in CR-001).

The haptics-findings document is a design catalogue. It contradicts nothing in the code.

### 13.4 QA addons in the install (item 3)
- [Fact] Both sit in `Interface/AddOns/QA/`, one folder too deep. The client loads only top-level addon folders, so neither has loaded since `QA/` was created (2026-09-22 09:36, mtime) [Inference from the loader rule]. Neither has SavedVariables.
- `WoWForeverGamepadQA` v0.2.2: diagnostics only, and it never calls a vibration API.
  - It does register `SmartNavigation`, `GamepadMode` and `EventRegistry` callbacks, the same path `d9f590f` and `outstanding.md` §11 found raising ADDON_ACTION_FORBIDDEN on gamepad deactivation. While it was loaded (until 09-22) it may have contributed to the forbidden-action popups [Inference].
  - The `.md` file is an older copy (v0.2.0) of the same Lua, confirmed by diff.
- `WoWForeverRadialQA`: its TOC names `WoWForeverRadialQA.lua`, which does not exist → the FrameXML.log error. The file that is there holds the radial probe and a swing proof of concept.
  - The proof of concept calls `C_GamePad.SetVibration(type, 0.35)` once per `PLAYER_SWING` and never stops it.
  - Its `/psv stop` passes an argument to `StopVibration`, which takes none (`GamePadDocumentation.lua:288-290`).
- [Fact] No Blizzard UI Lua in the Forever source calls `SetVibration` or `StopVibration`, so there is no in-client reference for pulse lifetime. **V11 and the trigger question stay open.** Nothing here measures vibration.

### 13.5 Counts and plan impact
Two new findings (CR-030, CR-031), both P3 → 31 total (P0 0 · P1 6 · P2 14 · P3 11; 20 wholly new). New unverified item V12. Plan impact:
- Phase 3 (footsteps) gains CR-030 and should start from the user's own locomotion settings.
- Phase 5 (dead features) gains CR-031.
- Phase 7's first step is V12: the preset and Steam Input state during each test.

---

## 14. Review of `Ongoing Bugs/` (2026-09-29, user request "Review ongoing bugs")

Read-only. The folder is untracked (not in `git status` at session start) and holds bug reports written 2026-09-24 → 09-26, i.e. **before** DOCS_COMPILATION and this review. Every claim was checked against the current tree (HEAD `ac3d02f` + uncommitted WIP).

### 14.1 Inventory and coverage
| File | Date | What it is | Read |
|---|---|---|---|
| `PulseHaptics ongoing bug review.md` | 09-26 | static review of `CastActivity`/`Engine` (P1 keyFor, P2 sweep, P2 raw output, P3 header) | full |
| `PulseSensation_Post_Implementation_Haptic_Engine_Review.md` | 09-24 | review of `ea0368a` (5 items) | full |
| `pulsehaptics-bug-report.md` + `pulsehaptics-engine-bug-report.mmd` | 09-25 | ENG-01/02/03, CA-01, DB-01 (the `.mmd` is the same report as a diagram) | full |
| `eng-01-fix-draft.md` | 09-26 | proposed patch for ENG-01 | full; reviewed in §14.3 |
| `pulsesensation_critical_code_review.md` + `gemini-code-1790281723009.md` | 09-24 | 6-item critical review (the gemini file is a truncated copy of its item 1) | full |
| `newBugs.md.rtf`, `moreNewBugs.rtf`, `Untitled.rtf` | 09-24 | 2 + 4 items (Untitled repeats moreNewBugs with "consequences") | full (raw RTF) |
| `jk.rtf` | 09-26 | chat transcript: 5 ideas + a review (4 items) + a self-correction | full (raw RTF) |
| `codingdoctorbot-pulsesensation-8a5edab282632443.txt` (968 KB) | 09-24 | repo snapshot for feeding an AI (directory tree + file bodies), not a bug report | header only |
| `WoWAddonAPIAgents-main/`, `wow-addon-dev-main/` | — | third-party AI-agent reference kits for WoW addon work | **not read** (not bug reports) |

### 14.2 Claim ledger (deduplicated)
| # | Claim (source) | Verdict now | Evidence | Tracked as |
|---|---|---|---|---|
| 1 | ENG-01: pooled role tables recycled under pending timers (bug-report, `.mmd`, fix draft) | **open** | `Engine.lua:200-212`, `:379`, `:405-409` unchanged | CR-013 (known) |
| 2 | ENG-02 + "time-dilation step collapse": sub-frame steps expire unseen; same-frame timers overwrite one layer (bug-report, moreNewBugs, Untitled) | **partial** | WIP floors: step ≥ 0.020 s, gap ≥ 0.025 s (`Engine.lua:367-377`). Duration slider 0.25–3.0 (`Spec.lua:1424-1430`). [Inference] Covers ≥ ~50 fps only: below that, a 20 ms step set by a timer can expire before the next tick reads it, and two steps whose timers fire in the same frame overwrite the same layer (all steps share one name). The spacing guard is dead (DOCS §10.2) | DOCS §10.2 (extended here) |
| 3 | ENG-03 / ongoing-review P2: raw-path `SetVibration` unguarded → error reaches the `OnUpdate` pcall → `StopAll` kills every live cue, silently unless debug (bug-report, ongoing review) | **open**, consequence confirmed | bare calls `Engine.lua:518`, `:529`; recovery `:651-666` calls `StopAll`, prints only `if Pulse.debug`. **New angle:** the calibration page gives every channel, including "Left/Right trigger (unconfirmed)", a Test and a Ramp button on this raw path (`Spec.lua:1629-1655`). [Unverified] If Forever *throws* on an unaccepted vibration type, pressing Test on a trigger row silently cancels every live cue — and that throw is exactly the answer to the unconfirmed-trigger question, currently thrown away | DOCS §4 "pcall around C_GamePad PARTIAL", §6 re-confirmed (extended here) |
| 4 | CA-01 / moreNewBugs #1: 10 s sweep drops Hearthstone-length casts | **mostly fixed in WIP** | `STALE_TIMEOUT` 30 (`CastActivity.lua:35`), active-cast protection `:333-339`. Remaining: hard 60 s cap ×3, and one flag protects every entry (`:343`, `:349`, `:355`) (ongoing review P2). [Inference] Real channels that reach 60 s end there anyway, so the impact is small | DOCS §10.2 |
| 5 | `keyFor` stringifies possibly secret GUID/spellID (ongoing review P1) | **open**, client-dependent | `CastActivity.lua:65-70` | DOCS §4 P1-04; CR §10 A1 |
| 6 | Engine header says "max-blend" (ongoing review P3) | **confirmed, new** | `Engine.lua:5` ("named layers, max-blend"); the `:417-421` comment also says layers collide "via max". Layers actually use a saturating sum (`:562-564`); only role→channel collisions are max (`:605-607`) | extends CR-025 |
| 7 | DB-01 / moreNewBugs #3: `RenameProfile` never notifies | **fixed in WIP** | `Database.lua:1449-1453`; the harness asserts it | DOCS §10.2; remainder CR-021 |
| 8 | moreNewBugs #4: watchdog drops a new input equal to the decayed value | **not a bug** | when `delta <= epsilon`, the motor already has that value; onsets force a send (`Engine.lua:469-486`). The 09-25 bug report reached the same verdict | — |
| 9 | critical review #1: `PlayMode` breaks zero-GC | **partial** | step tables now pooled (`:379`) — which introduced ENG-01; one closure per delayed step remains (`:405`). Textures verified allocation-free (A4) | DOCS §4.8 → PARTIAL (A4) |
| 10 | critical review #2: 1-frame lag on transients | **fixed** | `Engine.lua:398-402` (`f447944`) | — |
| 11 | critical review #3: stuck motor below the silence gate | **fixed** | `Engine.lua:456-467` | — |
| 12 | critical review #4: MicroFlutter phase loses precision at large `GetTime()` | **not a bug as stated** | Lua numbers are doubles: at 10⁶ s of uptime the phase is ~4.4·10⁷ rad with a spacing of ~10⁻⁸ rad. The `% TWO_PI` (`Waves.lua:169`) is applied after the product, so it changes nothing, and nothing needs changing | — |
| 13 | critical review #5: `HoldRoles(…, 0)` makes a dead layer | **fixed** | `Engine.lua:266-269`, `:243` | — |
| 14 | critical review #6: `UnitIsUnit` as proxy for `RegisterUnitEvent` | **fixed** | `CastActivity.lua:414` checks `frame.RegisterUnitEvent` | — |
| 15 | newBugs #1: PulseDebug HOLD logging allocates every frame | **open** | measured +134.7 KB/s (A4) | CR-016 |
| 16 | newBugs #2: `"xinput"` matched before `"8bitdo"` | **confirmed, new, low impact** | `Devices.lua:356-361`. Only reached when vendor+product are unknown (step 1 runs first, `:461-466`); an 8BitDo in XInput mode usually reports Microsoft `045E:028E` and becomes Xbox at step 1 anyway. Detect only suggests (`:340-341`) | extends CR-019 |
| 17 | post-impl #1: raw holds bypass the watchdog | **fixed** | the raw path re-sends every 250 ms (`Engine.lua:524-533`) | — |
| 18 | post-impl #2: one transient switches the **whole channel** to the fast attack | **confirmed** | `channelHasTransient` (`:608-610`) → `transientAttackTau` for everything on that channel (`:449-450`); a continuous baseline rising under an impact snaps up. Not a true two-lane envelope | extends CR-012 |
| 19 | post-impl #3: short duration implies transient | **fixed** | `SetRoles` sets `isTransient` explicitly only (`:245`) | — |
| 20 | post-impl #4: role→channel collisions still use MAX | **confirmed, by design** | `Engine.lua:605-607` | DOCS §4 / §6 #1 mixer decision |
| 21 | jk.rtf: README "202 triggers, 21 categories" stale; triggers unconfirmed; swing = swing not hit; riding-tier ids unconfirmed | **stale docs re-confirmed**; the rest are known [Unverified] items flagged in code comments | README `:72`; 190 cues (CR §6) | CR §6, DOCS §7 |
| 22 | jk.rtf ideas: priority ducking, spatial L/R, curve preview, load telemetry | design ideas, not bugs. Ducking contradicts the stated "continuous baseline is NEVER muted or ducked" (`Engine.lua:573`), as jk.rtf itself concluded. A curve preview would help with CR-008 | — | DOCS §6 |

**Re-confirmed while verifying (already CR-025):** the Ramp button's tooltip says "Climbs this motor slowly from silence to half power over eight seconds" (`Spec.lua:1657-1658`). The ramp actually climbs to 0.40 in 0.01 steps every 0.4 s, about 16 s (`Devices.lua:149-151`; the engine's own comment says "a sixteen-second ramp", `Engine.lua:755-756`). Still unfixed.

### 14.3 The ENG-01 fix draft
[Fact] It targets the right lines (`Engine.lua:376-412`) and removes the aliasing:
- **Immediate steps** keep the pooled table. That is safe because `SetRoles` copies values into `layer.roles` before returning (`:237-242`).
- **Delayed steps** capture scalars and build a private table when the timer fires. Nil roles become absent keys, which `SetRoles` handles.

Cost: one small table per *fired* delayed step, on top of the closure that already exists. That is negligible at step rate.

It does **not** address ENG-02 (#2) or the channel-level attack (#18), and it adds no test. [Rec] Take it as the CR-013 fix. Turn the scratchpad `pool-probe.lua` scenario (two layers, more than 16 draws inside a pending window) into an `engine-test` case in the same commit. Once the pool is used only synchronously, one scratch table could replace the whole pool.

### 14.4 Outcome
- No new CR: 31 findings, unchanged.
- Five extensions:
  - #2 → DOCS §10.2;
  - #3 → the raw-path `pcall` item;
  - #6 → CR-025;
  - #16 → CR-019;
  - #18 → CR-012.
- Of the 22 claims:
  - fixed: 7 (#7 in the WIP);
  - mostly fixed in the WIP: 1 (#4);
  - partial: 2;
  - open and tracked: 4;
  - confirmed, newly recorded: 3 (#6, #16, #18);
  - confirmed by design: 1 (#20);
  - not a bug: 2 (#8, #12);
  - known docs or [Unverified] items: 1 (#21);
  - ideas: 1 (#22).
- The folder has served its purpose; everything still actionable is now in this report. [Rec] Commit it, move it into `docs/`, or delete it — the user's decision; untouched here.
