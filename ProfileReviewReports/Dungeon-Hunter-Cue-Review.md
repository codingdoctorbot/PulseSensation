# Dungeon: Hunter — cue review

**Review window:** 2026-09-29  
**Result:** 51 Yes · 139 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Paced ranged rhythm with melee-weaving support archetype. Auto-shot timing, weapon swings, feign-death threat warning, and boss mechanics.
- Ranged & Melee Cadence: `autoShotFired`, `weaponSwingMain`, `weaponSwingOff`, `critLanded`, `procGlow`, `cooldownReady`, `targetDied`, and `damageTaken` are **Yes**.
- Threat Alarm: `threatRising` is **Yes** (essential signal to Feign Death or misdirect).
- Telegraphs & Interrupts: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.
- CC & Survival: `ccMaster`, `ccStun`, `ccSilence`, `lowHealthWarning`, and `debuffReceived` are **Yes**.
- Silences cast engine textures, footfalls (`locomotion = No` due to kite pacing), flight, mounts, weather, and world looting.

## Yes — belongs (51)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `autoShotFired` | `bgQueue` | `bossAbilityWarning` |
| `bossChatWarning` | `ccMaster` | `ccSilence` |
| `ccStun` | `combatEnter` | `combatLeave` |
| `controllerUIMaster` | `cooldownReady` | `critLanded` |
| `damageTaken` | `debuffReceived` | `durabilityLow` |
| `encounterEnd` | `encounterStart` | `focusCastStart` |
| `focusChannelStart` | `groupTargetingStart` | `groupTargetingStop` |
| `lowHealthWarning` | `padBattery` | `padDisconnected` |
| `playerAlive` | `playerDead` | `popupHidden` |
| `popupShown` | `procGlow` | `queuePop` |
| `radialClose` | `radialOpen` | `radialPage` |
| `radialSelect` | `radialTick` | `raidTarget` |
| `readyCheck` | `readyCheckDone` | `rolePoll` |
| `softEnemyChanged` | `softTargetInteraction` | `summonRequest` |
| `targetBigDefensive` | `targetCastStart` | `targetCastStopped` |
| `targetDied` | `threatRising` | `uiNavigate` |
| `uiTabChanged` | `weaponSwingMain` | `weaponSwingOff` |

## No — does not belong (139)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `bagFull` |
| `bagItemAdded` | `bagItemUsed` | `bankClosed` |
| `bankGold` | `bankOpened` | `binderShow` |
| `bnWhisper` | `breathTexture` | `breathWarning` |
| `castTexture` | `ccConfuse` | `ccDisarm` |
| `ccFear` | `ccPacify` | `ccRoot` |
| `comboPoint` | `craftComplete` | `craftStart` |
| `craftStopped` | `craftTexture` | `cursorDrop` |
| `cursorPickup` | `deflect` | `dismount` |
| `drowningDamage` | `duelRequest` | `emote` |
| `enteringWorld` | `equipChanged` | `factionGained` |
| `focusChanged` | `formChanged` | `glideThrust` |
| `gossipShow` | `groupRoster` | `guildBankOpened` |
| `guildInvite` | `harvestComplete` | `healCrit` |
| `healReceived` | `honorGained` | `inputModeChanged` |
| `interactionWindow` | `interactionWindowClosed` | `itemObtained` |
| `itemTextBegin` | `jumped` | `landingHard` |
| `landingSoft` | `levelUp` | `locomotion` |
| `lootConfirm` | `lootGold` | `lootOpened` |
| `lootReceived` | `lootRoll` | `lowHealthTexture` |
| `mailShow` | `meleeAttackStart` | `meleeAttackStop` |
| `meleeRangeIn` | `meleeRangeOut` | `merchantBuy` |
| `merchantRepair` | `merchantSell` | `merchantShow` |
| `mountUp` | `npcEmote` | `oceanTexture` |
| `padConnected` | `panelClose` | `panelOpen` |
| `partyInvite` | `partyLeader` | `pingPinAdded` |
| `questAccepted` | `questComplete` | `questDetail` |
| `questTurnedIn` | `radialBlocked` | `radialCancel` |
| `recipeLearned` | `resourceCapped` | `resting` |
| `resurrectRequest` | `selfCastFailed` | `selfCastInstant` |
| `selfCastInterrupted` | `selfCastSent` | `selfCastStart` |
| `selfCastStop` | `selfCastSucceeded` | `selfChannelInterrupted` |
| `selfChannelStart` | `selfChannelStop` | `selfEmpowerStage` |
| `skillUp` | `softFriendChanged` | `softInteractChanged` |
| `spellLearned` | `spiritHealerShow` | `stableShow` |
| `stackSplit` | `stealthTexture` | `swimTexture` |
| `targetChanged` | `targetChannelStart` | `targetedByEnemy` |
| `taxiLanding` | `taxiOpened` | `taxiRide` |
| `taxiTakeoff` | `threatAggro` | `threatLost` |
| `tradeRequest` | `tradeSkillShow` | `trainerShow` |
| `uiFocusIn` | `uiFocusOut` | `uiInfoMessage` |
| `uiNavigateEdge` | `uiSelectionDisabled` | `vehicleEnter` |
| `vehicleExit` | `waterTexture` | `weatherChanged` |
| `weatherTexture` | `whisper` | `xpGained` |
| `zoneChanged` |  |  |

## Source and scope

Generated for the default profile **Dungeon: Hunter** in PulseSensation.
