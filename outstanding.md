# Outstanding findings

Things found on 2026-09-22 **outside** the two cloud review passes. `cloudreviewultra.md`
is a faithful record of those passes and contains none of this.

Nothing here is fixed. Ordered by whether a player can see it.

---

## 1. Internal doc citations render in the settings panel — FIXED
Resolved in commit `40be1601` (2026-09-22): internal `.md` doc citations removed from `Registry.lua` caveats while keeping explanatory text clean and intact.

---

## 2. Every document cited from code is missing from the repo

Roughly 48 comment sites across `Pulse/` cite 15 `.md` documents. Not one is in the
repository.

**Recoverable — the file exists elsewhere on this machine:**

| Document | Refs | Location |
|---|---|---|
| `alphafeatures.md` | 20 | `~/PulseGit2/Cooking/` |
| `CodeReview-2026-09-22.md` | 3 | `~/PulseGit2/Pulse/helpdocs/` |
| `UIguide.md` | 2 | `~/Documents/OldDeveloperBackups/Pulse/` |
| `Pulse_Retail_Combat_Text_Windfury_Findings.md` | 2 | `~/PulseGit2/Cooking/` |
| `Pulse — Proposed New Vibration Modes.md` | 1 | `~/PulseGit2/Cooking/` |
| `deprecatedbutfuturecode.md` | 1 | `~/PulseGit2/Cooking/` |
| `Pulse_Ideas_for_Improvements.md` | 1 | `~/PulseGit2/Cooking/` |
| `IntegrationofHapticforWOWforever.md` | 1 | `~/PulseGitBackups/PulseGit 2/` |

**Not on disk anywhere:**

| Document | Refs |
|---|---|
| `continuous.md` | 8 |
| `combat-detection.md` | 4 |
| `FUTURE.md` | 3 |
| `reverseeng.md` | 1 |
| `KNOWN_ISSUES.md` | 1 |
| `DESIGN.md` | 1 |
| `Discovery — Weapon Swing Haptic Cue Proposal.md` | 1 |

The lost ones matter more than their count. They are cited as *evidence*:
`Registry.lua:91` justifies a design with "combat-detection.md §3"; `Registry.lua:261`
resolves two conflicting live observations against "combat-detection.md Part 1 §1" and then
warns that a suspicion in "reverseeng.md §4/FUTURE.md B1" is not settled. Those are the
load-bearing *why* comments, and the citation underneath them can no longer be opened by
anyone.

**Decision taken:** leave it. The assertions are true, the author has the archive, and 45
edits across the best comments in the codebase is churn with real downside. Recorded here
so the choice is deliberate rather than forgotten.

---

## 3. `Movement.lua:159` — changelog in a comment — FIXED
Resolved: Stray changelog comments removed.

---

## 4. Opening PulseChecklist writes all 110 entries — FIXED
Resolved: `PulseChecklist/Checklist.lua` uses `getEntry(triggerID)` which returns a default fallback without writing to `PulseChecklistDB`. Entries are only persisted on user action (`ensureEntry(triggerID)` on click or comment).

---

## 5. PulseDebug gaps — FIXED
Resolved:
- **Event Logging & Peaks**: 50-entry millisecond timestamped event log (`views.log`) and 1.5s decaying peak capture added in `PulseDebug/UI.lua`.
- **Module Reach-ins**: `_Debug*` introspection added across modules (`Locomotion`, `Crafting`, `Interaction`, `Flight`, `Encounter`, `Combat`, `Environment`, `Movement`, `Health`, and `CastActivity`). `CastActivity:_DebugActive()` returns a table detailing registration and consumer modules (`Casting`, `Combat`).
- **Profile Introspection**: `HasPendingProfileSwitch` and `GetProfileResolution` wired into `/pdebug state` and the UI state view.
- **Throttle Visibility**: `Pulse:_DebugLastFireTime(triggerID)` exposed in `Init.lua` and consumed by `/pdebug why <triggerID>` to show elapsed vs. throttle window.
- **Interactive Action Buttons**: Added interactive test buttons directly to `PulseDebug` UI (`Stop All`, `Thud`, `Tick`, `Hold 2s`, and `Clear Log`) with tooltips.

---

## 6. README calls Tremor a sibling; the TOC calls it a precursor — FIXED
Resolved: `README.md` and all `.toc` manifests harmonized; Tremor is consistently credited as the foundational precursor alpha.

---

## 7. Unreviewed code

The two cloud passes covered `Pulse/` only — 4,598 lines of `Core/`, then 7,874 of
`Modules/` + `UI/`.

Never reviewed:

- `PulseChecklist/` and `PulseDebug/` as they stood — roughly 1,700 lines
- `PulseDebug/UI.lua` — new, ~350 lines
- `PulseChecklist/tests/pulsedebug-test.lua` and `checklist-test.lua` — new
- The `confirmedBy` changes in `PulseChecklist/Checklist.lua`

Also worth noting: all ten review findings landed in `Core/` and `Modules/`. The `UI/` half
of the second pass — 3,936 of 7,874 lines — produced nothing, which suggests the unreviewed
companion addons are a better use of a future pass than re-running `UI/`.

---

## 8. Consolidate spell cast event frames into `CastActivity.lua` — FIXED
Resolved: `Pulse/Core/CastActivity.lua` handles `UNIT_SPELLCAST_FAILED_QUIET` with Touch of Death / dead-state filters, and `Pulse/Modules/Combat.lua`'s `castFrame` now consumes `CastActivity:OnActivity` rather than registering duplicate spell events.

---

## 9. Clean up weapon swing fallback estimator formula — FIXED
Resolved: Comment and formula in `Pulse/Modules/Combat.lua` clarified; 2.6s constant is explicitly treated as the unhasted base speed, properly divided by `mult = 1.0 + (haste / 100)`.

---

## 10. DualSense trigger channel capability in Blizzard SDL layer

On macOS and Windows, Blizzard's embedded SDL gamepad subsystem accepts bare cstrings for
`vibrationType` (`C_GamePad.SetVibration`). While `"Low"` and `"High"` are confirmed functional,
`"LTrigger"` and `"RTrigger"` remain unconfirmed in the live client engine.

Pulse cleanly handles this via `Core/Engine.lua`'s `ROLE_FALLBACK` (`ltrigger -> low`, `rtrigger -> high`),
ensuring trigger cues are felt as rumble on standard hardware. If Blizzard enhances SDL trigger
haptic bindings in future client revisions, the infrastructure is already fully in place.
