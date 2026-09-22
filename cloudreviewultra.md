# Cloud Ultrareview — `Pulse/Core/`

**Date:** 2026-09-22
**Scope:** 14 files, 4,598 insertions — `Pulse/Core/` only
**Base:** `base-rv-core` (synthetic empty-context base; full tree on disk for reference)
**Findings returned:** 3 — 2 `normal`, 1 `nit`

No code was changed by this review, and this file is the only thing it produced. (A
clarifying comment was later added to `Pulse/Pulse.toc` by request — unrelated to any
finding below.)

| # | File | Reviewer severity | My verdict |
|---|---|---|---|
| 1 | `Core/CastActivity.lua:232` | normal | **Confirmed** — real bug, bounded blast radius |
| 2 | `Core/Schemas/LowOnly.lua:11` | normal | **Confirmed** — but the suggested fix names the wrong role |
| 3 | `Core/Engine.lua:409` | nit | **Accurate, not worth fixing** |

---

## 1. `CastActivity:SetActive` has no refcount — CONFIRMED

**Claim:** a single unrefcounted `registered` boolean is shared by two independent callers, so one module can deregister events the other still needs.

**Verified.** The mechanism is exactly as described:

- `CastActivity.lua:211` — `local registered = false`, one module-level flag.
- `CastActivity.lua:233` — `if active == registered then return end`, so a second `SetActive(true)` is a no-op.
- `CastActivity.lua:250-252` — `SetActive(false)` unconditionally runs `frame:UnregisterAllEvents()`, `frame:SetScript("OnUpdate", nil)`, `self:Reset()`. No consumer accounting.

Two independent callers:

- `Modules/Casting.lua:53` calls `SetActive(wanted)`, where `wanted` is derived only from its own four cues (`Casting.lua:24`), bound to only those four (`Casting.lua:58`).
- `Modules/Crafting.lua:290` calls `SetActive(true)` — and **only ever `true`**. Its `sync()` early-returns at `Crafting.lua:285-286` when the cue is off, never calling `SetActive(false)`.

**The dispatch is per-cue, which is what makes it bite.** `Pulse:BindFrame` (`Init.lua:217-223`) subscribes the sync to each of *its own* cue ids via `Database:OnCueChanged`, and `Database.lua:923` notifies via `notify(cueListeners, triggerID)` — only listeners for the changed cue. So turning off `selfCastInstant` runs Casting's sync and not Crafting's.

**Failing sequence:** `craftTexture` on, `selfCastInstant` on → both satisfied. Turn off `selfCastInstant` → Casting's sync recomputes `wanted = false` from its own cues → `SetActive(false)` → all trade-skill events unregistered and state reset. `craftTexture` silently stops working. Crafting never finds out.

**Two things the reviewer did not establish, both of which lower the severity:**

*It self-heals.* `BindFrame` also subscribes every sync to `masterEnabled` (`Init.lua:221`) and calls `sync()` once at bind time (`Init.lua:222`), and `Database.lua:617,630` call `notifyAll(cueListeners)` on what appear to be profile/reset paths. Any of those re-runs both syncs. Because `Pulse.toc` loads `Modules/Casting.lua` (line 56) **before** `Modules/Crafting.lua` (line 63), Crafting's sync runs last and its `SetActive(true)` wins. So a `/reload`, a master toggle, or a profile switch restores the cue. The failure window is "until the next reload," not permanent.

*The leak is the other direction and is real.* Turn `craftTexture` off while no Casting cue is on: Crafting's sync early-returns without ever calling `SetActive(false)`, so the nine events and the `OnUpdate` sweep stay registered with nothing consuming them. That one also clears on reload, since Casting's sync runs and sets false.

**Shape of a fix (not applied):** refcount by consumer — `SetActive(key, wanted)` keyed on caller, registering while any key is true. That fixes both directions at once and removes the load-order dependency, which currently works only by accident of `.toc` ordering.

---

## 2. `LowOnly` does not mirror `HighOnly` — CONFIRMED, fix misdirected

**Claim:** `LowOnly` maps both `low` and `high` to the Low channel at 1.0/1.0, unlike `HighOnly`, which uses 0.6/1.0 so collapsed roles stay distinguishable.

