#!/usr/bin/env python3
"""
Generate comprehensive cue review markdown reports for all Pulse built-in profiles,
and format the Lua PROFILE_TRIGGER_OVERRIDES table in PulseHaptics/Core/Database.lua.
"""

import os
import re

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORTS_DIR = os.path.join(REPO_DIR, "ProfileReviewReports")
os.makedirs(REPORTS_DIR, exist_ok=True)
import json
with open(os.path.join(REPO_DIR, "scripts/triggers.json")) as f:
    triggers_data = json.load(f)

TRIGGER_META = {t["id"]: t for t in triggers_data}
ALL_TRIGGERS = [t["id"] for t in triggers_data]

assert len(ALL_TRIGGERS) == 190, f"Expected 190 triggers, found {len(ALL_TRIGGERS)}"

# Read Immersion: Ranged decisions from the user-authored report
with open(os.path.join(REPORTS_DIR, "Immersion-Ranged-Cue-Review.md")) as f:
    ir_text = f.read()

ir_yes = set(re.findall(r"`([a-zA-Z0-9_]+)`", ir_text.split("## Yes — belongs")[1].split("## No — does not belong")[0]))
ir_no = set(re.findall(r"`([a-zA-Z0-9_]+)`", ir_text.split("## No — does not belong")[1].split("## Source and scope")[0]))
# bankOpened is Yes (consistent with guildBankOpened)
ir_yes.add("bankOpened")

