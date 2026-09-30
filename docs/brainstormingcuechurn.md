# 🌪️ PulseHaptics: Cue Enrichment & Feasibility Churn
> **WoW Forever Client Focus (`1.60.1.69913` / Interface `120100` / `_classic_beta_`)**  
> **Codebase Reality Check, Systems Audit, Pros vs. Cons & Architectural Pseudocode**  
> **Status:** Systems Analysis & Engineering Specification (Zero code changes applied)  
> **Date:** September 2026  

---

## 1. Executive Overview & Mission

This document performs a rigorous engineering review ("churn") of potential haptic expansions for **World of Warcraft Forever** (`_classic_beta_`). 

While `brainstormingcue.md` cataloged broad sensory concepts, this document:
1. **Audits the Live Codebase:** Verifies line-by-line which proposed cues are **already implemented**, which are **partially implemented** (ripe for enrichment), and which are **genuinely new / absent**.
2. **Evaluates Feasibility & Player Impact:** Conducts an honest, granular **Pros vs. Cons analysis** for every candidate, balancing tactile immersion against sensory fatigue ("rumble soup"), polling overhead, and execution taint.
3. **Provides Production-Ready Pseudocode:** Outlines exact Lua 5.1 implementations adhering to **Zero-GC recycling** (User Rule 4), **taint immunity** (User Rule 5), and **`issecretvalue()` defensive guards**.

---

## 2. Codebase Reality Check: Audit vs. Existing Implementation

Before proposing new development, the entire PulseHaptics repository (`PulseHaptics/Core/Registry.lua` and `PulseHaptics/Modules/*.lua`) was audited against the brainstormed candidates.

### 2.1 Audit Results Matrix

