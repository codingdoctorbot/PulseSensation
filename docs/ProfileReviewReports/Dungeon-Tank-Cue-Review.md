# Dungeon: Tank — cue review

**Review window:** 2026-09-29  
**Result:** 58 Yes · 132 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Commanding protection archetype. Emphasizes threat alerts, active mitigation, crowd control, and kick windows.
- `threatLost` is a vital high-priority alarm; `threatRising`, `threatAggro`, and `targetedByEnemy` are all **Yes**.
- Mitigation and defense: `damageTaken`, `deflect` (parry/dodge/block), `targetBigDefensive`, `lowHealthWarning`, and `lowHealthTexture` are **Yes**.
- Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccDisarm`, `ccPacify`, `ccConfuse`, `ccRoot`).
- Enemy and boss cast telegraphs enabled (`targetCastStart`, `targetChannelStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`).
- 100% stripped of footfalls (`locomotion = No`), mounts, taxis, flight, weather, swimming, world looting, quests, merchants, and routine weapon swings.

## Yes — belongs (58)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bgQueue` | `bossAbilityWarning` | `bossChatWarning` |
| `ccConfuse` | `ccDisarm` | `ccFear` |
| `ccMaster` | `ccPacify` | `ccRoot` |
| `ccSilence` | `ccStun` | `combatEnter` |
| `combatLeave` | `controllerUIMaster` | `cooldownReady` |
| `damageTaken` | `debuffReceived` | `deflect` |
| `durabilityLow` | `encounterEnd` | `encounterStart` |
| `focusCastStart` | `focusChannelStart` | `groupTargetingStart` |
| `groupTargetingStop` | `lowHealthTexture` | `lowHealthWarning` |
| `padBattery` | `padDisconnected` | `playerAlive` |
| `playerDead` | `popupHidden` | `popupShown` |
| `queuePop` | `radialClose` | `radialOpen` |
| `radialPage` | `radialSelect` | `radialTick` |
| `raidTarget` | `readyCheck` | `readyCheckDone` |
| `resurrectRequest` | `rolePoll` | `softEnemyChanged` |
| `softTargetInteraction` | `summonRequest` | `targetBigDefensive` |
| `targetCastStart` | `targetCastStopped` | `targetChannelStart` |
| `targetDied` | `targetedByEnemy` | `threatAggro` |
| `threatLost` | `threatRising` | `uiNavigate` |
| `uiTabChanged` |  |  |

## No — does not belong (132)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `binderShow` | `bnWhisper` | `breathTexture` |
| `breathWarning` | `castTexture` | `comboPoint` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `critLanded` | `cursorDrop` |
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
| `lootRoll` | `mailShow` | `meleeAttackStart` |
| `meleeAttackStop` | `meleeRangeIn` | `meleeRangeOut` |
| `merchantBuy` | `merchantRepair` | `merchantSell` |
| `merchantShow` | `mountUp` | `npcEmote` |
| `oceanTexture` | `padConnected` | `panelClose` |
| `panelOpen` | `partyInvite` | `partyLeader` |
| `pingPinAdded` | `procGlow` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `radialBlocked` | `radialCancel` | `recipeLearned` |
| `resourceCapped` | `resting` | `selfCastFailed` |
| `selfCastInstant` | `selfCastInterrupted` | `selfCastSent` |
| `selfCastStart` | `selfCastStop` | `selfCastSucceeded` |
| `selfChannelInterrupted` | `selfChannelStart` | `selfChannelStop` |
| `selfEmpowerStage` | `skillUp` | `softFriendChanged` |
| `softInteractChanged` | `spellLearned` | `spiritHealerShow` |
| `stableShow` | `stackSplit` | `stealthTexture` |
| `swimTexture` | `targetChanged` | `taxiLanding` |
| `taxiOpened` | `taxiRide` | `taxiTakeoff` |
| `tradeRequest` | `tradeSkillShow` | `trainerShow` |
| `uiFocusIn` | `uiFocusOut` | `uiInfoMessage` |
| `uiNavigateEdge` | `uiSelectionDisabled` | `vehicleEnter` |
| `vehicleExit` | `waterTexture` | `weaponSwingMain` |
| `weaponSwingOff` | `weatherChanged` | `weatherTexture` |
| `whisper` | `xpGained` | `zoneChanged` |

## Source and scope

Generated for the default profile **Dungeon: Tank** in PulseSensation.
