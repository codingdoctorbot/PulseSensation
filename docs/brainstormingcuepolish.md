# 💎 PulseHaptics: Smart Cue Polish & Architectural Blueprints
> **Exploratory Brainstorming Compendium: Competing Implementations, UI Paradigms, and Double-Fire Eradication**  
> **Target Client:** World of Warcraft Forever (`_classic_beta_` / `1.60.1.69913` / Interface `120100`)  
> **Status:** Architectural Design Specification (Strictly read-only regarding code; zero code changes applied)  
> **Date:** September 2026  

---

## Chapter 1: The Brainstorming Mandate — The Value of Competing Paradigms

Brainstorming is not about prematurely forcing a consensus; it is about stress-testing radically different philosophies against real user needs and technical constraints. 

In haptic feedback design, two diametrically opposed design philosophies exist:
1. **The "Apple / Console" Philosophy (Blueprint A):** Radical simplification. Do not burden the player with 190 dials. Curate a cohesive, tactile soundscape that "just works" with 6 macro-switches.
2. **The "Power-User / Modular" Philosophy (Blueprint B):** Maximum player agency. Haptics are deeply neuro-ergonomic; what feels immersive to one player causes sensory fatigue in another. Preserve every single granular dial, but organize them into clean hierarchical accordions with master overrides.
3. **The "Dynamic / Adaptive" Philosophy (Blueprint C):** Context-aware intelligence. Don't make the user configure settings at all—let the addon dynamically dampen non-essential cues during boss fights and elevate them in peaceful taverns.

By detailing each approach in its own dedicated chapter, we preserve all creative avenues, analyze their exact code implementations, and provide a clear basis for decision-making.

---

## Chapter 2: The Core Problem Statement: Sensory Mud vs. Menu Bloat

Regardless of which philosophy is chosen, PulseHaptics faces two structural design challenges:

### 1. The UX Challenge: Menu Bloat ("The Spreadsheet of 190 Rows")
- In the current addon, `Registry.lua` registers roughly 190 cues across internal engine categories (`INTERFACE`, `WORLD`, `COMBAT`, `ENVIRONMENT`, `ALERT_UNIT_WATCH`).
- When opened on a PC monitor, it requires endless vertical scrolling.
- When opened on a handheld or couch setup (Steam Deck, ROG Ally, gamepad TV play), navigating 190 rows with a D-pad or analog stick causes extreme decision fatigue.

### 2. The Engine Challenge: Sensory Mud (Double-Firing Race Conditions)
- When a player performs a single game action, multiple isolated modules trigger simultaneously:
  - **Buying from a vendor:** `merchantBuy` + `bagItemAdded` + `itemObtained` fire within milliseconds.
  - **Looting a mob:** `lootOpened` + `harvestComplete` + `itemObtained` + `lootReceived` + `lootGold` + `bagItemAdded` fire in an overlapping blur.
  - **Repairing armor:** `merchantRepair` + `durabilityLow` + `merchantBuy` collide.
- When multiple vibration events fire simultaneously, gamepad linear resonant actuators (LRAs) or dual-rumble motors cannot articulate distinct waveforms—they blur into an undefined, mushy buzz.

---

## Chapter 3: The Universal Engine Truth: Root Causes of Double-Firing

Before comparing UI paradigms, we must address the engine layer. Any successful design requires eliminating cross-module collisions.