**Verified, and the intensity genuinely reaches the hardware:** `Engine.lua:391` applies `def.intensity` into the channel magnitude, so this is not a cosmetic table difference.

```
HighOnly.lua:21-24          LowOnly.lua:17-20
  low      High  0.6          low      Low  1.0
  high     High  1.0          high     Low  1.0
  ltrigger High  0.6          ltrigger Low  0.7
  rtrigger High  1.0          rtrigger Low  1.0
```

`HighOnly.lua:12-14` states the intent outright — `low` arrives at 0.6 "so the two stay distinguishable once they share a motor" — and `LowOnly.lua:9` calls itself a "Mirror of HighOnly." It isn't one for the rumble pair.

**The reviewer's suggested fix is wrong in detail.** It proposes reducing `low` "matching HighOnly's pattern." But HighOnly's pattern reduces the *displaced* role and leaves the *native* one at full: on the High channel, `high` is native (1.0) and `low` is the incomer (0.6). Mirroring that in LowOnly means reducing **`high`**, not `low` — `low` is native to the Low channel and should stay at 1.0. Applying the fix as written would attenuate the wrong half.

**One asymmetry the reviewer missed:** the trigger roles differ too — `ltrigger` is 0.6 in HighOnly but 0.7 in LowOnly. LowOnly clearly *does* differentiate its trigger pair, just at a different ratio, which makes the flat 1.0/1.0 on the rumble pair look more like an oversight than a decision. Whether 0.6 and 0.7 should be reconciled is a judgement call I can't make from the code.

---

## 3. `driveChannel` closure allocated per frame — ACCURATE, NIT

**Claim:** `Engine.lua:409` declares `local function driveChannel` inside the `OnUpdate` handler, allocating a closure every frame.

**Factually correct.** `Engine.lua:330` is the `OnUpdate` script and `Engine.lua:409` is inside it, so a fresh closure is built each tick.

**Why I would leave it alone:**

- It is gated by `if not deviceReady then return end` (`Engine.lua:331`), so nothing is allocated unless a gamepad is actually connected.
- The closure captures three per-frame locals — `dt` (`:343`), `epsilon` (`:402`) and the mutable `anyOn` (`:403`). Hoisting it means threading all three through the signature and returning the `anyOn` contribution, which trades one small allocation for a wider signature and a return value to thread back.
- One small closure per frame is modest churn by WoW addon standards, and the 4-line comment at `Engine.lua:405-408` explaining the gain → gamma → floor → smoothing ordering is well placed where it is.

The reviewer rated this `nit` and that rating is right.

---

## Coverage

This pass saw `Pulse/Core/` only — 14 files, 4,598 lines. **Not reviewed:** `Pulse/Modules/` (3,891 lines), `Pulse/UI/` (3,936 lines), `PulseChecklist/`, `PulseDebug/`. The second pass is set up on branch `rv-modules-ui` against base `base-rv-modules-ui` (30 files, 7,874 lines) and has not been run.

Note that finding 1 sits on the Core/Modules boundary: it was found from the Core side, but the two colliding callers both live in `Modules/`, which this pass could read for context but was not reviewing.

---
---

# Cloud Ultrareview — `Pulse/Modules/` + `Pulse/UI/`

**Date:** 2026-09-22
**Scope:** 30 files, 7,874 insertions
**Base:** `base-rv-modules-ui`
**Findings returned:** 7 — 5 `normal`, 2 `nit`

No code was changed by this pass either.

| # | File | Reviewer severity | My verdict |
|---|---|---|---|
| 4 | `Modules/Encounter.lua:68` | normal | **Confirmed** — and broader than reported |
| 5 | `Modules/Crafting.lua:281` | normal | **Confirmed** — same bug as finding 1, found from the other side |
| 6 | `Modules/World.lua:39` | normal | **Confirmed** — and broader than reported |
| 7 | `Modules/Interaction.lua:66` | normal | **Plausible** — not decidable from source |
| 8 | `Modules/Flight.lua:17` | normal | **Confirmed** |
| 9 | `Modules/Combat.lua:227` | nit | **Confirmed** — count exact |
| 10 | `Modules/Crafting.lua:41` | nit | **Confirmed** — reviewer undercounted by one |

