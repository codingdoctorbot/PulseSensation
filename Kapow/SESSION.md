# KAPOW! session notes

Handoff for whoever works on KAPOW! next (human or agent). Last updated 2026-10-19, after one long Claude Code
session that took the addon from PulseComic 0.1.0 (pull request #1) to KAPOW! 0.2.0-alpha. Artwork and fonts were
produced in parallel by ChatGPT Codex. See `CHANGELOG.md` for what changed and `README.md` for how it works.

## State

- **Offline**: luacheck clean; `wowdev check PulseSensation --lint --tests` passes all 14 suites, including
  `kapow-test` (261 checks: secret gating, kill sources, announcer, falls, fight flow, themes, fonts, profiles,
  export / import including hostile input, migrations). A separate UI smoke run built all three tabs, drove every
  dropdown (384 menu entries), button and edit box.
- **In game**: never run yet. The game's `Interface/AddOns/Kapow` links to this folder; restart the client (or go to
  character select) the first time so it is discovered.
- **Game links**: Kapow, PulseHaptics, PulseDebug, PulseChecklist and PulseProfileReview all point at
  `WoW/PulseSensation`. `PulseSensation2` is the earlier working copy and is no longer linked.

## Layout

| Path | What |
|:---|:---|
| `Kapow.lua` | Core: hit frames and their secret alpha gates, kill detection, settings API, slash commands |
| `Events.lua` | Every event, its defaults, text templates (`ComposeText`) |
| `Display.lua` | Drawing: stages, animation presets, flipbook, fonts, colors, positions, sounds |
| `Art.lua`, `ArtCatalog.lua` | Art catalog (`ArtCatalog.lua` is generated; do not edit) |
| `Themes.lua` | Theme presets |
| `Profiles.lua` | Saved variables, profiles, export / import |
| `Announcer.lua` | Banner queue, kill feed, kills, deaths, interrupts, falls, fight flow |
| `Meter.lua` | Hit-meter prototype |
| `UI/` | Settings window (General, Events, Profiles), rows, theme, minimap button |
| `Art/` | Copy of the frames and fonts the addon loads (master copy: `../Art`) |

## Rules this code follows

- **Secret values are drawn, never read.** Crit and death flags go to `SetAlphaFromBoolean` gates; amounts and enemy
  names go to `SetText` / `SetFormattedText` or the client's number formatters. Check `issecretvalue` before any
  comparison, even with `nil` (`Plain()` / `Present()`). The test's source scan fails on a branch or comparison against
  a possibly-secret name; copy a value into a plain-named local only after it has been checked.
- **Decisions use plain facts only**: your group's GUIDs (`PARTY_KILL` attacker), your own and your pet's casts, which
  event fired and when. "You interrupted your target" is timing (your interrupt spell, then the target's interrupt
  event within 0.5 s), not the target's payload.
- **No `ShowUIPanel`**: the window shows with a plain `Show` plus `UISpecialFrames`.
- **Art is copied, not linked or compressed.** Add art to `../Art` and its manifest, then run
  `python3 scripts/make-art-catalog.py`.
- **Names are the addon's own.** Folder ids are plain (`tactical`, not a game title); labels are Roadfighter,
  Shadow Clan, Boomer Shooter, Strike Squad, Soccer League.

## Verify first in game

1. `/kapow` → General → **Crit** test button. Invisible frame means `SetAlphaFromBoolean` takes 0-255, not 0-1
   (`Gate()` in `Kapow.lua`).
2. A display font in Events → Font. Blank or game-font text means the TTF did not load (`SetFonts()` falls back).
3. **Kill log in chat** while killing solo and with a pet: does `PARTY_KILL` fire, with a plain attacker GUID?
4. In a group: TEAMMATE DOWN (`UNIT_DIED` with plain GUIDs), FIRST BLOOD, MVP, Flawless.
5. Get interrupted by a mob: INTERRUPTED needs `interruptedBy`; if it never shows, Forever does not fill it.
6. Jump off something tall: Falling, Hard landing, Fell to death (`IsFalling()`).
7. Profiles → **Export this**, paste the string into **Import**: long strings in the edit box.

## Open ideas

- Revenge / payback (PvP), comeback after a resurrect, honorable kill, crit heal, shutdown of an enemy on a streak.
- Per-event position by dragging, hold time per event, a gamepad-navigable window.
- Codex's art automation `complete-full-pulsecomic-message-pack` may still be scheduled in the Codex app; pause it
  if no more art is wanted.
