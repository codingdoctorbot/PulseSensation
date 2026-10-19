# PulseComic Expansion Pack

28 distinct messages, three base animation frames per message: **84 transparent TGA textures**. Created with the built-in image_gen tool on 19 October 2026.

| Folder / category | Messages |
| --- | --- |
| `anime` | CRITICAL!, LIMIT BREAK!, ANNIHILATED! |
| `comic` | KRAKOOM!, WHAM!, SPLAT!, BOOM!, ZAP!, SMASH!, CRASH! |
| `arcade` | COUNTER!, PERFECT!, SUPER COMBO! |
| `ninja` | OBLITERATED!, SHADOW STRIKE!, EXECUTED! |
| `arena` | FRAGGED!, GIBBED!, plus the shared RAMPAGE! set |
| `escalation` | DOUBLE KILL!, MULTIKILL!, RAMPAGE! |
| `failure` | WHIFF!, NOPE!, BONK!, BOING! |
| `originals` | POW!, OVERKILL!, K.O.! |

RAMPAGE! lives only at `escalation/rampage_01.tga` through `_03.tga`. Arena and escalation both refer to these same files. SPLAT! also has one set. Categories have 29 memberships but 28 unique messages; no duplicate generation was performed for category reuse.

## Files and format

- `STYLE/message_01.tga`, `_02.tga`, `_03.tga`: 84 individual textures, each 256x256, uncompressed true-color TGA, 32-bit RGBA, 8-bit alpha, at least four pixels of transparent padding on every edge.
- `sources/`: 28 high-resolution transparent PNG strips. Each strip contains three cells, read left to right. One source has a few pixels of generator rounding; export splits proportional thirds and fits each cell without stretching.
- `previews/`: 84 transparent frame PNGs, 28 looping GIFs, and eight category review sheets showing every frame in order. GIFs and review sheets use a solid review background; source PNGs and TGAs preserve true alpha.
- `preview-sheet.png`: all 28 unique messages at peak impact, shown at the actual 256x256 export size.
- `manifest.json`: exact actual generation prompts, source paths, all frame filenames, suggested timing, category memberships, and cross-category reuse.
- `validation.json`: format, alpha, transparent borders, source boundary clipping and exact decode checks for all 84 textures.
- `audit/`: original inventory and manifest, original texture/source hashes, addition receipts with actual prompts, rejected WHAM source and reason, and final verification.
- `export_assets.py`: repeatable mechanical splitting, downscaling, TGA conversion and preview assembly. Requires Pillow. Run `python3 export_assets.py` from any directory. It verifies existing textures instead of replacing them when pixels match.

The `originals/` remakes add nine frames for the three original messages, preserving their recognizable palettes: POW! white/black with yellow-orange; OVERKILL! yellow/black with red/yellow; K.O.! white/black with blue. Original TGA references were converted without alteration into `references/original-*.png` for the image generator. Their new source strips are `sources/originals--*.png`; animated reviews are `previews/originals--*.gif`, and `previews/review-originals.png` shows all nine frames. All previous 75 TGA frames and the three original `Media/*.tga` files remain byte-identical.

## Animation

Suggested sequence: `_01` onset (80 ms), `_02` peak (120 ms), `_03` aftershock (180 ms), followed by a fade. These are starting timings. `_02` also works as a static popup with scale and fade.

Each message uses one canvas and center anchor. New prompts explicitly request unchanged lettering with controlled motion in surrounding effects: rings expand, slime stretches, smoke separates, glass and plates fracture, glints travel, blades slash, and the spring recoils. Small hand-drawn differences in lettering remain between some poses, especially the initial set. These are animation bases, not separate pixel-locked text/effect layers; use the GIFs and category sheets to choose flipbook or crossfade treatment.

The first 11 messages and their 33 TGAs and 11 source strips were preserved byte-for-byte. Their original prompts remain unchanged. Fourteen missing messages were generated after deduplicating text case-insensitively while ignoring punctuation and whitespace. The original all-fiery silhouette was deliberately avoided in new work: the comic additions use flat ink, smoke clouds, lightning, slime, stone slabs and glass; anime uses energy rings and manga shards; arcade uses gleam and sideways speed bands; ninja uses open ink rings and diagonal cuts; arena uses riveted steel; BOING! uses a cartoon spring.

One new WHAM! strip initially had yellow wedge tips crossing cell boundaries. It was corrected before TGA export; the rejected PNG and its original prompt remain in `audit/rejected/`. The other satisfactory assets were reused.

## Integration

This is an artwork-only pack. No addon Lua, TOC, triggers or original textures outside this pack were changed. Escalation and failure labels still need suitable event detection if the addon does not already support it. In-game appearance and timing have not been tested.

Example texture path (omit `.tga` in `SetTexture`):

```lua
texture:SetTexture("Interface\\AddOns\\PulseComic\\Media\\ExpansionPack\\anime\\limit-break_02")
```

## Visual references

The supplied local comic sheet, `/Users/erik2/Downloads/360_F_1990632694_5z0ho42MssULYGsEABfxzCFVB08Pd0tE.jpg`, was inspected and supplied as visual inspiration for seven new comic/cartoon assets. It informed bold flat lettering, heavy outlines, halftone and varied silhouettes; the generated artwork uses original compositions.

Research and user-provided directions also referenced the [Dragon Ball FighterZ media gallery](https://en.bandainamcoent.eu/dragon-ball/dragon-ball-fighterz/media), [Team Ninja's Ninja Gaiden 2 Black site](https://teamninja-studio.com/ng2black/uk/), [PlayStation's Ninja Gaiden 2 Black page](https://www.playstation.com/en-us/games/ninja-gaiden-2-black/), [Quake III Arena](https://store.steampowered.com/app/2200/Quake_III_Arena/), [Cuphead](https://cupheadgame.com/), and the [Devil May Cry style-rank overview](https://www.shacknews.com/article/110322/stylish-points-and-style-ranks-in-devil-may-cry-5). These informed broad visual directions; no game logos, characters or screenshots were embedded in the output. The two supplied direct dramatic-finish/Third Strike image URLs could not be fetched and were not used as image inputs. The arcade direction follows the user's stated brief.