---

## 4. `Encounter.lua` sync wipes live encounter state — CONFIRMED, broader than reported

`sync()` (`Encounter.lua:68-78`) runs `inEncounter = false` at line 71 unconditionally, before its own enablement guards. `inEncounter` is set true only by `ENCOUNTER_START` (line 84), which will not re-fire for a pull already in progress, and `chatFrame`'s handler gates on it (lines 112-116). `Pulse:BindFrame({ "bossAbilityWarning", "bossChatWarning" }, sync)` at line 119 means any toggle of either cue re-runs it, as does `masterEnabled` (`Init.lua:221`) and any profile switch (`Database.lua:617,630`).

So: open the panel mid-pull, toggle either boss cue, and `bossChatWarning` is dead for the rest of that fight.

**Broader than the reviewer stated.** Line 70 also calls `clearBossTimers()`, so the scheduled `bossAbilityWarning` pulses for the current encounter are discarded too. Both cues are affected, not just the chat one.

**The codebase already knows the right pattern.** `PlayerState.lua:123` reseeds with `popupWasShown = anyPopupShown()` inside its sync; `Health.lua:157` re-reads `LowHealthFrame:IsShown()` rather than trusting a cached flag. `Encounter.lua` is the outlier. `IsEncounterInProgress()` exists as a client API, though I have not confirmed it behaves usefully here.

---

## 5. `CastActivity` shared flag — CONFIRMED (same defect as finding 1)

The Modules pass rediscovered finding 1 independently, approaching from `Crafting.lua:281-296` and `Casting.lua:54` rather than from `CastActivity.lua:232`. Same mechanism, same conclusion — two consumers, one last-write-wins boolean, no refcount.

Worth recording that the two passes disagree slightly on recovery. This pass says the cue stays dead "until the player toggles craftTexture off and back on." That is one recovery path, but finding 1 established there are others: because `Pulse.toc` loads `Modules/Casting.lua` (line 56) before `Modules/Crafting.lua` (line 63), Crafting's `SetActive(true)` runs last on any full re-sync, so a `/reload`, a `masterEnabled` toggle or a profile switch also restores it. The first pass's account is the more complete one.

That two independent passes over disjoint file sets both surfaced this is the strongest signal either produced.

---

## 6. `World.lua` emote filter contradicts its own comment — CONFIRMED, broader than reported

`World.lua:26-27` states the contract: react "only to the player's own or a crowded area buzzes continuously." `World.lua:41` does not honour it:

```lua
if sender == playerName or (message and playerName and message:find(playerName, 1, true)) then
```

The OR'd branch fires on any other player's `CHAT_MSG_TEXT_EMOTE` whose text contains your name — someone `/hug`ging you, for instance — which is precisely the crowded-area case the comment says the filter exists to prevent.

**Broader than the reviewer stated.** `find(..., 1, true)` is a plain substring search with no word boundary, so partial-name collisions fire too: a character named `Ana` matches "Anakin waves." Name length is inversely proportional to how often this misfires.

**An ambiguity the finding glosses over.** Firing on emotes *targeted at you* may well be desirable — being waved at is arguably worth feeling. But the comment promises own-emotes-only, so code and comment disagree whichever behaviour is intended. This needs a decision about intent before it needs a patch.

---

## 7. `questDetail` mapped to a broader interaction type — PLAUSIBLE, not decidable from source

`Interaction.lua:66` maps `questDetail` to `Enum.PlayerInteractionType.QuestGiver` (4), and `onShow` (`:97-108`) fires the cue for every `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` carrying it.

The promised semantics are confirmed: `Registry.lua:705` reads `label = "Quest offered", desc = "Fires when a quest's detail page opens, ready to accept."`, with `events = { "QUEST_DETAIL" }` — an event that genuinely does fire only for the offer page.