```
                          ┌───► Interaction.lua ──► FIRES 'merchantBuy' (Primary)
[ 1. Buy From Vendor ] ───┼───► Inventory.lua   ──► SUPPRESSED: 'bagItemAdded' (Was Duplicate)
                          └───► World.lua       ──► SUPPRESSED: 'itemObtained' (Was Duplicate)

                          ┌───► World.lua       ──► Settles 120ms Buffer ──► FIRES 'itemObtained' (Rarity Scaled)
[ 2. Looting Corpse ]  ───┼───► Inventory.lua   ──► SUPPRESSED: 'bagItemAdded' (Was Redundant)
                          ├───► World.lua       ──► SUPPRESSED: 'lootReceived' (Was Raw Chat Spam)
                          └───► Interaction.lua ──► FIRES: 'lootOpened' (Distinct Container Open)

                          ┌───► Interaction.lua ──► FIRES 'merchantRepair' (Ringing Anvil)
[ 3. Repairing Gear ]  ───┼───► Interaction.lua ──► SUPPRESSED: 'merchantBuy' (Money spent was repair)
                          └───► World.lua       ──► SUPPRESSED: 'durabilityLow' (False durability flash)

                          ┌───► Movement.lua    ──► FIRES 'jumpStart' (Kinetic Push-Off)
[ 4. Jump & Landing ]  ───┼───► Locomotion.lua  ──► COALESCED: Smooth ground departure curve
                          └───► Environment.lua ──► FIRES 'fallImpact' ONLY if airborne duration > threshold

                          ┌───► AlertThreat.lua ──► FIRES 'combatEnter' (Threat Flare)
[ 5. Enter Combat ]    ───┴───► Combat.lua      ──► SUPPRESSED: Secondary Regen-Disabled click

                          ┌───► Combat.lua      ──► FIRES 'meleeRangeIn' (Detent Tick)
[ 6. Melee Swing ]     ───┴───► Combat.lua      ──► 80ms Swing Protection: 'weaponSwingMain' strikes cleanly
```

### 3.1 The 6 Cross-Module Collision Hotspots

| Hotspot / Player Action | Triggering Events | Primary Cue Fired | Secondary Cues Actively Suppressed | Root Cause in Source & Elegant Fix |
|:---|:---|:---|:---|:---|
| **1. Buying from Vendor** | `PLAYER_MONEY` (delta < 0 while in merchant) | `merchantBuy` | **`bagItemAdded`** & **`itemObtained`** | `Inventory.lua:146` checks `free < lastFreeSlots` without checking if merchant is open. Adding `not Pulse.Context:IsRecentMerchantPurchase()` eliminates the double pulse. |
| **2. Selling to Vendor** | `PLAYER_MONEY` (delta > 0 while in merchant) | `merchantSell` | **`bagItemUsed`** | `Inventory.lua:149` checks `isInteractingWithStorageOrMerchant()`, but `World.lua` must also ignore bag drops during merchant transactions. |
| **3. Repairing Gear** | `UPDATE_INVENTORY_DURABILITY` while in merchant | `merchantRepair` | **`merchantBuy`** & **`durabilityLow`** | `Interaction.lua:187` tracks `wasRepair` to block `merchantBuy`, but `World.lua:17` still blindly catches durability alerts. Coordinating via `Pulse.Context.isRepairing` solves this. |
| **4. Looting Corpse / Chest** | Settled loot intake (`LOOT_SLOT_CLEARED` + `BAG_UPDATE_DELAYED`) | **`itemObtained`** (Quality Scaled) | **`lootReceived`**, **`harvestComplete`**, **`bagItemAdded`** | `LOOT_READY` (`harvestComplete`) and raw `CHAT_MSG_LOOT` (`lootReceived`) fire alongside bag updates. Coalescing them into a settled intake eliminates 4 overlapping pulses. |
| **5. Banking Items** | Moving gear into bank container | **`bankGold`** / `bankClosed` | **`bagItemUsed`** & **`bagItemAdded`** | Suppress generic bag flutter when transferring into bank storage slots. |
| **6. Melee Range & Initial Strike** | `PLAYER_SWING_RANGE_UPDATE` + `PLAYER_SWING` | `targetInMeleeRange` $\to$ `weaponSwingMain` | Colliding initial swing collision | 80ms debounce ensures stepping into range clicks cleanly before the first kinetic swing strikes. |

### 3.2 The Zero-GC Arbitration Engine (`Pulse.Context`)

To coordinate modules cleanly without introducing garbage collection overhead or execution taint, Pulse can implement a static context registry:

```lua
-- File: PulseHaptics/Core/Context.lua
-- Pure Lua 5.1, Rule 4 (Zero-GC), Rule 5 (Taint Immunity)

local ADDON_NAME, Pulse = ...

local Context = {
    isInteractingWithMerchant = false,
    isInteractingWithStorage = false,
    isRepairing = false,
    lastMerchantTransactionTime = 0,
    lastLootIntakeTime = 0,
    highestLootQuality = -1,
}
Pulse.Context = Context

function Context:SetMerchantOpen(isOpen)
    self.isInteractingWithMerchant = isOpen and true or false
    if not isOpen then
        self.isRepairing = false
    end
end

function Context:SetStorageOpen(isOpen)
    self.isInteractingWithStorage = isOpen and true or false
end

function Context:RecordMerchantPurchase()
    self.lastMerchantTransactionTime = GetTime()
end

function Context:IsRecentMerchantPurchase()
    -- Suppress bag additions within 250ms of a vendor money deduction
    return (GetTime() - self.lastMerchantTransactionTime) < 0.250
end

function Context:RecordLootDrop(quality)
    local now = GetTime()
    if (now - self.lastLootIntakeTime) > 0.120 then
        self.highestLootQuality = quality
    else
        if quality > self.highestLootQuality then
            self.highestLootQuality = quality
        end
    end
    self.lastLootIntakeTime = now
end
```

---

## Chapter 4: Implementation Blueprint A — The Aggressive Monolithic / Consolidated Architecture

### 4.1 Philosophy & Concept ("The Gamepad-First Minimalist")
Blueprint A treats haptic design like high-end audio mixing. Just as an audiophile game does not let the player toggle the sound of every individual shoe material, PulseHaptics curates **6 Unified Tactile Systems**. 

The player does not toggle `bankOpened`, `mailShow`, `merchantShow`, and `trainerShow` individually. They toggle **"World & NPC Interactions"**. Under the hood, the engine dynamically selects the appropriate material vibration (iron for bank, paper for mail, wood for vendor), but the player is presented with a distraction-free interface.

### 4.2 UI Wireframe: The Single-Page Dashboard
The entire configuration fits onto a single screen with zero scrolling required:

```
===================================================================================
                       PULSE HAPTICS: SYSTEM CONTROLS
===================================================================================

  [1] SERVICES & NPC DIALOGUE                  [ ENABLED  ]   [ Volume: ──●── 80% ]
      Bank vaults, mailboxes, merchants, trainers, and auctioneers.
      Vibration: Physical Material Simulation (Iron, Paper, Wood, Stone)

  [2] LOOT & INVENTORY INTAKE                  [ ENABLED  ]   [ Volume: ────● 100% ]
      Corpse looting, container opening, and item quality fanfare.
      Vibration: Smart Rarity Scaling (Common to Legendary)

  [3] COMMERCE & CURRENCY FLOW                 [ ENABLED  ]   [ Volume: ──●── 75% ]
      Vendor purchases, sales, gear repairs, and gold accumulation.
      Vibration: Weighted Coin & Anvil Dynamics

  [4] KINETIC MELEE COMBAT                     [ ENABLED  ]   [ Volume: ────● 100% ]
      Weapon swings, melee range boundaries, and extra attack flurries.
      Vibration: Heavy Motor Dual-Cadence & Windfury Bursts

  [5] PETS & COMPANIONS                        [ ENABLED  ]   [ Volume: ──●── 70% ]
      Pet death alerts, taunt confirmation, and health distress.
      Vibration: Emotional Pulse & Heartbeat Throb

  [6] ENVIRONMENTAL HAZARDS                    [ ENABLED  ]   [ Volume: ──●── 85% ]
      World screen shakes, lava heat, acid immersion, and fall impact.
      Vibration: Low-Frequency Rumble & Concussive Shocks

===================================================================================
  [ Test All Systems ]                             [ Reset Defaults ]  [ Close ]
===================================================================================
```

### 4.3 SavedVariables Schema (Ultra-Compact)
```lua
PulseDB = {
    profile = {
        masterVolume = 1.0,
        systems = {
            services = { enabled = true, volume = 0.8 },
            loot = { enabled = true, volume = 1.0 },
            commerce = { enabled = true, volume = 0.75 },
            melee = { enabled = true, volume = 1.0 },
            pets = { enabled = true, volume = 0.7 },
            hazards = { enabled = true, volume = 0.85 },
        }
    }
}
```