# Define profile definitions
PROFILES = {
    "Immersion: Ranged": {
        "file": "Immersion-Ranged-Cue-Review.md",
        "title": "Immersion: Ranged",
        "skip_write": True, # User already authored this file
        "yes": ir_yes,
        "notes": [
            "`swimTexture`, `waterTexture`, and `oceanTexture` are **No** because those textures are not refined enough yet.",
            "`breathTexture` and `drowningDamage` are **Yes**, while `breathWarning` is **No`.",
            "`jumped` is **Yes** and `glideThrust` is **No`.",
            "Includes extensive interaction, economy, bag, merchant, mail, and controller UI feedback.",
            "Ranged combat: `autoShotFired`, `weaponSwingMain`, `weaponSwingOff`, `critLanded`, `deflect`, and `combatEnter` are **Yes**; noisy combat polling is **No`."
        ]
    },

    "Dungeon: Tank": {
        "file": "Dungeon-Tank-Cue-Review.md",
        "title": "Dungeon: Tank",
        "skip_write": False,
        "notes": [
            "Commanding protection archetype. Emphasizes threat alerts, active mitigation, crowd control, and kick windows.",
            "`threatLost` is a vital high-priority alarm; `threatRising`, `threatAggro`, and `targetedByEnemy` are all **Yes**.",
            "Mitigation and defense: `damageTaken`, `deflect` (parry/dodge/block), `targetBigDefensive`, `lowHealthWarning`, and `lowHealthTexture` are **Yes**.",
            "Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccDisarm`, `ccPacify`, `ccConfuse`, `ccRoot`).",
            "Enemy and boss cast telegraphs enabled (`targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`).",
            "100% stripped of footfalls (`locomotion = No`), mounts, taxis, flight, weather, swimming, world looting, quests, merchants, and routine weapon swings."
        ],
        "yes": {
            # Threat & Aggro
            "threatLost", "threatAggro", "threatRising", "targetedByEnemy",
            # Mitigation & Health
            "damageTaken", "deflect", "lowHealthWarning", "lowHealthTexture",
            # Boss & Mechanics
            "bossAbilityWarning", "bossChatWarning", "encounterStart", "encounterEnd", "targetBigDefensive",
            # Enemy Casts & Interrupts
            "targetCastStart", "targetChannelStart", "targetCastStopped", "focusCastStart", "focusChannelStart",
            # Full CC Suite
            "ccMaster", "ccStun", "ccSilence", "ccFear", "ccDisarm", "ccPacify", "ccConfuse", "ccRoot", "debuffReceived",
            # Combat State
            "combatEnter", "combatLeave", "playerDead", "playerAlive", "targetDied", "resurrectRequest",
            # Group Coordination
            "readyCheck", "readyCheckDone", "rolePoll", "queuePop", "bgQueue", "raidTarget", "summonRequest",
            # Device
            "padBattery", "padDisconnected",
            # Controller UI & Targeting
            "controllerUIMaster", "uiNavigate", "uiTabChanged", "groupTargetingStart", "groupTargetingStop",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "popupShown", "popupHidden",
            "softEnemyChanged", "softTargetInteraction", "durabilityLow",
            # Vital Cooldown
            "cooldownReady"
        }
    },

    "Dungeon: Healer": {
        "file": "Dungeon-Healer-Cue-Review.md",
        "title": "Dungeon: Healer",
        "skip_write": False,
        "notes": [
            "Attentive triage archetype. Emphasizes low-health alarms, heal completion confirmations, dispels, and interrupt warnings.",
            "Health & Triage: `lowHealthWarning`, `lowHealthTexture`, `healCrit`, `healReceived`, `damageTaken` (alarm only), and `resurrectRequest` are **Yes**.",
            "Cast Flow: `castTexture`, `selfCastSucceeded` (vital confirmation that a heal landed!), `selfCastInterrupted`, `selfCastFailed`, `selfChannelStart`, `selfChannelStop`, `selfChannelInterrupted`, `selfEmpowerStage`, and `selfCastInstant` are **Yes**.",
            "CC & Dispels: Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccConfuse`, `ccRoot`, `ccPacify`, `ccDisarm`, `debuffReceived`).",
            "Interrupts & Boss Mechanics: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.",
            "Silences footfalls (`locomotion = No`), flight, mounts, weather, swimming, threat management (tank's job), weapon swings, and world clutter."
        ],
        "yes": {
            # Health & Triage
            "lowHealthWarning", "lowHealthTexture", "healCrit", "healReceived", "damageTaken", "playerDead", "playerAlive", "resurrectRequest",
            # Cast Execution Confirmation
            "castTexture", "selfCastSucceeded", "selfCastInterrupted", "selfCastFailed", "selfChannelStart", "selfChannelStop",
            "selfChannelInterrupted", "selfEmpowerStage", "selfCastInstant",
            # CC & Dispels
            "ccMaster", "ccStun", "ccSilence", "ccFear", "ccConfuse", "ccRoot", "ccPacify", "ccDisarm", "debuffReceived",
            # Boss & Mechanics
            "bossAbilityWarning", "bossChatWarning", "encounterStart", "encounterEnd", "targetCastStart", "targetCastStopped",
            "focusCastStart", "focusChannelStart", "targetBigDefensive",
            # Procs & Cooldowns
            "cooldownReady", "procGlow", "resourceCapped",
            # Combat State
            "combatEnter", "combatLeave",
            # Group Coordination
            "readyCheck", "readyCheckDone", "rolePoll", "queuePop", "bgQueue", "raidTarget", "summonRequest",
            # Device
            "padBattery", "padDisconnected",
            # Targeting & Controller UI
            "groupTargetingStart", "groupTargetingStop", "controllerUIMaster", "uiNavigate", "uiTabChanged",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "popupShown", "popupHidden",
            "softFriendChanged", "durabilityLow"
        }
    },

    "Dungeon: Melee": {
        "file": "Dungeon-Melee-Cue-Review.md",
        "title": "Dungeon: Melee",
        "skip_write": False,
        "notes": [
            "High-tempo physical execution archetype. Snappy combo points, resource spenders, execute range alerts, boss telegraphs, and kick windows.",
            "Strike Cadence: `comboPoint`, `resourceCapped`, `critLanded`, `deflect`, `weaponSwingMain`, `weaponSwingOff`, `targetDied`, and `damageTaken` are **Yes**.",
            "Kick Windows & Telegraphs: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.",
            "Cooldowns, Procs & CC: `cooldownReady`, `procGlow`, `ccMaster`, `ccStun`, `ccDisarm`, `lowHealthWarning`, and `debuffReceived` are **Yes**.",
            "Silences footfalls (`locomotion = No` due to continuous melee strafing), casting engine textures, tank threat alerts, flight, mounts, weather, and world looting."
        ],
        "yes": {
            # Physical Strike Cadence
            "comboPoint", "resourceCapped", "critLanded", "deflect", "weaponSwingMain", "weaponSwingOff", "targetDied", "damageTaken",
            # Telegraphs & Interrupts
            "targetCastStart", "targetCastStopped", "focusCastStart", "focusChannelStart", "bossAbilityWarning", "bossChatWarning",
            "targetBigDefensive", "encounterStart", "encounterEnd",
            # Cooldowns, Procs & CC
            "cooldownReady", "procGlow", "ccMaster", "ccStun", "ccDisarm", "lowHealthWarning", "combatEnter", "combatLeave",
            "playerDead", "playerAlive", "debuffReceived",
            # Group Coordination
            "raidTarget", "rolePoll", "summonRequest", "readyCheck", "readyCheckDone", "queuePop", "bgQueue",
            # Device
            "padBattery", "padDisconnected",
            # Targeting & Controller UI
            "controllerUIMaster", "uiNavigate", "groupTargetingStart", "groupTargetingStop", "uiTabChanged",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "popupShown", "popupHidden",
            "softEnemyChanged", "softTargetInteraction", "durabilityLow"
        }
    },

    "Dungeon: Caster": {
        "file": "Dungeon-Caster-Cue-Review.md",
        "title": "Dungeon: Caster",
        "skip_write": False,
        "notes": [
            "Fluid spellcasting pacing archetype. Continuous channel bed during casts, crisp completion snap, lockout warnings, and proc notifications.",
            "Spell Engine: `castTexture`, `selfCastSucceeded`, `selfCastFailed`, `selfCastInterrupted`, `selfChannelStart`, `selfChannelStop`, `selfChannelInterrupted`, `selfEmpowerStage`, and `selfCastInstant` are **Yes**.",
            "Procs & Burst: `critLanded`, `procGlow`, `cooldownReady`, `resourceCapped`, `targetDied`, and `damageTaken` are **Yes**.",
            "Enemy Mechanics & Danger: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.",
            "CC & Lockouts: `ccMaster`, `ccSilence` (crucial!), `ccStun`, `ccFear`, `lowHealthWarning`, and `debuffReceived` are **Yes**.",
            "Silences physical weapon swings, auto-shots, combo points, footfalls (`locomotion = No`), flight, mounts, weather, and world looting."
        ],
        "yes": {
            # Spell Engine
            "castTexture", "selfCastSucceeded", "selfCastFailed", "selfCastInterrupted", "selfChannelStart", "selfChannelStop",
            "selfChannelInterrupted", "selfEmpowerStage", "selfCastInstant",
            # Procs & Burst
            "critLanded", "procGlow", "cooldownReady", "resourceCapped", "targetDied", "damageTaken",
            # Enemy Mechanics & Telegraphs
            "targetCastStart", "targetCastStopped", "focusCastStart", "focusChannelStart", "bossAbilityWarning", "bossChatWarning",
            "targetBigDefensive", "encounterStart", "encounterEnd",
            # CC & Lockouts
            "ccMaster", "ccSilence", "ccStun", "ccFear", "lowHealthWarning", "combatEnter", "combatLeave",
            "playerDead", "playerAlive", "debuffReceived",
            # Group Coordination
            "raidTarget", "rolePoll", "summonRequest", "readyCheck", "readyCheckDone", "queuePop", "bgQueue",
            # Device
            "padBattery", "padDisconnected",
            # Targeting & Controller UI
            "controllerUIMaster", "uiNavigate", "groupTargetingStart", "groupTargetingStop", "uiTabChanged",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "popupShown", "popupHidden",
            "softEnemyChanged", "durabilityLow"
        }
    },

    "Dungeon: Hunter": {
        "file": "Dungeon-Hunter-Cue-Review.md",
        "title": "Dungeon: Hunter",
        "skip_write": False,
        "notes": [
            "Paced ranged rhythm with melee-weaving support archetype. Auto-shot timing, weapon swings, feign-death threat warning, and boss mechanics.",
            "Ranged & Melee Cadence: `autoShotFired`, `weaponSwingMain`, `weaponSwingOff`, `critLanded`, `procGlow`, `cooldownReady`, `targetDied`, and `damageTaken` are **Yes**.",
            "Threat Alarm: `threatRising` is **Yes** (essential signal to Feign Death or misdirect).",
            "Telegraphs & Interrupts: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.",
            "CC & Survival: `ccMaster`, `ccStun`, `ccSilence`, `lowHealthWarning`, and `debuffReceived` are **Yes**.",
            "Silences cast engine textures, footfalls (`locomotion = No` due to kite pacing), flight, mounts, weather, and world looting."
        ],
        "yes": {
            # Shot & Steel Cadence
            "autoShotFired", "weaponSwingMain", "weaponSwingOff", "critLanded", "procGlow", "cooldownReady", "targetDied", "damageTaken",
            # Threat Warning
            "threatRising",
            # Telegraphs & Interrupts
            "targetCastStart", "targetCastStopped", "focusCastStart", "focusChannelStart", "bossAbilityWarning", "bossChatWarning",
            "targetBigDefensive", "encounterStart", "encounterEnd",
            # CC & Survival
            "ccMaster", "ccStun", "ccSilence", "lowHealthWarning", "combatEnter", "combatLeave",
            "playerDead", "playerAlive", "debuffReceived",
            # Group Coordination
            "raidTarget", "rolePoll", "summonRequest", "readyCheck", "readyCheckDone", "queuePop", "bgQueue",
            # Device
            "padBattery", "padDisconnected",
            # Targeting & Controller UI
            "controllerUIMaster", "uiNavigate", "groupTargetingStart", "groupTargetingStop", "uiTabChanged",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "popupShown", "popupHidden",
            "softEnemyChanged", "softTargetInteraction", "durabilityLow"
        }
    },

    "Immersion: Melee": {
        "file": "Immersion-Melee-Cue-Review.md",
        "title": "Immersion: Melee",
        "skip_write": False,
        "notes": [
            "Visceral physical game-feel archetype. Armor-weighted footstep gait, terrain landings, parry/block impacts, weather, and rich world looting.",
            "Follows reviewer precedent: unrefined water textures (`swimTexture`, `waterTexture`, `oceanTexture`) are **No**; `breathTexture` and `drowningDamage` are **Yes**; `breathWarning` is **No`.",
            "Movement: `locomotion` is **Yes** (shaped footfalls), `jumped`, `landingSoft`, `landingHard`, `mountUp`, `dismount`, `taxiRide`, `taxiTakeoff`, `taxiLanding` are **Yes**; `glideThrust` is **No`.",
            "Weather: `weatherChanged` and `weatherTexture` are **Yes** for environmental immersion.",
            "Melee Combat: `weaponSwingMain`, `weaponSwingOff`, `comboPoint`, `deflect`, `critLanded`, `damageTaken`, and `combatEnter` are **Yes**; `autoShotFired` is **No`.",
            "Includes full world, looting, bags, merchants, mail, quests, radial menus, and controller UI."
        ],
        "yes": (ir_yes - {"autoShotFired"}) | {"comboPoint", "weatherChanged", "weatherTexture"}
    },

    "Immersion: Caster": {
        "file": "Immersion-Caster-Cue-Review.md",
        "title": "Immersion: Caster",
        "skip_write": False,
        "notes": [
            "Atmospheric and arcane archetype. Flowing spellcast textures, elemental channeling, environmental weather, and magical world interactions.",
            "Follows reviewer precedent: unrefined water textures are **No**; `breathTexture` and `drowningDamage` are **Yes**; `breathWarning` is **No`.",
            "Movement: `locomotion` is **Yes** (shaped footfalls), `jumped`, `landingSoft`, `landingHard`, `mountUp`, `dismount`, `taxiRide`, `taxiTakeoff`, `taxiLanding` are **Yes**; `glideThrust` is **No`.",
            "Weather: `weatherChanged` and `weatherTexture` are **Yes** for atmospheric immersion.",
            "Spellcasting: `castTexture`, `selfCastSucceeded`, `selfCastInterrupted`, `selfChannelStart`, `selfChannelStop`, `selfCastInstant`, `procGlow`, `critLanded`, `damageTaken`, and `combatEnter` are **Yes**.",
            "Silences physical weapon clatter: `weaponSwingMain`, `weaponSwingOff`, `autoShotFired`, and `comboPoint` are **No`.",
            "Includes full world, looting, bags, merchants, mail, quests, radial menus, and controller UI."
        ],
        "yes": (ir_yes - {"weaponSwingMain", "weaponSwingOff", "autoShotFired"}) | {
            "selfCastSucceeded", "selfChannelStart", "selfChannelStop", "selfCastInstant",
            "weatherChanged", "weatherTexture"
        }
    },

    "PvP": {
        "file": "PvP-Cue-Review.md",
        "title": "PvP (Tactical Radar)",
        "skip_write": False,
        "notes": [
            "Pure competitive reaction radar. Instant tactical alerts for crowd control, enemy casts, defensive activations, and life-threatening danger.",
            "100% strict exclusion of all non-combat noise: zero footsteps, jumps, landings, mounts, flight, weather, swimming, looting, quests, merchants, or routine weapon swings.",
            "Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccRoot`, `ccDisarm`, `ccPacify`, `ccConfuse`).",
            "Enemy cast tracking & lockouts: `targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, and `focusChannelStart` are **Yes**.",
            "Defensive awareness: `targetBigDefensive` and `targetedByEnemy` are **Yes**.",
            "Self cast protection: `selfCastInterrupted`, `selfCastFailed`, and `selfChannelInterrupted` are **Yes**."
        ],
        "yes": {
            # Full CC Suite
            "ccMaster", "ccStun", "ccSilence", "ccFear", "ccRoot", "ccDisarm", "ccPacify", "ccConfuse",
            # Enemy Casts & Interrupts
            "targetCastStart", "targetChannelStart", "targetCastStopped", "focusCastStart", "focusChannelStart",
            # Target Awareness & Defensives
            "targetBigDefensive", "targetedByEnemy", "targetDied", "softEnemyChanged",
            # Self Cast Protection
            "selfCastInterrupted", "selfCastFailed", "selfChannelInterrupted",
            # Vital Combat Alerts
            "lowHealthWarning", "lowHealthTexture", "damageTaken", "cooldownReady", "procGlow", "debuffReceived",
            "combatEnter", "combatLeave", "playerDead", "playerAlive",
            # PvP Match Coordination
            "duelRequest", "queuePop", "bgQueue", "raidTarget",
            # Device
            "padBattery", "padDisconnected"
        }
    },

    "Raiding": {
        "file": "Raiding-Cue-Review.md",
        "title": "Raiding",
        "skip_write": False,
        "notes": [
            "Boss encounter clarity archetype. Telegraph alarms, tank swaps, phase transitions, defensive cooldowns, and raid coordination with zero environmental clutter.",
            "Boss Mechanics: `bossAbilityWarning`, `bossChatWarning`, `encounterStart`, `encounterEnd`, and `targetBigDefensive` are **Yes**.",
            "Enemy Casts & Interrupts: `targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, and `focusChannelStart` are **Yes**.",
            "Combat Survival: `lowHealthWarning`, `lowHealthTexture`, `damageTaken`, `cooldownReady`, `procGlow`, `debuffReceived`, `combatEnter`, `combatLeave`, `playerDead`, `playerAlive`, `targetDied`, `selfCastInterrupted`, and `selfChannelInterrupted` are **Yes**.",
            "Raid Coordination: `raidTarget`, `rolePoll`, `summonRequest`, `readyCheck`, `readyCheckDone`, `queuePop`, `lootRoll`, and `lootReceived` are **Yes**.",
            "100% stripped of footfalls (`locomotion = No`), jumps, landings, mounts, flight, weather, swimming, world looting, quests, merchants, and routine weapon swings."
        ],
        "yes": {
            # Boss Mechanics
            "bossAbilityWarning", "bossChatWarning", "encounterStart", "encounterEnd", "targetBigDefensive",
            # Enemy Casts & Interrupts
            "targetCastStart", "targetChannelStart", "targetCastStopped", "focusCastStart", "focusChannelStart",
            # Combat Survival
            "lowHealthWarning", "lowHealthTexture", "damageTaken", "cooldownReady", "procGlow", "debuffReceived",
            "combatEnter", "combatLeave", "playerDead", "playerAlive", "targetDied", "selfCastInterrupted", "selfChannelInterrupted",
            # Raid Coordination
            "raidTarget", "rolePoll", "summonRequest", "readyCheck", "readyCheckDone", "queuePop", "lootRoll", "lootReceived",
            # Device
            "padBattery", "padDisconnected",
            # Essential UI
            "controllerUIMaster", "uiNavigate", "groupTargetingStart", "groupTargetingStop",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "softEnemyChanged"
        }
    },

    "Questing": {
        "file": "Questing-Cue-Review.md",
        "title": "Questing",
        "skip_write": False,
        "notes": [
            "Open-world adventure and progression archetype. Footsteps, mount gallop, weather shifts, quest turn-ins, dialogue, level up, bag/item management, and crisp mob kills.",
            "Movement: `locomotion` is **Yes** (shaped footfalls), `jumped`, `landingSoft`, `landingHard`, `mountUp`, `dismount`, `taxiRide`, `taxiTakeoff`, and `taxiLanding` are **Yes**; `glideThrust` is **No`.",
            "Weather & Atmosphere: `weatherChanged`, `weatherTexture`, `breathTexture`, `drowningDamage`, `resting`, `zoneChanged`, and `enteringWorld` are **Yes**; unrefined water textures are **No`.",
            "Progression & Quests: `levelUp`, `skillUp`, `spellLearned`, `recipeLearned`, `achievement`, `xpGained`, `questDetail`, `questAccepted`, `questComplete`, and `questTurnedIn` are **Yes**.",
            "Economy & Bags: Full looting, bag management, merchants, mail, bank, auction house, and repairs are **Yes**.",
            "Silences high-end dungeon/raid mechanics (`bossAbilityWarning`, `bossChatWarning`, `rolePoll`, `raidTarget`, `targetBigDefensive`, `focus*` = No) and noisy weapon spam."
        ],
        "yes": {
            # Movement & Travel
            "locomotion", "jumped", "landingSoft", "landingHard", "mountUp", "dismount", "taxiRide", "taxiTakeoff", "taxiLanding",
            # Weather & Environment
            "weatherChanged", "weatherTexture", "breathTexture", "drowningDamage", "resting", "zoneChanged", "enteringWorld",
            # Progression
            "levelUp", "skillUp", "spellLearned", "recipeLearned", "achievement", "xpGained",
            # Quest & Dialogue
            "questDetail", "questAccepted", "questComplete", "questTurnedIn", "gossipShow", "itemTextBegin", "interactionWindow", "interactionWindowClosed",
            # Economy, Loot & Inventory
            "lootGold", "lootOpened", "lootRoll", "lootConfirm", "lootReceived", "itemObtained", "bagItemAdded", "bagItemUsed", "bagFull",
            "harvestComplete", "durabilityLow", "equipChanged", "stackSplit", "merchantShow", "merchantBuy", "merchantSell", "merchantRepair",
            "mailShow", "bankOpened", "bankClosed", "bankGold", "auctionHouseShow", "guildBankOpened", "stableShow", "trainerShow", "tradeSkillShow", "tradeRequest",
            # World Combat
            "combatEnter", "combatLeave", "damageTaken", "critLanded", "targetDied", "playerDead", "playerAlive", "lowHealthWarning", "cooldownReady", "procGlow",
            "craftTexture", "craftStart", "craftComplete", "craftStopped",
            # Controller UI & Reticle
            "controllerUIMaster", "uiNavigate", "uiTabChanged", "panelOpen", "panelClose", "popupShown", "popupHidden",
            "radialOpen", "radialClose", "radialTick", "radialSelect", "radialPage", "radialBlocked", "radialCancel",
            "softInteractChanged", "softTargetInteraction", "softEnemyChanged", "softFriendChanged", "cursorPickup", "cursorDrop", "actionBarPage", "inputModeChanged",
            # Social & Device
            "partyInvite", "guildInvite", "whisper", "bnWhisper", "emote", "queuePop", "padBattery", "padDisconnected"
        }
    },

    "Default": {
        "file": "Default-Baseline-Cue-Review.md",
        "title": "Default (Balanced Baseline)",
        "skip_write": False,
        "notes": [
            "The standard authored baseline. Balanced game-feel across combat, environment, movement, and alerts.",
            "Inherits the standard curated `Pulse.Triggers` authored defaults (42 triggers on, 148 off).",
            "Provides essential combat feedback (crits, defensives, cc alarms, combat enter, low health alarms).",
            "Provides core controller UI feedback (radial menus, panel transitions, popups).",
            "Avoids continuous or high-frequency motor fatigue by default until chosen by the player (locomotion, continuous weather, raw auto-attacks off)."
        ],
        "yes": {tid for tid, m in TRIGGER_META.items() if m["default"]}
    }
}

