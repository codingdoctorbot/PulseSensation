# PulseSensation Art

47 messages, each with three transparent 256x256 RGBA TGA frames: 141 textures.

- Theme folders: anime/, comic/, arcade/, ninja/, arena/, escalation/, failure/, tactical/, football/, falling/.
- Filenames: <message>_1.tga (onset), _2.tga (peak), _3.tga (aftershock).
- POW!, OVERKILL!, and K.O.! are in comic/.
- RAMPAGE! has one sequence in escalation/, also usable for arena.
- _sources/<theme>/: high-resolution transparent PNG strips.
- _sources/_references/comic/: PNG copies of the three original reference textures.
- _previews/<theme>/: transparent frame PNGs, animated GIFs, and sequence sheets.
- _previews/all-messages.png: complete overview.
- _metadata/manifest.json: actual imagegen prompts, sources, frame order and category reuse.
- _metadata/validation.json: existing export checks.
- _metadata/rename-map.json: old-to-new filenames.
- _metadata/audit/: historical creation records; paths inside historical snapshots refer to their original layout.
- _metadata/export_assets.py: export helper adjusted for this layout; requires Pillow.

Suggested timing: frame 1 for 80 ms, frame 2 for 120 ms, frame 3 for 180 ms, followed by fade. Minor alignment polish is deferred.

The collection was moved from PulseComic/Media/ExpansionPack. Original Media/pow.tga, overkill.tga, ko.tga and addon code were left untouched. This is the artwork delivery folder; no triggers or runtime paths were added.

Strike Squad (tactical/) additions: COUNTER-TERRORISTS WIN!, TERRORISTS WIN!, BOMB PLANTED!, BOMB DEFUSED!, HEADSHOT!, CLUTCH!, ACE!. Each uses three tactical HUD frames, with sources and previews in the matching tactical subfolders. All 84 earlier frames are preserved. Actual built-in imagegen prompts are in _metadata/manifest.json.

Football: GOAL!, HAT-TRICK!, TOP BINS!, WHAT A SAVE!, OFFSIDE!, RED CARD!, OWN GOAL!, VAR CHECK!. Sources and previews are grouped under football. All earlier artwork is preserved.

Falling: WHEEE!, FACEPLANT!, TIMBER!, GRAVITY WINS!, plus shared SPLAT! from comic/splat_1.tga through _3.tga. SPLAT is registered in both categories, with no duplicate TGA files or generation.

Fonts: _fonts/ contains nine unmodified static OFL 1.1 TTFs for all ten themes, with full licenses, source provenance and category-fonts.json. Keep OFL.txt with each distributed font. One specimen is in _previews/fonts/specimen.png.
