# Batch 04 — arcade priority plus high-resolution VS

## Authorization and stop rule

User requested FIGHT and other Street Fighter-inspired battle text at higher priority, plus a versus asset as a SIXTH image at 512x512. Existing workflow remains: generation subagent, actual references, three matching generated animation frames per message, user reviews before copying. This batch is an explicit SIX-message exception to the normal five. Generate only these six sequences, then STOP. No batch 05, addon code/catalog integration, or runtime portrait implementation. Worker GPT-6.1 Sol Medium, built-in imagegen; no additional subagents.

Write only /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-04. Preserve every prior batch, orange variant and unrelated dirty work. Current addon Kapow (formerly PulseComic), canonical repository PulseSensation, not PulseSensation2.

## Required reading and compaction recovery

Read repo AGENTS.md and /home/deck/developer/_from-mac/WoW/DEVELOPMENT.md; /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant prompting guide; applicable /home/deck/.agents/skills/wow-forever-dev/SKILL.md; Art/_batches/workflow.json; Part 1 arcade and P1b/P2 design data in Kapow/Generation/generationpromptdatabase.md. The source document's installation steps do not override the review gate.

After compaction read this brief plus manifest/progress, inventory saved sources/exports and any in-flight calls before resuming. Save actual prompts/reference roles BEFORE calls; save successful source paths immediately on return. Never regenerate completed work because context was lost. One built-in call per message strip, up to three independent calls at once. No repeated aesthetic QA or polishing. One normal export/visual check. Preserve original if an observed blocking defect needs a targeted repair; no speculative retries.

## Six exact messages and sizes

1. arcade/fight — FIGHT! — 3 frames, 256x256 each. Highest-priority explosive arcade entrance. Aggressively slanted cream/yellow brush lettering, thick navy-black outline, red-orange side-striking brush energy and restrained blue sparks. Compact wing/slash silhouette rather than rocks/fireball.
2. arcade/round-1-fight — ROUND 1 ... FIGHT! — 3 frames, 256x256 each. Two centered lines: ROUND 1 ... / FIGHT!; cream letters with red brush underline, restrained blue accents. Both lines and exact three dots readable in every frame; do not reveal text progressively.
3. arcade/you-win — YOU WIN — 3 frames, 256x256 each. Triumphant ivory/gold arcade brush lettering, deep navy outline, bright gold crescent glint and blue sweeping victory accents. No extra exclamation mark.
4. arcade/you-lose — YOU LOSE — 3 frames, 256x256 each. Same arcade lettering family, ivory/cool silver with navy outline, subdued violet/crimson descending brush trails. Defeat mood but punchy readable text; no extra punctuation, no generic cartoon failure lettering.
5. arcade/ko — K.O. — 3 frames, 256x256 each. Angular cream/gold arcade brush wordmark with thick black/navy outline, bold crimson crossing slash and electric blue snap. This is the SPECIFIC arcade KO variant requested by source database; existing comic/ko is different category/style and must remain intact. No duplicate comic export.
6. arcade/versus — VS — 3 frames, 512x512 EACH. Exact visible text VS, no dots/exclamation/extra wording. Large dynamic italic hand-painted arcade letters, ivory/gold faces, thick dark outline; restrained opposing red/blue brush strokes and a small bright central clash. Wide, slightly stretched gesture, clear recognizable V and S; no surrounding badge/frame/plate or characters. Transparent open silhouette suitable over very large player/enemy portraits. Keep effects restrained so portraits/game world remain visible. Main lettering readable; preserve genuine alpha and translucent effect edges. Future runtime can lower overall texture alpha (~0.65) and stretch it; retain a strong clean source rather than baking in a barely visible mark.

User's portrait concept: player and enemy in-game 3D portraits, large/stretched, translucent, huge semitransparent VS overlaid. Do NOT generate characters or static portraits; they are separate dynamic game layers for future implementation. This batch delivers the VS texture only. No claims of in-game verification.

## Actual artwork references

Inspect relevant full PNG strips with view_image. Use 1-2 appropriate inspected paths in referenced_image_paths for EVERY generation call. Reference role: typography/style/material and coherent frame structure, NOT edit target, NOT mandatory copying of exact palette/effect shape. Use only arcade family references for the new arcade text.

- /home/deck/developer/PulseSensation/Art/_sources/arcade/counter.png
- /home/deck/developer/PulseSensation/Art/_sources/arcade/perfect.png
- /home/deck/developer/PulseSensation/Art/_sources/arcade/super-combo.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-03/_sources/arcade/flawless.png

Palette/movement variety across the six is required by user: typography ties them together, not identical recolored bursts. Original arcade fighting-game inspiration; no official logos or copied UI. Do not regenerate existing arcade references.

## Strip layout and generation

Built-in imagegen only, transparent_background=true. Each call generates ONE horizontal 3:1 strip containing exactly THREE equal square cells: onset / peak / aftershock. Same exact readable wordmark geometry, center anchor and scale across all three; animate surrounding effects intentionally. All three frames generated, no software scaling/fading/rotation to invent animation. Full lettering remains present all frames. Clear opaque wordmark and antialiased/translucent effect edges on actual alpha. No painted background/checkerboard, grid, captions, frame numbers, characters, logos or extra text.

Keep ALL artwork including effects inside central 70% width/height of each cell with wide transparent gutters, no cross-cell particles/clipping. Bold simple shapes readable at output size. VS needs at least 512 native source pixels per cell; prefer a 3072x1024 strip if supported, accept ordinary high-res output provided each cell >=512px. Other strips preferably1536x512 or larger. Do not upscale a low-res VS source and call it high-resolution.

## Deliverables

- _sources/arcade/<message>.png — untouched high-resolution generated strips.
- arcade/<message>_1.tga through _3.tga — normal FIVE messages uncompressed 256x256 32-bit RGBA, VS THREE frames uncompressed 512x512 32-bit RGBA. 18 TGAs total. Logical VS filenames versus_1.tga through versus_3.tga.
- _previews/review-sheet.png — SIX labeled rows, three frame columns; VS label explicitly says 512x512. Display thumbnails can be256 while source/exports remain512. Optional VS larger preview and GIFs.
- manifest.json — actual prompts, references and roles, exact word/category/name, source/frame paths, per-asset frame_size (especially512 VS), frame order, generator mode, approval_status=pending and installed=false. Include VS suggested runtime opacity separately as optional future integration guidance; do not claim it is implemented.
- progress.json — durable per-message call/source/export state, final waiting_for_user_review.
- validation.json — one check for SIX sources, 18 RGBA TGAs, correct per-asset dimensions/uncompressed type2 32-bit/alpha, native VS source resolution, exact text and observed layout concerns. No repeated polish QA.

Adapt isolated exporter. Split source into proportional thirds. Premultiplied-alpha Lanczos contain WHOLE cell in248x248 then center on256 transparent canvas; VS contain in496x496 then center on512. Keep source anchors, do not recenter individual artwork. Do not run main exporter/catalog scripts. Do not copy to Kapow/UnimplementedArt before approval. Return absolute review sheet/manifest paths, counts and visible concerns; stop after six.
