# Review: `brainstormingcuepolish.md` — Smart Cue Polish & Architectural Blueprints

> **Reviewed document:** `brainstormingcuepolish.md` (repository root, untracked, 503 lines)
> **Code baseline:** `441f4f3` on `main` (2026-09-30). Working tree at review time: `.luacheckrc` modified; `PulseProbe/` and the three `brainstormingcue*.md` files untracked. No file under `PulseHaptics/` modified.
> **Target client:** World of Warcraft Forever — `_classic_beta_`, build `1.60.1.69913`, Interface `120100`.
> **Reference UI source:** `docs/DevelopmentplusReference/Developer Documents/WOW SOURCECODE/wow-ui-source-forever/` (its `version.txt` reads `1.60.1.69913`). Written below as `<forever-src>/`.
> **Date:** 2026-09-30
> **Mode:** Read-only. This file is the only file written. No code, `.toc`, `.xml` or other document was changed.

**Evidence labels used throughout**

| Label | Meaning |
|:---|:---|
| **[Fact]** | Read directly in the code, the Forever UI source, or a command's output. A `path:line` or commit is given. |
| **[Inference]** | Follows from facts shown, but not observed in game. |
| **[Unverified]** | Plausible or widely reported, not checked against this client. Needs an in-game probe. |
| **[Recommendation]** | What this review suggests doing. |

---

## 0. Verdict in one screen

1. **The direction is right, the premises are not.** The document's two main instincts are sound: fix the engine (event arbitration) before the UI, and layer Blueprint B (hierarchy) and Blueprint C (presets / context) rather than choosing one. About half of its statements about the current codebase are wrong or out of date (§2). Several things it proposes as new already ship:
   - category master gates (`Registry.ALERT_CATEGORY_MASTER`)
   - 12 curated profiles with per-spec, per-character and per-account rules
   - a simple/advanced switch (`showAdvancedCueControls`)
   - a per-device, calibrated motor breakaway floor
   - a settings panel already split into 12 pages with labelled sections
2. **Three constraints on this client, none of them mentioned in the document, change what can be built:**
   - **Addons cannot read the combat log on this client.** `COMBAT_LOG_EVENT_UNFILTERED` errors when an addon frame registers it (`PulseHaptics/Modules/Combat.lua:665-667`; `PulseHaptics/Core/Registry.lua:692`, confirmed live 2026-09-17). Windfury/extra-attack bursts, CC-break alerts and pet death via `UNIT_DIED` can't be built as the document describes. Blueprint A/B's "melee" and "pets" groups assume they can.
   - **The settings window is mouse-driven by design.** `DRIVE_BLIZZARD_NAVIGATION = false` (`PulseHaptics/UI/Panel/Gamepad.lua:40-69`) is an intentional stability decision, confirmed by the project owner on 2026-09-30: driving Blizzard's SmartNavigation from an addon ends at the protected `SetOverrideBindingClick`. The document's "Steam Deck / D-pad" arguments for Blueprints A and C therefore don't apply to the settings UI. Controller relevance lies in the haptic output, not in configuring it, and the choice between blueprints has to rest on coverage, player control and correctness (§0.1).
   - **In the Default profile the "primary" cues are mostly off** (`merchantBuy`, `itemObtained`, `lootOpened`, `lootReceived`, `lootGold` default off). `bagItemAdded` is on. The document's guards remove the secondary cue unconditionally, so they would **silence** vendor purchases and looting for Default users. They are not "100% invisible".
3. **The timing constants (250 ms, 120 ms, 50 ms, 200 ms) were never measured.** Some of them are already contradicted:
   - The Forever mail UI retrieves one attachment every ≥ 0.15 s plus server round-trip, so a 200 ms batching window will split an "Open All" run into many batches.
   - `panelOpen` is polled at 20 Hz, i.e. up to 50 ms late, so it straddles a 50 ms window.
   - `GetTime()` only advances once per frame, so millisecond windows behave differently at 30 fps and 144 fps.

   Where the game provides a start and end event (loot window, merchant, mail), group cues by that episode instead of by a timer. Otherwise use priority-based replacement in the engine (§9).
4. **Blocking issue outside the document's scope: HEAD breaks the motor floor.** Commit `f623a8a` deleted the `else` in `Engine.lua` `mapValue`. Since then, discrete cues get the breakaway floor applied **twice** and continuous textures get **no floor at all** (`PulseHaptics/Core/Engine.lua:524-538`). All 7 test suites still pass. Thought 9.4 builds directly on this function, so fix it first (§7.6).
5. **Recommended order** (§6, §10):
   - **Phase 0:** fix the floor; measure event order with PulseProbe; decide suppression policy.
   - **Phase 1:** arbitration that knows which cue owns an interaction. A secondary cue steps aside only when the owner cue is enabled; work is grouped into episodes; a small set of cue "buses" (below) handles replacement.
   - **Phase 2:** one-line cue rows plus collapsible sections plus gates on the existing panel (mouse-driven, as designed).
   - **Phase 3:** presets built from the existing profiles, plus an Accessibility profile. Combat dampening as an opt-in runtime gain.

   A *bus* here means a shared engine layer for a family of cues: a newer or more important cue on the same bus replaces the one playing instead of stacking on it.

---

## 0.1 Determination: Blueprint A vs B vs C

**[Recommendation] Build on Blueprint B. Add Blueprint C's presets on top of it later. Use Blueprint A only as an optional "Simple" page over B's gates, never as the data model.**

| Rank | Blueprint | Verdict | Deciding reasons |
|:--:|:---|:---|:---|
| **1** | **B — hierarchy and non-destructive master gates** | **Adopt as the foundation** | Keeps all 190 cues and every per-cue mode and intensity choice in the 12 curated profiles. The gate mechanism already ships (`ALERT_CATEGORY_MASTER`, `Init.lua:66-69`), so B generalises existing code rather than inventing it. The panel already has what collapsing needs: visibility predicates, two-pass layout and automatic header hiding (§4.2). One-line cue rows give the largest density saving. Its SavedVariables change is additive (group gate state), not lossy. |
| **2** | **C — presets and contextual mixer** | **Adopt in part, after B** | *Presets:* mostly exist as the 12 curated profiles; add the missing Accessibility (and Minimal) profiles. *Mixer:* only as an opt-in runtime gain (§5, §9.4). Automatic muting conflicts with accessibility play and makes behaviour hard to predict. Tag muting does nothing for the economy collisions, which happen out of combat. It depends on B's group or tag data, so it comes second. |
| **3** | **A — six master toggles** | **Reject as the data model; optional as a view** | The six groups cover about 45 of the 190 cues, leaving roughly 145 with no home. "Zero double-firing by design" is false. Migrating the 12 profiles into six system states loses information. Its main selling point, D-pad and handheld configuration, doesn't apply because the panel is mouse-driven by design. What survives is a "Simple" page of B's gates that covers every page. |

**What didn't decide the ranking:**
- **Double-firing.** Blueprints A, B and C all live at the UI or config layer; none of them fixes collisions. The Phase 1 engine arbitration (§7, §9) is needed whichever blueprint is chosen.
- **Controller ergonomics.** The comparison table's (Ch. 7) "Gamepad / Handheld usability" row drops out because the settings window is intentionally mouse-driven.

---

## 1. What this review is based on (coverage ledger)

| Scope | Read |
|:---|:---|
| **In full** | `brainstormingcuepolish.md`, `brainstormingcuechurn.md`, `brainstormingcue.md`; `PulseHaptics/Modules/Inventory.lua`, `World.lua`, `Interaction.lua`, `AlertThreat.lua`, `AlertWorld.lua`; `PulseHaptics/Core/Init.lua`; `PulseHaptics/UI/Panel/Content.lua` (lines 1-80, 100-280) |
| **Every trigger, by script** | All 190 `Pulse.Triggers` entries in `PulseHaptics/Core/Registry.lua`, loaded under LuaJIT and dumped: id, category, mode, throttle, default, events, page/section |
| **In part** | `Registry.lua`: 1-97, 954-1034, 2787-2830, 3060-3120, 3209-3307, selected entries. `Engine.lua`: 1-300, 347-387, 400-640, 680-870. `Combat.lua`: 25-60, 240-270, 660-670, 790-1020, plus event greps. `Database.lua`: 1-68, 115-195, 1185-1212, 2286-2600, plus curated-override greps. `Devices.lua`: 40-221, 274-338. `Gamepad.lua`: 40-132, 340-395. `Spec.lua`: 84-120, 596-643. `Popup.lua`: 12-22, 619-640. `ControllerUI.lua`: 140-168, 405-430. `Movement.lua`: 115-165. `Modes.lua`: mode list, TAP/TICK/THUD/CHIME. `PulseChecklist/tests/engine-test.lua`: 548-610. `PulseProbe/`: toc, `Core.lua` 1-110, `Probes/CombatProcs.lua` 1-30 and 70-80. `PULSEHAPTICS_CODE_REVIEW_2026-09-30.md`: findings table and F-01 |
| **Forever UI source** | `Blizzard_MailFrame/MailFrame.lua` 1505-1680 and its toc; `Blizzard_UIPanels_Game/Mainline/LootFrame.lua` (grep); `Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml` (grep); `Blizzard_DurabilityFrame/DurabilityFrame.lua` (grep); `Blizzard_APIDocumentationGenerated/ItemQualitiesDocumentation.lua`; `ContainerDocumentation.lua` (grep); `Blizzard_SwingTimer` (grep) |
| **Not read** | `Locomotion.lua` (only a grep for its `PLAYER_REGEN_*` handling), `Environment.lua`, `Health.lua`, `Crafting.lua`, `CastActivity.lua`, `Casting.lua`, `Flight.lua`, `PlayerState.lua`, `AlertUnitWatch.lua`, `AlertLossOfControl.lua`, `AlertSocial.lua`, `AlertDevice.lua`, `AlertExperimental.lua`, `Encounter.lua`; `UI/Panel/Rows.lua`, `Sidebar.lua`, `Panel.lua`, `Theme.lua`; `UI/Settings.lua`, `UI/Minimap.lua`; `PulseDebug/`; the rest of `PulseChecklist/`; other `docs/` files |
| **Commands run** | `./scripts/test.sh` at `441f4f3`: luacheck **0 warnings / 0 errors in 52 files**; **all 7 suites pass**. `git status` identical before and after. `git diff 1ca6a24 HEAD -- PulseHaptics/Core/Engine.lua`. A LuaJIT model of `mapValue` at HEAD and at the intended structure (Appendix A). |
| **Not done** | Nothing was tested in game. Every event-ordering statement below is **[Inference]** or **[Unverified]** unless it cites source. |

