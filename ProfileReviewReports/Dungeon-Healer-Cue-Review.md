# Dungeon: Healer — cue review

**Review window:** 2026-09-29  
**Result:** 63 Yes · 127 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Attentive triage archetype. Emphasizes low-health alarms, heal completion confirmations, dispels, and interrupt warnings.
- Health & Triage: `lowHealthWarning`, `lowHealthTexture`, `healCrit`, `healReceived`, `damageTaken` (alarm only), and `resurrectRequest` are **Yes**.
- Cast Flow: `castTexture`, `selfCastSucceeded` (vital confirmation that a heal landed!), `selfCastInterrupted`, `selfCastFailed`, `selfChannelStart`, `selfChannelStop`, `selfChannelInterrupted`, `selfEmpowerStage`, and `selfCastInstant` are **Yes**.
- CC & Dispels: Full CC suite enabled (`ccMaster`, `ccStun`, `ccSilence`, `ccFear`, `ccConfuse`, `ccRoot`, `ccPacify`, `ccDisarm`, `debuffReceived`).
- Interrupts & Boss Mechanics: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.
- Silences footfalls (`locomotion = No`), flight, mounts, weather, swimming, threat management (tank's job), weapon swings, and world clutter.

## Yes — belongs (63)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bgQueue` | `bossAbilityWarning` | `bossChatWarning` |
| `castTexture` | `ccConfuse` | `ccDisarm` |
| `ccFear` | `ccMaster` | `ccPacify` |
| `ccRoot` | `ccSilence` | `ccStun` |
| `combatEnter` | `combatLeave` | `controllerUIMaster` |
| `cooldownReady` | `damageTaken` | `debuffReceived` |
| `durabilityLow` | `encounterEnd` | `encounterStart` |
| `focusCastStart` | `focusChannelStart` | `groupTargetingStart` |
| `groupTargetingStop` | `healCrit` | `healReceived` |
| `lowHealthTexture` | `lowHealthWarning` | `padBattery` |
| `padDisconnected` | `playerAlive` | `playerDead` |
| `popupHidden` | `popupShown` | `procGlow` |
| `queuePop` | `radialClose` | `radialOpen` |
| `radialPage` | `radialSelect` | `radialTick` |
| `raidTarget` | `readyCheck` | `readyCheckDone` |
| `resourceCapped` | `resurrectRequest` | `rolePoll` |
| `selfCastFailed` | `selfCastInstant` | `selfCastInterrupted` |
| `selfCastSucceeded` | `selfChannelInterrupted` | `selfChannelStart` |
| `selfChannelStop` | `selfEmpowerStage` | `softFriendChanged` |
| `summonRequest` | `targetBigDefensive` | `targetCastStart` |
| `targetCastStopped` | `uiNavigate` | `uiTabChanged` |

## No — does not belong (127)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `binderShow` | `bnWhisper` | `breathTexture` |
| `breathWarning` | `comboPoint` | `craftComplete` |
| `craftStart` | `craftStopped` | `craftTexture` |
| `critLanded` | `cursorDrop` | `cursorPickup` |
| `deflect` | `dismount` | `drowningDamage` |
| `duelRequest` | `emote` | `enteringWorld` |
| `equipChanged` | `factionGained` | `focusChanged` |
| `formChanged` | `glideThrust` | `gossipShow` |
| `groupRoster` | `guildBankOpened` | `guildInvite` |
| `harvestComplete` | `honorGained` | `inputModeChanged` |
| `interactionWindow` | `interactionWindowClosed` | `itemObtained` |
| `itemTextBegin` | `jumped` | `landingHard` |
| `landingSoft` | `levelUp` | `locomotion` |
| `lootConfirm` | `lootGold` | `lootOpened` |
| `lootReceived` | `lootRoll` | `mailShow` |
| `meleeAttackStart` | `meleeAttackStop` | `meleeRangeIn` |
| `meleeRangeOut` | `merchantBuy` | `merchantRepair` |
| `merchantSell` | `merchantShow` | `mountUp` |
| `npcEmote` | `oceanTexture` | `padConnected` |
| `panelClose` | `panelOpen` | `partyInvite` |
| `partyLeader` | `pingPinAdded` | `questAccepted` |
| `questComplete` | `questDetail` | `questTurnedIn` |
| `radialBlocked` | `radialCancel` | `recipeLearned` |
| `resting` | `selfCastSent` | `selfCastStart` |
| `selfCastStop` | `skillUp` | `softEnemyChanged` |
| `softInteractChanged` | `softTargetInteraction` | `spellLearned` |
| `spiritHealerShow` | `stableShow` | `stackSplit` |
| `stealthTexture` | `swimTexture` | `targetChanged` |
| `targetChannelStart` | `targetDied` | `targetedByEnemy` |
| `taxiLanding` | `taxiOpened` | `taxiRide` |
| `taxiTakeoff` | `threatAggro` | `threatLost` |
| `threatRising` | `tradeRequest` | `tradeSkillShow` |
| `trainerShow` | `uiFocusIn` | `uiFocusOut` |
| `uiInfoMessage` | `uiNavigateEdge` | `uiSelectionDisabled` |
| `vehicleEnter` | `vehicleExit` | `waterTexture` |
| `weaponSwingMain` | `weaponSwingOff` | `weatherChanged` |
| `weatherTexture` | `whisper` | `xpGained` |
| `zoneChanged` |  |  |

## Source and scope

Generated for the default profile **Dungeon: Healer** in PulseSensation.
