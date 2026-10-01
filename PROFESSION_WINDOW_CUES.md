# Profession window: extra cues on open, tab switch and close

**Status:** proposed fix, not yet applied. It changes cue settings in `Core/Registry.lua` only.
No code changes.

## What happens

Steps: press **K** to open the profession window on the Fishing tab, switch to the Blacksmithing
tab, then close the window. With debug on and every cue enabled, chat shows:

```
Profession window opened fired -> TAP (intensity 0.60)        ← open
Instant ability used fired -> CLICK (intensity 0.50)
Your cast succeeded fired -> CHIME (intensity 1.00)
Interface took controller focus fired -> TAP (intensity 0.50)
Profession window opened fired -> TAP (intensity 0.60)        ← switch tab
Instant ability used fired -> CLICK (intensity 0.50)
Your cast succeeded fired -> CHIME (intensity 1.00)
UI focus moved fired -> TICK (intensity 0.35)                 ← close
Interface released controller focus fired -> TICK (intensity 0.50)
UI panel closed fired -> CLICK (intensity 0.50)
```

Opening the window plays **four** vibrations, switching tabs plays **three**, and closing plays
**three**.

## Why

### 1. Opening a profession window counts as casting a spell

In this client, opening a profession window (or switching to another profession's tab) is
technically **casting that profession's spell**, an instant cast. The addon sees a spell succeed
and does what it does for any spell:

- **"Instant ability used"** (`selfCastInstant`): `Core/CastActivity.lua` sees a spell succeed
  with no cast bar and labels it an instant ability.
- **"Your cast succeeded"** (`selfCastSucceeded`): fires on every spell success.

Neither is wrong about the game event. The player just didn't *use an ability*: they opened a
window. **Only profession windows do this.** Merchant, mail, bank and other windows don't cast
anything.

### 2. The controller focus cues stack on top of the window cues

When a window opens, the controller's selection moves into it ("Interface took controller
focus"), and when it closes, the selection leaves ("Interface released controller focus").
These are separate cues, so they play alongside the window's own cue.

### 3. Why the existing arbiter didn't prevent it

The addon already has a system for this, the **arbiter** (`Core/Arbiter.lua`). Cues can share a
**bus**, a common channel. When a cue on a bus fires, any **lower-priority** cue on that same bus
is blocked for 0.15 s, or for as long as the first cue is still playing.

"Profession window opened" is on the `window` bus at priority 3, with the other window cues.
That's why "UI panel opened" (priority 1) correctly stays silent when the profession window
opens. But **the cast cues and the focus cues aren't on any bus**, so the arbiter never compares
them with the window cues, and they all play.

## The fix

Put four cues on the `window` bus at the lowest priority (0), so they give way to any window
cue. Two lines per cue in `Core/Registry.lua`:

```diff
 	{
 		id = "selfCastInstant",
+		bus = "window",
+		busPriority = 0,
 		category = "ALERT_SELF_CAST",
 		mode = "CLICK",
```

```diff
 	{
 		id = "selfCastSucceeded",
+		bus = "window",
+		busPriority = 0,
 		category = "ALERT_SELF_CAST",
 		mode = "CHIME",
```

```diff
 	{
 		id = "uiFocusIn",
+		bus = "window",
+		busPriority = 0,
 		category = "CONTROLLER_UI",
 		mode = "TAP",
```

```diff
 	{
 		id = "uiFocusOut",
+		bus = "window",
+		busPriority = 0,
 		category = "CONTROLLER_UI",
 		mode = "TICK",
```

### Why it works

The live client confirms the order: **"Profession window opened" always comes first.** It
claims the `window` bus at priority 3. The cast cues and the focus cue arrive just after it at
priority 0, so they are blocked.

| Moment | Before | After |
|---|---|---|
| Open | TAP + CLICK + CHIME + TAP | **TAP** |
| Switch tab | TAP + CLICK + CHIME | **TAP** |
| Close | TICK + TICK + CLICK | **TICK + CLICK** (see below) |

"Interface took controller focus" is blocked if it arrives within 0.15 s. The addon checks focus
20 times a second, so it usually notices within 50–100 ms. If the game is ever slower to hand
over focus, the TAP plays as it does today, so nothing gets worse.

### Closing: what this does and doesn't fix

- **"Interface released controller focus"** fires in the same moment as "UI panel closed"
  (priority 1). Both share one playback channel, so the CLICK replaces the TICK and only the
  CLICK is felt. If the two ever land in separate 50 ms checks, both play as they do today.
- **"UI focus moved"** is **left out on purpose.** It fires *before* "UI panel closed" (the
  selection briefly jumps to another button as the window hides), and the arbiter can only block
  cues that come *after* a higher-priority one, not take back one that has already played.
  Adding it would gain nothing on close and would add the risk below.

## Risks

There is no way for this change to cause a Lua error. The worst case is a cue staying silent when
it shouldn't, and undoing the change means deleting the added lines.

| Risk | When | Who notices | Real-world chance |
|---|---|---|---|
| A real instant spell is silent | Cast within 0.15 s of **any** window opening, or while that window's cue is still playing (up to 0.45 s for the longest) | Players with the optional cast cues on | **Close to zero:** only profession windows cast, so this needs a coincidental cast |
| "Instant ability used" and "Your cast succeeded" no longer both play | Every instant spell: they are one game event, and the CHIME replaces the CLICK | Players with **both** optional cues on | Every time, but it's arguably the intended behaviour: one event, one cue |
| A cast cue and a window cue cut each other short | They share one playback channel; the window cue always wins | Players with cast cues on | Rare |
| The focus TAP still plays on open | The game takes longer than 0.15 s to hand over focus | Players with `uiFocusIn` on | Same as today: nothing gets worse |

**What can't go wrong:**

- **No casting logic changes.** `CastActivity` classifies every spell exactly as before. Only
  whether these four cues *play* changes.
- **No new code.** It's existing arbiter code, already used by the window cues and the loot cues.
- **Window cues are unaffected.** Priority 0 never blocks a higher-priority cue.
- **Blocked cues don't use up their throttle.** The throttle only counts once the bus lets a cue
  through, so a blocked cue never causes the next one to be skipped.
- **Saved settings are untouched.** Bus and priority come from the registry, not from player
  profiles, so nothing needs migrating.
- **Other panels improve too.** Opening bags or the character sheet will play one TAP ("UI panel
  opened") instead of panel TAP plus focus TAP.

## Not fixed here

- **The "UI focus moved" TICK on close.** Removing it would mean changing `Modules/ControllerUI.lua`
  to hold focus cues for one check (50 ms) and drop them if a panel closes. That's a code change
  with its own risks, so it's left for later. Both "UI focus moved" and "UI panel closed" are on
  by default, so every player currently feels TICK + CLICK when closing a window.
- **"Profession window opened" on every tab switch.** The game sends a fresh "profession window
  opened" event per tab. A tap on switching profession is reasonable feedback, so it's kept.

## How to verify

1. **Automated:** a test that replays the sequence above through the real arbiter: profession
   window opened, then the two cast cues and focus-in within 0.15 s. Expected: only the first one
   plays. It should also check that an instant spell with no window open still plays.
2. **In game, debug on:** repeat the steps (K, switch tab, close).
   - Expected: one "Profession window opened" line per open or tab switch, **no** "Instant
     ability used" or "Your cast succeeded" lines, and no focus-in line on open.
   - Then cast a real instant spell away from any window, and check that its cues still fire.
