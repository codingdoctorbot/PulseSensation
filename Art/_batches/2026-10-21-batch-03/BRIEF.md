# Batch 03 — five new banners, pending review

## Authorization and scope

User explicitly approved this proposed batch: "okay sounds good generate go." Generate ONLY these FIVE new messages, THREE original animation frames each, then STOP for approval/rejection. Same ongoing generation subagent, GPT-6.1 Sol Medium, built-in imagegen. No extra subagents. No batch 04. No automatic copying into addon yet; the parent handles approved copying later. Existing batches and original orange alternatives remain intact.

Write only /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-03. Preserve all unrelated dirty work. Canonical repo is PulseSensation, not PulseSensation2; current addon Kapow (formerly PulseComic). Do not run main exporter, catalog builder, packaging or code changes.

## Required reading and recovery

- /home/deck/developer/PulseSensation/AGENTS.md and /home/deck/developer/_wow/DEVELOPMENT.md
- /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant prompting guidance
- Applicable /home/deck/.agents/skills/wow-forever-dev/SKILL.md asset conventions
- /home/deck/developer/PulseSensation/Kapow/Generation/generationpromptdatabase.md, Part 1 and P1 category design data (not its installation instructions)
- /home/deck/developer/PulseSensation/Art/_batches/workflow.json

After compaction read THIS brief, manifest.json and progress.json, then inventory source PNGs and exports. Save actual prompts, reference paths/roles and planned names BEFORE generation; save returned source paths immediately and update per-message state. Do not regenerate saved assets or duplicate in-flight calls. One call per message, at most three independent calls in parallel. No repeated polish/QA loops; report observed issues. One targeted repair only if an obvious blocking failure prevents a usable export; preserve its original and record why.

## Exact five messages and style

1. escalation/wicked-sick — WICKED SICK! — level 5 escalation, chunky ivory/blackened steel lettering, toxic GREEN sparks and restrained acid-green electrical energy, dark emerald fragments. Match escalation family but avoid repeating orange explosions. Two centered lines WICKED / SICK!.
2. arena/mvp — MVP! — heavy industrial arena lettering with ivory/gunmetal faces and black outline, prominent GOLD STAR behind instead of hot fissures, restrained gold glints/metal fragments. Stamp and shatter motion; not another fireball.
3. arcade/flawless — FLAWLESS! — cream/yellow aggressive slanted brush lettering, thick navy-black outline, CRIMSON and BLUE sweeping energy, 1990s arcade fighter slam/stamp. Different from arena industrial material. Compact angular side-striking silhouette, not a generic rock explosion.
4. failure/defeated — DEFEATED! — funny failure, deflated SKY BLUE cartoon lettering, thick dark outline, PURPLE smoke puffs and sagging/deflating effects, goofy anticlimax. Full readable word remains present and fixed in all frames. No characters/faces or trademark game phrases.
5. tactical/teammate-down — TEAMMATE DOWN! — ivory stencil letters on a dark NAVY clipped-corner gunmetal plate, RED warning strips/chevrons (restrained warm accents only). Two lines TEAMMATE / DOWN!. Same tactical HUD family as existing refs, not an orange fiery burst. Onset restrained red edge traces, peak red edge gleam, aftershock few red light flecks.

These palettes/styles were proposed to and approved by the user. Apply them in the ACTUAL generation prompts; references are typography/material/style guides, NOT permission to copy all their hues. Preserve category differences in shape and material as well as palette.

## Actual reference art to inspect and use

Use view_image to inspect relevant full PNG strips before each call. Pass one or two appropriate inspected paths in referenced_image_paths for EVERY imagegen call. Role: category typography/material/frame-structure references, not edit targets. New artwork must use exact new wording, never copy reference words or unintended colors.

WICKED SICK:
- /home/deck/developer/PulseSensation/Art/_sources/escalation/rampage.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-recolor-01/_sources/escalation/monster-kill.png

MVP:
- /home/deck/developer/PulseSensation/Art/_sources/arena/fragged.png
- /home/deck/developer/PulseSensation/Art/_sources/arena/gibbed.png

FLAWLESS:
- /home/deck/developer/PulseSensation/Art/_sources/arcade/perfect.png
- /home/deck/developer/PulseSensation/Art/_sources/arcade/super-combo.png

DEFEATED:
- /home/deck/developer/PulseSensation/Art/_sources/failure/whiff.png
- /home/deck/developer/PulseSensation/Art/_sources/failure/nope.png

TEAMMATE DOWN:
- /home/deck/developer/PulseSensation/Art/_sources/tactical/counter-terrorists-win.png
- /home/deck/developer/PulseSensation/Art/_sources/tactical/terrorists-win.png

## Generation layout

Built-in imagegen, transparent_background=true. One output horizontal strip of exactly THREE equal square cells in a 3:1 layout per message. Left onset, middle peak, right aftershock. Keep identical exact readable wordmark geometry, scale and center anchor across all three cells; intentional animation in surrounding effects. All three are generated art frames, no software-scaled/rotated/faded copies. Full opaque lettering, antialiased edges, bold shapes readable at 256x256. Keep entire sticker INCLUDING all effects in central 70% width/height of its own cell, broad transparent gutters, no overlaps or edge clipping/stray cross-cell particles. No grid, labels, frame numbers, backgrounds, painted checkerboard, extra words, logos or characters. Sparse effects and clear typography preferred over tiny details.

## Deliverables and naming

- _sources/<category>/<message>.png — untouched high-resolution transparent generated strip.
- <category>/<message>_1.tga, _2.tga, _3.tga — onset/peak/aftershock, uncompressed 256x256 32-bit RGBA TGA.
- _previews/review-sheet.png — five labeled rows, three frame columns (ONSET / PEAK / AFTERSHOCK), neutral review background. Optional GIFs/PNG frame previews.
- manifest.json — exact words, category/key, source/frame paths, actual prompts, real reference paths and role, frame order, generator mode, entry status=exported once exported, approval_status=pending, installed=false.
- progress.json — durable per-message generation/export status; final waiting_for_user_review.
- validation.json — one basic export check: 5 sources, 15 files, RGBA256, uncompressed type2 32-bit with genuine alpha, exact wording and visible layout/palette concerns. No repeated aesthetic review or live-client claims.

Adapt previous isolated exporter if helpful. Split proportional thirds, fit each WHOLE cell in 248x248 using premultiplied-alpha Lanczos, center on transparent 256x256. Do not recenter individual artwork and create anchor drift. Do not alter original PNGs or synthesize creative effects with code. No copying to Kapow/UnimplementedArt until approval.

## Finish

Report meaningful source/export milestones. Return review-sheet absolute path, manifest path, counts and visible concerns. Stop after these five pending user approval.