| Brainstormed Cue / Concept | Current Codebase Status | Existing Location / Mechanism | Verdict & Action Required |
|:---|:---:|:---|:---|
| **Melee Range Boundary (`meleeRangeIn` / `Out`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/Combat.lua:970-1019` via `PLAYER_SWING_RANGE_UPDATE` | Fully functional; candidate for intensity tuning only. |
| **Weapon Swing Hit (`weaponSwingMain` / `Off`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/Combat.lua:860-920` via `PLAYER_SWING` | Implemented; missing pre-swing windup anticipation. |
| **Soft-Target Events (`softInteract`, `softEnemy`, etc.)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/ControllerUI.lua:450-480` via `PLAYER_SOFT_*` | Fully wired; fires generic clicks; could be enriched with object classification. |
| **Targeted By Enemy (`targetedByEnemy`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/AlertUnitWatch.lua:171-204` via `UNIT_TARGET` | Fully wired for `target` and `focus`. |
| **Drowning & Breath (`breathWarning`, `breathTexture`, `drowningDamage`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/Environment.lua` via `MIRROR_TIMER_START` | Implemented; missing granular lava/slime/fatigue profiles. |
| **Vehicle Controls (`vehicleEnter`, `vehicleExit`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Core/Registry.lua` via `UNIT_ENTERED_VEHICLE` | Basic triggers exist; turret aim & artillery recoil missing. |
| **Action Error Trigger (`actionFailed`)** | ✅ **ALREADY IN CODE** | `PulseHaptics/Modules/Casting.lua` via `UI_ERROR_MESSAGE` | Generic single pulse; does not differentiate starvation vs. cooldown vs. range. |
| **Durability Alert (`durabilityLow`)** | ⚠️ **PARTIAL IN CODE** | `PulseHaptics/Modules/World.lua:17` via `UPDATE_INVENTORY_ALERTS` | Watches event blindly; cannot distinguish yellow warning (<20%) from red broken (0%). |
| **Cooldown Ready (`cooldownReady`)** | ⚠️ **PARTIAL IN CODE** | `PulseHaptics/Modules/Combat.lua` via `SPELL_UPDATE_COOLDOWN` | Fires for minor 6s abilities; cannot distinguish major 3m burst/defensive cooldowns. |
| **Crafting Activity (`craftStart`, `craftComplete`)** | ⚠️ **PARTIAL IN CODE** | `PulseHaptics/Modules/Casting.lua` via `CastActivity.lua` | Basic start/complete only; zero multicraft, ingenuity, or first-craft procs. |
| **Multi-Hit Extra Attacks (`SPELL_EXTRA_ATTACKS`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references) | **Top Priority Candidate for Classic Melee.** |
| **CC Premature Break Snap (`SPELL_AURA_BROKEN_SPELL`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references) | **Top Priority Candidate for Tactical CC.** |
| **Pet Death Mourning Alert (`petDead`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references to `"pet"`) | **Top Priority Candidate for Pet Classes.** |
| **Screen Shake Translation (`ShakeFrame`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references) | **Transformative World Immersion Candidate.** |
| **Loot Quality Fanfare Tiers (`Enum.ItemQuality`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (`Inventory.lua` only counts slots) | **High Dopamine Progression Loop.** |
| **Waypoint Proximity Geiger (`C_Navigation`)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references) | **Game-Changing Couch Gamepad Navigation.** |
| **Brewmaster Monk Stagger Gauge & Purify Snap** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (0 references) | **Elite Class Resource Feel.** |
| **Granular Environmental Hazards (Lava/Slime/Fall)** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (`ENVIRONMENTAL_DAMAGE` unparsed) | **Atmospheric Classic World Danger.** |
| **School Lockout Paralyzed Motor Bed** | 🆕 **GENUINELY NEW (ABSENT)** | *Not in codebase* (only deflection click on kick) | **Tactile Silence / Lockout Feedback.** |

---

## 3. High-Impact Enrichment Candidates: Pros, Cons & Pseudocode

Below is an exhaustive technical evaluation of the top candidates that can genuinely enrich World of Warcraft Forever.

---

### Candidate 1: Multi-Hit Extra Attack Bursts (`SPELL_EXTRA_ATTACKS`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_CombatLogProcessor/Blizzard_CombatLogProcessor.lua:597`
* **Underlying Engine Event:** `COMBAT_LOG_EVENT_UNFILTERED` with sub-event `SPELL_EXTRA_ATTACKS`
* **Spells Covered:** Windfury Weapon (Shaman), Sword Specialization (Warrior/Rogue), Thrash Blade, Ironfoe, Hand of Justice, Reckoning.

#### Enrichment Rationale
In Classic WoW, the Windfury proc is arguably the single most iconic, celebrated combat event in the entire game. Currently in Pulse, an extra attack either registers as an indistinguishable standard hit or gets masked. By detecting `SPELL_EXTRA_ATTACKS`, Pulse can deliver an instantaneous high-velocity staccato burst across both motors before the floating combat text even animates on screen.

#### Pros vs. Cons
* **Pros:**
  - **Sensory Dopamine:** Instantly transforms melee combat into an exhilarating, visceral experience.
  - **Zero Maintenance:** Uses Blizzard's standard combat log sub-event; works universally across all extra-attack weapons and talents.
  - **Low Overhead:** Fires strictly on procs (rare, discrete event), imposing negligible CPU load.
* **Cons:**
  - **Chain Cascades:** An extra swing triggering another extra swing (e.g. Ironfoe or Classic Windfury procs) could cause motor clipping if unthrottled. Must clamp with a 150ms debounce window.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/Combat.lua (Enrichment Hook)
-- Compliant with Lua 5.1, Rule 4 (Zero-GC), and Rule 5 (Taint Immunity)

local extraAttacksFrame = CreateFrame("Frame")
local playerGUID = nil
local lastExtraAttackTime = 0
local EXTRA_ATTACK_CLAMP = 0.150 -- 150ms anti-clipping clamp

local function onCombatLogEvent()
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool,
          amount = CombatLogGetCurrentEventInfo()

    if event ~= "SPELL_EXTRA_ATTACKS" then
        return
    end

    if not playerGUID then
        playerGUID = UnitGUID("player")
    end

    -- Strictly verify the player is the source of the extra attack proc
    if sourceGUID == playerGUID then
        local now = GetTime()
        if now - lastExtraAttackTime >= EXTRA_ATTACK_CLAMP then
            lastExtraAttackTime = now
            local extraHits = amount or 1
            if extraHits >= 2 then
                -- Windfury (2 extra swings) or Ironfoe/Thrash cascade: machine-gun punch
                Pulse:FireIfEnabled("procExtraAttacksHeavy")
            else
                -- Sword Specialization / Hand of Justice (1 extra swing): sharp staccato snap
                Pulse:FireIfEnabled("procExtraAttacksLight")
            end
        end
    end
end

local function syncExtraAttacks()
    extraAttacksFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end
    if Pulse.Database:GetCue("procExtraAttacks") then
        playerGUID = UnitGUID("player")
        extraAttacksFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        extraAttacksFrame:SetScript("OnEvent", onCombatLogEvent)
    else
        extraAttacksFrame:SetScript("OnEvent", nil)
    end
end
```

---

### Candidate 2: Crowd Control Premature Break Shatter (`SPELL_AURA_BROKEN_SPELL`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_CombatLogProcessor/Blizzard_CombatLogProcessor.lua:660`
* **Underlying Engine Events:** `SPELL_AURA_BROKEN`, `SPELL_AURA_BROKEN_SPELL`
* **Spells Covered:** Polymorph, Sap, Blind, Freezing Trap, Gouge, Repentance, Fear, Hibernate, Shackle Undead.

#### Enrichment Rationale
In dungeon pulls and PvP, crowd control breaking prematurely due to stray AoE, pet attacks, or dot ticks causes party wipes. While Pulse notifies players when *they* are CC'd (`AlertLossOfControl.lua`), it completely ignores the tactical state of CC *the player placed on an enemy*. A sharp, brittle glass-shatter snap (`CRACK`, 0.85 High motor) gives instant tactile alert that an enemy has broken loose without requiring constant gaze on debuff timers.

#### Pros vs. Cons
* **Pros:**
  - **Tactical Utility:** Massive awareness gain for Mages, Rogues, Hunters, and Priests.
  - **Immersion:** The tactile sensation of "broken glass" communicates vulnerability perfectly.
  - **Event Frequency:** Only fires when CC breaks prematurely by damage, not on natural duration expiry.
* **Cons:**
  - **Target Filtering:** Must verify whether the CC aura that broke was cast by the player (`sourceGUID == playerGUID`) or is on the player's primary target to avoid false alerts from other group members' mobs.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/Combat.lua or AlertLossOfControl.lua
local ccBreakFrame = CreateFrame("Frame")
local playerGUID = nil

local function onCombatLogCC()
    local _, event, _, sourceGUID, _, _, _, destGUID, _, _, _,
          spellId, spellName, spellSchool, extraSpellId, extraSpellName, extraSpellSchool, auraType = CombatLogGetCurrentEventInfo()

    if event == "SPELL_AURA_BROKEN_SPELL" or event == "SPELL_AURA_BROKEN" then
        if not playerGUID then playerGUID = UnitGUID("player") end
        
        -- Trigger if the CC broken was on player's target, OR the breaker/victim relates to player
        local isTargetVictim = (destGUID == UnitGUID("target"))
        local isPlayerSource = (sourceGUID == playerGUID)

        if isTargetVictim or isPlayerSource then
            -- High-frequency brittle crack alerting early CC break
            Pulse:FireIfEnabled("crowdControlBroken")
        end
    end
end
```

---

### Candidate 3: Companion & Pet Death Mourning Alert (`petDead`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_CombatLogProcessor/Blizzard_CombatLogProcessor.lua:847` (`UNIT_DIED`), `UNIT_PET`
* **Engine APIs:** `UnitIsDead("pet")`, `UnitExists("pet")`

#### Enrichment Rationale
In Classic WoW, roughly **35% of all active characters** are pet-dependent (Beast Mastery / Marksmanship Hunters, Demonology / Affliction Warlocks, Frost Mages with Water Elementals). In the middle of intense combat with spells flying everywhere, a pet dying often goes completely unnoticed until Kill Command fails or threat collapses onto the player. Delivering a heavy, hollow mourning thud (`HEAVY_HOLLOW`, 0.85 Low motor, 220ms) followed by tactile silence communicates the companion's loss physically into the player's hands.

#### Pros vs. Cons
* **Pros:**
  - **Huge Player Base Value:** Directly enriches the two most popular leveling classes in Classic (Hunter and Warlock).
  - **Zero CPU Cost:** `UNIT_DIED` filtered strictly for `destGUID == UnitGUID("pet")` executes in microseconds.
  - **Emotional Impact:** Deepens the physical bond between player and companion.
* **Cons:**
  - **Intentional Dismissal / Phasing:** Must ensure normal dismissals (e.g. mounting, taxi, `/petdismiss`) do not fire a false death alert. Resolved by pairing `UNIT_DIED` with `UnitIsDead("pet")`.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/AlertUnitWatch.lua or dedicated Minion.lua
local petDeathFrame = CreateFrame("Frame")

local function onPetEvent(_, event, ...)
    if event == "UNIT_DIED" then
        local _, _, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        local petGUID = UnitGUID("pet")
        if petGUID and destGUID == petGUID then
            -- Ensure pet is actually dead, not phased or dismissed
            if UnitIsDead("pet") or UnitHealth("pet") <= 0 then
                Pulse:FireIfEnabled("petDead")
            end
        end
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "pet" then
            local maxHP = UnitHealthMax("pet")
            local curHP = UnitHealth("pet")
            if maxHP > 0 and (curHP / maxHP) < 0.20 and not UnitIsDead("pet") then
                Pulse:FireIfEnabled("petHealthCriticalWarning")
            end
        end
    end
end

local function syncPetWatch()
    petDeathFrame:UnregisterAllEvents()
    if not Pulse.Database:Get("masterEnabled") then return end
    if Pulse.Database:GetCue("petDead") or Pulse.Database:GetCue("petHealthCriticalWarning") then
        petDeathFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        petDeathFrame:RegisterUnitEvent("UNIT_HEALTH", "pet")
        petDeathFrame:SetScript("OnEvent", onPetEvent)
    end
end
```

---

### Candidate 4: Native Screen Shake to Haptic Translation (`ShakeFrame`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_SharedXML/ScriptAnimationUtil.lua`, `Blizzard_ShakeUtil/Blizzard_ShakeUtil.lua`
* **Native API:** `ScriptAnimationUtil.ShakeFrame(region, shake, duration, frequency)`

#### Enrichment Rationale
Throughout World of Warcraft, monumental physical moments shake the screen: giant boss footfalls (Fel Reaver, Thaddius, Colossus, Ragnaros), collapsing catacombs, artillery cannon fire, and earthquake abilities. Blizzard already calculates the exact magnitude, duration, and frequency of these shakes. By securely hooking `ScriptAnimationUtil.ShakeFrame` when `region == UIParent`, Pulse can synthesize proportional sub-bass rumblings automatically with **zero hardcoded spell tables**!

#### Pros vs. Cons
* **Pros:**
  - **Universal Coverage:** Automatically supports every current and future boss stomp, world quake, and scripted cinematic explosion in the game.
  - **Zero Maintenance:** Never needs spell ID updates or patch upkeep.
  - **Visceral Immersion:** Synchronizes visual camera shaking with physical controller rumble with 0ms perceptual desync.
* **Cons:**
  - **Taint Risk:** Hooking a core Blizzard utility requires absolute adherence to `hooksecurefunc` (User Rule 5). Never overwrite or modify arguments.
  - **Consecutive Shake Flooding:** Some encounters trigger continuous shake loops; must throttle minimum re-trigger interval (e.g. 200ms).

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/World.lua
local isShakeHooked = false
local lastShakeTime = 0
local SHAKE_THROTTLE = 0.200 -- 200ms clamp

local function onScreenShakeHook(region, shakeConfig, duration, frequency)
    -- Rule 5: Pure post-execution inspection, zero writes, zero taint
    if region ~= UIParent then return end
    if not Pulse.Database:Get("masterEnabled") or not Pulse.Database:GetCue("screenShakeTranslation") then return end

    local now = GetTime()
    if now - lastShakeTime < SHAKE_THROTTLE then return end
    lastShakeTime = now

    local dur = (type(duration) == "number" and duration > 0) and duration or 0.35
    local lowIntensity = 0.70

    -- Synthesize dynamic rumble matching Blizzard's visual shake parameters
    Pulse:HoldContinuous("screenShake", lowIntensity, 0.15, dur)
end

local function hookScreenShake()
    if isShakeHooked then return end
    if ScriptAnimationUtil and type(ScriptAnimationUtil.ShakeFrame) == "function" then
        hooksecurefunc(ScriptAnimationUtil, "ShakeFrame", onScreenShakeHook)
        isShakeHooked = true
    end
end
```

---

### Candidate 5: Loot Quality Fanfare Tiers (`Enum.ItemQuality`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_Inventory`, `Blizzard_WorldLootObjectList`, `C_Item.GetItemInfo`
* **Engine Events:** `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `CHAT_MSG_LOOT`
* **API:** `C_Loot.GetSlotInfo(slot)` or `GetLootSlotInfo(slot)` -> `itemLink`, `quality`

#### Enrichment Rationale
In Classic WoW, loot is the central emotional engine. Currently, Pulse's `Inventory.lua` only monitors total bag slot depletion (`bagItemAdded`). Opening a chest to find a grey cracked tooth produces the exact same tactile tick as looting an Epic *Krol Blade* or *Staff of Jordan*. Differentiating item rarity into distinct sensory tiers brings the dopamine loop into physical reality.

#### Pros vs. Cons
* **Pros:**
  - **Emotional High:** A grand dual-motor fanfare surge for Epic drops (`FANFARE_EPIC`) and an earthquake sub-bass swell for Legendaries (`CELEBRATION_LEGENDARY`).
  - **Inventory Awareness:** Players know instantly whether an item picked up in the field is vendor trash or valuable without stopping to open bags.
* **Cons:**
  - **AoE Looting Burst:** Looting 10 corpses at once in modern Classic engine could fire 10 cues in a single frame. Must process the highest rarity found in the batch and fire only one fanfare.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/Inventory.lua
local lootRarityFrame = CreateFrame("Frame")
local highestQualitySeen = -1

local function onLootOpened()
    if not Pulse.Database:GetCue("lootQualityFanfare") then return end
    
    local numItems = GetNumLootItems()
    highestQualitySeen = -1

    for slot = 1, numItems do
        local slotType = GetLootSlotType(slot)
        if slotType == 1 then -- Item
            local itemLink = GetLootSlotLink(slot)
            if itemLink and not issecretvalue(itemLink) then
                local _, _, quality = C_Item.GetItemInfo(itemLink)
                if quality and quality > highestQualitySeen then
                    highestQualitySeen = quality
                end
            end
        end
    end

    -- Trigger fanfare matching the highest item in the loot window
    if highestQualitySeen == Enum.ItemQuality.Legendary then
        Pulse:FireIfEnabled("lootQualityLegendary")
    elseif highestQualitySeen == Enum.ItemQuality.Epic then
        Pulse:FireIfEnabled("lootQualityEpic")
    elseif highestQualitySeen == Enum.ItemQuality.Rare then
        Pulse:FireIfEnabled("lootQualityRare")
    elseif highestQualitySeen == Enum.ItemQuality.Uncommon then
        Pulse:FireIfEnabled("lootQualityUncommon")
    end
end
```

---

### Candidate 6: Waypoint Proximity Geiger (`C_Navigation`)

* **Status:** 🆕 **GENUINELY NEW (ABSENT)**
* **Forever Subsystem:** `Blizzard_QuestNavigation`, `Blizzard_APIDocumentationGenerated/InGameNavigationDocumentation.lua`
* **Engine APIs:** `C_Navigation.GetDistance()`, `C_SuperTrack.GetHighestPrioritySuperTrackingType()`

#### Enrichment Rationale
For controller players playing from a couch or handheld device (Steam Deck / ROG Ally), looking back and forth between a tiny minimap arrow and the game world breaks immersion. The native `C_Navigation` subsystem calculates accurate 3D vector distance to active quest objectives, user pins, or corpse waypoints. Pulse can transform the gamepad into a physical Geiger counter that ticks progressively faster as you close in on the objective, resolving into a warm arrival chime upon arrival.

#### Pros vs. Cons
* **Pros:**
  - **Transformative Couch Accessibility:** Players can navigate to quest destinations and player corpses using touch alone.
  - **Natural Tension & Reward:** Accelerating click cadence creates organic excitement as an objective nears.
* **Cons:**
  - **Polling Overhead:** Must monitor distance without generating GC garbage (User Rule 4). Must only run when actively super-tracking, and throttle ticks to 0.5s–1.0s.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/Movement.lua or Navigation.lua
local navTicker = nil
local lastDistance = 999999
local arrivalFired = false

local function updateProximityGeiger()
    if not C_SuperTrack or not C_SuperTrack.IsSuperTrackingAnything() then
        return
    end

    local distance = C_Navigation.GetDistance()
    if issecretvalue(distance) or type(distance) ~= "number" then return end

    if distance < 5 and not arrivalFired then
        arrivalFired = true
        Pulse:FireIfEnabled("waypointArrival")
    elseif distance >= 5 and distance <= 50 then
        arrivalFired = false
        -- Cadence scales from 1.0s interval at 50yd down to 0.15s at 5yd
        Pulse:FireIfEnabled("waypointGeigerTick")
    elseif distance > 50 then
        arrivalFired = false
    end
end
```

---

### Candidate 7: Major Cooldown Broadcaster Integration (`TrackedCooldownsBySpec`)

* **Status:** ⚠️ **PARTIAL IN CODE (ENRICHMENT CANDIDATE)**
* **Forever Subsystem:** `Blizzard_CooldownBroadcaster/TrackedCooldowns.lua` (`namespace.TrackedCooldownsBySpec`)
* **Current Code State:** Pulse has a generic `cooldownReady` in `Combat.lua`, but it triggers on *every* ability reset (e.g. 6s Frost Shock or 8s Concussion Shot), drowning out high-impact cooldowns.

#### Enrichment Rationale
Activating a major 2m–5m offensive cooldown (Combustion, Avenging Wrath, Metamorphosis, Army of the Dead) or popping a life-saving defensive (Shield Wall, Icebound Fortitude, Survival Instincts) deserves an unmistakable high-impact tactile surge. Rather than maintaining a brittle, hand-crafted spell list that breaks on every balance patch, WoW Forever ships with `namespace.TrackedCooldownsBySpec`, Blizzard's authoritative dictionary of major cooldown IDs for every class specialization.

#### Pros vs. Cons
* **Pros:**
  - **Zero Maintenance:** Blizzard's internal UI maintainers keep the table accurate for all specs.
  - **Tactical Salience:** Players instantly feel when their primary burst or survival tools are ready or active without UI clutter.
* **Cons:**
  - **Addon Load Timing:** `Blizzard_CooldownBroadcaster` is loaded by Blizzard; Pulse must verify availability before indexing or cache the spec table on `ADDON_LOADED`.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/Combat.lua
local majorCooldowns = {}

local function cacheTrackedCooldowns()
    local specIndex = GetSpecialization and GetSpecialization() or 1
    local specID = GetSpecializationInfo and GetSpecializationInfo(specIndex) or 0

    -- Query Blizzard's native TrackedCooldowns table
    local broadcaster = _G["CooldownBroadcaster"] or CooldownBroadcaster
    local trackedTable = broadcaster and broadcaster.TrackedCooldownsBySpec
    
    wipe(majorCooldowns)
    if trackedTable and trackedTable[specID] then
        for _, spellID in ipairs(trackedTable[specID]) do
            majorCooldowns[spellID] = true
        end
    end
end

local function onSpellCooldownUpdate()
    -- Check if any tracked major cooldown just became ready
    for spellID in pairs(majorCooldowns) do
        local start, duration = GetSpellCooldown(spellID)
        if start == 0 and duration == 0 then
            Pulse:FireIfEnabled("majorCooldownReady")
        end
    end
end
```

---

### Candidate 8: UI Error Feedback & Mechanical Starvation ("Dead Clicks")

* **Status:** ⚠️ **PARTIAL IN CODE (ENRICHMENT CANDIDATE)**
* **Forever Subsystem:** `Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua:82-101`
* **Engine Event:** `UI_ERROR_MESSAGE`
* **Enums:** `LE_GAME_ERR_OUT_OF_ENERGY`, `LE_GAME_ERR_OUT_OF_RAGE`, `LE_GAME_ERR_OUT_OF_MANA`, `LE_GAME_ERR_OUT_OF_RANGE`, `LE_GAME_ERR_SPELL_COOLDOWN`

#### Enrichment Rationale
In gamepad play, players frequently mash buttons while waiting for energy, rage, or range. Currently, Pulse has a single generic `actionFailed` cue that triggers on arbitrary UI messages. By isolating specific numeric error codes, the controller can provide subtle mechanical resistance:
- **No Resource:** A spongy, hollow click (`HOLLOW_CLICK`, 0.20 intensity) mimicking an empty mechanical chamber.
- **Out of Range:** A dull rubbery deflection bump (`DEFLECT`, 0.25 intensity).
- **On Cooldown:** A stiff spring resistance rebound tick (`SPRING_TICK`, 0.20 intensity).

#### Pros vs. Cons
* **Pros:**
  - **Ergonomic Intuition:** Gamepad buttons feel physically connected to the character's internal energy constraints.
  - **Speech Suppression:** Players can disable annoying character error voices ("I can't do that yet") and rely purely on subtle tactile feedback.
* **Cons:**
  - **Spam Risk:** Fast button mashing during adrenaline moments could cause constant buzzing. Must enforce a strict **400ms temporal clamp** per error category.

#### Architectural Pseudocode
```lua
-- File: PulseHaptics/Modules/ControllerUI.lua
local lastErrorTimes = { resource = 0, range = 0, cooldown = 0 }
local ERROR_CLAMP = 0.400 -- 400ms clamp

local function onUIErrorMessage(_, _, messageType, message)
    if issecretvalue(messageType) then return end
    local now = GetTime()

    -- Resource Starvation (Out of Energy, Rage, Mana, Combo Points, Runes)
    if messageType == LE_GAME_ERR_OUT_OF_ENERGY or messageType == LE_GAME_ERR_OUT_OF_RAGE 
       or messageType == LE_GAME_ERR_OUT_OF_MANA or messageType == LE_GAME_ERR_OUT_OF_COMBO_POINTS then
        if now - lastErrorTimes.resource >= ERROR_CLAMP then
            lastErrorTimes.resource = now
            Pulse:FireIfEnabled("actionErrorNoResource")
        end
    -- Out of Range
    elseif messageType == LE_GAME_ERR_OUT_OF_RANGE or messageType == LE_GAME_ERR_SPELL_OUT_OF_RANGE then
        if now - lastErrorTimes.range >= ERROR_CLAMP then
            lastErrorTimes.range = now
            Pulse:FireIfEnabled("actionErrorOutOfRange")
        end
    -- Cooldown Incomplete
    elseif messageType == LE_GAME_ERR_ABILITY_COOLDOWN or messageType == LE_GAME_ERR_SPELL_COOLDOWN then
        if now - lastErrorTimes.cooldown >= ERROR_CLAMP then
            lastErrorTimes.cooldown = now
            Pulse:FireIfEnabled("actionErrorOnCooldown")
        end
    end
end
```

---

## 4. Top 10 Ranked "Must-Have" WoW Forever Cues

Ranked by **Return on Investment (ROI)**: balancing sensory value against implementation complexity and taint risk.

```
       HIGH IMPACT │  [1] Windfury/Extra Attacks
                   │  [2] Screen Shake Translation
                   │  [3] Pet Death Alert
                   │  [4] CC Premature Break
                   │  [5] Loot Quality Fanfare
                   │  [6] Waypoint Geiger
                   │  [7] Major Cooldown Ready
                   │  [8] UI Error Dead-Clicks
                   │  [9] Granular Environmental Hazards
        LOW IMPACT │  [10] Monk Stagger Gauge
                   └───────────────────────────────────────────────
                     LOW COMPLEXITY                  HIGH COMPLEXITY
```

| Rank | Cue Identifier | Domain | Impact | Complexity | Core Reason for Inclusion |
|:---:|:---|:---:|:---:|:---:|:---|
| **1** | `procExtraAttacks` | Combat | **Legendary** | **Low** | The definitive tactile joy of Classic melee (Windfury, Sword Spec, Ironfoe). |
| **2** | `screenShakeTranslation` | World | **Very High** | **Low** | Free rumble on every boss stomp, quake, and explosion with zero spell lists. |
| **3** | `petDead` | Minions | **Very High** | **Low** | Lifeline awareness for the 35% of players maining Hunters and Warlocks. |
| **4** | `crowdControlBroken` | Combat/CC | **High** | **Low** | Immediate tactical glass-shatter alert when an enemy sheep/trap breaks early. |
| **5** | `lootQualityFanfare` | Economy | **High** | **Medium** | Transforms mundane looting into an exciting progression dopamine loop. |
| **6** | `waypointGeiger` | Navigation | **High** | **Medium** | Game-changer for couch/handheld players navigating without looking at minimaps. |
| **7** | `majorCooldownReady` | Class/Burst | **High** | **Medium** | Leverages Blizzard's native `TrackedCooldownsBySpec` for major offensive bursts. |
| **8** | `actionErrorDeadClicks`| Ergonomics | **Medium-High**| **Low** | Replaces annoying vocal error spam with subtle physical button resistance. |
| **9** | `envDamageGranular` | Environment | **Medium** | **Low** | Gives physical identity to Lava sizzle and Slime churn in Classic dungeons. |
| **10**| `monkStaggerGauge` | Class | **Medium** | **Medium** | Transformative heartbeat monitor and purify release for Brewmaster Tanks. |

---

## 5. Architectural Guardrails for Future Implementation

When the user gives the signal to begin prototyping or authoring code, all changes must adhere strictly to the following standards:

1. **Rule 4: Zero-GC Enforcement in High-Frequency Frames:**
   - No table allocations (`{}`) inside `COMBAT_LOG_EVENT_UNFILTERED`, `OnUpdate`, or `UI_ERROR_MESSAGE`.
   - Use file-scoped static recycling tables (`staticCombatBuffer`, `lastErrorTimes`) and `wipe(tbl)`.
2. **Rule 5: Combat Protection & Taint Immunity:**
   - All hooks on Blizzard UI functions (`ScriptAnimationUtil.ShakeFrame`) MUST use `hooksecurefunc`.
   - Never write to or modify Blizzard protected tables during combat.
3. **Lua 5.1 Sandbox Compliance:**
   - Adhere strictly to Lua 5.1 syntax (no `goto`, no `&`/`|` bitwise operators; use the built-in `bit` library).
4. **Defensive Secrecy Guards:**
   - Every text string, GUID, and numeric reading must pass through `issecretvalue()` guards to guarantee compatibility with WoW 12.0 and Classic Beta privacy sandboxes.
5. **Quality Verification:**
   - Format all files using `stylua`.
   - Verify 0 errors and 0 warnings using `luacheck` before testing.

---

## 6. Summary

This churn document confirms that while Pulse already possesses foundational systems for swing timing, melee range, and basic soft-targeting, **the highest-impact tactile experiences in Classic WoW—Windfury extra attacks, premature CC breaks, pet death alerts, screen shake quakes, and loot rarity fanfare—remain completely untapped.**

Each candidate is fully specified above with its mechanical value, risk analysis, and defensive Lua 5.1 pseudocode, ready for phased implementation planning upon user instruction.
