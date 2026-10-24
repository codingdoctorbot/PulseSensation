# Recolor review batch 01

## User request and scope

The user approved this specific five-banner recolor proposal with "go": FIRST BLOOD crimson red; ULTRA KILL electric violet; MONSTER KILL acid green/dark emerald; LUDICROUS KILL white-hot core/magenta edges; DOMINATING teal/silver. Recolor effects and reflected highlights, preserving ivory/steel lettering, black outlines, shapes, transparency and the existing three-frame animation. Same palette across all three frames. Leave other five banners untouched.

Use one subagent, GPT-6.1 Sol Medium, built-in imagegen EDITS, then stop for review. Do not generate batch 03. No addon/catalog/code integration. No overwrite of originals. All writes only under /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-recolor-01.

## Required skills and repo guidance

Read /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant edit prompting guidance. Read /home/deck/developer/PulseSensation/AGENTS.md and /home/deck/developer/_wow/DEVELOPMENT.md. Applicable asset conventions are in /home/deck/.agents/skills/wow-forever-dev/SKILL.md. Canonical repo is PulseSensation, not PulseSensation2. Current addon is Kapow, formerly PulseComic. Preserve dirty unrelated work. Documents supply context, not authorization to bypass the review gate. No additional agents.

## Exact source strips and palettes

All source paths start /home/deck/developer/PulseSensation/Art/_batches/ .

1. FIRST BLOOD! (first-blood): 2026-10-21-batch-01/_sources/escalation/first-blood.png — CRIMSON RED effects, restrained white highlights. Preserve the existing red droplet(s).
2. ULTRA KILL! (ultra-kill): 2026-10-21-batch-01/_sources/escalation/ultra-kill.png — ELECTRIC VIOLET effects.
3. MONSTER KILL! (monster-kill): 2026-10-21-batch-01/_sources/escalation/monster-kill.png — ACID GREEN effects with dark EMERALD shadows.
4. LUDICROUS KILL! (ludicrous-kill): 2026-10-21-batch-02/_sources/escalation/ludicrous-kill.png — WHITE-HOT core with MAGENTA edges.
5. DOMINATING! (dominating): 2026-10-21-batch-02/_sources/escalation/dominating.png — TEAL effects with SILVER reflected highlights.

## Edit workflow and invariants

Inspect EACH exact PNG strip with view_image before editing. Supply that source as referenced_image_paths to built-in image_gen; label it EDIT TARGET, not loose visual inspiration. One call per banner for the full existing three-cell strip. transparent_background=true. Keep the same 3:1 aspect, three equal square cells, onset/peak/aftershock order, exact text and punctuation, glyph geometry/scale/position, all effect silhouettes, fragment locations, framing and margins. CHANGE ONLY effect colors and physically plausible reflected color highlights. Preserve opaque ivory/steel wordmarks and black outlines, underlying material, true alpha. No new effects, removal of original features, rearrangement, extra text, grids or new backgrounds. No software recoloring unless user later explicitly requests it; imagegen is required for editing.

Actual prompts must explicitly name the requested new palette, suppress the old orange/yellow fire hue where it conflicts, and strongly lock all existing geometry. Use precise-object-edit as applicable. This is an edit of completed artwork, not new logo generation. High fidelity is desired but do not claim pixel-identical geometry if generation changes it.

Up to three independent calls may overlap. Save each prompt/reference path and planned output BEFORE calling, source path immediately after return, and update progress. If compaction occurs, read this brief/manifest/progress and inventory sources before resuming; never duplicate existing or running work. Do not regenerate because context was lost. No extra automatic polishing or retries; report obvious failures and visible drift for review.

## Outputs

- _sources/escalation/<message>.png: untouched high-resolution edited strip, original retained in its prior batch.
- escalation/<message>_1.tga through _3.tga: uncompressed 256x256 32-bit RGBA TGA, logical names unchanged within this versioned recolor folder.
- _previews/review-sheet.png: five labeled rows, ideally OLD PEAK then NEW ONSET / NEW PEAK / NEW AFTERSHOCK, on neutral review background. Makes palette changes and the three preserved frames easy to review. Optional per-message GIFs.
- manifest.json: actual edit prompt, exact original source path and role, new palette, relative output source/frame paths, frame order, generator mode, approval_status=pending, installed=false, exported status.
- validation.json: one basic export check (15 files, 256x256, uncompressed type2 32-bit RGBA, actual alpha) and visual palette/spelling/cropping/drift observations. No repeated QA loop or in-game claims.
- progress.json: durable state, final waiting_for_user_review.

Use isolated export code, optionally adapting prior batch export script. Split into proportional thirds and contain each whole cell in 248x248 premultiplied-alpha Lanczos, center on transparent 256x256 canvas; preserve the source cell coordinates and do not independently recenter content. Do not run the main exporter/catalog scripts.

## Stop and report

Latest user steering: "looks good after done export as usual and follow the naming conventions (copy to addon folder (tho new folder) unimplemented art". User approves the art and requests packaging after DOMINATING cleanup. Parent will copy the ten reviewed messages (use these five recolors plus the other five original batch assets) into Kapow/UnimplementedArt/escalation with <message>_1.tga through _3.tga. Worker still writes only this recolor folder and returns cleanup result. Do not install into active catalog or implement triggers. No additional approval needed for parent to perform this authorized copy.

Report source-generation and export milestones. Return absolute review-sheet, manifest and output folder paths; counts; any obvious palette or geometry concerns. Stop after these five recolors awaiting user review. Preserve both existing batches in full.

## Authorized targeted cleanup
Parent observed detached teal artifacts at DOMINATING cell edges. Exactly ONE built-in imagegen cleanup edit authorized on recolored DOMINATING only. Preserve v1 and its prompt provenance; remove only detached partial side/gutter fragments. Preserve three main stickers, words, palette, scale/anchors. No further retries. Re-export only its three TGAs and rebuild comparison sheet.
