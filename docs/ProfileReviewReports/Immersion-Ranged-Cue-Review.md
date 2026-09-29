# Immersion: Ranged — cue review

**Review window:** 2026-09-26 20:09 to 2026-09-26 20:22  
**Result:** 112 Yes · 77 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- `swimTexture` and `waterTexture` are **No** because those textures are not refined enough yet. This is a quality/tuning judgment, not a rejection of underwater feedback as a concept.
- `oceanTexture` is also **No**. Revisit the water-related textures together after refinement and playtesting.
- `breathTexture` and `drowningDamage` are **Yes**, while `breathWarning` is **No**: the reviewed preference retains underwater texture/drowning feedback but excludes the separate low-breath warning.
- `jumped` is **Yes** and `glideThrust` is **No**. If sustained flight feedback is reconsidered later, test the ascent cue alongside it; the trigger registry notes a possible overlap on Skyriding takeoff.
- The Yes list includes many interaction, accessibility, and controller UI cues. Whether that density feels right should be judged during normal play; this document captures the review choices, not a claim that every combination has been playtested.

## Yes — belongs (112)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `auctionHouseShow` | `healReceived` | `radialTick` |
| `autoShotFired` | `interactionWindow` | `readyCheck` |
| `bagFull` | `interactionWindowClosed` | `recipeLearned` |
| `bagItemAdded` | `itemObtained` | `resurrectRequest` |
| `bagItemUsed` | `itemTextBegin` | `rolePoll` |
| `bgQueue` | `jumped` | `selfCastInstant` |
| `bnWhisper` | `landingHard` | `selfCastInterrupted` |
| `breathTexture` | `landingSoft` | `skillUp` |
| `castTexture` | `levelUp` | `softEnemyChanged` |
| `ccConfuse` | `locomotion` | `softFriendChanged` |
| `ccDisarm` | `lootConfirm` | `softInteractChanged` |
| `ccFear` | `lootGold` | `spellLearned` |
| `ccMaster` | `lootOpened` | `spiritHealerShow` |
| `ccPacify` | `lootReceived` | `stableShow` |
| `ccRoot` | `lootRoll` | `stackSplit` |
| `ccSilence` | `lowHealthTexture` | `summonRequest` |
| `ccStun` | `mailShow` | `targetCastStart` |
| `combatEnter` | `merchantBuy` | `targetChanged` |
| `controllerUIMaster` | `merchantRepair` | `targetDied` |
| `craftTexture` | `merchantSell` | `taxiLanding` |
| `critLanded` | `merchantShow` | `taxiOpened` |
| `cursorDrop` | `mountUp` | `taxiRide` |
| `cursorPickup` | `panelClose` | `taxiTakeoff` |
| `damageTaken` | `panelOpen` | `tradeRequest` |
| `debuffReceived` | `partyInvite` | `tradeSkillShow` |
| `deflect` | `playerAlive` | `trainerShow` |
| `dismount` | `playerDead` | `uiFocusIn` |
| `drowningDamage` | `questAccepted` | `uiFocusOut` |
| `duelRequest` | `questComplete` | `uiInfoMessage` |
| `durabilityLow` | `questDetail` | `uiNavigate` |
| `equipChanged` | `questTurnedIn` | `uiNavigateEdge` |
| `gossipShow` | `queuePop` | `uiSelectionDisabled` |
| `groupTargetingStart` | `radialBlocked` | `uiTabChanged` |
| `groupTargetingStop` | `radialCancel` | `weaponSwingMain` |
| `guildBankOpened` | `radialClose` | `weaponSwingOff` |
| `guildInvite` | `radialOpen` | `whisper` |
| `harvestComplete` | `radialPage` |  |
| `healCrit` | `radialSelect` |  |

## No — does not belong (77)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `focusChannelStart` | `selfCastSent` |
| `achievement` | `formChanged` | `selfCastStart` |
| `actionBarPage` | `glideThrust` | `selfCastStop` |
| `actionFailed` | `groupRoster` | `selfCastSucceeded` |
| `afkToggle` | `honorGained` | `selfChannelInterrupted` |
| `autoRepeatStart` | `inputModeChanged` | `selfChannelStart` |
| `autoRepeatStop` | `lowHealthWarning` | `selfChannelStop` |
| `bankClosed` | `meleeAttackStart` | `selfEmpowerStage` |
| `bankGold` | `meleeAttackStop` | `softTargetInteraction` |
| `binderShow` | `meleeRangeIn` | `stealthTexture` |
| `bossAbilityWarning` | `meleeRangeOut` | `swimTexture` |
| `bossChatWarning` | `npcEmote` | `targetBigDefensive` |
| `breathWarning` | `oceanTexture` | `targetCastStopped` |
| `combatLeave` | `padBattery` | `targetChannelStart` |
| `comboPoint` | `padConnected` | `targetedByEnemy` |
| `cooldownReady` | `padDisconnected` | `threatAggro` |
| `craftComplete` | `partyLeader` | `threatLost` |
| `craftStart` | `pingPinAdded` | `threatRising` |
| `craftStopped` | `popupHidden` | `vehicleEnter` |
| `emote` | `popupShown` | `vehicleExit` |
| `encounterEnd` | `procGlow` | `waterTexture` |
| `encounterStart` | `raidTarget` | `weatherChanged` |
| `enteringWorld` | `readyCheckDone` | `weatherTexture` |
| `factionGained` | `resourceCapped` | `xpGained` |
| `focusCastStart` | `resting` | `zoneChanged` |
| `focusChanged` | `selfCastFailed` |  |

## Source and scope

Generated from the `PulseProfileReviewDB` SavedVariables entry for the exact profile name **Immersion: Ranged**. It includes the review decisions and cue IDs; it does not infer or apply new profile defaults. The addon review log is separate from Pulse's settings.
