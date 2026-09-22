# Outstanding findings

Things found on 2026-09-22 **outside** the two cloud review passes. `cloudreviewultra.md`
is a faithful record of those passes and contains none of this.

Nothing here is fixed. Ordered by whether a player can see it.

---

## 1. Internal doc citations render in the settings panel — user-facing

`Registry.lua`'s `caveat =` and `desc =` fields are **not comments**. They are the text the
settings panel shows next to a cue. Twelve of them cite internal design documents, so a
player toggling a cue currently reads things like:

> Not filtered by rarity yet (alphafeatures.md G18) — fires for anything, common items
> included.

The assertion is useful; the citation is noise to anyone who is not the author, and the
documents are not shipped with the addon.

Sites, all in `Pulse/Core/Registry.lua`:

```
86   180   198   210   261   277   367   379   389   407   411   954
```

**Fix:** delete the parenthetical, keep the sentence. No rewriting needed. This is the only
finding here that reaches a user, and it is the cheapest to close.

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

## 3. `Movement.lua:159` — changelog in a comment

```lua
-- 0.10, matching the registry. Was 0.12.
local peak = Pulse.Database:GetTriggerSetting("swimTexture", "peak", 0.10)
```

`Was 0.12.` is git's job. Worse, the comment asserts a cross-file invariant nothing
enforces: the `0.10` fallback duplicates `Registry.lua:116`'s `default = 0.10`. Verified
accurate today. The next three lines duplicate `strokeRateMin`, `strokeRateMax` and
`strokeDepth` the same way without any comment, so the convention is not even applied
consistently.

---

## 4. Opening PulseChecklist writes all 110 entries

`createRow` calls `ensureEntry` during construction, so simply opening the window populates
`PulseChecklistDB` with an entry per trigger whether or not anything is touched.

Harmless — the defaults are what `ensureEntry` would produce anyway — but a "fresh" saved
file is not empty, which matters if you ever diff saved variables to see what you actually
tested. Predates the `confirmedBy` work.

---

## 5. PulseDebug gaps

Surveyed after building `PulseDebug/UI.lua`. None are regressions; all are things the tool
still cannot answer.

**Live refresh is not logging.** The window re-renders at 10Hz. A value that spikes and
falls between two samples leaves no trace. Watching a `HUM` decay works; catching a `TICK`
does not — the pulse can land entirely between frames. A real log would append timestamped
lines on change, with peak capture.

**18 of 21 modules expose nothing.** Only `Locomotion`, `Crafting` and `Interaction` have a
`_Debug*` reach-in. This lands badly, because the review's confirmed bugs live exactly where
the tool is blind:

| Bug | State that would reveal it | Visible |
|---|---|---|
| `cloudreviewultra.md` finding 8 — Flight | `wasMounted`, `mountStateReady` | no |
| finding 4 — Encounter | `inEncounter` | no |
| findings 1/5 — CastActivity | `registered`, and which module wants it | no |

Closing this means adding reach-ins to **Pulse**, in the shape `_DebugGait` already uses.

**Four introspection APIs exist and nothing calls them:** `Database:GetProfileResolution`,
`GetProfileRule`, `HasPendingProfileSwitch`, `GetChangeEpsilon`. The pending-switch one is
worth wiring — it is the combat-deferred path whose own comment says it is "the kind of
thing that goes wrong once and never reproduces".

**Throttle is invisible.** `/pdebug why` prints "last-fire time is private" because
`lastFireTime` is a local in `Init.lua` with no accessor, so a throttled cue and a broken
one look identical.

**`watch` cannot see native triggers.** Only registry-declared `events` work, so Movement,
Flight, Combat, Environment and Health are unwatchable. Acknowledged in the code.

**The window cannot act.** `fire`, `hold`, `raw`, `why` and `cues` are chat-only, so the
hold workflow the window exists to support still means switching to chat to start it.

---

## 6. README calls Tremor a sibling; the TOC calls it a precursor

`README.md` says "sibling addon Tremor" and "sibling project" in two places, which reads as
something shipping alongside Pulse. `Pulse.toc` now states it is the proof-of-concept alpha
that preceded this one. Both cannot be right.

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