---

## 2. Fact-check of the document's premises

| # | The document says (where) | What the code or source shows | Label and evidence | Consequence |
|:--:|:---|:---|:---|:---|
| 1 | "~190 cues across … categories (`INTERFACE`, `WORLD`, `COMBAT`, `ENVIRONMENT`, `ALERT_UNIT_WATCH`)" (Ch. 2 §1) | Exactly 190 triggers in 16 functional categories. `INTERFACE` is a settings **page** id, not a category. | [Fact] `Registry.lua:29-46`, `:93-2787`, `:3083` | Any regrouping must keep `category` unchanged. Companion addons key on it (`Registry.lua:2793-2797`). |
| 2 | "The Spreadsheet of 190 Rows"; Phase 2 "replaces 190 flat rows" | 12 sidebar pages, each with labelled sections (`PAGE_LAYOUT`), built on first open. The density problem is **rows per cue**: checkbox + intensity + mode + tunables + test button. Code comments put the total at ~764 controls (`Content.lua:163-165`) or ~1,395 (`PulseHaptics.toc` comment); they disagree. | [Fact] `Registry.lua:2807-3209`; `Content.lua:8-12`; `Spec.lua:596-621` | The real saving is collapsing each cue to one row, not cutting 190 to 6 (§4.2). |
| 3 | Hotspot 1: `Inventory.lua:146` checks `free < lastFreeSlots` with no merchant check | Correct. | [Fact] `Inventory.lua:146-147` | The fix must respect defaults (next row). |
| 3a | "`merchantBuy` + `bagItemAdded` + `itemObtained` fire" | `merchantBuy` and `itemObtained` are **off** in Default; `bagItemAdded` is **on**. All three are on in *Immersion: Melee/Caster/Ranged* and *Questing*. | [Fact] `Registry.lua:971-988`, `:1848-1856`; `Database.lua:492ff`, `:928ff`, `:1032-1035` | Default users feel one cue; four curated profiles feel the collision. An unconditional guard silences Default purchases. |
| 4 | Hotspot 2: "`World.lua` must also ignore bag drops during merchant transactions" | `World.lua` has no bag cue. `bagItemUsed` is already suppressed while the merchant, bank, mail, trade, guild bank or auction house is open. | [Fact] `World.lua:12-31`; `Inventory.lua:43-86`, `:148-151` | Already solved. |
| 5 | Hotspot 3: `Interaction.lua:187` `wasRepair`; `World.lua:17` catches durability alerts blindly | Both correct. `durabilityLow` is a plain `WatchTrigger` on `UPDATE_INVENTORY_ALERTS`: no condition, no throttle, **on in Default and 9 other profiles**. `merchantRepair` is on in Default too. | [Fact] `Init.lua:388-414`; `Registry.lua:1020-1026`; override counts in `Database.lua` | The one hotspot in the document that reaches Default users. Blizzard's own frame re-reads alert status on this event (`<forever-src>/Interface/AddOns/Blizzard_DurabilityFrame/DurabilityFrame.lua:22,73,87`), so it very likely fires when a repair *clears* the alert [Inference]. |
| 6 | Hotspot 4 loot: `lootOpened` + `harvestComplete` + `itemObtained` + `lootReceived` + `lootGold` + `bagItemAdded` | All six exist. Five are off in Default; all six are on in Immersion ×3 and Questing. `harvestComplete` listens to `LOOT_READY`, which is not specific to gathering. | [Fact] `World.lua:14-16`; `Registry.lua:963-1018`, `:1792`, `:1825` | Real in four profiles. The "Harvest complete" label is misleading [Inference]. |
| 7 | Hotspot 5 banking: primary cue is `bankGold` / `bankClosed` | `bankGold` fires on **money** changes, not item moves. Depositing items is already suppressed (row 4). Withdrawing fires `bagItemAdded` with no guard. | [Fact] `Interaction.lua:195-203`; `Inventory.lua:146` | Hotspot misdescribed. The open issue is withdrawals, and there is no bank-item cue to "own" them. |
| 8 | Hotspot 6: `targetInMeleeRange`, "80 ms swing protection" | The cue is `meleeRangeIn` / `meleeRangeOut`. No swing protection exists. The only 80 ms guard in `Combat.lua` de-duplicates `UNIT_COMBAT` against `COMBAT_TEXT_UPDATE` for the same cue. | [Fact] `Registry.lua:632`; `Combat.lua:970-1019`, `:259-268` | The fix targets something that doesn't exist. |
| 9 | Flow 4: `jumpStart`; `fallImpact` in `Environment.lua` | The cue is `jumped`, fired from `hooksecurefunc("JumpOrAscendStart")`. Landings are `landingSoft` / `landingHard` in `Movement.lua`. | [Fact] `Movement.lua:119-129`, `:158-163`; `Registry.lua:106`, `:120` | Wrong names and file. |
| 10 | Flow 5: `AlertThreat.lua` fires `combatEnter`; `Combat.lua` has a "secondary Regen-Disabled click" to suppress | `combatEnter` is a declarative `PLAYER_REGEN_DISABLED` watcher run by `AlertGeneric.lua`. `Combat.lua` registers no `PLAYER_REGEN_*` event. `AlertThreat` fires `threatRising/Aggro/Lost`. | [Fact] `Registry.lua:1497-1505`; `AlertGeneric.lua:39`; `AlertThreat.lua:36-37,63-69`; grep of `Combat.lua` | The real pull collision is `combatEnter` (LONG) + `threatAggro` (HEAVY), both **on in Default** (§8). |
| 11 | Mode names `LATCH_HEAVY`, `PAPER_POP`, `WOOD_SLIDE`, `GAVEL_TAP`, `HARMONIC_HUM`, `MARTIAL_SNAP`, `DOUBLE_CLICK`, `ETHEREAL_HUM`, `TICK_SOFT`, `LATCH_LIGHT`, `MOTOR_BURST` | None occurs anywhere under `PulseHaptics/`. `Modes.lua` defines 35 shapes. | [Fact] grep count 0 for each | Each wireframe dropdown implies new modes. |
| 11a | "Material simulation (iron, paper, wood)" for NPC windows | This reverses a stated design decision: window cues deliberately share one shape so they stay distinct from Controller-UI cues. | [Fact] `Registry.lua:3087-3091` | A design change to make on purpose, not a polish item. |
| 12 | Groups "Pets & Companions", "Environmental Hazards", "extra attack flurries" | No pet cue exists. No screen-shake, lava or acid cue exists. Extra attacks need the combat log, which addons can't register on this client. | [Fact] registry dump; `Combat.lua:665-667`; `Registry.lua:692` | Two of the six groups would ship empty or be infeasible as specified. |
| 13 | Non-destructive master gates as new (Ch. 5.3) | Already implemented for `ALERT_CC` (`ccMaster`) and `CONTROLLER_UI` (`controllerUIMaster`). The gate is checked on fire, the child setting is never overwritten, and the UI greys the children. | [Fact] `Registry.lua:88-91`; `Init.lua:66-69`, `:110-113`, `:152-155`; `Spec.lua:95-103` | Blueprint B means generalising this, not inventing it. |
| 14 | Four one-click presets as new (Ch. 6.3) | 12 built-in curated profiles. Most are exclusive cue lists (`__exclusive`). They resolve per spec, per character or per account. | [Fact] `Database.lua:54-67`, `:192-195`, `:2286-2310` | Three of the four presets overlap existing profiles. **Accessibility is the real gap.** |
| 15 | Simple vs Advanced switch as new (Thought 9.1) | `showAdvancedCueControls` already hides the per-cue intensity, mode and tunable rows, and takes effect without a reload. | [Fact] `Database.lua:36`; `Spec.lua:113-115`, `:223`, `:250`, `:268`; `Content.lua:176-187` | Extend it rather than build it. |
| 16 | Non-linear perception floor as new (Thought 9.4) | A per-channel `floor` remap exists, with per-device presets and a calibration ramp. | [Fact] `Engine.lua:506-539`, `:928`; `Devices.lua:84-91`, `:195-221` | Currently regressed at HEAD (§7.6). |
| 17 | `GetCurrentMixerProfile`: `IsInRaid() or IsInGroup()` labelled "In Raid / Dungeon Instance" | Being in a group isn't being in an instance. A group questing in the open world would get the dungeon mix. | [Fact] on the document text; [Inference] on the effect | Use `IsInInstance()`. |
| 18 | Blueprint B "more complex UI code" in the "Classic Blizzard XML/Lua framework" | The panel has no XML. It uses a plain `ScrollFrame` and already has visibility predicates, two-pass layout and automatic hiding of empty section headers. | [Fact] `Content.lua:14-18`, `:176-249` | Cheaper than the document estimates (§4.2). |
| 19 | Gamepad / handheld usability ratings (Ch. 7) | The settings window is mouse-driven by design. `DRIVE_BLIZZARD_NAVIGATION = false` is an intentional stability decision that avoids the protected-binding taint path. | [Fact] `Gamepad.lua:40-69`; intent confirmed by the project owner 2026-09-30 | This row shouldn't weigh in the choice between blueprints (§0.1). |
| 20 | "LRAs or dual-rumble motors … blur into an undefined, mushy buzz" (Ch. 2 §2) | The engine takes the **maximum** of simultaneous discrete cues per role, so two cues at the same instant play as one pulse. The failure you actually feel is two onsets 60-200 ms apart, which reads as an unintended double-tap. | [Fact] `Engine.lua:748-757`; [Inference] on perception | Arbitration should target near-simultaneous onsets, not same-frame ones. |
| 21 | Phase 1 "100% invisible to user" | False wherever suppression removes the only enabled cue (row 3a). | [Inference] from defaults | Suppression must check that the owner cue is enabled (§9.1). |
| 22 | 9.2: bulk sell creates "12 rapid `BAG_UPDATE_DELAYED` events and 12 … money shifts" | The bag side is already silent at a vendor. `merchantSell` is throttled to 0.2 s, i.e. at most 5 Hz. | [Fact] `Inventory.lua:149`; `Registry.lua:1858-1866` | The storm is a bounded 5 Hz tick train, not a motor overload. |
| 23 | 9.2: "while an `OPEN_ALL_MAIL` loop is active" | There is no such event. The Forever source ships `OpenAllMailMixin`: one attachment per step, `OPEN_ALL_MAIL_MIN_DELAY = 0.15` s, `C_Mail.SetOpeningAll(true/false)`, driven by `MAIL_INBOX_UPDATE`. Its toc says `AllowLoadGameType: mainline`, so whether the live Forever client loads it is unverified. | [Fact] `<forever-src>/Interface/AddOns/Blizzard_MailFrame/MailFrame.lua:1510-1680`, `Blizzard_MailFrame.toc:6`; [Unverified] live load | Any settle window must exceed 0.15 s plus the server round-trip (§7.4). |
| 24 | 9.5: quest items are "Common (White) or Quest (Uncommon)" | `Enum.ItemQuality` has no quest tier (Poor 0 … WoWToken 8). The Forever loot frame reads `isQuestItem` and `questID` as separate `GetLootSlotInfo` returns. | [Fact] `<forever-src>/…/ItemQualitiesDocumentation.lua:6-20`; `<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua:236,485` | Use the quest flag, not a quality rank (§7.7). |
| 25 | 9.6: a paperdoll swap triggers `bagItemAdded` / `bagItemUsed` | A straight swap leaves the free-slot count unchanged, so no bag cue fires. Only equipping into an empty slot (fires `bagItemUsed`) or unequipping into the bag (fires `bagItemAdded`) does. `equipChanged` already exists: default off, described as "pure novelty". | [Inference] from `Inventory.lua:146-152`; [Fact] `World.lua:18`, `Registry.lua:1028-1034` | Smaller than described. |