### 4.4 Pros & Cons of Blueprint A
* **Pros:**
  - **Zero Cognitive Load:** Instant comprehension. Anyone can configure the addon in 5 seconds.
  - **Gamepad / Couch Ergonomics:** Navigating 6 sliders on a Steam Deck or ROG Ally with a D-pad is effortless.
  - **Zero Double-Firing by Definition:** Because each domain is a single consolidated system, there are no competing sub-toggles to create conflicting states.
  - **Minimal Memory Footprint:** Tiny SavedVariables table and ultra-lightweight UI frame hierarchy.
* **Cons:**
  - **Zero Sub-Cue Autonomy:** A player cannot disable `gossipShow` while keeping `bankOpened`.
  - **Inflexible for Power Users:** Advanced players who want custom vibration modes (`MOTOR_BURST` vs `TICK`) on specific spells or events are locked out.

---

## Chapter 5: Implementation Blueprint B — The Hierarchical Accordion & Master Gates

### 5.1 Philosophy & Concept ("The Power-User Autonomy Model")
Blueprint B acknowledges that tactile sensation is deeply subjective. What feels delightful to one player can feel like an annoying buzz to another. 

Therefore, **every single granular cue must remain individually customizable**, but the presentation must be rescued from the "190-row spreadsheet" through **Collapsible Group Cards** and **Non-Destructive Master Gates**.

### 5.2 UI Wireframe: Collapsible Group Cards

```
===================================================================================
                       PULSE HAPTICS CONFIGURATION
   [ Search Cues...                                                  [ Filter ] ]
===================================================================================

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▼] SERVICES & NPC WINDOWS                       [ MASTER: ON ]  [ Vol: ──●── ] │
│     Interactions with merchants, mail, banks, auctioneers, and trainers.         │
│     Status: 8 of 11 Cues Active (Click header to collapse)                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│   Granular Settings:                                                            │
│   ☑ Personal Bank & Guild Vault Latch            [ LATCH_HEAVY  ▼ ]  [ Vol: ──● ]
│   ☑ Mailbox Envelope Rustle & Wax Seal           [ PAPER_POP    ▼ ]  [ Vol: ──● ]
│   ☑ Merchant Counter & Stall Dialogue            [ WOOD_SLIDE   ▼ ]  [ Vol: ──● ]
│   ☑ Auction House Gavel Strike                   [ GAVEL_TAP    ▼ ]  [ Vol: ──● ]
│   ☑ Innkeeper Hearthstone Binding Ceremony       [ HARMONIC_HUM ▼ ]  [ Vol: ──● ]
│   ☐ Class & Profession Trainers                  [ MARTIAL_SNAP ▼ ]  [ Vol: ──● ]
│   ☐ Stable Master & Beast Stalls                 [ DOUBLE_CLICK ▼ ]  [ Vol: ──● ]
│   ☐ Spirit Healer Transcendence                  [ ETHEREAL_HUM ▼ ]  [ Vol: ──● ]
│   ☐ Conversation / Gossip Dialogues              [ TICK_SOFT    ▼ ]  [ Vol: ──● ]
│   ☑ Vault / Window Closure Latch                 [ LATCH_LIGHT  ▼ ]  [ Vol: ──● ]
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▶] LOOT & INVENTORY INTAKE                      [ MASTER: ON ]  [ Vol: ──●── ] │
│     Corpse loot, chest opening, bag management, and item quality fanfare.       │
│     Status: 9 of 9 Cues Active (Click to expand fine-tuning)                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▶] COMMERCE & CURRENCY FLOW                     [ MASTER: ON ]  [ Vol: ──●── ] │
│     Buying, selling, armor repairs, and coin accumulation.                      │
│     Status: 5 of 5 Cues Active (Click to expand fine-tuning)                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▶] MELEE COMBAT & WEAPON RHYTHM                 [ MASTER: ON ]  [ Vol: ──●── ] │
│     Swing cadences, melee range detents, and extra attack flurries.             │
│     Status: 5 of 5 Cues Active (Click to expand fine-tuning)                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▶] MINIONS & COMPANION BONDS                    [ MASTER: ON ]  [ Vol: ──●── ] │
│     Pet death alerts, taunt anchors, distress flutter, and feeding purrs.       │
│     Status: 4 of 4 Cues Active (Click to expand fine-tuning)                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│ [▶] WORLD & ENVIRONMENTAL HAZARDS                [ MASTER: ON ]  [ Vol: ──●── ] │
│     Camera screen shakes, lava sizzle, acid slime, fall impact, and drowning.   │
│     Status: 5 of 5 Cues Active (Click to expand fine-tuning)                     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Non-Destructive Master Gate Architecture
The crucial technical rule of Blueprint B is that **Master Switches must never overwrite individual child settings**:

```lua
PulseDB = {
    profile = {
        groups = {
            windows = { enabled = true, volume = 1.0, expanded = false },
            loot = { enabled = true, volume = 1.0, expanded = false },
            commerce = { enabled = true, volume = 0.8, expanded = false },
            melee = { enabled = true, volume = 1.0, expanded = true },
            minions = { enabled = true, volume = 1.0, expanded = false },
            hazards = { enabled = true, volume = 0.9, expanded = false },
        },
        cues = {
            bankOpened = { enabled = true, mode = "LATCH_HEAVY", volume = 1.0 },
            mailShow = { enabled = true, mode = "PAPER_POP", volume = 1.0 },
            gossipShow = { enabled = false, mode = "TICK_SOFT", volume = 0.5 },
            -- Every granular cue retains its individual state!
        }
    }
}
```

#### Runtime Execution Gate
```lua
function Pulse:IsCuePlayable(cueId)
    local cueConfig = self.db.profile.cues[cueId]
    if not cueConfig or not cueConfig.enabled then
        return false
    end
    
    -- Check Master Gate for the cue's parent group
    local groupId = self:GetCueGroup(cueId)
    if groupId then
        local groupConfig = self.db.profile.groups[groupId]
        if groupConfig and not groupConfig.enabled then
            return false -- Master switch silenced the category instantly!
        end
    end
    
    return true
