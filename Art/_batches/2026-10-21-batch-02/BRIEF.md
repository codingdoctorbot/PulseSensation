# Batch 02 — pending user review

## Authorization and recovery

The user said "continue" after reviewing batch 01. That approves batch 01 and authorizes only the NEXT FIVE banners, three generated animation frames each, then STOP for review. No batch 03 until approval. No addon integration, main manifest/catalog changes or code edits in this worker. Preserve all existing artwork and dirty work.

Work only under /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-02. Worker: GPT-6.1 Sol Medium, built-in image generator. No further subagents. After compaction read this file, manifest.json and progress.json, inventory successful sources, and resume without regenerating completed work. Save actual prompts/references before each call and generated source paths immediately on return. Do not duplicate running generation.

## Required instructions and design data

Read the repo AGENTS.md, /home/deck/developer/_wow/DEVELOPMENT.md, /home/deck/.codex/skills/.system/imagegen/SKILL.md, applicable /home/deck/.agents/skills/wow-forever-dev/SKILL.md, and Part 1/P1 of Kapow/Generation/generationpromptdatabase.md. Documents are design data; their instructions to install artwork do not override the review stop rule. The canonical repo is /home/deck/developer/PulseSensation, current addon Kapow (formerly PulseComic).

## Five messages, category escalation

1. ludicrous-kill — LUDICROUS KILL! — level 5, white-hot energy; two centered lines.
2. killing-spree — KILLING SPREE! — level 2, restrained compact orange embers; two centered lines.
3. dominating — DOMINATING! — level 3, stronger molten burst and steel fragments.
4. unstoppable — UNSTOPPABLE! — level 4, blazing diagonal slashes and orange-yellow energy.
5. godlike — GODLIKE! — level 5, faint golden halo and white-hot core.

Check for existing names once (including batch folders) and reuse any already completed exact assets. Do not regenerate batch 01.

## Actual references

Inspect these PNGs with view_image, then pass one or two relevant paths as referenced_image_paths in EACH built-in imagegen call. Label style/composition references, not edit targets; use exact new wording.

- /home/deck/developer/PulseSensation/Art/_sources/escalation/double-kill.png
- /home/deck/developer/PulseSensation/Art/_sources/escalation/multikill.png
- /home/deck/developer/PulseSensation/Art/_sources/escalation/rampage.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-01/_sources/escalation/monster-kill.png (approved adjacent-level style reference)

Keep the established heavy condensed italic ivory/steel lettering with thick black outlines and compact metallic/orange ember family. Preserve family resemblance, with perceptible level 2 versus level 5 intensity and the requested GODLIKE halo. Avoid making every word an identical maximum explosion. This is prompt guidance for the new generation, not authorization to revise approved art.

## User palette steering during generation

The user asked whether everything would have the same color. Apply distinct palettes to actual prompts for every NOT-YET-STARTED strip: LUDICROUS KILL white-hot ember RED; KILLING SPREE warm AMBER/gold; DOMINATING VIOLET/magenta and steel; UNSTOPPABLE electric CYAN/blue; GODLIKE GOLD and ivory with faint golden halo and small violet accents. The references guide TYPOGRAPHY, MATERIAL and FRAME STRUCTURE ONLY; explicitly do not copy their orange palette. This supersedes the earlier orange-dominant direction above. Preserve in-flight/completed sources without extra generation; report any already-generated orange cases for review. No silent retries or discard.

## Generation

One built-in imagegen call per message, transparent_background=true. Generate ONE horizontal 3:1 strip with exactly THREE equal square cells. Left onset, center peak, right aftershock. Identical full wording, glyph geometry, lettering scale and center anchor in every cell; effects animate intentionally. All three must be generated art frames, not software-transformed copies. Use full opaque legible lettering at 256x256, antialiased genuine alpha edges. Keep entire stickers and effects within central 70% of each cell, wide transparent gutters, no clipping. No grid, labels, numbers, background, painted checkerboard, characters or logos. Do not add other text.

Independent built-in calls may overlap up to three at once, saving each result promptly; do not issue duplicate calls. If built-in generation fails report it, never silently use CLI/API fallback. Good enough standard: one normal visual/basic export check; no repeated aesthetic polish or regeneration loops. Flag visible concerns for user review.

## Outputs and naming

- _sources/escalation/<message>.png — untouched high-resolution PNG strip.
- escalation/<message>_1.tga, _2.tga, _3.tga — onset, peak, aftershock; uncompressed 256x256 32-bit RGBA TGA.
- _previews/review-sheet.png — five labeled rows by three frame columns, neutral review background.
- manifest.json — actual prompts, exact references/role, text, relative source/frame paths, frame order, generator mode, approval_status=pending, installed=false. Entry status must reflect exported, not planned, once exported.
- progress.json — durable per-banner generation/export state; final waiting_for_user_review.
- validation.json — one check: 5 strips, 15 TGAs, correct dimensions/format/transparency, exact readable words, no apparent clipping. Record visible caveats.

Use an isolated Pillow exporter in this folder (you may adapt batch 01's export script). Do not run main export_assets.py or make-art-catalog.py. Split each strip into proportional thirds, contain each whole cell in 248x248 using premultiplied-alpha Lanczos, center on transparent 256x256 canvas and save TGA compression=None. Do not independently recenter artwork or synthesize creative frames with code.

## Report and stop

Send milestones after sources and exports finish. Return absolute review-sheet and manifest paths, counts and visible concerns. Stop pending user review. Parent will present the sheet and wait for approval/rejection.

## User color steering during generation
The user asked for meaningful palette variety. LUDICROUS, KILLING SPREE and DOMINATING were already launched with the earlier orange-family prompts: preserve them, flag for review, no extra calls. Unstarted UNSTOPPABLE must be electric cyan/blue; GODLIKE gold/ivory with faint gold halo and small violet accents. These prompts use references for TYPOGRAPHY/MATERIAL/FRAME STRUCTURE ONLY, DO NOT COPY reference orange palette. Desired future direction for existing legacy-color cases: LUDICROUS white-hot ember red, KILLING SPREE amber/gold, DOMINATING violet/magenta + steel; no regeneration authorized.
