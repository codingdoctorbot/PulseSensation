# PulseComic (alpha)

Comic-book frames for your hits: **POW!** on a crit, **K.O.!** on a killing blow, **OVERKILL!** when a crit kills.
A standalone companion to PulseHaptics. It does not call into PulseHaptics and works without it.

Install: copy the `PulseComic` folder into `Interface/AddOns/`. Not included in the PulseHaptics release zip.

## Settings window

`/comic` (or left-click the minimap button) opens PulseComic's own window, separate from Blizzard's settings panel.
Right-click the minimap button to turn PulseComic on or off; drag it to move it. No gamepad support yet.

- **General**: on/off, overall size, which hits count, kill detection, critical hits, kill feed, extras.
- **Events**: what each moment shows. Pick a group (Hits, Kills, Multi-kills, Sprees, Deaths, Interrupts,
  Encounters, Testing), then an event, then its look:
  - **Art**: any three-frame sequence from `Art/` by category (Comic, Anime, Arcade, Ninja, Arena, Escalation,
    Failure, Original), *Random* from one category or from everything, or *None* for text only.
  - **Animation**: Flipbook pop, Slam in, Bounce, Rise and fade, Shake, Still. Flipbook, Bounce, Rise and Shake play
    the art's frames (onset 80 ms, peak 120 ms, aftershock).
  - **Title text** and **Detail line**: templates with tokens such as `{killer}`, `{victim}`, `{count}`, `{amount}`,
    `{name}`, `{level}`. Secret values (enemy names, damage) are drawn by the client, never read.
  - **Title color**, **Size**, **Position** (comic spot, top banner, low centre, left, right), **Sound**.
  - **Preview** and **Reset event**.
- **Profiles**: profiles are shared across the account. Each character uses one or follows the account default.
  New, Copy, Rename, Delete (click twice), Reset. **Export this** / **Export all** put a `PCOMIC1:` string in the box
  to copy; **Import** adds pasted profiles beside yours, never over them. Import parses the string itself (no code
  is run) and keeps only known settings of the right type.

Art lives in the repository's `Art/` folder; `PulseComic/Art` is a symlink to it so the addon can load it.

## Commands

| Command | Action |
|:---|:---|
| `/comic` | Open or close the settings window |
| `/comic test pow\|ko\|overkill\|hit` | Show a frame with plain booleans, no fight needed |
| `/comic on` / `off` | Enable or disable |
| `/comic kill event` | Toggle the killing-blow event (`PARTY_KILL`) as a kill source |
| `/comic kill death` | Toggle the target death check (`UnitIsDead`) as a kill source |
| `/comic kill pet` | Toggle whether your pet's killing blows count |
| `/comic kill log` | Toggle a chat line for every killing blow the client reports, and whether it counted |
| `/comic minimap` | Show or hide the minimap button |
| `/comic profile [name]` | Show profiles, or switch this character to one |
| `/comic credits` | Font attributions |
| `/comic scale <0.3-3>` | Frame size |
| `/comic pos <x> <y>` | Offset from screen centre |
| `/comic attribution recent\|any` | Only your hits (default), or every hit on your target |
| `/comic numbers` | Toggle the damage number inside the burst |
| `/comic meter` | Toggle the hit-meter prototype panel (drag to move) |
| `/comic meter test <dmg> <hp> [max]` | Drive the meter with plain numbers, e.g. `5000 4000` is a kill |
| `/comic meter source hit\|prev` | Which health reading drives the OVERKILL slide |
| `/comic jitter` | Toggle random offset and tilt per pop |
| `/comic debug` | Print the raw feed values for every hit on your target (secret ones as `<secret ...>`) |

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
`AbbreviateNumbers` ("12.3K") and `BreakUpLargeNumbers` ("12,345") also accept secrets from addon code, so the
number is shortened by the client; without either, it goes to `SetText` as it is. Nothing converts it in Lua.

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

## Themes

A theme is a ready-made look for every event (titles, detail lines, art, animation, color, font, sound). In the
Profiles tab pick one and press **New from theme** (a fresh profile) or **Apply here** (click twice: replaces every
event look in the profile in use; which events are on is kept, apart from those the theme turns on).

The themes are homages to genres under PulseComic's own names, not borrowed game titles:

| Theme | Flavour | Font |
|:---|:---|:---|
| Classic | The defaults: comic hits, arena announcer, each art's own font | Match the art |
| Comic chaos | Random comic bursts for kills and streaks | Bangers |
| Roadfighter | Arcade fighting game: COMBO, K.O., SUPER COMBO, COUNTER, PERFECT, ROUND 1 FIGHT, GAME OVER / Insert coin | Russo One |
| Shadow Clan | Ninja action: SHADOW STRIKE, EXECUTED, OBLITERATED, SEVERED, SILENT DEATH | Shojumaru |
| Boomer Shooter | Old-school arena shooter: FRAGGED, GIBBED, DOUBLE KILL to LUDICROUS, RAMPAGE, OOF | Metal Mania |
| Strike Squad | Round-based tactical shooter: HEADSHOT, 2K to ACE, CLUTCH, BOMB PLANTED / DEFUSED, team wins, GO GO GO | Black Ops One |
| Soccer League | Football broadcast: GOAL, TOP BINS, HAT-TRICK, OFFSIDE, VAR CHECK, RED CARD, OWN GOAL, WHAT A SAVE, KICK-OFF, FULL TIME | Graduate |

A theme uses its art when the catalog has it and falls back to its title text when not; art added later is picked
up by applying the theme again.

## Art categories

