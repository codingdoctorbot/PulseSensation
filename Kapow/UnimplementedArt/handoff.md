# KAPOW artwork handoff

Snapshot: 22 October 2026. Repository: `/home/deck/developer/wow/PulseSensation`. Addon: **Kapow / KAPOW!**, formerly PulseComic. This is an artwork handoff, not a claim of completed addon integration or in-game verification.

## Current status

- Batches 01–14 and the five recolors are approved and copied here: **69 message keys, 74 three-frame sequences, 222 TGA files**. The five extra sequences are the preserved original orange alternatives.
- Final batch 14 is complete and explicitly approved: **CONTINUE?, GAME OVER, GUARD BREAK, BLOCKED!, LEVEL UP!** Three frames each, 15 TGA files. The user said "approve the last generated images"; these are included in the counts above. No review or generation work remains in this artwork task.
- The earlier master pack remains separate: **47 generated message keys / 141 frames** under the root `Art/`, plus the old single-frame `Kapow/Media` originals. Do not add the numbers in this staging folder to the active catalog count without integrating the assets.
- No Lua, TOC, active art catalog, event detection, profile logic or game links were changed by this artwork work. Other agents' extensive dirty work in this repository is unrelated and must be preserved.

## Asset inventory and locations

| Location | Purpose |
| --- | --- |
| [inventory.json](/home/deck/developer/wow/PulseSensation/Kapow/UnimplementedArt/inventory.json) | Authoritative list of copied staging assets, category keys, frame order, dimensions, source manifests and SHA-256 hashes |
| This folder's `<category>/` directories | Selected new TGA sequences, ready for future integration |
| `original-orange/escalation/` | Five original orange alternatives: first-blood, ultra-kill, monster-kill, ludicrous-kill, dominating; logical filenames remain unchanged within this variant folder |
| [Batch workflow](/home/deck/developer/wow/PulseSensation/Art/_batches/workflow.json) | Generation, review and copying state across all batches |
| [Bulk review index](/home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-22-bulk-remaining/review-index.md) | Seven complete animation sheets for batches 07–13 and accepted design caveats |
| [Bulk prompts and provenance](/home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-22-bulk-remaining/manifest.json) | All 33 messages from the bulk completion run, with links to their batch manifests |
| [Final batch brief](/home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-22-batch-14/BRIEF.md) | Exact final-five request and generation stop rule |
| [Final batch manifest](/home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-22-batch-14/manifest.json) | Final-five prompts, sources and approved export metadata |
| [Final animation sheet](/home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-22-batch-14/_previews/review-sheet.png) | Onset, peak and aftershock of the last five |
| [Master manifest](/home/deck/developer/wow/PulseSensation/Art/_metadata/manifest.json) | Existing 47-message source catalog; new staging assets have not been merged into it |
| [Implementation plan](/home/deck/developer/wow/PulseSensation/Kapow/UnimplementedArt/implementation.md) | Proposed integration steps, event/theme mapping, VS concept and deferred brainstorming |

Names are `<category>/<message>_1.tga`, `_2.tga`, `_3.tga`, meaning **onset / peak / aftershock**. Files are uncompressed true-color TGA, 32-bit RGBA with alpha. Normal frames are 256×256; `arcade/versus_1.tga` through `_3.tga` are **512×512**, exported from native 724×724 source cells. The visible word is **VS**, while the logical filename is `versus`.

The original orange versions of TRIPLE KILL, MEGA KILL and KILLING SPREE already remain in the selected escalation directory; they were not redundantly duplicated in the variant directory. Both recolor generations of DOMINATING also remain in the source batch, even though only the selected version is copied here.

Category/name is the identity. `arcade/excellent` and `arena/excellent` are deliberate different styles; `comic/ko` and `arcade/ko` are different versions. RAMPAGE is shared between escalation and arena, and SPLAT between comic and falling in the original pack; do not regenerate or duplicate those shared sequences.

## Source provenance and preservation

All artwork used the built-in image generator with inspected category reference PNGs passed to the actual calls. The generation subagent used GPT-6.1 Sol Medium for prompting/export orchestration. Each batch retains its actual prompts and reference roles in `manifest.json`, high-resolution transparent strips in `_sources/<category>/`, exports in `<category>/`, previews, progress and validation.