end
```

### 5.4 Pros & Cons of Blueprint B
* **Pros:**
  - **100% Customization Freedom:** Every cue remains independently tunable in volume, toggle state, and vibration pattern.
  - **Non-Destructive State Preservation:** Toggling a Master Switch off for a raid does not wipe child preferences. When toggled back on, fine-tuned settings return immediately.
  - **Clean Executive Overview:** Collapsed cards provide an immediate summary badge (e.g., `8 of 11 Cues Active`).
* **Cons:**
  - **More Complex UI Code:** Requires implementing dynamic accordion expansion, scroll height adjustments, and child-parent linkage in `UI/Panel/Content.lua`.
  - **Larger SavedVariables Footprint:** Persists both group states and individual cue records.

---

## Chapter 6: Implementation Blueprint C — The Adaptive Contextual & Tag-Based Dynamic Engine

### 6.1 Philosophy & Concept ("The Living Haptic Mix")
Blueprint C takes inspiration from dynamic audio engines like Wwise or FMOD. In high-stakes combat, you don't care about the sound of a coin or a mailbox opening—your sensory bandwidth must be 100% dedicated to survival.

Instead of static checkboxes, cues carry semantic tags:
- `#combat_critical`: Low health alerts, loss of control, CC breaks, Windfury procs.
- `#combat_rhythm`: Auto-attack swings, melee range detents.
- `#world_immersion`: Screen shakes, footsteps, weather, swimming.
- `#economy_service`: Vendor dialogues, mailbox rustles, bag management.

### 6.2 Dynamic Context Gating
The engine automatically switches mixer profiles based on the player's immediate game state:

```
[ Game State ] ──────► In Combat Lockdown? ───┬──► YES: Suppress #economy_service & #world_immersion
                                              │         Elevate #combat_critical & #combat_rhythm
                                              │
                                              └──► NO:  In Raid / Dungeon Instance? ──┬──► YES: Standard Combat Mix
                                                                                      │
                                                                                      └──► NO:  Full Immersion Mix (All Cues)
```

