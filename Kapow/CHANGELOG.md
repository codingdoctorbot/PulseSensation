# KAPOW! changelog

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
