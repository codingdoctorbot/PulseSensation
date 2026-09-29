# Raiding — cue review

**Review window:** 2026-09-29  
**Result:** 42 Yes · 148 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Boss encounter clarity archetype. Telegraph alarms, tank swaps, phase transitions, defensive cooldowns, and raid coordination with zero environmental clutter.
- Boss Mechanics: `bossAbilityWarning`, `bossChatWarning`, `encounterStart`, `encounterEnd`, and `targetBigDefensive` are **Yes**.
- Enemy Casts & Interrupts: `targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, and `focusChannelStart` are **Yes**.
- Combat Survival: `lowHealthWarning`, `lowHealthTexture`, `damageTaken`, `cooldownReady`, `procGlow`, `debuffReceived`, `combatEnter`, `combatLeave`, `playerDead`, `playerAlive`, `targetDied`, `selfCastInterrupted`, and `selfChannelInterrupted` are **Yes**.
- Raid Coordination: `raidTarget`, `rolePoll`, `summonRequest`, `readyCheck`, `readyCheckDone`, `queuePop`, `lootRoll`, and `lootReceived` are **Yes**.
- 100% stripped of footfalls (`locomotion = No`), jumps, landings, mounts, flight, weather, swimming, world looting, quests, merchants, and routine weapon swings.

## Yes — belongs (42)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bossAbilityWarning` | `bossChatWarning` | `combatEnter` |
| `combatLeave` | `controllerUIMaster` | `cooldownReady` |
| `damageTaken` | `debuffReceived` | `encounterEnd` |
| `encounterStart` | `focusCastStart` | `focusChannelStart` |
| `groupTargetingStart` | `groupTargetingStop` | `lootReceived` |
| `lootRoll` | `lowHealthTexture` | `lowHealthWarning` |
| `padBattery` | `padDisconnected` | `playerAlive` |
| `playerDead` | `procGlow` | `queuePop` |
| `radialClose` | `radialOpen` | `radialSelect` |
| `radialTick` | `raidTarget` | `readyCheck` |
| `readyCheckDone` | `rolePoll` | `selfCastInterrupted` |
| `selfChannelInterrupted` | `softEnemyChanged` | `summonRequest` |
| `targetBigDefensive` | `targetCastStart` | `targetCastStopped` |
| `targetChannelStart` | `targetDied` | `uiNavigate` |

## No — does not belong (148)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `bgQueue` | `binderShow` | `bnWhisper` |
| `breathTexture` | `breathWarning` | `castTexture` |
| `ccConfuse` | `ccDisarm` | `ccFear` |
| `ccMaster` | `ccPacify` | `ccRoot` |
| `ccSilence` | `ccStun` | `comboPoint` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `critLanded` | `cursorDrop` |
| `cursorPickup` | `deflect` | `dismount` |
| `drowningDamage` | `duelRequest` | `durabilityLow` |
| `emote` | `enteringWorld` | `equipChanged` |
| `factionGained` | `focusChanged` | `formChanged` |
| `glideThrust` | `gossipShow` | `groupRoster` |
| `guildBankOpened` | `guildInvite` | `harvestComplete` |
| `healCrit` | `healReceived` | `honorGained` |
| `inputModeChanged` | `interactionWindow` | `interactionWindowClosed` |
| `itemObtained` | `itemTextBegin` | `jumped` |
| `landingHard` | `landingSoft` | `levelUp` |
| `locomotion` | `lootConfirm` | `lootGold` |
| `lootOpened` | `mailShow` | `meleeAttackStart` |
| `meleeAttackStop` | `meleeRangeIn` | `meleeRangeOut` |
| `merchantBuy` | `merchantRepair` | `merchantSell` |
| `merchantShow` | `mountUp` | `npcEmote` |
| `oceanTexture` | `padConnected` | `panelClose` |
| `panelOpen` | `partyInvite` | `partyLeader` |
| `pingPinAdded` | `popupHidden` | `popupShown` |
| `questAccepted` | `questComplete` | `questDetail` |
| `questTurnedIn` | `radialBlocked` | `radialCancel` |
| `radialPage` | `recipeLearned` | `resourceCapped` |
| `resting` | `resurrectRequest` | `selfCastFailed` |
| `selfCastInstant` | `selfCastSent` | `selfCastStart` |
| `selfCastStop` | `selfCastSucceeded` | `selfChannelStart` |
| `selfChannelStop` | `selfEmpowerStage` | `skillUp` |
| `softFriendChanged` | `softInteractChanged` | `softTargetInteraction` |
| `spellLearned` | `spiritHealerShow` | `stableShow` |
| `stackSplit` | `stealthTexture` | `swimTexture` |
| `targetChanged` | `targetedByEnemy` | `taxiLanding` |
| `taxiOpened` | `taxiRide` | `taxiTakeoff` |
| `threatAggro` | `threatLost` | `threatRising` |
| `tradeRequest` | `tradeSkillShow` | `trainerShow` |
| `uiFocusIn` | `uiFocusOut` | `uiInfoMessage` |
| `uiNavigateEdge` | `uiSelectionDisabled` | `uiTabChanged` |
| `vehicleEnter` | `vehicleExit` | `waterTexture` |
| `weaponSwingMain` | `weaponSwingOff` | `weatherChanged` |
| `weatherTexture` | `whisper` | `xpGained` |
| `zoneChanged` |  |  |

## Source and scope

Generated for the default profile **Raiding** in PulseSensation.
