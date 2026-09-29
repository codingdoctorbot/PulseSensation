# PvP (Tactical Radar) — cue review

**Review window:** 2026-09-29  
**Result:** 36 Yes · 154 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Pure competitive reaction radar. Instant tactical alerts for crowd control, enemy casts, defensive activations, and life-threatening danger.
- 100% strict exclusion of all non-combat noise: zero footsteps, jumps, landings, mounts, flight, weather, swimming, looting, quests, merchants, or routine weapon swings.
- Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccRoot`, `ccDisarm`, `ccPacify`, `ccConfuse`).
- Enemy cast tracking & lockouts: `targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, and `focusChannelStart` are **Yes**.
- Defensive awareness: `targetBigDefensive` and `targetedByEnemy` are **Yes**.
- Self cast protection: `selfCastInterrupted`, `selfCastFailed`, and `selfChannelInterrupted` are **Yes**.

## Yes — belongs (36)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bgQueue` | `ccConfuse` | `ccDisarm` |
| `ccFear` | `ccMaster` | `ccPacify` |
| `ccRoot` | `ccSilence` | `ccStun` |
| `combatEnter` | `combatLeave` | `cooldownReady` |
| `damageTaken` | `debuffReceived` | `duelRequest` |
| `focusCastStart` | `focusChannelStart` | `lowHealthTexture` |
| `lowHealthWarning` | `padBattery` | `padDisconnected` |
| `playerAlive` | `playerDead` | `procGlow` |
| `queuePop` | `raidTarget` | `selfCastFailed` |
| `selfCastInterrupted` | `selfChannelInterrupted` | `softEnemyChanged` |
| `targetBigDefensive` | `targetCastStart` | `targetCastStopped` |
| `targetChannelStart` | `targetDied` | `targetedByEnemy` |

## No — does not belong (154)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `binderShow` | `bnWhisper` | `bossAbilityWarning` |
| `bossChatWarning` | `breathTexture` | `breathWarning` |
| `castTexture` | `comboPoint` | `controllerUIMaster` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `critLanded` | `cursorDrop` |
| `cursorPickup` | `deflect` | `dismount` |
| `drowningDamage` | `durabilityLow` | `emote` |
| `encounterEnd` | `encounterStart` | `enteringWorld` |
| `equipChanged` | `factionGained` | `focusChanged` |
| `formChanged` | `glideThrust` | `gossipShow` |
| `groupRoster` | `groupTargetingStart` | `groupTargetingStop` |
| `guildBankOpened` | `guildInvite` | `harvestComplete` |
| `healCrit` | `healReceived` | `honorGained` |
| `inputModeChanged` | `interactionWindow` | `interactionWindowClosed` |
| `itemObtained` | `itemTextBegin` | `jumped` |
| `landingHard` | `landingSoft` | `levelUp` |
| `locomotion` | `lootConfirm` | `lootGold` |
| `lootOpened` | `lootReceived` | `lootRoll` |
| `mailShow` | `meleeAttackStart` | `meleeAttackStop` |
| `meleeRangeIn` | `meleeRangeOut` | `merchantBuy` |
| `merchantRepair` | `merchantSell` | `merchantShow` |
| `mountUp` | `npcEmote` | `oceanTexture` |
| `padConnected` | `panelClose` | `panelOpen` |
| `partyInvite` | `partyLeader` | `pingPinAdded` |
| `popupHidden` | `popupShown` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `radialBlocked` | `radialCancel` | `radialClose` |
| `radialOpen` | `radialPage` | `radialSelect` |
| `radialTick` | `readyCheck` | `readyCheckDone` |
| `recipeLearned` | `resourceCapped` | `resting` |
| `resurrectRequest` | `rolePoll` | `selfCastInstant` |
| `selfCastSent` | `selfCastStart` | `selfCastStop` |
| `selfCastSucceeded` | `selfChannelStart` | `selfChannelStop` |
| `selfEmpowerStage` | `skillUp` | `softFriendChanged` |
| `softInteractChanged` | `softTargetInteraction` | `spellLearned` |
| `spiritHealerShow` | `stableShow` | `stackSplit` |
| `stealthTexture` | `summonRequest` | `swimTexture` |
| `targetChanged` | `taxiLanding` | `taxiOpened` |
| `taxiRide` | `taxiTakeoff` | `threatAggro` |
| `threatLost` | `threatRising` | `tradeRequest` |
| `tradeSkillShow` | `trainerShow` | `uiFocusIn` |
| `uiFocusOut` | `uiInfoMessage` | `uiNavigate` |
| `uiNavigateEdge` | `uiSelectionDisabled` | `uiTabChanged` |
| `vehicleEnter` | `vehicleExit` | `waterTexture` |
| `weaponSwingMain` | `weaponSwingOff` | `weatherChanged` |
| `weatherTexture` | `whisper` | `xpGained` |
| `zoneChanged` |  |  |

## Source and scope

Generated for the default profile **PvP** in PulseSensation.