#### Zero-Allocation Context Checker
```lua
-- File: PulseHaptics/Core/Mixer.lua
local function GetCurrentMixerProfile()
    if InCombatLockdown() then
        return "COMBAT_FOCUS"
    elseif IsInRaid() or IsInGroup() then
        return "DUNGEON_ACTIVE"
    else
        return "WORLD_IMMERSION"
    end
end
```

### 6.3 One-Click Archetype Presets
For players who do not want to configure 190 cues or fiddle with accordions, Blueprint C provides **4 One-Click Presets**:

1. **Tactile Minimalist:** Only life-saving alerts (CC breaks, threat loss, execution health thresholds, lethal fall damage). Zero ambient buzz.
2. **Kinetic Brawler:** Focused entirely on melee combat rhythm (swings, range boundaries, extra attack procs) with interface noise muted.
3. **Full Sensory Immersion:** Every world interaction, material window, footsteps, and loot drop vibrating with maximum fidelity.
4. **Accessibility / Deaf Player:** Maximum tactile contrast and prolonged vibration waveforms for off-screen visual and auditory events.

### 6.4 Pros & Cons of Blueprint C
* **Pros:**
  - **Smart & Zero-Touch:** The addon feels intelligent. Players never have to manually turn off annoying cues during boss encounters.
  - **Optimal Sensory Clarity:** Eliminates haptic fatigue by clearing the channel when combat starts.
  - **Preset Convenience:** 4 distinct archetypes satisfy 95% of players with a single click.
* **Cons:**
  - **Loss of Determinism:** If a player specifically *wants* to feel an item drop during combat, the dynamic filter might suppress it unless configured with overrides.
  - **State Transition Overhead:** Requires monitoring `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` cleanly without generating execution taint.

---

## Chapter 7: Side-by-Side Comparative Matrix (Blueprint A vs. B vs. C)

| Evaluation Vector | Blueprint A: Monolithic Consolidated | Blueprint B: Hierarchical Accordion | Blueprint C: Adaptive Dynamic Mixer |
|:---|:---:|:---:|:---:|
| **Initial Visual Simplicity** | ⭐️⭐️⭐️⭐️⭐️ (1 Screen, 6 Sliders) | ⭐️⭐️⭐️⭐️ (6 Cards, Expandable) | ⭐️⭐️⭐️⭐️⭐️ (4 Preset Buttons) |
| **Player Autonomy & Precision** | ⭐️ (All or nothing per category) | ⭐️⭐️⭐️⭐️⭐️ (Every cue tunable) | ⭐️⭐️⭐️ (Tag/Profile based) |
| **Gamepad / Handheld Usability** | ⭐️⭐️⭐️⭐️⭐️ (Effortless D-pad nav) | ⭐️⭐️⭐️ (Scrolling expanded cards) | ⭐️⭐️⭐️⭐️⭐️ (Select preset & play) |
| **Double-Fire Immunity** | ⭐️⭐️⭐️⭐️⭐️ (Built-in by design) | ⭐️⭐️⭐️⭐️⭐️ (Via `Pulse.Context`) | ⭐️⭐️⭐️⭐️⭐️ (Via Dynamic Tag Mute) |
| **Combat Sensory Clarity** | ⭐️⭐️⭐️ (Static volume) | ⭐️⭐️⭐️ (Static volume) | ⭐️⭐️⭐️⭐️⭐️ (Auto-clears non-combat noise) |
| **Config Persistence Safety** | ⭐️⭐️⭐️⭐️⭐️ (Simple keys) | ⭐️⭐️⭐️⭐️⭐️ (Non-destructive master) | ⭐️⭐️⭐️⭐️ (Profile overrides) |
| **Implementation Complexity** | ⭐️ (Very Low) | ⭐️⭐️⭐️ (Moderate UI work) | ⭐️⭐️⭐️⭐️ (Dynamic state engine) |
| **Target User Group** | Couch / Casual Players | Power Users & Min-Maxers | Modern Gamers & Accessibility |

---

## Chapter 8: Synthesis & The Recommended Phased Roadmap

Having all three implementations documented side-by-side reveals an exciting truth: **they are not mutually exclusive.** They can be layered into a cohesive product evolution:

```
[ Phase 1: Engine Foundation ] ────► Implement Pulse.Context (Zero-GC Mutual Exclusion)
                                     - Fixes vendor buy double-fire (Inventory.lua:146)
                                     - Fixes looting multi-item blur (120ms settlement buffer)
                                     - 100% invisible to user, instantly improves tactile crispness

[ Phase 2: UI Evolution ]        ────► Implement Blueprint B (Hierarchical Group Cards)
                                     - Replaces 190 flat rows with 6 Collapsible Thematic Cards
                                     - Non-destructive Master Gates protect child preferences
                                     - Preserves full autonomy for power users

[ Phase 3: Smart Presets ]       ────► Layer on Blueprint C (Archetype Presets & Dynamic Muting)
                                     - Add "Minimalist", "Brawler", "Immersion", and "Accessibility" buttons
                                     - Optional "Combat Dampening" toggle in Settings
```

This phased pathway protects player agency, elevates gamepad ergonomics, and guarantees crystal-clear, collision-free tactile feedback for World of Warcraft Forever.

---

## Chapter 9: Advanced Brainstorming Thoughts & Edge-Case Dynamics

This chapter captures deeper operational thoughts, edge cases, and architectural nuances explored during brainstorming. These thoughts address real-world game interactions and refine how the smart engine behaves under stress.

---

### Thought 9.1: Unifying Blueprint A and Blueprint B via a "Simple vs. Advanced" View Switch
Rather than forcing a permanent binary choice between Blueprint A (console simplicity) and Blueprint B (power-user accordions), the UI can seamlessly bridge them with a single **Mode Switch** in the top-right header of the settings panel:

* **"Simple Mode" (Default / Couch Play):**
  - Displays exclusively the **6 Master Group Cards** with their master toggles and group volume sliders.
  - The accordion disclosure chevrons are hidden or locked.
  - Zero cognitive friction; fits cleanly onto a single screen with zero scrolling, ideal for handhelds (Steam Deck, ROG Ally) and gamepad couch navigation.
* **"Advanced Mode" (Power-User Workshop):**
  - Unlocks the accordion chevrons `[▶]`, revealing all ~190 granular sub-cues with their individual checkboxes, vibration mode selectors (`LATCH_HEAVY`, `TICK`, `MOTOR_BURST`), and independent volume sliders.
* **Non-Destructive Bridge:** Switching between Simple and Advanced modes never resets or modifies child settings. Simple mode simply hides the granular rows without disabling them.

---

### Thought 9.2: The "Bulk Action" Avalanche (Shift-Looting, Junk Sellers & Mass Mail)
Standard mutual exclusion solves single-item purchases, but rapid automated interactions in World of Warcraft trigger event storms that must be coalesced into single, cohesive physical gestures:

#### 1. Bulk Grey Selling (Addons like Leatrix, Scrap, or SellJunk)
- **The Problem:** When an automated junk-seller addon liquidates 12 grey items in 1 millisecond, the WoW client fires 12 rapid `BAG_UPDATE_DELAYED` events and 12 distinct money balance shifts. Left unguarded, this results in an abrasive motor stutter that overwhelms controller actuators.
- **The Smart Solution (Till Drawer Coalescence):** The engine detects money influxes occurring within a 200ms transaction window. Instead of 12 micro-clicks, it fires **one crisp initial cash-drawer slide click** when the sale begins, followed by **one solid, weighted coin thud** for the total net gold gained when the transaction batch settles.

#### 2. Shift-Looting (Vacuum Corpse Looting)
- **The Problem:** Shift-clicking a corpse or mining node immediately loots all available slots in rapid succession.
- **The Smart Solution (Settled Loot Intake):** The container open click (`lootOpened`) fires instantly on corpse interaction. Subsequent item acquisitions within a 120ms settlement buffer are collapsed into a single tactile chime scaled to the highest quality item looted, rather than rattling the motors for every individual linen cloth or broken boar tusk.

