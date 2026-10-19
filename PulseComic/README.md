# PulseComic (alpha)

Comic-book frames for your hits: **POW!** on a crit, **K.O.!** on a killing blow, **OVERKILL!** when a crit kills.
A standalone companion to PulseHaptics. It does not call into PulseHaptics and works without it.

Install: copy the `PulseComic` folder into `Interface/AddOns/`. Not included in the PulseHaptics release zip.

## Commands

| Command | Action |
|:---|:---|
| `/comic test pow\|ko\|overkill\|hit` | Show a frame with plain booleans, no fight needed |
| `/comic on` / `off` | Enable or disable |
| `/comic scale <0.3-3>` | Frame size |
| `/comic pos <x> <y>` | Offset from screen centre |
| `/comic attribution recent\|any` | Only your hits (default), or every hit on your target |
| `/comic numbers` | Toggle the damage number inside the burst |
| `/comic meter` | Toggle the hit-meter prototype panel (drag to move) |
| `/comic meter test <dmg> <hp> [max]` | Drive the meter with plain numbers, e.g. `5000 4000` is a kill |
| `/comic meter source hit\|prev` | Which health reading drives the OVERKILL slide |
| `/comic jitter` | Toggle random offset and tilt per pop |
| `/comic debug` | Print the raw feed values for every hit on your target (secret ones as `<secret ...>`), plus whether the damage text's width is readable |

## How it works

In 12.x the crit flag and the target's death state can be secret booleans, which addon code cannot branch on.
Each frame is two nested alpha gates driven by `Region:SetAlphaFromBoolean`. Effective alpha multiplies down the
parent chain, so visibility becomes an AND of the two booleans without the code reading either:

| Frame | Crit gate | Death gate |
|:---|:---|:---|
| POW! | crit | not dead |
| K.O.! | not crit | dead |
| OVERKILL! | crit | dead |

The pop and fade animation runs on the outer frame, never on a gate. On clients without
`SetAlphaFromBoolean` (16001, 110x) there are no secrets, and the gates fall back to plain `SetAlpha`.

## Damage numbers

Each burst prints the hit's damage, e.g. "12.3K". In combat the amount is a secret number: it cannot be compared or
used in arithmetic, so it cannot decide which frame shows or whether a hit counts as overkill. `FontString:SetText()`
accepts secrets, though, so the client draws the number and the addon never reads it. The client's
`AbbreviateNumbers` is tried first; if it refuses a secret, the number is passed through `string.format` unshortened.

`/comic debug` also sets each amount on a hidden font string and reports `GetStringWidth()`. If that ever comes back
readable for a secret amount, text width would be a crude hit-size signal. It is expected to be secret as well.

## Hit meter (prototype)

Chat output is a dead end for secrets: the value prints as `<secret>`. The client will still *draw* a secret number
and *fill* a StatusBar from secret min/max/value, so the meter lets the engine do the maths and shows the result:

- **Bars.** `SetMinMaxValues(0, health)` + `SetValue(damage)`: the fill is damage ÷ health, computed by the client.
  The numbers are drawn on top. Each hit snaps to 0 and eases in (`ExponentialEaseOut`, 12.0+).
- **Lamps.** A 28 px clipping window over the right end of the same bar made 1000× wider. Only the last 0.1% is
  visible, so the lamp stays dark until damage ≥ ~99.9% of health and is fully lit at ≥ 100%. A threshold
  decided by geometry, not by Lua.
- **OVERKILL slide.** The OVERKILL art anchored to the right edge of a zoomed bar's fill, in a clipping window: it
  slides in only on a killing-size hit.

Rows: *of max health*, *of health at hit* (`UnitHealth` read when the hit arrives) and *of health, prior* (the
`UNIT_HEALTH` value before the latest one). Whether `UNIT_HEALTH` lands before or after the combat-text event is
unknown, so one of the two is the true "health before the hit"; watch which lamp lights on kills only.

Check in this order:
1. Out of combat: `/comic meter test 3000 4000` (no lamp) and `/comic meter test 5000 4000` (lamps lit, art slid in).
   This proves the geometry: a 128,000 px bar, clipping, and anchoring to a fill texture.
2. On a dummy or mobs: do the bars move and the numbers draw? If yes, secret min/max/value work.
3. On kills only: which row's lamp lights? Set `/comic meter source` to match.

If all three hold, OVERKILL can switch from "critical killing blow" to real overkill.

## Unconfirmed in the live client

Use `/comic debug` to settle these:

1. Setting the combat-text active unit to `"target"` delivers hits on your target, with a crit flag either in the
   message type or as the third value of the event info.
2. `UnitIsDead("target")` is correct about 0.15 s after the killing hit (`killDelay` in `PulseComicDB`).
3. `SetAlphaFromBoolean(v, 1, 0)` takes alpha on a 0-1 scale. If frames look nearly invisible, the scale is 0-255.
4. The second event-info value is the hit's amount, and `AbbreviateNumbers` either handles a secret or refuses it
   cleanly (refusal falls back to the full number).
5. OVERKILL means "critical killing blow". Real overkill damage needs arithmetic on secrets, which is not allowed.
   `C_DamageMeter` has an `overkillAmount` field (12.0.1), but whether it is readable in combat is unconfirmed.

## Known conflict with PulseHaptics

The combat-text active unit is global. PulseHaptics sets it to `"player"` for its damage-taken cues, and PulseComic
sets it to `"target"`. Whichever syncs last wins, so with both loaded one of them may see the wrong feed.
Check with `/comic debug` before trusting either.

## Attribution

The target feed includes groupmates' hits. `attribution recent` (the default) only counts hits within 0.7 s of your
own cast, or while auto-attack is on. DoT ticks outside that window are not counted.

## Art

`Media/*.tga` are 256x256 32-bit textures generated by `scripts/make-comic-art.py` (Pillow):
`python3 scripts/make-comic-art.py PulseComic/Media`.
