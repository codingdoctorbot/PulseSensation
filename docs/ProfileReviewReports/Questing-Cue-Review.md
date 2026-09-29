# Questing — cue review

**Review window:** 2026-09-29  
**Result:** 101 Yes · 89 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Open-world adventure and progression archetype. Footsteps, mount gallop, weather shifts, quest turn-ins, dialogue, level up, bag/item management, and crisp mob kills.
- Movement: `locomotion` is **Yes** (shaped footfalls), `jumped`, `landingSoft`, `landingHard`, `mountUp`, `dismount`, `taxiRide`, `taxiTakeoff`, and `taxiLanding` are **Yes**; `glideThrust` is **No`.
- Weather & Atmosphere: `weatherChanged`, `weatherTexture`, `breathTexture`, `drowningDamage`, `resting`, `zoneChanged`, and `enteringWorld` are **Yes**; unrefined water textures are **No`.
- Progression & Quests: `levelUp`, `skillUp`, `spellLearned`, `recipeLearned`, `achievement`, `xpGained`, `questDetail`, `questAccepted`, `questComplete`, and `questTurnedIn` are **Yes**.
- Economy & Bags: Full looting, bag management, merchants, mail, bank, auction house, and repairs are **Yes**.
- Silences high-end dungeon/raid mechanics (`bossAbilityWarning`, `bossChatWarning`, `rolePoll`, `raidTarget`, `targetBigDefensive`, `focus*` = No) and noisy weapon spam.

## Yes — belongs (101)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `achievement` | `actionBarPage` | `auctionHouseShow` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `bnWhisper` | `breathTexture` | `combatEnter` |
| `combatLeave` | `controllerUIMaster` | `cooldownReady` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `critLanded` | `cursorDrop` |
| `cursorPickup` | `damageTaken` | `dismount` |
| `drowningDamage` | `durabilityLow` | `emote` |
| `enteringWorld` | `equipChanged` | `gossipShow` |
| `guildBankOpened` | `guildInvite` | `harvestComplete` |
| `inputModeChanged` | `interactionWindow` | `interactionWindowClosed` |
| `itemObtained` | `itemTextBegin` | `jumped` |
| `landingHard` | `landingSoft` | `levelUp` |
| `locomotion` | `lootConfirm` | `lootGold` |
| `lootOpened` | `lootReceived` | `lootRoll` |
| `lowHealthWarning` | `mailShow` | `merchantBuy` |
| `merchantRepair` | `merchantSell` | `merchantShow` |
| `mountUp` | `padBattery` | `padDisconnected` |
| `panelClose` | `panelOpen` | `partyInvite` |
| `playerAlive` | `playerDead` | `popupHidden` |
| `popupShown` | `procGlow` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `queuePop` | `radialBlocked` | `radialCancel` |
| `radialClose` | `radialOpen` | `radialPage` |
| `radialSelect` | `radialTick` | `recipeLearned` |
| `resting` | `skillUp` | `softEnemyChanged` |
| `softFriendChanged` | `softInteractChanged` | `softTargetInteraction` |
| `spellLearned` | `stableShow` | `stackSplit` |
| `targetDied` | `taxiLanding` | `taxiRide` |
| `taxiTakeoff` | `tradeRequest` | `tradeSkillShow` |
| `trainerShow` | `uiNavigate` | `uiTabChanged` |
| `weatherChanged` | `weatherTexture` | `whisper` |
| `xpGained` | `zoneChanged` |  |

## No — does not belong (89)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `actionFailed` | `afkToggle` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bgQueue` | `binderShow` | `bossAbilityWarning` |
| `bossChatWarning` | `breathWarning` | `castTexture` |
| `ccConfuse` | `ccDisarm` | `ccFear` |
| `ccMaster` | `ccPacify` | `ccRoot` |
| `ccSilence` | `ccStun` | `comboPoint` |
| `debuffReceived` | `deflect` | `duelRequest` |
| `encounterEnd` | `encounterStart` | `factionGained` |
| `focusCastStart` | `focusChanged` | `focusChannelStart` |
| `formChanged` | `glideThrust` | `groupRoster` |
| `groupTargetingStart` | `groupTargetingStop` | `healCrit` |
| `healReceived` | `honorGained` | `lowHealthTexture` |
| `meleeAttackStart` | `meleeAttackStop` | `meleeRangeIn` |
| `meleeRangeOut` | `npcEmote` | `oceanTexture` |
| `padConnected` | `partyLeader` | `pingPinAdded` |
| `raidTarget` | `readyCheck` | `readyCheckDone` |
| `resourceCapped` | `resurrectRequest` | `rolePoll` |
| `selfCastFailed` | `selfCastInstant` | `selfCastInterrupted` |
| `selfCastSent` | `selfCastStart` | `selfCastStop` |
| `selfCastSucceeded` | `selfChannelInterrupted` | `selfChannelStart` |
| `selfChannelStop` | `selfEmpowerStage` | `spiritHealerShow` |
| `stealthTexture` | `summonRequest` | `swimTexture` |
| `targetBigDefensive` | `targetCastStart` | `targetCastStopped` |
| `targetChanged` | `targetChannelStart` | `targetedByEnemy` |
| `taxiOpened` | `threatAggro` | `threatLost` |
| `threatRising` | `uiFocusIn` | `uiFocusOut` |
| `uiInfoMessage` | `uiNavigateEdge` | `uiSelectionDisabled` |
| `vehicleEnter` | `vehicleExit` | `waterTexture` |
| `weaponSwingMain` | `weaponSwingOff` |  |

## Source and scope

Generated for the default profile **Questing** in PulseSensation.