---

## 3. Blueprint A — Monolithic consolidation (6 master toggles)

**Is 6 toggles too aggressive, or ideal for gamepad and Steam Deck?**

- **As the only UI: too aggressive, and it covers too little.**
  - **[Fact]** Its six systems map to roughly 45 of the 190 existing cues: Interface/Windows 16, Conversation and Anything-else 4, Loot & inventory 10, Offensive 10, plus a handful of hazards. There are 0 pet cues. The other ~145 cues have no home: casting, movement and locomotion, loss of control, threat, target and focus, social, device, and the whole controller-UI set.
  - **[Inference]** Folding them into six switches would also discard the per-cue mode and intensity choices of 12 curated profiles, and any custom profiles.
- **"Zero double-firing by definition" is false.**
  - **[Inference]** Collisions happen in the event flow. `merchantBuy` and `bagItemAdded` both fire when their events arrive, whatever the UI groups them under. A consolidated "commerce" system still needs the Phase 1 arbitration, and some collisions cross groups (loot vs commerce vs services).
- **"Very low implementation complexity" is understated.**
  - **[Inference]** It needs the same arbitration, a new mode catalogue (§2 row 11), and a lossy migration of `DB.profiles[*].triggers` / `triggerSettings` into six system states.
  - **[Fact]** Profile migrations here have a history of silently not applying (`PULSEHAPTICS_CODE_REVIEW_2026-09-30.md` F-03; `DB_VERSION = 11`, `Database.lua:27`).
