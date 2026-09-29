# Dungeon: Melee — cue review

**Review window:** 2026-09-29  
**Result:** 52 Yes · 138 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- High-tempo physical execution archetype. Snappy combo points, resource spenders, execute range alerts, boss telegraphs, and kick windows.
- Strike Cadence: `comboPoint`, `resourceCapped`, `critLanded`, `deflect`, `weaponSwingMain`, `weaponSwingOff`, `targetDied`, and `damageTaken` are **Yes**.
- Kick Windows & Telegraphs: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.
- Cooldowns, Procs & CC: `cooldownReady`, `procGlow`, `ccMaster`, `ccStun`, `ccDisarm`, `lowHealthWarning`, and `debuffReceived` are **Yes**.
- Silences footfalls (`locomotion = No` due to continuous melee strafing), casting engine textures, tank threat alerts, flight, mounts, weather, and world looting.

## Yes — belongs (52)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bgQueue` | `bossAbilityWarning` | `bossChatWarning` |
| `ccDisarm` | `ccMaster` | `ccStun` |
| `combatEnter` | `combatLeave` | `comboPoint` |
| `controllerUIMaster` | `cooldownReady` | `critLanded` |
| `damageTaken` | `debuffReceived` | `deflect` |
| `durabilityLow` | `encounterEnd` | `encounterStart` |
| `focusCastStart` | `focusChannelStart` | `groupTargetingStart` |
| `groupTargetingStop` | `lowHealthWarning` | `padBattery` |
| `padDisconnected` | `playerAlive` | `playerDead` |
| `popupHidden` | `popupShown` | `procGlow` |
| `queuePop` | `radialClose` | `radialOpen` |
| `radialPage` | `radialSelect` | `radialTick` |
| `raidTarget` | `readyCheck` | `readyCheckDone` |
| `resourceCapped` | `rolePoll` | `softEnemyChanged` |
| `softTargetInteraction` | `summonRequest` | `targetBigDefensive` |
| `targetCastStart` | `targetCastStopped` | `targetDied` |
| `uiNavigate` | `uiTabChanged` | `weaponSwingMain` |
| `weaponSwingOff` |  |  |

## No — does not belong (138)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `binderShow` | `bnWhisper` | `breathTexture` |
| `breathWarning` | `castTexture` | `ccConfuse` |
| `ccFear` | `ccPacify` | `ccRoot` |
| `ccSilence` | `craftComplete` | `craftStart` |
| `craftStopped` | `craftTexture` | `cursorDrop` |
| `cursorPickup` | `dismount` | `drowningDamage` |
| `duelRequest` | `emote` | `enteringWorld` |
| `equipChanged` | `factionGained` | `focusChanged` |
| `formChanged` | `glideThrust` | `gossipShow` |
| `groupRoster` | `guildBankOpened` | `guildInvite` |
| `harvestComplete` | `healCrit` | `healReceived` |
| `honorGained` | `inputModeChanged` | `interactionWindow` |
| `interactionWindowClosed` | `itemObtained` | `itemTextBegin` |
| `jumped` | `landingHard` | `landingSoft` |
| `levelUp` | `locomotion` | `lootConfirm` |
| `lootGold` | `lootOpened` | `lootReceived` |
| `lootRoll` | `lowHealthTexture` | `mailShow` |
| `meleeAttackStart` | `meleeAttackStop` | `meleeRangeIn` |
| `meleeRangeOut` | `merchantBuy` | `merchantRepair` |
| `merchantSell` | `merchantShow` | `mountUp` |
| `npcEmote` | `oceanTexture` | `padConnected` |
| `panelClose` | `panelOpen` | `partyInvite` |
| `partyLeader` | `pingPinAdded` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `radialBlocked` | `radialCancel` | `recipeLearned` |
| `resting` | `resurrectRequest` | `selfCastFailed` |
| `selfCastInstant` | `selfCastInterrupted` | `selfCastSent` |
| `selfCastStart` | `selfCastStop` | `selfCastSucceeded` |
| `selfChannelInterrupted` | `selfChannelStart` | `selfChannelStop` |
| `selfEmpowerStage` | `skillUp` | `softFriendChanged` |
| `softInteractChanged` | `spellLearned` | `spiritHealerShow` |
| `stableShow` | `stackSplit` | `stealthTexture` |
| `swimTexture` | `targetChanged` | `targetChannelStart` |
| `targetedByEnemy` | `taxiLanding` | `taxiOpened` |
| `taxiRide` | `taxiTakeoff` | `threatAggro` |
| `threatLost` | `threatRising` | `tradeRequest` |
| `tradeSkillShow` | `trainerShow` | `uiFocusIn` |
| `uiFocusOut` | `uiInfoMessage` | `uiNavigateEdge` |
| `uiSelectionDisabled` | `vehicleEnter` | `vehicleExit` |
| `waterTexture` | `weatherChanged` | `weatherTexture` |
| `whisper` | `xpGained` | `zoneChanged` |

## Source and scope

Generated for the default profile **Dungeon: Melee** in PulseSensation.
