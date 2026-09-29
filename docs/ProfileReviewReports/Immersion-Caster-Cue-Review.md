# Immersion: Caster — cue review

**Review window:** 2026-09-29  
**Result:** 115 Yes · 75 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Atmospheric and arcane archetype. Flowing spellcast textures, elemental channeling, environmental weather, and magical world interactions.
- Follows reviewer precedent: unrefined water textures are **No**; `breathTexture` and `drowningDamage` are **Yes**; `breathWarning` is **No`.
- Movement: `locomotion` is **Yes** (shaped footfalls), `jumped`, `landingSoft`, `landingHard`, `mountUp`, `dismount`, `taxiRide`, `taxiTakeoff`, `taxiLanding` are **Yes**; `glideThrust` is **No`.
- Weather: `weatherChanged` and `weatherTexture` are **Yes** for atmospheric immersion.
- Spellcasting: `castTexture`, `selfCastSucceeded`, `selfCastInterrupted`, `selfChannelStart`, `selfChannelStop`, `selfCastInstant`, `procGlow`, `critLanded`, `damageTaken`, and `combatEnter` are **Yes**.
- Silences physical weapon clatter: `weaponSwingMain`, `weaponSwingOff`, `autoShotFired`, and `comboPoint` are **No`.
- Includes full world, looting, bags, merchants, mail, quests, radial menus, and controller UI.

## Yes — belongs (115)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `auctionHouseShow` | `bagFull` | `bagItemAdded` |
| `bagItemUsed` | `bankOpened` | `bgQueue` |
| `bnWhisper` | `breathTexture` | `castTexture` |
| `ccConfuse` | `ccDisarm` | `ccFear` |
| `ccMaster` | `ccPacify` | `ccRoot` |
| `ccSilence` | `ccStun` | `combatEnter` |
| `controllerUIMaster` | `craftTexture` | `critLanded` |
| `cursorDrop` | `cursorPickup` | `damageTaken` |
| `debuffReceived` | `deflect` | `dismount` |
| `drowningDamage` | `duelRequest` | `durabilityLow` |
| `equipChanged` | `gossipShow` | `groupTargetingStart` |
| `groupTargetingStop` | `guildBankOpened` | `guildInvite` |
| `harvestComplete` | `healCrit` | `healReceived` |
| `interactionWindow` | `interactionWindowClosed` | `itemObtained` |
| `itemTextBegin` | `jumped` | `landingHard` |
| `landingSoft` | `levelUp` | `locomotion` |
| `lootConfirm` | `lootGold` | `lootOpened` |
| `lootReceived` | `lootRoll` | `lowHealthTexture` |
| `mailShow` | `merchantBuy` | `merchantRepair` |
| `merchantSell` | `merchantShow` | `mountUp` |
| `panelClose` | `panelOpen` | `partyInvite` |
| `playerAlive` | `playerDead` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `queuePop` | `radialBlocked` | `radialCancel` |
| `radialClose` | `radialOpen` | `radialPage` |
| `radialSelect` | `radialTick` | `readyCheck` |
| `recipeLearned` | `resurrectRequest` | `rolePoll` |
| `selfCastInstant` | `selfCastInterrupted` | `selfCastSucceeded` |
| `selfChannelStart` | `selfChannelStop` | `skillUp` |
| `softEnemyChanged` | `softFriendChanged` | `softInteractChanged` |
| `spellLearned` | `spiritHealerShow` | `stableShow` |
| `stackSplit` | `summonRequest` | `targetCastStart` |
| `targetChanged` | `targetDied` | `taxiLanding` |
| `taxiOpened` | `taxiRide` | `taxiTakeoff` |
| `tradeRequest` | `tradeSkillShow` | `trainerShow` |
| `uiFocusIn` | `uiFocusOut` | `uiInfoMessage` |
| `uiNavigate` | `uiNavigateEdge` | `uiSelectionDisabled` |
| `uiTabChanged` | `weatherChanged` | `weatherTexture` |
| `whisper` |  |  |

## No — does not belong (75)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `autoRepeatStart` |
| `autoRepeatStop` | `autoShotFired` | `bankClosed` |
| `bankGold` | `binderShow` | `bossAbilityWarning` |
| `bossChatWarning` | `breathWarning` | `combatLeave` |
| `comboPoint` | `cooldownReady` | `craftComplete` |
| `craftStart` | `craftStopped` | `emote` |
| `encounterEnd` | `encounterStart` | `enteringWorld` |
| `factionGained` | `focusCastStart` | `focusChanged` |
| `focusChannelStart` | `formChanged` | `glideThrust` |
| `groupRoster` | `honorGained` | `inputModeChanged` |
| `lowHealthWarning` | `meleeAttackStart` | `meleeAttackStop` |
| `meleeRangeIn` | `meleeRangeOut` | `npcEmote` |
| `oceanTexture` | `padBattery` | `padConnected` |
| `padDisconnected` | `partyLeader` | `pingPinAdded` |
| `popupHidden` | `popupShown` | `procGlow` |
| `raidTarget` | `readyCheckDone` | `resourceCapped` |
| `resting` | `selfCastFailed` | `selfCastSent` |
| `selfCastStart` | `selfCastStop` | `selfChannelInterrupted` |
| `selfEmpowerStage` | `softTargetInteraction` | `stealthTexture` |
| `swimTexture` | `targetBigDefensive` | `targetCastStopped` |
| `targetChannelStart` | `targetedByEnemy` | `threatAggro` |
| `threatLost` | `threatRising` | `vehicleEnter` |
| `vehicleExit` | `waterTexture` | `weaponSwingMain` |
| `weaponSwingOff` | `xpGained` | `zoneChanged` |

## Source and scope

Generated for the default profile **Immersion: Caster** in PulseSensation.