Whether `QuestGiver` also covers turn-in, progress checks and greetings is a claim about client behaviour I cannot settle from this repository. If true, the finding holds and the cue will fire on quest hand-ins as well as offers. The reviewer is also right that the module's throttle argument (`Interaction.lua:11-15`) answers a different question — it prevents a duplicate pulse for one event, not a semantically wider trigger population.

Note the module already flags this table as provisional: `Interaction.lua:95-96` says "One trip past a guild bank and an auctioneer with `/pulse debug` on settles it." That is the right way to resolve this one.

---

## 8. `Flight.lua` never reseeds mount state — CONFIRMED

`syncMount()` (`Flight.lua:17-23`) unregisters and re-registers events but never touches `wasMounted` or `mountStateReady`. Registering `PLAYER_ENTERING_WORLD` at line 22 does not cause it to fire, so re-enabling never re-baselines.

Unmounted with `wasMounted = false`; disable the cues; mount while nothing is listening; re-enable. `wasMounted` is still `false`. Dismount now and the handler computes `mounted = false` against a stale `wasMounted = false`, so neither branch at lines 32-36 runs and the cue is dropped.

**It fails both directions.** Disable while mounted, dismount while disabled, re-enable, then mount: `mounted = true` against a stale `wasMounted = true`, and `mountUp` is dropped instead.

Two lines in `syncMount` after the guards fix it, in the shape `PlayerState.lua:123` already uses.

---

## 9. `clamp01` duplicated seven times — CONFIRMED, nit

Exactly as reported. Two pre-existing in Core (`Engine.lua:60`, `Waves.lua:32`) and five in Modules (`Combat.lua:227`, `Environment.lua:25`, `Movement.lua:29`, `Flight.lua:49`, `Crafting.lua:148`), all with an identical body. `Flight.lua:47` carries the explanation: native `math.clamp` is confirmed absent on this client.

The count is exact. Whether seven three-line copies justify a `Pulse.Util` table is a taste call; the cost of the status quo is that adopting `math.clamp`, if it ever lands, is a seven-file edit.

---

## 10. Enum-with-literal-fallback duplicated — CONFIRMED, and undercounted

The reviewer found three sites and named them correctly: `Crafting.lua:42` (`Enum.Profession`), `Interaction.lua:41` (`Enum.PlayerInteractionType`) and `Combat.lua:531` (`Enum.PlayerSwingType`). The Combat one is written in two steps rather than one line, so it does not match the others textually, but the logic is the same.

**There is a fourth.** `Locomotion.lua:194` does the same thing inline rather than as a function:

```lua
local armorClass = Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4
```

`Interaction.lua:37-38` names Locomotion as using "the pattern," so the codebase already treats it as the same family. Four sites, not three.

---

## The pattern underneath findings 4, 5 and 8

These three are one bug wearing three faces: **a `sync()` that re-registers events without reconciling the state those events maintain.**

- `Encounter.lua:71` — destroys live state it should have reseeded.
- `Flight.lua:17-23` — never reseeds at all.
- `CastActivity` via `Casting.lua:53` / `Crafting.lua:290` — never coordinates state shared with another consumer.

`Pulse:BindFrame` (`Init.lua:217-223`) invokes these syncs far more often than their authors appear to have assumed: on every relevant cue toggle, on every `masterEnabled` change, and on every profile switch through `notifyAll`. Any sync that caches state across that boundary has to re-derive it.

The convention already exists in the codebase — `PlayerState.lua:123` and `Health.lua:157` both re-read live state rather than trusting a cached flag. It is applied inconsistently rather than unknown. Auditing every `sync()` for cached state would likely be worth more than fixing these three individually, and neither review pass said so, because neither could see the whole picture: finding 5's two colliding callers live in `Modules/` while the flag they fight over lives in `Core/`.

---

## Coverage, both passes

`Pulse/` is now fully reviewed across two passes — 4,598 lines of Core, then 7,874 of Modules and UI. **Still unreviewed:** `PulseChecklist/` and `PulseDebug/`, roughly 1,700 lines.

Notably, all ten findings landed in `Core/` and `Modules/`. The UI pass contributed none, despite `UI/` being 3,936 of the second pass's 7,874 lines — about half the diff produced nothing.
