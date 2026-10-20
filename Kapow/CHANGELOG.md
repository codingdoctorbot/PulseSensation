# KAPOW! changelog

## Unreleased

Not yet tested in the live client.

### Added
- **Pet kill backup** (off by default, General tab): estimates a pet kill from your target's death when the
  killing-blow event is missing. Also feeds the Announcer and kill feed.
- **Experimental tab** with **hit sounds**: Critical hit, Killing blow and Critical killing blow sounds moved here. They
  play only when the game says plainly what kind of hit it was, and then only the matching one. "Also when the game
  hides the hit type" restores the old behaviour (every hit event's sound on every hit).

- **More kill sources** (General tab, each optional): the game's **target death event** (PLAYER_TARGET_DIED: exact
  timing, still right after a target switch) and the **combat log colour** (Blizzard paints your own killing blow
  white; KAPOW reads only the colour, never the text, so it knows the kill was yours even when the game hides who
  died). From MikScrollingBattleText's Forever build and Blizzard's own combat audio alerts.
- **Accurate** hit attribution (General tab, "Hits that count"): each hit on your target is matched to your weapon
  swings, casts (by damage type), damage-over-time ticks, pet and combat-log lines. Condensed from
  MikScrollingBattleText's Forever engine.
- Experimental tab:
  - **Overkill numbers on OVERKILL!** from Blizzard's damage meter (`{overkill}` token too). Clears the damage meter
    window while on, as MidnightBattleText does.
  - **Interrupts confirmed by the damage meter**, on any enemy, and **interrupt streaks grow**: each interrupt in a row
    pops bigger, up to double size (`{count}` token).
  - **Combat text unit**: "Leave it alone" never switches the shared combat-text unit (the PulseHaptics / MidnightFCT
    conflict); hits then come from your target's own combat events. Default unchanged.
  - **Kill statistic**: a server kill counter going up confirms your kill (WarCult's method). `/kapow stats` lists them.

- **Animation settings:** a per-event **Duration** (0.5x–3x, the art's flipbook stretches with it); adjustable random
  **offset** (sideways, up/down) and **tilt** for the hit pops, optionally **also on banners**; **several banners at
  once** (up to three, stacked) instead of one after another.
- **Sound pools:** six more of the game's own sounds and three **random pools** (fight start, victory, alert); Fight
  start and Fight end default to them, and the Roadfighter, Strike Squad and Soccer League themes use them.
  Generated sounds drop into `Kapow/Sounds/<pool>/` and `scripts/make-sound-catalog.py` adds them.
- `Kapow/Generation/generationpromptdatabase.md`: prompts for the missing banners (P1 events with text only, P2 a
  Street Fighter-style Roadfighter set, P3 category gaps) and for high-fidelity announcer and effect sounds.

- **Multi-kill timer bar** (General tab, Announcer; idea from MegaKill Announcer): after each kill of yours a thin bar
  drains over the 4 s you have to chain the next one, with the chain so far.
- **UwU mode** (Experimental tab; idea from Forever UwU): a cute word floats up over your character on crits, gated by
  the crit flag like the comic frames (secret crits included); its optional sound plays only on plain crits.

- **Extras tab** (all off by default; nothing changes until switched on):
  - **Combo counter**: a fighting-game "12 HITS" counter while your hits on one target keep coming; a **Combo**
    banner when the chain ends at the minimum or more. Counts hits, never amounts.
  - **Impact flash** on crit kills, every kill or every crit, behind the same hidden crit/death gates as the comic
    frames.
  - **Low health warning** and **FINISH IT!** (execute range on your target): health stays hidden; the client's
    curve helper (`UnitHealthPercent` with a step curve) turns it into the overlay's opacity, so both work in combat.
  - **Reduce motion**: no slam, bounce, shake, offset, tilt, flash or pulsing; shorter shows.
  - **Controller navigation** for this window.
  - **Placing**: `/kapow unlock` shows drag handles for the hit pops, banners, timer bar, UwU, combo counter and
    FINISH IT!; banner and other spots are saved per profile.
  - **Personal records** per character (best multi-kill, spree, combo; kills, multi-kills, duels) and a **New
    personal record** banner, once per run. `/kapow records`.
  - **Party sync**: groupmates running KAPOW see your multi-kills, sprees, first blood, combos, records and duel wins
    in their kill feed. Only an event id and a count are sent.
- New event groups (all off): **Arcade** (Combo, Countdown 3-2-1 and FIGHT! for arena/battleground gates and pull
  timers, duel ROUND 1 ... FIGHT!, YOU WIN, YOU LOSE, boss pull) and **Moments** (Assist, New personal record,
  Achievement, Epic loot, Quest complete, Honorable kill).

### Fixed
- A sound picked for a hit event played on every hit, up to three at once (sound cannot follow the secret alpha gates).
- Import kept out-of-range settings from a pasted string (a zero scale errors on every pop; an endless kill delay stops
  kills resolving). Scale, position, timing and the text choices are now clamped to the window's ranges.
- Pet kill backup: a crit no longer disappears when you change target right after it; it also works when the
  target's GUID is hidden, and a killing-blow report with a hidden victim is no longer counted twice.

## 0.2.0-alpha — 2026-10-19

The addon formerly called PulseComic, renamed and grown from three comic frames into a configurable popup engine.
Not yet tested in the live client.

### Renamed
- PulseComic is now **KAPOW!**: folder, TOC and main file `Kapow`, saved variables `KapowDB` / `KapowCharDB`, slash
  command `/kapow` (`/comic` still works), export prefix `KAPOW1:` (old `PCOMIC1:` exports still import).

### Added
- **Events**: every moment is an event with its own look. Hits (crit, kill, crit kill), first blood, multi-kills
  (double to ludicrous), sprees (5 to 30+), fight start / end, MVP, flawless, deaths (you, teammate, last one standing,
  wipe, pet), interrupts (yours on your target, someone's on you), boss down / encounter wipe, level up, falls
  (falling, hard landing, fell to death) and dodges / parries for testing.
- **Per-event look**: art (any sequence, random from a category, or none), animation (flipbook, slam, bounce, rise,
  shake, still), title and detail-line templates with tokens (`{killer}` `{victim}` `{count}` `{amount}` `{name}`
  `{level}` `{total}` `{time}`), color, font, size, position, sound, preview and reset.
- **Art**: 47 three-frame sequences in ten categories (Anime, Comic, Roadfighter, Shadow Clan, Boomer Shooter,
  Escalation, Failure, Strike Squad, Soccer League, Falling), shipped inside the addon folder.
- **Fonts**: nine display fonts (SIL Open Font License 1.1) plus the game's fonts; *Match the art* uses each art
  category's font. Credits in `FONT-CREDITS.md` and `/kapow credits`.
- **Themes**: Classic, Comic chaos, Roadfighter, Shadow Clan, Boomer Shooter, Strike Squad, Soccer League.
- **Profiles**: account-wide list, per-character choice or account default, new / copy / rename / delete / reset,
  export and import as text (parsed without running code; only known settings of the right type are kept).
- **Kill detection**: killing-blow event (`PARTY_KILL`) and/or the target death check (`UnitIsDead`), pet kills, and a
  chat kill log to check group and pet behaviour.
- **Kill feed** top right, **announcer** queue, **settings window** (General, Events, Profiles tabs) and a
  **minimap button**.
- `scripts/make-art-catalog.py`: checks every frame and font, regenerates `ArtCatalog.lua` and `FONT-CREDITS.md`,
  and copies what the addon loads from the repository's `Art/` folder into `Kapow/Art`.

### Fixed (since the 0.1.0 review)
- The damage amount is read from the first combat-text value, as Blizzard's own code does.
- Secret amounts go straight to the client's number formatters and `SetText`; no Lua-side conversion.
- Heals, misses and dodges on your target no longer pop a crit frame (`UNIT_COMBAT` counts only `WOUND`).
- `/kapow off` is honoured by the delayed kill check.
- The width probe was removed.

## 0.1.0-alpha — 2026-10-19

First version, as PulseComic (pull request #1): POW! on a crit, K.O.! on a killing blow, OVERKILL! when a crit kills,
drawn through two nested alpha gates so secret booleans are never read; damage number inside each burst; the hit-meter
prototype (`/comic meter`).
