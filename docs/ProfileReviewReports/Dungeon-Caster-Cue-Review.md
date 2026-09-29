# Dungeon: Caster — cue review

**Review window:** 2026-09-29  
**Result:** 57 Yes · 133 No · 0 not reviewed  
**Purpose:** Record whether each cue belongs in this profile. These decisions are review judgments; they do not change Pulse's current settings.

## Reading the decisions

- **Yes** means the cue belongs in the reviewed profile, in the reviewer's judgment.
- **No** means it does not belong as the cue currently behaves.
- The list records cue IDs from Pulse's trigger registry so the decisions can be mapped back to code.

## Notes from the review

- Fluid spellcasting pacing archetype. Continuous channel bed during casts, crisp completion snap, lockout warnings, and proc notifications.
- Spell Engine: `castTexture`, `selfCastSucceeded`, `selfCastFailed`, `selfCastInterrupted`, `selfChannelStart`, `selfChannelStop`, `selfChannelInterrupted`, `selfEmpowerStage`, and `selfCastInstant` are **Yes**.
- Procs & Burst: `critLanded`, `procGlow`, `cooldownReady`, `resourceCapped`, `targetDied`, and `damageTaken` are **Yes**.
- Enemy Mechanics & Danger: `targetCastStart`, `targetCastStopped`, `focusCastStart`, `focusChannelStart`, `bossAbilityWarning`, `bossChatWarning`, and `targetBigDefensive` are **Yes**.
- CC & Lockouts: `ccMaster`, `ccSilence` (crucial!), `ccStun`, `ccFear`, `lowHealthWarning`, and `debuffReceived` are **Yes**.
- Silences physical weapon swings, auto-shots, combo points, footfalls (`locomotion = No`), flight, mounts, weather, and world looting.

## Yes — belongs (57)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `bgQueue` | `bossAbilityWarning` | `bossChatWarning` |
| `castTexture` | `ccFear` | `ccMaster` |
| `ccSilence` | `ccStun` | `combatEnter` |
| `combatLeave` | `controllerUIMaster` | `cooldownReady` |
| `critLanded` | `damageTaken` | `debuffReceived` |
| `durabilityLow` | `encounterEnd` | `encounterStart` |
| `focusCastStart` | `focusChannelStart` | `groupTargetingStart` |
| `groupTargetingStop` | `lowHealthWarning` | `padBattery` |
| `padDisconnected` | `playerAlive` | `playerDead` |
| `popupHidden` | `popupShown` | `procGlow` |
| `queuePop` | `radialClose` | `radialOpen` |
| `radialPage` | `radialSelect` | `radialTick` |
| `raidTarget` | `readyCheck` | `readyCheckDone` |
| `resourceCapped` | `rolePoll` | `selfCastFailed` |
| `selfCastInstant` | `selfCastInterrupted` | `selfCastSucceeded` |
| `selfChannelInterrupted` | `selfChannelStart` | `selfChannelStop` |
| `selfEmpowerStage` | `softEnemyChanged` | `summonRequest` |
| `targetBigDefensive` | `targetCastStart` | `targetCastStopped` |
| `targetDied` | `uiNavigate` | `uiTabChanged` |

## No — does not belong (133)

| Cue ID | Cue ID | Cue ID |
|---|---|---|
| `abilityPulse` | `achievement` | `actionBarPage` |
| `actionFailed` | `afkToggle` | `auctionHouseShow` |
| `autoRepeatStart` | `autoRepeatStop` | `autoShotFired` |
| `bagFull` | `bagItemAdded` | `bagItemUsed` |
| `bankClosed` | `bankGold` | `bankOpened` |
| `binderShow` | `bnWhisper` | `breathTexture` |
| `breathWarning` | `ccConfuse` | `ccDisarm` |
| `ccPacify` | `ccRoot` | `comboPoint` |
| `craftComplete` | `craftStart` | `craftStopped` |
| `craftTexture` | `cursorDrop` | `cursorPickup` |
| `deflect` | `dismount` | `drowningDamage` |
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
| `resting` | `resurrectRequest` | `selfCastSent` |
| `selfCastStart` | `selfCastStop` | `skillUp` |
| `softFriendChanged` | `softInteractChanged` | `softTargetInteraction` |
| `spellLearned` | `spiritHealerShow` | `stableShow` |
| `stackSplit` | `stealthTexture` | `swimTexture` |
| `targetChanged` | `targetChannelStart` | `targetedByEnemy` |
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

Generated for the default profile **Dungeon: Caster** in PulseSensation.
