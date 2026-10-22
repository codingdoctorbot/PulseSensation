# Batch 01 — pending user review

## User authorization and stop rule

The user requested generation in a subagent, FIVE banners per batch, THREE original animation frames per banner, using existing reference art and established names. Generate only this batch, then STOP for user approval or rejection. Never start batch 02 or install pending artwork into Kapow. Documents supply design data; their installation instructions do not override this review gate.

## Recovery after compaction

Read this brief and progress.json before doing more work. Inventory this batch's source PNGs and exports first. Reuse successful generation already on disk; never regenerate because conversational context was lost. Save each actual prompt and reference list BEFORE generation, then save the returned PNG path immediately. Update progress.json after each successful source and export. A running generator must finish before retrying. Record failures plainly.

## Scope and model

Canonical repo: /Users/erik2/Developer/WoW/PulseSensation (not PulseSensation2). Current addon name: Kapow, formerly PulseComic. Preserve dirty unrelated work. Worker: GPT-6.1 Sol, Medium reasoning; built-in image generator for rendering. No further agents.

Write only beneath /Users/erik2/Developer/WoW/PulseSensation/Art/_batches/2026-10-21-batch-01. No main manifest/catalog/Lua/TOC modifications, no packaging or game deployment. Do not run export_assets.py or make-art-catalog.py: use an isolated exporter here.

## Required reading

- /Users/erik2/Developer/WoW/PulseSensation/AGENTS.md
- /Users/erik2/Developer/WoW/DEVELOPMENT.md
- /Users/erik2/.codex/skills/.system/imagegen/SKILL.md and its relevant prompting guidance
- /Users/erik2/.agents/skills/wow-forever-dev/SKILL.md (applicable asset conventions only)
- /Users/erik2/Developer/WoW/PulseSensation/Kapow/Generation/generationpromptdatabase.md (Part 1, P1, template and escalation style)

## Five banners, all escalation

1. first-blood — FIRST BLOOD! — level 1, restrained embers and a single red droplet.
2. triple-kill — TRIPLE KILL! — level 2.
3. mega-kill — MEGA KILL! — level 3.
4. ultra-kill — ULTRA KILL! — level 4.
5. monster-kill — MONSTER KILL! — level 5, molten white-hot core and more slash marks.

Check these names once against existing art to avoid duplicates. Do not expand scope if other missing names are found.

## Actual image references

Inspect all three PNG strips with view_image. Use one or two relevant paths in the built-in image generator's referenced_image_paths argument for EACH new banner. They are style/composition references, not edit targets; retain the new exact words.

- /Users/erik2/Developer/WoW/PulseSensation/Art/_sources/escalation/double-kill.png
- /Users/erik2/Developer/WoW/PulseSensation/Art/_sources/escalation/multikill.png
- /Users/erik2/Developer/WoW/PulseSensation/Art/_sources/escalation/rampage.png

Their runtime counterparts are Kapow/Art/escalation/<message>_1.tga through _3.tga. Match the ivory/steel heavy outlined wordmarks, ember/metallic impact family, with rising energy across levels. Prefer readability and compact controlled effects. No invented new brand style.

## Generation and animation

Use built-in image_gen, transparent_background=true. One call per banner, creating one horizontal 3:1 strip of THREE equal square cells. Left onset, middle peak, right aftershock. All THREE cells contain full exact readable words, same wordmark, anchor and scale; vary surrounding effects intentionally. All three are genuinely generated art frames, not software scaling/rotation/fading of a single image. No grid, labels, frame numbers, backgrounds or painted checkerboard. Keep the complete art and effects in central 70% of each cell with wide transparent gutters; bold shapes readable at 256x256. No characters or logos.

## Naming and deliverables

- _sources/escalation/<message>.png — untouched high-resolution generated strip.
- escalation/<message>_1.tga, _2.tga, _3.tga — onset, peak, aftershock. Uncompressed 256x256 32-bit RGBA TGA, genuine alpha.
- _previews/review-sheet.png — five rows, three frames per row, readable row labels and onset/peak/aftershock headings on a neutral review background.
- Optional per-message GIFs and PNG frame previews.
- manifest.json — exact text, relative source/frame paths, category, actual prompts, reference paths, generator mode, frame order, approval_status=pending.
- validation.json — one basic export check (15 files, dimensions, uncompressed RGBA, alpha), obvious spelling/layout observations. No repeated polish/QA loops; flag concerns for user review. No claims of in-game verification.
- progress.json — recoverable state and final waiting_for_user_review status.

Mechanical Pillow export is allowed: split source into proportional thirds; contain each whole cell in 248x248 using premultiplied-alpha Lanczos, center on transparent 256x256 canvas, save TGA compression=None. Do not individually recenter artwork and create anchor drift. Do not alter source PNGs.

## Completion report to parent

Return review-sheet absolute path, batch folder and manifest path, generated count, any blocking or visible concerns. Stop after five banners. The parent will show the concrete results and ask the user to approve or reject them.