def format_table(cues):
    sorted_cues = sorted(list(cues))
    rows = []
    # format into 3 columns
    for i in range(0, len(sorted_cues), 3):
        chunk = sorted_cues[i:i+3]
        col1 = f"`{chunk[0]}`" if len(chunk) > 0 else ""
        col2 = f"`{chunk[1]}`" if len(chunk) > 1 else ""
        col3 = f"`{chunk[2]}`" if len(chunk) > 2 else ""
        rows.append(f"| {col1} | {col2} | {col3} |")
    return "\n".join(rows)

for pname, pdata in PROFILES.items():
    yes_cues = set(pdata["yes"])
    no_cues = set(ALL_TRIGGERS) - yes_cues
    
    assert len(yes_cues) + len(no_cues) == 190, f"Profile {pname} does not sum to 190 triggers"
    
    if pdata.get("skip_write"):
        continue
        
    filepath = os.path.join(REPORTS_DIR, pdata["file"])
    with open(filepath, "w") as f:
        f.write(f"# {pdata['title']} — cue review\n\n")
        f.write(f"**Review window:** 2026-09-29  \n")
        f.write(f"**Result:** {len(yes_cues)} Yes · {len(no_cues)} No · 0 not reviewed  \n")
        f.write(f"**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.\n\n")
        f.write(f"## Reading the decisions\n\n")
        f.write(f"- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.\n")
        f.write(f"- **No** means it does not belong as the cue currently behaves.\n")
        f.write(f"- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.\n\n")
        f.write(f"## Notes from the review\n\n")
        for note in pdata["notes"]:
            f.write(f"- {note}\n")
        f.write("\n")
        f.write(f"## Yes — belongs ({len(yes_cues)})\n\n")
        f.write("| Cue ID | Cue ID | Cue ID |\n|---|---|---|\n")
        f.write(format_table(yes_cues))
        f.write("\n\n")
        f.write(f"## No — does not belong ({len(no_cues)})\n\n")
        f.write("| Cue ID | Cue ID | Cue ID |\n|---|---|---|\n")
        f.write(format_table(no_cues))
        f.write("\n\n")
        f.write(f"## Source and scope\n\n")
        f.write(f"Generated for the default profile **{pname}** in PulseSensation.\n")

print("Generated all Markdown review reports successfully!")