- **The gamepad benefit doesn't apply.** **[Fact]** The window is mouse-driven by design for stability (`Gamepad.lua:40-69`; intent confirmed by the project owner 2026-09-30). The case for A as a D-pad or couch configuration screen falls away, so A has to win on simplicity alone, and B's Simple page delivers that without losing any cues.
- **What to keep.** **[Recommendation]** Keep Blueprint A as a *view*, not a data model:
  - A "Simple" page with one gate and one optional volume per group.
  - The groups must **cover every cue.** The 12 existing pages are the obvious partition, or a merged 8-10 if some pages are too thin.
  - Add master intensity and the profile picker.
  - It is a mouse page like the rest of the panel. Judge it on readability at small resolutions (e.g. a Steam Deck's 1280×800), not on controller navigation.

---

## 4. Blueprint B — Hierarchical accordion and master gates

### 4.1 Is the non-destructive master gate robust?

**[Fact]** The mechanism already ships:

- `FireIfEnabled`, `HoldIfEnabled` and `HoldRolesIfEnabled` each check the category master before playing, and never write to the child (`Init.lua:66-69`, `:110-113`, `:152-155`).
- The panel greys children through `cueGate` / `subordinateGate` (`Spec.lua:95-110`).

The document's `IsCuePlayable` uses an AceDB-style `self.db.profile.cues[id]`. That shape doesn't exist here: state lives in `DB.profiles[name].triggers` / `triggerSettings`, read through `Pulse.Database:GetCue` / `GetTriggerSetting`.

Robustness gaps to design for before generalising:

1. **Choose the gate key.** **[Fact]** `ALERT_CATEGORY_MASTER` is keyed by functional `category`. `PAGE_LAYOUT` is presentation-only by design ("nothing here is read by event registration", `Registry.lua:2789-2797`). Blueprint B's groups match neither key.
   - **[Recommendation]** Add a third, explicit `gate` key rather than making `PAGE_LAYOUT` behavioural or re-keying `category`. Re-keying would break PulseDebug and PulseChecklist.
2. **Unregister events while gated.** **[Inference]** A gate switched off is correct at fire time, but member modules stay registered, because `BindFrame` only listens to each module's own cue ids (`Init.lua:377-383`).
   - **[Recommendation]** A gate change should notify every member's cue listeners so modules unregister (the "zero cost when off" rule).
   - This path can run in combat. Like profile switches, defer it with the existing `pendingProfileNotify` pattern (`Database.lua:2458-2491`).
3. **Settle what a gate is.** **[Fact]** `ccMaster` is both a gate and a playable cue (mode `DOUBLE_TAP`, fires on any loss of control). `controllerUIMaster` is a pure gate (no mode).
   - **[Recommendation]** Make group gates pure gates. Don't copy `ccMaster`'s dual role.
4. **Continuous textures.** **[Fact]** The gate already applies to `HoldIfEnabled` / `HoldRolesIfEnabled`. Keep it that way, including in any mixer (§5).
5. **Group volume compounds with everything else.** See §7.6. **[Recommendation]** If a group volume is added, give it a bounded range and show the *effective* level next to each cue.
6. **Scope of `expanded` state.** The document stores `expanded` inside the profile.
   - **[Inference]** Profiles switch automatically per spec (`Database.lua:2286-2310`), so the panel would re-fold on a spec change.
   - **[Recommendation]** Store expand/collapse as global UI state, as `showAdvancedCueControls` is (`Database.lua:29-43`).

### 4.2 UI complexity of dynamic accordions in this panel

The question assumes "Classic Blizzard XML/Lua frames". **[Fact]** This panel uses no XML and no `ScrollBox`. It is a plain `ScrollFrame` with one tall child, rows built once per page and never recycled (`Content.lua:8-18`, `:114-133`).

**What already exists:**

- a `visibleWhen` predicate per row (`Content.lua:176-187`)
- two-pass layout that measures wrapped rows and hides empty section headers (`:191-249`)
- a `RefreshNavigation()` hook after layout changes (`:158`, `:173`)

An accordion is therefore:

- a per-section "collapsed" predicate added to `rowVisible`;
- a clickable header row;
- the existing `LayoutRows()` call.

**[Inference]** That is a small change.

Real complexities, in order of risk:

1. **Headers are text today.** **[Fact]** Section headers are plain `kind = "header"` rows (`Spec.lua:640`), and `navTargetOf` treats header and text rows as non-interactive (`Gamepad.lua:88-99`). **[Recommendation]** A collapsible header becomes a clickable `Button` row. That's mouse-only, consistent with the intentionally mouse-driven panel. No controller navigation work is implied.
2. **Open popups anchored to a hidden row.** **[Inference]** Collapsing a section while one of Pulse's own dropdowns (`UI/Panel/Popup.lua`) is open on a row inside it would leave the list anchored to a hidden frame. Close any open popup when a section collapses.
3. **Scroll position.** **[Inference]** Collapsing a section above the viewport shortens the child (`Content.lua:248`). Clamp `SetVerticalScroll` to the new range, possibly on the next frame, after the scroll range updates.
4. **Search vs collapse.** **[Inference]** Search is page-scoped (`Content.lua:163-174`). A match inside a collapsed section must expand it, or the search finds nothing visible.
5. **"8 of 11 cues active" badges.** Cheap: recompute on `OnCueChanged`. The wireframe's own counts are inconsistent (it lists 10 rows under "8 of 11").
6. **The biggest win is row density, not folding.** **[Fact]** Each cue is up to 3-5 rows today (`Spec.lua:596-621`). **[Recommendation]** A one-line cue row (checkbox + inline intensity + inline mode + a small ▶) cuts the panel by roughly 60-75% even with nothing collapsed.

---

## 5. Blueprint C — Adaptive contextual mixer

### 5.1 Hidden taint risks across `PLAYER_REGEN_DISABLED` ↔ peaceful transitions

**Short answer:** the mixer itself carries **no inherent execution-taint risk.** The risks sit next to it, in the UI and in how state changes are applied.

- **[Fact]** The cue path is ordinary insecure addon code. It reads state and calls `C_GamePad.SetVibration` (`Engine.lua:597-624`). The engine runs through combat already; combat-texture cues exist and ship. Multiplying a gain by a flag set from `PLAYER_REGEN_*` touches no secure frame, attribute or protected function.
- **Where taint actually appears:**
  - **[Fact]** Opening Blizzard menus or StaticPopups from Pulse's stack ends at protected `SetOverrideBindingClick`. That produced the documented ~30 s freeze (`UI/Panel/Popup.lua:12-22`; `PulseHaptics.toc` comment at line 119). The same applies to driving SmartNavigation (`Gamepad.lua:40-69`).
  - **[Fact]** `SetPropagateKeyboardInput` is restricted in combat and already guarded (`Popup.lua:619-640`).
  - **[Recommendation]** Any preset buttons or "combat dampening" controls must use Pulse's own dialogs and dropdowns. Any hooks must be post-hooks (`hooksecurefunc`), never replacements.
- **Stability risk (not taint):** implementing the mixer as profile switching.
  - **[Fact]** A profile switch makes every module unregister and re-register its events, and the code defers exactly this in combat (`Database.lua:2458-2491`; flushed on `PLAYER_REGEN_ENABLED`, `Database.lua:1188-1210`).
  - **[Recommendation]** The mixer must be a runtime multiplier applied in `FireIfEnabled` / `HoldIfEnabled` / `HoldRolesIfEnabled`. It must never write SavedVariables and never notify `BindFrame` (sketch in §9.4).
- **Timing:**
  - **[Unverified on Forever]** Retail addon authors widely report that `PLAYER_REGEN_DISABLED` fires *before* `InCombatLockdown()` returns true. That is why secure-frame addons make last-moment changes in that handler.
  - A mixer that reads `InCombatLockdown()` inside that event could therefore mix the first cue of a pull (`combatEnter`) as peaceful.
  - **[Recommendation]** Set mixer state from the events themselves, or read `UnitAffectingCombat("player")`. "Combat lockdown" is a UI-security concept, not a gameplay state.
  - **[Fact]** `Combat.lua:39` gates `abilityPulse` on `InCombatLockdown()`, so the same caveat applies there.

### 5.2 Other risks in Blueprint C

1. **Flapping.** **[Inference]** Combat drops briefly between pulls, on Feign Death, and when a pet pulls. A hard switch would flap the mix. **[Recommendation]** Hold the combat mix for about 2-3 s after `PLAYER_REGEN_ENABLED`.
2. **"Elevate `#combat_critical`" isn't possible.** **[Fact]** Every stage clamps to 1.0 (`Engine.lua:92-100`, `:793`). A mixer can only attenuate the other cues, which lowers total haptic energy.
3. **The tag targets are wrong for Classic.** **[Inference]** Vendor and mail windows are rarely open mid-fight. What clutters a fight here is:
   - bag cues from soul shards, ammo stacks and looting during a pull (§8)
   - `targetChanged`
   - `uiInfoMessage`
   - `xpGained`
   - group `lootReceived`
   - social pings
   - locomotion and weather textures

   Tag those.
4. **Accessibility conflict.** **[Inference]** The "Accessibility / Deaf player" preset needs combat *and* interface information. Automatic dampening must be opt-in and forced off in that profile.
5. **Determinism.** **[Recommendation]** Show the current mix state in the panel and in PulseDebug. Give each cue a "never dampen" override, as the document's own con already suggests.
6. **Matrix ratings (Ch. 7).**
   - "Double-fire immunity ★★★★★ via dynamic tag mute" doesn't hold. **[Inference]** Economy collisions happen out of combat, where C mutes nothing.
   - A's ★★★★★ "built-in by design" is false (§3).
   - B's ★★★★★ depends on work not yet done.

---

## 6. The phased synthesis: agree, with a different order

**Agree:**

- engine before UI
- B before C
- presets and dynamic muting as a later layer
- non-destructive gates

**Disagree:**

1. **Phase 1 has no measurement step.** Every constant in the document is a guess (§7).
2. **Phase 1 has no suppression policy.** Unconditional suppression breaks Default (§2 row 21).
3. **Phase 2 scope.** Six cards don't partition the 190 cues. The bigger saving (one-line rows) isn't mentioned.
4. **Phase 3 ignores the 12 existing profiles.** It also inherits their open defects: F-03 curated migration and F-08 missing pages (`PULSEHAPTICS_CODE_REVIEW_2026-09-30.md`).
5. **Its gamepad/handheld arguments for the config UI don't hold.** The panel is intentionally mouse-driven for stability (§0.1). Rank the phases on coverage and correctness, not D-pad ergonomics.
6. **The floor regression** at HEAD comes before any volume work.

**Proposed order:**

```
Phase 0  Preconditions (no feature code)
         0a  Restore mapValue's else-branch (Engine.lua:524-538); make engine-test.lua:552-574
             assert exact values instead of loose bounds.
         0b  Trace real event order with PulseProbe (frame counter + debugprofilestop), §11.
         0c  Write the suppression policy down as data: owner cue, secondaries, episode.

Phase 1  Arbitration (feels invisible only when owner-aware)
         1a  Vendor: state-based, owner-aware guard at Inventory.lua:146.
         1b  durabilityLow fires only when the worst slot status gets worse; harden repair detection.
         1c  Loot episode LOOT_OPENED..LOOT_CLOSED with a leading-edge claim (quality/quest scanned up front).
         1d  "window" and "pull" buses with priority replacement; deferred close for window chains.
         1e  lootReceived filtered to the player (or dropped from the Raiding profile).
         1f  Bulk coalescer for vendor-sell bursts and the Open-All-Mail session.

Phase 2  Panel
         2a  One-line cue rows; collapsible sections via visibleWhen; global collapse state.
         2b  Group gates generalising ALERT_CATEGORY_MASTER on a new presentation-independent key.
         2c  Simple view built on showAdvancedCueControls, covering all pages (mouse-driven,
             like the rest of the panel; controller navigation stays off by design).

Phase 3  Presets and mixer
         3a  Fix F-03 / F-08, then add "Accessibility" and "Minimal" curated profiles.
         3b  Combat dampening: runtime gain, opt-in, event-driven, with hysteresis; off under Accessibility.

Phase 4  New cues from brainstormingcuechurn.md, only those feasible without the combat log.
```

---

## 7. Technical feasibility and edge-case stress test

### 7.1 The 250 ms vendor guard (`Context:IsRecentMerchantPurchase`, proposed at `Inventory.lua:146`)

How the proposal works:

- The guard is armed by `PLAYER_MONEY` (in `Interaction.lua`).
- It is checked in `Inventory.lua` on `BAG_UPDATE_DELAYED`.
- **[Fact]** `BAG_UPDATE_DELAYED` is the settled end-of-batch bag event (`Inventory.lua:4-6`, `:107`).
- **[Unverified]** Whether the money update or the bag update reaches the client first after a purchase is not guaranteed. They come from separate server messages.

| Scenario | What the 250 ms guard does | Label |
|:---|:---|:---|
| The bag update settles **before** `PLAYER_MONEY` | The guard isn't armed yet, so `bagItemAdded` fires, then `merchantBuy`. **Still double.** | [Inference]; order [Unverified] |
| The bag update settles **> 250 ms after** `PLAYER_MONEY` (Wi-Fi jitter, packet loss, server hitch) | The guard has expired. Double. | [Inference] |
| A long frame (loading hitch, 15-30 fps on a handheld) | `GetTime()` advances per frame, so one 200 ms frame can use up most of the window. | [Inference] |
| `merchantBuy` **disabled** (Default profile) | `bagItemAdded` is suppressed anyway, so **the purchase is silent.** | [Inference] from defaults (§2 row 3a) |
| The purchase merges into an existing stack | No slot change, so nothing to suppress. Correct. | [Inference] |
| Buyback | Money goes down and a slot fills; suppressed. Correct. | [Inference] |
| A junk-seller addon sells while the player buys | If two transactions land in one `PLAYER_MONEY`, the net delta's sign picks buy or sell and the other is lost. The window also suppresses a legitimate non-purchase intake. | [Inference] |
| A legitimate non-purchase bag intake within 250 ms at a vendor (e.g. a conjured item) | Dropped. Rare; negligible. | [Inference] |

**Answer:**

- The time window both **still double-fires** (ordering and latency) and **can drop legitimate feedback** (disabled owner cue).
- Neither problem needs a window. While the merchant interaction is open, a bag gain is almost always a purchase or buyback.

**[Recommendation]** Replace the timer with a state gate that knows the owner cue:

- Suppress `bagItemAdded` only when the merchant is open **and** `merchantBuy` is enabled.
- Get "merchant open" from one owner: the interaction-manager state that `Inventory.lua:62-83` already queries, rather than a second copy in a new `Pulse.Context`. **[Fact]** `Interaction.lua` keeps its own `inMerchant` (`:108`, `:119-123`, `:151-153`, `:168-175`).
- **[Fact]** `Inventory.lua`'s `IsShown()` checks fail when bag or bank replacement addons hide Blizzard frames, but the interaction-manager fallback in the same function covers that (`:62-83`). Make that fallback the primary source.

### 7.2 The repair path (hotspot 3)

The document proposes `Context.isRepairing`. **[Fact]** The current logic works like this (`Interaction.lua:176-194`):

- `UPDATE_INVENTORY_DURABILITY` while a merchant is open sets `wasRepair = true` and fires `merchantRepair`.
- The next `PLAYER_MONEY` is consumed as "the repair payment".

This breaks in several ways:

- **Durability updates without a repair** at a vendor, such as equipping or unequipping gear with the window open.
  - What happens: a false `merchantRepair`, and `wasRepair` stays true, so the **next real buy or sell is swallowed**.
  - **[Inference]** Whether this event fires on equipment changes is [Unverified].
- **Guild-funded repair.**
  - **[Fact]** Forever's merchant UI has `CanGuildBankRepair()` / `GetGuildBankWithdrawMoney()` (`<forever-src>/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/MerchantFrame.xml:301,317`).
  - **[Inference]** Personal money doesn't change, so no `PLAYER_MONEY` arrives and `wasRepair` stays latched until the next real transaction, which it swallows.
- **Order inversion** (money before durability): the repair is felt as `merchantBuy`, then `merchantRepair`, and `wasRepair` is left latched. **[Inference]**
- **Auto-repair addons** call repair as the merchant opens. That gives a cluster of `panelOpen` + `merchantShow` + `merchantRepair` + `durabilityLow` in about 100 ms. **[Inference]**

**[Recommendation]**

- Make `wasRepair` expire after about 1 s, or after one frame once the payment has been matched, so it can never swallow a later transaction.
- Identify the repair by its cost (`GetRepairAllCost()` sampled before and after), or with a post-hook `hooksecurefunc("RepairAllItems", …)`. Both are taint-free.
- Fire `durabilityLow` only when the worst `GetInventoryAlertStatus(slot)` value **gets worse** (0→1, 1→2). That is the same data Blizzard's frame reads (`DurabilityFrame.lua:73,87`).
- Together these remove the repair collision without any cross-module flag. They also stop repeat firing on events that don't worsen gear, such as login or zoning. **[Inference]**

### 7.3 The 120 ms "settled loot" buffer

- **The code sketch can't produce a cue.**
  - **[Fact]** `Context:RecordLootDrop` (Ch. 3.2) only records a maximum. There is no timer, no settle callback, no fire call, and `highestLootQuality` is never reset after a fire.
  - It also has no source for `quality`. **[Unverified]** `ITEM_PUSH` doesn't carry quality in its usual form, and `CHAT_MSG_LOOT` links are unfiltered chat text in a group.
- **Latency and merging are in tension.**
  - **[Inference]** With auto-loot, each slot arrives with its own server response. On high-latency links (handheld Wi-Fi, distant realms) the gaps can exceed 120 ms, so one corpse produces two or three chimes.
  - Widening the window delays the chime by the same amount. A time window can't escape this.
- **Episodes don't end on a timer.** **[Inference]** A player with full bags, a partly looted corpse, or a loot window left open never "settles". `LOOT_CLOSED` is the natural end (the Forever loot frame registers `LOOT_OPENED` / `LOOT_CLOSED`, `LootFrame.lua:59-60`).
- **Group loot (Classic).** **[Inference]** Items above the loot threshold go to a roll (`lootRoll`, `lootConfirm`) and arrive much later. Keep them out of the corpse episode (they show as locked slots).
- **Frame-rate edge case.** **[Inference]** At 30 fps, 120 ms is under 4 frames. Two slots processed in the same frame are merged anyway.

**[Recommendation]** Use a loot episode with a leading-edge claim:

1. Scan the slots once at `LOOT_OPENED`, using `GetLootSlotInfo` for quality and `isQuestItem`. Before anything moves, you know the best item.
2. Fire the tiered cue on the **first** intake.
3. Suppress later intake cues until `LOOT_CLOSED` plus a short tail. **[Unverified]** The tail matters because the last `BAG_UPDATE_DELAYED` may land after `LOOT_CLOSED`; measure it.

This adds no latency and doesn't depend on timing guesses (§9.2).

### 7.4 Bulk actions (Thought 9.2): a better pattern

- **What actually happens today:**
  - **[Fact]** A junk-seller at a vendor produces a stream of `merchantSell` ticks, throttled to 5 Hz. Bag cues are already silent.
  - **[Fact]** During Open All Mail, the storm is `itemObtained` (no throttle, `Registry.lua:971-978`) plus `bagItemAdded` (0.2 s throttle), once per attachment. `bagItemAdded` has no mail guard (`Inventory.lua:146`). Both are on in Immersion ×3 and Questing.
- **Why a 200 ms window fails.**
  - **[Fact]** Forever's own Open All waits `OPEN_ALL_MAIL_MIN_DELAY = 0.15` s after each `MAIL_INBOX_UPDATE` before the next retrieval (`MailFrame.lua:1510`, `:1642-1680`).
  - **[Inference]** Item spacing is therefore at least 0.15 s plus one round-trip, which is usually over 200 ms. The document's window would split one session into many "batches".
- **A better pattern.** **[Recommendation]** Use a leading-plus-trailing debounce with a maximum wait, scoped to a session:
  - **Leading edge:** fire one crisp cue on the first transaction of a burst. This is the document's "till drawer click", and it has no latency.
  - **Quiet-gap extension:** each new transaction pushes the settle deadline out. The gap must exceed the measured spacing: about 0.4-0.5 s for Blizzard's Open All (0.15 s plus round-trip); measure for junk-sellers (§11).
  - **Maximum wait:** after about 1.5 s, flush a "settle" cue even if the burst continues, so feedback never goes stale.
  - **Session scoping:** use the merchant-visit and mail-session episodes rather than time alone. For mail, prefer a post-hook on the Blizzard `OpenAllMail` button's `StartOpening` / `StopOpening`, if that frame loads on Forever ([Unverified], §2 row 23), over guessing from timing.
  - **Zero-GC:** implement with one static frame's `OnUpdate` that compares timestamps, or with one reusable `C_Timer.After(delay, STATIC_FN)` and a generation counter. Never create a closure per event.
    - **[Fact]** `Engine:PlayMode` already allocates a closure and a table per delayed mode step (`Engine.lua:483-492`). So coalescing bursts also *reduces* garbage.
- **Keep the "rhythmic paper-sorting flutter" optional.** **[Inference]** A 20-mail Open All lasts several seconds. A continuous texture that long is more fatiguing than two discrete cues.

### 7.5 Window chaining (Thought 9.3): will a 50 ms priority filter work?

- **The logic runs backwards.**
  - **[Fact]** On hide, `Interaction.lua` fires the close cue immediately (`:145-161`). By the time a `SHOW` arrives within 50 ms, the close is already playing.
  - Suppressing it needs one of two things:
    - (a) defer every close by one frame and cancel it if a `SHOW` arrives first. There is a precedent: the one-frame `C_Timer.After(0, …)` coalescing in `Gamepad.lua:376-392`.
    - (b) bus replacement: the arriving open cue takes over the close cue's engine layer (§9.3).
- **50 ms depends on frame rate.** **[Inference]** `GetTime()` advances per frame. 50 ms is about 1.5 frames at 30 fps and 7 at 144 fps, so the same setting behaves differently on a Steam Deck and a desktop.
- **The real gap is unknown.** **[Unverified]**
  - If the client closes the old interaction when the new one's server reply arrives, `HIDE` and `SHOW` land in the same frame and any window works.
  - If it closes on the click, the gap is about one round-trip (50-300 ms) and a 50 ms filter misses it.
  - Measure (§11).
- **A third participant the document missed.**
  - **[Fact]** `ControllerUI.lua` polls `GetUIPanel` at 20 Hz and fires `panelOpen` / `panelClose` (`:146-163`, `:415-426`). These are on in Default and in Immersion ×3 and Questing.
  - **[Inference]** Their 0-50 ms polling jitter against the event path is larger than the proposed window.
- **The commonest chain in Classic.** **[Inference]** An NPC greets with gossip; the player picks "browse goods" or "train". That is `gossipShow` → gossip hide → merchant show, i.e. `interactionWindowClosed` + `merchantShow` + `panelOpen`, all on in the four immersion-style profiles.
- **Existing same-frame double.** **[Fact]** Closing a bank fires `bankClosed` **and** `interactionWindowClosed` from one hide (`Interaction.lua:154-160`). Both are on in Questing.
- **Risk of muting deliberate rapid closes: negligible.** **[Inference]** A person can't close one NPC window and open another interaction within a frame or two, except through the chain itself. Escape closing several windows at once produces several hides in one frame, which the 1.0 s throttle on `interactionWindowClosed` already merges (`Registry.lua:1975-1984`).

**[Recommendation]**

- Define the rule by frames, not ms: "a close is dropped if a `SHOW` arrives before the deferred close runs (next frame)".
- Put `merchantShow`, `gossipShow`, `interactionWindowClosed`, `bankClosed`, `panelOpen` and `panelClose` on one `window` bus with priorities, so the most specific cue wins (§9.3).

### 7.6 Deadzone physics and volume maths (Thought 9.4)

**The pipeline that already exists.** **[Fact]**

1. per-cue intensity × mode step `relIntensity` × mode `lowMult` / `highMult` (`Engine.lua:436`, `:452-481`)
2. per-role blend: maximum for discrete cues, saturating sum for continuous ones (`:731-778`)
3. × `masterIntensity` × schema role intensity (`:781-793`)
4. × channel `gain` → gamma or S-curve → **floor remap** (`:506-539`)
5. smoothing → `SetVibration`

The floor is applied **once, after mixing, per physical channel.** That is the right place, and it is what the document's formula needs.

**Does a fixed 15% floor match ERM / LRA hardware?** Partly for ERM, not for LRA:

- **ERM** (eccentric mass): a real static-friction breakaway threshold exists. The large low-frequency motor has the higher one. **[Fact]** The presets encode 0.095-0.145 (`Devices.lua:195-213`, `:285-327`).
- **LRA** (voice coil on a spring): no static friction to break. Below threshold it is only weak, not stalled. **[Fact]** The presets encode DualSense 0.025, **Steam Deck 0.045 / 0.035**, Switch Pro 0.055 (`Devices.lua:215-221`, `:274-284`, `:329-338`). A fixed 15% over-floors the Deck, the document's flagship handheld, by 3-4×, and the DualSense by 6×, compressing their whole range.
- **"Hums at an irritating high-pitched whine"** **[Unverified]**: low-duty PWM whine exists on some ERM boards. The engine already cuts the decay tail below 0.025 to avoid lingering in the stall band (`Engine.lua:131-137`).
- **The document's clamp isn't monotonic.** "1-12% → 15%" leaves 13% → 13% and 14% → 14%, so a *larger* input gives a *smaller* output. The existing remap `floor + (1 − floor)·v` is monotonic and continuous above zero, and zero still means off. **[Fact]** Appendix A.
- **Stacking another multiplier.** Group volume adds another multiplier to an already long chain. Worked example on an Xbox pad's high motor (floor 0.095, γ 0.88), for a TICK (`relIntensity` 0.28):

  | Setting | Value before the floor stage | Intended output |
  |:---|:--:|:--:|
  | Master 0.7 only | 0.196 | 0.311 |
  | Master 0.7 × group 0.75 × cue 0.5 | 0.0735 | 0.186 |

  **[Inference]** The more stages, the more cues end up just above the floor, where they can't be told apart. Priority stops being felt.

**[Recommendation]**

- Keep per-channel calibrated floors (existing) and the Ramp tool (`Engine.lua:928`). Don't add a global constant.
- If a group volume is added, bound it (e.g. 0.5-1.0), and show "effective %" beside each cue.
- Consider applying per-cue and group volume as additive dB-like offsets rather than straight products.

**HEAD regression (blocking).**

- **[Fact]** `f623a8a` removed the `else` separating the discrete-cue hard floor from the continuous soft floor (`git diff 1ca6a24 HEAD -- PulseHaptics/Core/Engine.lua`).
- What the code does now (`Engine.lua:524-538`):
  - For discrete cues, the hard floor is applied and then the soft-floor formula runs on the lifted value. The floor is applied **twice**: effective floor ≈ `f + (1−f)·f` (0.181 instead of 0.095 on an Xbox high motor), and every quiet cue gets louder.
  - For continuous textures, no floor runs at all. Low values stay **under the motor's breakaway point**: 0.08 → 0.108 on a Low channel whose floor is 0.125.
- The numbers are in Appendix A.
- **[Fact]** `engine-test.lua:552-574` only asserts "continuous < 0.08" and "transient ≥ 0.125", which pass both ways, so all 7 suites are green.
- Relationship to F-01 of `PULSEHAPTICS_CODE_REVIEW_2026-09-30.md`: F-01's knee fix appears to be the intent of `f623a8a`, but its placement inverted which cues get the floor.

### 7.7 Thoughts 9.5 (quest-priority loot) and 9.6 (equipment swaps)

**9.5 — quest-priority loot**

- **[Fact]** There is no quest quality (§2 row 24). `GetLootSlotInfo` exposes `isQuestItem` / `questID` in the Forever loot frame.
- **[Recommendation]** Keep quest items off the rarity ladder:
  - Scan `isQuestItem` at `LOOT_OPENED` and choose a *distinct* quest cue.
  - Better still, tie the reward to objective progress. `UI_INFO_MESSAGE` ("Item: 3/8") is already watched as `uiInfoMessage` (`Registry.lua:1781`). The progress is the reward, not the item.
  - Which loot-frame variant (Vanilla / Mainline) Forever loads, and its exact return signature, is [Unverified].

**9.6 — equipment swaps**

- **[Inference]** A straight swap doesn't fire bag cues (§2 row 25). Only equipping into an empty slot or unequipping into the bag does.
- **[Recommendation]** On `PLAYER_EQUIPMENT_CHANGED`, open a one-frame "equip" episode that suppresses the `BAG_UPDATE_DELAYED` it causes, only if `equipChanged` is enabled (owner-aware again).
- Throttle it. **[Inference]** Weapon-swap macros in combat, and the Classic ammo slot, would otherwise spam a "martial buckle" cue.

---

## 8. Blind spots and missing opportunities (Forever-specific)

1. **The combat log is closed to addons.** **[Fact]** (`Combat.lua:665-667`; `Registry.lua:692`)
   - This removes the document's "extra attack flurries" and every combat-log candidate in `brainstormingcuechurn.md`: Windfury, CC break, pet `UNIT_DIED`, dispel, environmental damage.
   - **[Inference]** PulseProbe's `CombatProcs`, `PetsMinions` and `WorldHazards` probes register the combat-log event without `pcall` (`PulseProbe/Probes/CombatProcs.lua:75`), so they should hit the same registration error.
   - Alternatives worth probing:
     - **[Unverified]** an extra attack might show as a main-hand `PLAYER_SWING` arriving far sooner than the previous `swingDuration` implies. `PLAYER_SWING` is live and non-secret on Forever (`Combat.lua:853-898`).
     - pet death via `UNIT_HEALTH("pet")` / `UNIT_PET` plus `UnitIsDead("pet")`, with no combat log.
2. **Gathering is the worst real hotspot, and it isn't in the table.** **[Inference]** In Immersion and Questing, one herb or ore node can produce:
   - the gather-cast completion (Crafting / `craftComplete`)
   - `harvestComplete` (`LOOT_READY`)
   - `lootOpened`
   - `itemObtained`
   - `bagItemAdded`
   - `lootReceived`
   - `skillUp`

   That is up to seven cues in about a second.
3. **The pull moment.** **[Fact]** `combatEnter` (LONG) and `threatAggro` (HEAVY) are both on in Default and *Dungeon: Tank*. Curated profiles add `meleeAttackStart`, `targetChanged` and `autoRepeatStart`. **[Recommendation]** Put them on a `pull` bus.
4. **Classic inventory mechanics mid-combat.** **[Inference]**
   - Soul shards: created by Drain Soul kills, consumed by summons.
   - Ammo stacks emptied in a quiver or ammo pouch.
   - Conjured food, water and mana gems; reagents.

   All of these move bag slots during fights. **[Unverified]** Whether `C_Container.CalculateTotalNumberOfFreeBagSlots` counts special-purpose bags (quiver, soul bag) on Forever decides whether a hunter feels a `bagItemUsed` THUD each time an arrow stack runs out.
5. **Group loot chat.** **[Fact]** `lootReceived` is an unfiltered `CHAT_MSG_LOOT` watcher (`AlertWorld.lua:25` → `Init.lua:408-410`) and is on in the **Raiding** profile.
   - **[Inference]** Every raid member's loot and roll message fires it (throttled to 0.5 s).
   - **[Recommendation]** Filter it to the player's own loot, or remove it from Raiding.
6. **Addon ecosystems.** **[Inference]**
   - Auto-repair and junk-sell on merchant open (e.g. Leatrix Plus, Scrap) produce the vendor-open cluster (§7.2).
   - Mail addons pace retrieval differently from Blizzard's 0.15 s.
   - Bag and bank replacements hide Blizzard frames. Covered by the interaction-manager fallback (§7.1).
   - ConsolePort's own frames can change which frames count as UI panels for `panelOpen` polling. A reference copy is at `docs/DevelopmentplusReference/Reference addons/ConsolePort-3.2.5/`.
7. **Death and resurrection.** **[Inference]** Durability loss on death or resurrection sickness fires `UPDATE_INVENTORY_ALERTS`, so `durabilityLow` fires alongside `spiritHealerShow` / `playerAlive`. The worsening-edge rule (§7.2) keeps the one that carries information.
8. **Handheld reality.** **[Inference]** 30-40 fps caps, Wi-Fi jitter, and `GetTime()` advancing per frame. Every ms constant should be stated as a measured range (p50 / p95), not a single number.
9. **No accessibility profile.** **[Fact]** 12 curated profiles exist and none targets deaf or hard-of-hearing play (`Database.lua:54-67`), even though the whole `ALERT_*` set was imported for accessibility (`PulseHaptics.toc` comment). This is the most valuable Blueprint C preset.
10. **Continuous textures and the mixer.** **[Fact]** Locomotion, weather and cast textures go through `Hold*` (`Init.lua:98-187`). **[Recommendation]** A mixer applied only in `FireIfEnabled` misses the most fatiguing layer; it must also cover `Hold*`.
11. **Companion addons.** **[Fact]** PulseDebug and PulseChecklist read `category` (`Registry.lua:2793-2797`). **[Inference]** Bus layer names (§9.3) change the engine's layer names, which PulseDebug inspects; check `_DebugLayers` consumers.
12. **Migration risk.** **[Fact]** `DB_VERSION = 11`, and curated-profile migrations have failed silently before (review F-03). **[Recommendation]** Any gate or volume schema needs harness coverage over pre-existing installs.

---

## 9. Alternative designs (sketches only — not applied)

All sketches are Lua 5.1, allocate nothing per event, and call no protected API.

### 9.1 Owner-aware suppression (replaces the 250 ms window)

```lua
-- SKETCH. At Modules/Inventory.lua:146. A secondary cue steps aside only when the
-- window's own cue is switched on; otherwise this tick is the player's only feedback.
if free < lastFreeSlots then
    local merchantOwns = isInteractingWithMerchant() and Pulse.Database:GetCue("merchantBuy")
    if not merchantOwns then
        Pulse:FireIfEnabled("bagItemAdded")
    end
end
```

`isInteractingWithMerchant()` is the merchant half of the existing `isInteractingWithStorageOrMerchant()` (`Inventory.lua:43-86`). It depends on state, not order, so it doesn't matter whether the money or the bag update arrives first.

### 9.2 Loot episode with a leading-edge claim (replaces the 120 ms buffer)

```lua
-- SKETCH. Episode = LOOT_OPENED .. LOOT_CLOSED (+ short tail). Scalars only (Rule 4).
local lootOpen, lootClaimed, lootBest, lootQuest, lootClosedAt = false, false, -1, false, 0
local LOOT_TAIL = 0.3 -- [Unverified] measure: last BAG_UPDATE_DELAYED may trail LOOT_CLOSED

local function onLootOpened()
    lootOpen, lootClaimed, lootBest, lootQuest = true, false, -1, false
    for slot = 1, GetNumLootItems() do
        local _, _, _, _, quality, locked, isQuestItem = GetLootSlotInfo(slot)
        if not locked then -- roll items arrive later, outside this episode
            if not issecretvalue(quality) and type(quality) == "number" and quality > lootBest then
                lootBest = quality
            end
            if not issecretvalue(isQuestItem) and isQuestItem then
                lootQuest = true
            end
        end
    end
end

local function inLootEpisode()
    return lootOpen or (GetTime() - lootClosedAt) < LOOT_TAIL
end

-- On each intake (ITEM_PUSH / BAG_UPDATE_DELAYED) while inLootEpisode():
--   if not lootClaimed then
--       lootClaimed = Pulse:FireIfEnabled(tierCueFor(lootBest, lootQuest)) -- needs FireIfEnabled to return true when it played
--   end
--   return  -- every later intake in the episode stands down
-- LOOT_CLOSED: lootOpen = false; lootClosedAt = GetTime()
```

It needs one small API change: `FireIfEnabled` returns `true` when it actually played. If the tier cue is disabled, nothing claims the episode and `bagItemAdded` still fires, so the owner rule holds.

### 9.3 Buses: priority replacement in the engine (for window chains and pulls)

```lua
-- SKETCH. Registry data, e.g. merchantShow = { bus = "window", priority = 3 },
-- gossipShow = { bus = "window", priority = 2 }, interactionWindowClosed / panelClose =
-- { bus = "window", priority = 1 }, combatEnter / threatAggro = { bus = "pull", ... }.
local busTime, busPriority = {}, {} -- keyed by a handful of static bus names

-- Inside Pulse:FireIfEnabled, after the per-cue throttle:
local bus = trigger.bus
if bus then
    local now, last = GetTime(), busTime[bus]
    local prio = trigger.priority or 0
    if last and (now - last) < (trigger.busWindow or 0.15) and prio < (busPriority[bus] or 0) then
        return false -- something more specific on this bus has just spoken
    end
    busTime[bus], busPriority[bus] = now, prio
end
self.Engine:PlayMode(bus or triggerID, modeID, scale, intensityOverride)
return true
```

Why this works:

- It doesn't depend on arrival order.
  - A lower-priority cue arriving *after* a higher one is dropped.
  - A higher-priority cue arriving *after* a lower one **replaces** it: `PlayMode` on the same layer name bumps `layerTokens`, cancels the earlier cue's pending steps and overwrites the layer (`Engine.lua:354-355`, `:484`).
- It adds no latency.
- The window is only a "freshness" limit, not a guess at event spacing.

### 9.4 Mixer as a runtime gain (Blueprint C without profile swaps)

```lua
-- SKETCH. Never written to SavedVariables; never notifies BindFrame; no InCombatLockdown().
local inCombat, combatEndedAt = false, 0
local RELEASE_HOLD = 3.0                              -- hysteresis against combat flicker
local COMBAT_GAIN = { economy = 0.0, ambience = 0.4 } -- static per-tag table

-- PLAYER_REGEN_DISABLED: inCombat = true
-- PLAYER_REGEN_ENABLED:  inCombat = false; combatEndedAt = GetTime()

function Pulse:MixGain(tag)
    if not tag or not self.Database:Get("combatDampening") then
        return 1
    end
    if inCombat or (GetTime() - combatEndedAt) < RELEASE_HOLD then
        return COMBAT_GAIN[tag] or 1
    end
    return 1
end
-- FireIfEnabled / HoldIfEnabled / HoldRolesIfEnabled:
--   local g = self:MixGain(trigger.tag); if g <= 0 then return end; scale = scale * g
```

---

## 10. Actionable verdict: prioritised recommendations before implementation

| Pri | Recommendation | Why | Done when |
|:--:|:---|:---|:---|
| **P0** | Restore the `else` in `mapValue` (`Engine.lua:524-538`) and assert exact output values in `engine-test.lua:552-574`. | Discrete cues get the floor twice; continuous textures fall under breakaway (§7.6). Thought 9.4 builds on this function. | A 0.05 discrete cue on a 0.125 floor gives `0.125 + 0.875·0.05^γ`; an authored continuous default stays ≥ floor; the tests fail on HEAD's code. |
| **P0** | Correct the document's premises (§2) and re-baseline it on what already ships: gates, 12 profiles, the simple/advanced switch, calibrated floors, the sectioned panel. | Avoids rebuilding existing features, and naming and schema drift. | Updated spec cites real cue ids, files and modes. |
| **P0** | Measure event order and gaps with PulseProbe (§11) before choosing any constant. | 250 / 120 / 50 / 200 ms are guesses; §7 shows they fail both ways. | p50 / p95 / max per scenario at 30 and 60 fps, wired and Wi-Fi. |
| **P1** | Adopt **owner-aware** suppression as a rule, recorded as Registry data (owner, secondaries, episode) and checked by `cue-audit`. | Unconditional suppression silences Default users (§2 row 21). | Suppression is never active while the owner cue is disabled. |
| **P1** | Vendor: a state gate at `Inventory.lua:146`, with the interaction manager as the single source of truth. | Order-independent; removes the second copy of "merchant open" state. | No double on buy in Immersion or Questing; Default still feels purchases. |
| **P1** | `durabilityLow` fires only when gear gets worse; `wasRepair` expires; repair identified by cost or a post-hook. | Removes the repair collision, the guild-repair swallow and the equip-at-vendor swallow (§7.2). | Repairing gives one THUD; the next sale is still felt. |
| **P1** | Loot episode with leading-edge claim, quality and quest scanned at `LOOT_OPENED`. | No latency trade-off; handles full bags and partial loots (§7.3). | One cue per corpse in Immersion; `bagItemAdded` still fires in Default. |
| **P1** | `window` and `pull` buses with priorities; deferred close (one frame). | Covers gossip→vendor, bank close doubles, `panelOpen` polling jitter, and the pull (§7.5, §8.3). | Gossip→merchant in Questing gives one arrival cue. |
| **P1** | Filter `lootReceived` to the player, or remove it from *Raiding*. | Raid-wide loot and roll spam (§8.5). | No buzz on other players' loot. |
| **P2** | One-line cue rows; collapsible sections via `visibleWhen`; collapse state global. | Largest density gain for the smallest code (§4.2). | A page with ~20 cues fits in about one screen without collapsing. |
| **P2** | Group gates on a new, presentation-independent key, generalising `ALERT_CATEGORY_MASTER`; gate changes unregister member events (deferred in combat). | Non-destructive; matches existing code; zero cost when off (§4.1). | Gate off leaves children unchanged and their events unregistered. |
| **P2** | Simple view built on `showAdvancedCueControls`, covering **all** pages. | Blueprint A's strength without losing ~145 cues (§3). | Every cue is reachable from some gate in the simple view. |
| **P3** | Fix F-03 / F-08, then add *Accessibility* and *Minimal* curated profiles. | The real preset gap (§8.9). | New profiles apply on pre-existing installs. |
| **P3** | Combat dampening as an opt-in runtime gain, event-driven, with hysteresis, also applied to `Hold*`, and off under Accessibility. | Blueprint C without taint or re-registration risk (§5, §9.4). | No `BindFrame` activity on combat transitions; the mix state is visible in PulseDebug. |
| **P3** | Bulk coalescer: leading edge + quiet-gap settle + maximum wait, per session. | Vendor bursts and Open All (§7.4). | 20-mail Open All gives ≤ 2 cues; a 12-item junk sale gives ≤ 2. |
| **P3** | Re-plan the churn candidates on combat-log-free sources (`PLAYER_SWING` cadence, `UNIT_HEALTH("pet")`, `GetInventoryAlertStatus`, `GetLootSlotInfo`, `UI_ERROR_MESSAGE`). | The combat log is closed on this client (§8.1). | Each candidate has a confirmed event on Forever. |

**Do not:**

- ship Blueprint A as the only UI
- use a fixed 15% floor, or any non-monotonic clamp
- add group volume as an unbounded extra multiplier
- arbitrate by time windows alone
- implement the mixer as profile switching or SavedVariables writes
- re-enable Blizzard SmartNavigation for the panel or justify a blueprint by controller-driven configuration. Mouse-only is intentional for stability (`Gamepad.lua:40-69`).

---

## 11. Measurement plan (PulseProbe)

- **[Fact]** The probe timestamps with `GetTime()` (`PulseProbe/Core.lua:61`), which only advances once per frame. It can't separate events inside one frame, or order them.
- **[Recommendation]** Add a monotonically increasing frame counter (incremented in one `OnUpdate`) and `debugprofilestop()` per log entry. Log each event with its arrival index inside the frame.

| Scenario | Events to log | Question answered |
|:---|:---|:---|
| Buy one item into a new slot / into a stack / buyback | `PLAYER_MONEY`, `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, `ITEM_PUSH` | Money-vs-bag order and gap (§7.1) |
| Repair all (personal / guild) / equip an item at a vendor | `UPDATE_INVENTORY_DURABILITY`, `UPDATE_INVENTORY_ALERTS`, `PLAYER_MONEY` | Repair ordering; whether equipping fires durability events (§7.2) |
| Corpse loot: manual, auto-loot, full bags, group-loot threshold | `LOOT_READY`, `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `CHAT_MSG_LOOT`, `ITEM_PUSH`, `BAG_UPDATE_DELAYED`, `LOOT_CLOSED` | Spacing between slots; how long the tail after `LOOT_CLOSED` is (§7.3) |
| Herb / mine / skin | the above + `UNIT_SPELLCAST_*` (gather), `CHAT_MSG_SKILL` | Gathering cluster (§8.2) |
| Gossip → merchant; mail → click vendor; bank → close | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE`, `GOSSIP_SHOW/CLOSED`, `MERCHANT_SHOW`, `MAIL_SHOW/CLOSED`, `BANKFRAME_*`, and the `GetUIPanel` transitions | Same frame or one round-trip apart (§7.5) |
| Open All Mail (Blizzard, and Postal if used); junk-sell addon run | `MAIL_INBOX_UPDATE`, `ITEM_PUSH`, `BAG_UPDATE_DELAYED`, `PLAYER_MONEY`; `/dump OpenAllMail ~= nil` | Batch spacing; whether the Blizzard button exists on Forever (§7.4) |
| Pull a mob (melee / ranged / pet pull) | `PLAYER_REGEN_DISABLED` (log `InCombatLockdown()` inside it), `UNIT_THREAT_SITUATION_UPDATE`, `PLAYER_ENTER_COMBAT` | Pull cluster; lockdown timing (§5.1) |
| Windfury / Sword Spec proc (melee) | `PLAYER_SWING` (`swingDuration`, `swingType`) with inter-swing gaps | Whether extra attacks are visible without the combat log (§8.1) |
| Hunter shooting through an arrow stack; warlock Drain Soul kill | `BAG_UPDATE_DELAYED`, `C_Container.CalculateTotalNumberOfFreeBagSlots()` | Whether special bags count (§8.4) |

Run each at a 30 fps cap and at 60+ fps, on wired and Wi-Fi.

---

## Appendix A — Floor maths (LuaJIT model of `Engine.lua:506-539`)

"HEAD" reproduces `f623a8a`'s structure: soft floor nested inside the discrete-cue branch, no `else`. "Intended" is the `1ca6a24` structure with `f623a8a`'s knee (`max(0.02, floor·0.5)`). Presets: `Devices.lua` Xbox = `ERM_LOW` (floor 0.125, γ 0.88) and `ERM_HIGH` (floor 0.095, γ 0.88).

**Discrete cue, Xbox high motor (floor 0.095):**

| Input | HEAD | Intended |
|:--:|:--:|:--:|
| 0.02 | 0.207 | 0.124 |
| 0.05 | 0.240 | 0.160 |
| 0.0735 | 0.263 | 0.186 |
| 0.196 | 0.376 | 0.311 |
| 0.50 | 0.626 | 0.587 |

**Continuous texture, Xbox low motor (floor 0.125):**

| Input | HEAD | Intended |
|:--:|:--:|:--:|
| 0.05 | **0.072** (below floor) | 0.188 |
| 0.08 | **0.108** (below floor) | 0.220 |
| 0.10 | 0.132 | 0.240 |
| 0.30 | 0.347 | 0.428 |

**The document's clamp (Thought 9.4):**

| Input | 0.11 | 0.12 | **0.13** | **0.14** | 0.15 |
|:--|:--:|:--:|:--:|:--:|:--:|
| Output | 0.15 | 0.15 | **0.13** | **0.14** | 0.15 |

The output falls as the input rises from 0.12 to 0.13, so the clamp is not monotonic.

## Appendix B — Commands used (all read-only)

```sh
git status --short; git log --oneline -8 -- PulseHaptics/Core/Engine.lua
git diff 1ca6a24 HEAD -- PulseHaptics/Core/Engine.lua
./scripts/test.sh                                   # 0/0 luacheck, 7/7 suites; tree unchanged
luajit <registry dump script>                       # loads Core/Registry.lua with a stub namespace
grep -rc "<mode name>" PulseHaptics                 # 0 for every mode named in the document
grep -n / sed -n over the files listed in §1
```

*This review changed no code and no other document. It was not added to `docs/DOCS_COMPILATION.md`, because this task authorised writing only this file.*