- Batches 01–06 and recolor-01: `Art/_batches/2026-10-21-*`.
- Batches 07–14: `Art/_batches/2026-10-22-batch-*`.
- Recolor sources: `Art/_batches/2026-10-21-recolor-01/`. The original orange source strips remain in their original batches.
- Reference PNGs and initial sources: `Art/_sources/`.
- `Art/_batches/package_review_batch.py` copies a reviewed batch to this staging folder and updates inventory; it does **not** register art in the active addon. Its approval fields should be used only after actual user approval.

Keep the PNGs, original versions and prompt metadata. No new generation is required to integrate approved art. Do not discard the orange versions as obsolete or silently regenerate assets because prompts have evolved.

## Fonts

Nine real static TTF families already cover all ten categories. The exact paths, pinned upstream sources, hashes and accompanying licenses are in [the font pack](/home/deck/developer/wow/PulseSensation/Art/_fonts/README.md) and [category-fonts.json](/home/deck/developer/wow/PulseSensation/Art/_fonts/category-fonts.json).

| Category | Font |
| --- | --- |
| anime | Knewave |
| comic | Bangers |
| arcade | Russo One |
| ninja | Shojumaru |
| arena | Metal Mania |
| escalation, tactical | Black Ops One, shared binary |
| failure | Lilita One |
| football | Graduate |
| falling | Bubblegum Sans |

The pack includes each font's full OFL.txt; keep the corresponding notice with distributed binaries. Sources are unmodified and internal names retained. No OS font installation is needed. `Kapow/Art/_fonts/` already contains runtime copies; compare dirty files before running any tool that recopies them. Font metadata does not make the raster lettering dynamically editable.

## Work remaining

1. Confirm the inventory and choose selected variants for promotion into the active catalog; all current art is approved and copying is complete.
2. Import selected approved staging assets into the master catalog workflow, then the runtime catalog and art menus.
3. Choose appropriate event/theme defaults, avoiding duplicate baked lettering plus overlaid title text. Preserve customized profiles.
4. Decide how three-frame playback combines with slam/bounce/rise. Existing `slam` shows only the peak frame; it does not currently play all three.
5. Implement the separate VS portrait composition and settings if desired. Only the VS texture exists today.
6. Validate rendering, font loading, event delivery and secret-value handling in the real Forever client. Offline artwork checks are not live-client proof.

The detailed order and source entry points are in `implementation.md`. These notes are a plan for a later implementation task, not authorization to rewrite the addon during this artwork session.

## Known limitations and verification

- Each generation batch received one normal visual/export check. TGA size, uncompressed type-2 encoding, 32-bit color/alpha and actual transparency passed. Copied files were checked against source hashes.
- Some peak effects extend beyond the requested central 70% safe area. Small generated glyph/anchor differences can remain; no pixel-identical frame-geometry claim is made.
- Minor teal edge slivers remain in the DOMINATING recolor after one targeted cleanup. ROUND 1 ... FIGHT!, FINISH IT! and final GAME OVER can have small red margin flecks. ASSASSINATED has relatively small lettering at 256×256. The user accepted the art, including the final five; do not start a polish loop without a new request.
- Some optional prompt motifs became more burst-like than planned. The bulk review index documents these deviations. They are not missing files.
- The VS peak alpha reaches 254 rather than 255; generated alpha was retained. It is not a painted background. Overall VS opacity is a future runtime control.
- No game-client testing, trigger implementation, new custom audio generation or release packaging occurred in this art session. Existing built-in sounds and other code work must be assessed separately.
- `Kapow/Generation/generationpromptdatabase.md` still reads as an older missing-art list. Batches/inventory are authoritative for completed artwork; do not blindly regenerate its rows.

## User decisions and stop rule

- The original missing-banner list is complete; VS was an explicit additional 512×512 sequence.
- The user requested preserving original orange alternatives, varied palettes, actual references, three art frames per message, and a good-enough standard with minimal repeated QA.
- The user authorized the final five above and then explicitly requested wrapping up. **No further countdown or theme-phrase art generation is authorized.**
- Brainstorming in `implementation.md` is optional future work. It must not become an automatic generation backlog or recurring automation.
- The older art-completion automation was paused earlier; leave it paused. Do not resume automated generation as part of integration.
- Preserve current dirty files. Recheck repository identity and live source before implementation; do not work in PulseSensation2 or retired ControllerApex.