#### 3. "Open All Mail" Processing
- **The Problem:** Clicking "Open All" in modern mailbox interfaces retrieves dozens of attachments and coins sequentially, causing continuous overlapping envelope rustles and bag pings.
- **The Smart Solution:** While an `OPEN_ALL_MAIL` loop is active, individual envelope rustles are suppressed in favor of a soft, rhythmic paper-sorting flutter that concludes with a definitive latch click once all mail processing finishes.

---

### Thought 9.3: Window Chaining Collisions (Auto-Close Race Conditions)
In World of Warcraft, interacting with a new world object or NPC frequently forces an open window to close automatically:
* **The Scenario:** While viewing the mailbox, the player clicks on a nearby vendor or banker.
* **The Event Collision:** The game fires `MAIL_CLOSED` (or generic `interactionWindowClosed`) and `MERCHANT_SHOW` in the exact same frame render tick.
* **The Tactile Flaw:** The tactile "closing tick" clashes with or cancels out the "opening slide," producing an indistinct vibration pulse.
* **The Smart Solution (Transition Priority):** Implement a 50ms window transition priority filter. If an interaction window open event occurs within 50ms of a window close event, the "close" cue is suppressed. The player is intentionally engaging a new interface; their tactile focus should be 100% on the newly arrived window.

---

### Thought 9.4: Mathematical Volume Scaling & Motor Deadzone Physics
When calculating the final vibration intensity for a cue governed by multiple volume sliders:

$$\text{Effective Intensity} = \text{MasterVolume} \times \text{GroupVolume} \times \text{CueVolume}$$

For example, if Master is set to $0.80$, Commerce Group is set to $0.75$, and `merchantBuy` is set to $0.50$:

$$\text{Effective Intensity} = 0.80 \times 0.75 \times 0.50 = 0.30\ (30\%)$$

#### The Rumble Motor Deadzone Problem
Physical eccentric rotating mass (ERM) motors and linear resonant actuators (LRAs) inside gamepads have an electrical stall threshold:
* If a calculated intensity falls below $\sim 10\text{--}15\%$, the motor lacks the electrical current to break static friction. Instead of vibrating subtly, it either hums at an irritating high-pitched whine or does not spin at all.
* **The Smart Solution:** The haptic engine applies a **Non-Linear Perception Floor**:
  - Intensities between $1\%$ and $12\%$ are gently clamped up to the actuator's minimum effective activation threshold ($15\%$).
  - If a slider is pulled to $0\%$, it cleanly mutes to absolute zero without firing motor calls.

---

### Thought 9.5: Loot Settlement Hierarchy: Narrative Quest Items vs. Rare Gear
When looting multiple items at once, standard item quality logic ranks:
$$\text{Poor (Grey)} < \text{Common (White)} < \text{Uncommon (Green)} < \text{Rare (Blue)} < \text{Epic (Purple)} < \text{Legendary (Orange)}$$

However, narrative quest items (like *Head of VanCleef* or *A Mysterious Parchment*) are often classified internally as Common (White) or Quest (Uncommon), yet they carry the highest emotional reward for the player.

* **The Problem:** If a corpse contains a generic green BoE bracer and a major quest objective item, standard rarity scaling would play the green chime and silence the quest item.
* **The Smart Solution (Priority-Tiered Loot Settlement):** The 120ms settlement buffer incorporates quest flag awareness:
  $$\text{Legendary} > \text{Epic} > \text{Rare} > \mathbf{Quest\ Item\ (Objective)} > \text{Uncommon} > \text{Common} > \text{Poor}$$
  This guarantees that completing a quest objective or finding a rare mission artifact is never tactilely demoted by random vendor gear.

---

### Thought 9.6: Bag Inventory Drops vs. Equipment Paperdoll Swaps
When a player changes their weapon or armor in the character sheet:
* The item departs the inventory and enters an equipment slot; the old item leaves the character paperdoll and enters the bag.
* Currently, this swap can trigger generic `bagItemAdded` or `bagItemUsed` cues.
* **The Smart Solution:** Equipment changes should feel distinctly martial (a heavy leather buckle cinch, a metallic weapon sheath click, or a shield strap snap), completely differentiated from picking up loot in the wilderness or drinking a potion. Suppressing generic bag cues during character sheet equipment changes preserves the distinct physical identity of gear.