| Folder | Shown as | Font |
|:---|:---|:---|
| `anime/` | Anime | Knewave |
| `comic/` | Comic | Bangers |
| `arcade/` | Roadfighter | Russo One |
| `ninja/` | Shadow Clan | Shojumaru |
| `arena/` | Boomer Shooter | Metal Mania |
| `escalation/` | Escalation | Black Ops One |
| `failure/` | Failure | Lilita One |
| `tactical/` | Strike Squad | Black Ops One |
| `football/` | Soccer League | Graduate |
| `falling/` | Falling | Bubblegum Sans |

Each event's **Font** can be *Match the art* (the default: the art's category font, so random art brings its own
lettering; text-only events use Black Ops One), one of the game's fonts, or any of the nine display fonts. A font
file the client cannot load leaves the text on the game font.

## Credits

Artwork was generated for PulseComic with OpenAI's Codex image generation (prompts in `Art/_metadata/manifest.json`).
The nine display fonts are by their designers and used unmodified under the SIL Open Font License 1.1; see
[`FONT-CREDITS.md`](FONT-CREDITS.md) for each copyright notice and source, and `Art/_fonts/<font>/OFL.txt` for the full
licenses, which must stay with the font files. In game: `/comic credits` or **Font credits** on the General tab.

## Adding art

1. Add the sequence to `Art/<category>/<message>_1..3.tga` (256x256, 32-bit with alpha) and to
   `Art/_metadata/manifest.json` (`assets` and `categories`).
2. Run `python3 scripts/make-art-catalog.py`. It checks every frame and font and regenerates `PulseComic/ArtCatalog.lua`
   and `PulseComic/FONT-CREDITS.md`; a message with a missing or unusable frame is left out and reported.
3. `/reload`. The new art shows up in every event's Art menu.

## Falls and fight flow

- **Falling**: more than 1.2 s in the air. **Hard landing**: more than 2.5 s in the air and you live (`{time}`).
  **Fell to death**: you die while falling or within a second of landing; it shows instead of YOU DIED. Read from
  `IsFalling()` (plain for your own character), polled 20 times a second only while a fall event is on; flying
  mounts and taxis do not count.
- **Fight start / Fight end** (off by default; the Roadfighter, Strike Squad and Soccer League themes turn them on), **MVP** and
  **Flawless**: a group fight with kills in which nobody in the group died.

## Kill detection

Two sources, each its own option; with both off, only POW! shows.

- **Killing-blow event (`PARTY_KILL`).** The client reports the attacker of each killing blow in your group. Only
  yours count, and your pet's if that option is on. Its payload is secret for units that are not player-controlled
  or in your group, so your own GUID should arrive plain; a secret attacker is not counted. The kill counts for a
  hit within 0.3 s either side of it, so target swaps no longer matter. A pet kill with no hit of yours still pops
  K.O.!, using the latest hit on your target for the crit flag and number.
- **Target death check (`UnitIsDead`).** The previous method: your target's death state about 0.15 s after your
  hit. It cannot tell whose blow it was, so a groupmate's kill shows K.O. too.

To check group and pet behaviour, turn on **Kill log in chat** (`/comic kill log`). Every reported killing blow
prints who landed it (you, your pet, a groupmate by name, a groupmate's pet, someone outside your group, or a
secret attacker), whether the victim was your target, and whether PulseComic counted it.

## Announcer

Arena-shooter banners across the top of the screen, plus a kill feed top right. Each
modality is its own option in the window's Announcer column; `/comic announce test` plays a demo.

| Banner | When |
|:---|:---|
| FIRST BLOOD | The first kill of a fight by anyone in your group, with killer and victim. Solo too if enabled. |
| DOUBLE KILL ... LUDICROUS KILL | Your kills (and your pet's) less than 4 s apart |
| KILLING SPREE, RAMPAGE, DOMINATING, UNSTOPPABLE, GODLIKE, WICKED SICK | 5, 10, 15, 20, 25, then every 5 kills without dying |
| MVP | A group fight ends: most killing blows (3+ kills in the fight, no tie) |
| YOU DIED, TEAMMATE DOWN, LAST ONE STANDING, WIPE | Deaths in your group |
| PET DOWN | Your pet dies |
| INTERRUPT! / INTERRUPTED | Your interrupt stops your target's cast / someone stops yours |
| BOSS DOWN / WIPE | An encounter ends |
| LEVEL UP | You gain a level |
| DODGED! PARRIED! BLOCKED! MISSED! | Attacks on you fail (off by default; frequent, for testing) |

Decisions use only plain facts: who landed a kill (your group's GUIDs), your own and your pet's casts, which event
fired and when. Secret values (enemy names, an interrupter) are drawn with `SetFormattedText`, never read. "You
interrupted your target" is matched by timing: your interrupt spell, then your target's
`UNIT_SPELLCAST_INTERRUPTED` within 0.5 s.

## Unconfirmed in the live client

Use `/comic debug` to settle these:

1. Setting the combat-text active unit to `"target"` delivers hits on your target, with a crit flag either in the
   message type or as the third value of the event info.
2. `UnitIsDead("target")` is correct about 0.15 s after the killing hit (`killDelay` in `PulseComicDB`).
   `PARTY_KILL` fires for your own and your pet's kills when solo, with a plain attacker GUID (`/comic kill log`).
6. `UNIT_DIED` fires for groupmates and your pet with a plain GUID; `UNIT_SPELLCAST_INTERRUPTED` on you carries
   `interruptedBy` only when someone interrupted you; `UnitTokenFromGUID` + `UnitName` give the victim's name while
   it still has a token (target, nameplate).
3. `SetAlphaFromBoolean(v, 1, 0)` takes alpha on a 0-1 scale. If frames look nearly invisible, the scale is 0-255.
4. The first event-info value is the hit's amount (as in Blizzard_CombatText), and `AbbreviateNumbers` formats a
   secret as documented (`SecretArguments = "AllowedWhenTainted"`).
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
