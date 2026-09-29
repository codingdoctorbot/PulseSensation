# Default (Balanced Baseline) — cue review

**Review window:** 2026-09-29  
**Result:** 53 Yes · 137 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- The standard authored baseline. Balanced game-feel across combat, environment, movement, and alerts.
- Inherits the standard curated `Pulse.Triggers` authored defaults (42 triggers on, 148 off).
- Provides essential combat feedback (crits, defensives, cc alarms, combat enter, low health alarms).
- Provides core controller UI feedback (radial menus, panel transitions, popups).
- Avoids continuous or high-frequency motor fatigue by default until chosen by the player (locomotion, continuous weather, raw auto-attacks off).

## Yes — belongs (53)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bagFull` | `bagItemAdded` | `bgQueue` |
| `breathWarning` | `ccConfuse` | `ccFear` |
| `ccMaster` | `ccRoot` | `ccSilence` |
| `ccStun` | `combatEnter` | `controllerUIMaster` |
| `critLanded` | `deflect` | `drowningDamage` |
| `durabilityLow` | `glideThrust` | `groupTargetingStart` |
| `groupTargetingStop` | `landingHard` | `landingSoft` |
| `levelUp` | `merchantRepair` | `mountUp` |
| `padBattery` | `padDisconnected` | `panelClose` |
| `panelOpen` | `playerDead` | `popupHidden` |
| `popupShown` | `procGlow` | `queuePop` |
| `radialClose` | `radialOpen` | `radialPage` |
| `radialSelect` | `radialTick` | `readyCheck` |
| `resting` | `resurrectRequest` | `selfCastInterrupted` |
| `stackSplit` | `targetBigDefensive` | `targetCastStart` |
| `targetChannelStart` | `targetDied` | `taxiLanding` |
| `taxiTakeoff` | `threatAggro` | `threatRising` |
| `uiNavigate` | `uiTabChanged` |  |

## No — does not belong (137)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagItemUsed` | `bankClosed` | `bankGold` |
| `bankOpened` | `binderShow` | `bnWhisper` |
| `bossAbilityWarning` | `bossChatWarning` | `breathTexture` |
| `castTexture` | `ccDisarm` | `ccPacify` |
| `combatLeave` | `comboPoint` | `cooldownReady` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `cursorDrop` | `cursorPickup` |
| `damageTaken` | `debuffReceived` | `dismount` |
| `duelRequest` | `emote` | `encounterEnd` |
| `encounterStart` | `enteringWorld` | `equipChanged` |
| `factionGained` | `focusCastStart` | `focusChanged` |
| `focusChannelStart` | `formChanged` | `gossipShow` |
| `groupRoster` | `guildBankOpened` | `guildInvite` |
| `harvestComplete` | `healCrit` | `healReceived` |
| `honorGained` | `inputModeChanged` | `interactionWindow` |
| `interactionWindowClosed` | `itemObtained` | `itemTextBegin` |
| `jumped` | `locomotion` | `lootConfirm` |
| `lootGold` | `lootOpened` | `lootReceived` |
| `lootRoll` | `lowHealthTexture` | `lowHealthWarning` |
| `mailShow` | `meleeAttackStart` | `meleeAttackStop` |
| `meleeRangeIn` | `meleeRangeOut` | `merchantBuy` |
| `merchantSell` | `merchantShow` | `npcEmote` |
| `oceanTexture` | `padConnected` | `partyInvite` |
| `partyLeader` | `pingPinAdded` | `playerAlive` |
| `questAccepted` | `questComplete` | `questDetail` |
| `questTurnedIn` | `radialBlocked` | `radialCancel` |
| `raidTarget` | `readyCheckDone` | `recipeLearned` |
| `resourceCapped` | `rolePoll` | `selfCastFailed` |
| `selfCastInstant` | `selfCastSent` | `selfCastStart` |
| `selfCastStop` | `selfCastSucceeded` | `selfChannelInterrupted` |
| `selfChannelStart` | `selfChannelStop` | `selfEmpowerStage` |
| `skillUp` | `softEnemyChanged` | `softFriendChanged` |
| `softInteractChanged` | `softTargetInteraction` | `spellLearned` |
| `spiritHealerShow` | `stableShow` | `stealthTexture` |
| `summonRequest` | `swimTexture` | `targetCastStopped` |
| `targetChanged` | `targetedByEnemy` | `taxiOpened` |
| `taxiRide` | `threatLost` | `tradeRequest` |
| `tradeSkillShow` | `trainerShow` | `uiFocusIn` |
| `uiFocusOut` | `uiInfoMessage` | `uiNavigateEdge` |
| `uiSelectionDisabled` | `vehicleEnter` | `vehicleExit` |
| `waterTexture` | `weaponSwingMain` | `weaponSwingOff` |
| `weatherChanged` | `weatherTexture` | `whisper` |
| `xpGained` | `zoneChanged` |  |

## Source and scope

Generated for the default profile **Default** in PulseSensation.
