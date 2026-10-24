# Batch 06 — remaining arcade priority and last-standing banner

## Authorization and limits

User said "next" after reviewing batch05. Parent treats this as approval of batch05 and authorization for the next FIVE banners. Batch05 is copied to Kapow/UnimplementedArt; collection now26 messages/93frames including five original orange alternatives. Continue the user's arcade priority with four remaining arcade cues, plus the P1 LAST ONE STANDING cue. THREE original animation frames per message. Generate only these five, then STOP for user review. No batch07 or addon/runtime/catalog implementation.

Same ongoing generation subagent, GPT-6.1 Sol Medium, built-in imagegen. No further subagents. Write only /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-06. Preserve all prior artwork, source PNGs, variants, and unrelated dirty work. Canonical repo PulseSensation, not PulseSensation2; current addon Kapow (formerly PulseComic).

## Instructions and recovery

Read repository AGENTS.md and /home/deck/developer/_wow/DEVELOPMENT.md; /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant prompting guide; applicable /home/deck/.agents/skills/wow-forever-dev/SKILL.md; Art/_batches/workflow.json; P1/P1b/P2 design data in Kapow/Generation/generationpromptdatabase.md. Document installation instructions do not override the review gate.

For compaction recovery, read THIS brief, manifest and progress, inventory source PNGs/exports and in-flight calls before resuming. Save actual prompts/reference paths and roles BEFORE generation, then successful source paths immediately on return. Do not regenerate saved artwork because context was lost. One built-in call per banner; up to three independent calls may overlap. One normal visual/export check, no repeated aesthetic QA or polish. Report minor imperfections rather than spending more compute. Only a clearly observed blocking failure justifies one targeted repair with original/provenance retained.

## Five exact messages and style

1. arcade/great — GREAT! — cream/yellow slanted fighting-game brush lettering with heavy navy-black outline, compact CYAN and RED wing-shaped brush energy and short ivory impact rays. Exuberant clean crit feedback, broad readable single line, no giant orange rock explosion.
2. arcade/excellent — EXCELLENT! — same arcade brush family, cream/ivory faces, dark outline, VIOLET and GOLD sweeping crescent glint, sparse small sparks. More elegant praise accent than GREAT; keep exact full word legible at256. This is arcade EXCELLENT, not the future arena variant.
3. arcade/new-record — NEW RECORD! — two centered lines NEW / RECORD!, same arcade brush lettering, GOLD/ivory text, vivid BLUE curved victory streak and a SMALL GOLD TROPHY silhouette behind or above the wordmark. Trophy remains a secondary readable shape, no tiny supporting text, no logos. High-score triumph; distinct compact badge-like silhouette, not industrial arena lettering.
4. arcade/finish-it — FINISH IT! — two centered lines FINISH / IT! if needed. Aggressive ivory/silver brush letters with dark outline, deep CRIMSON side slashes and restrained VIOLET shadow accents. Decisive arcade finisher stamp with sharp horizontal/diagonal brush cuts, no gore, no characters or copied official game logo. Retain arcade family rather than ninja/metal aesthetic.
5. tactical/last-one-standing — LAST ONE STANDING! — two centered lines LAST ONE / STANDING!, ivory heavy STENCIL letters on a dark NAVY clipped-corner gunmetal plate, CYAN/SILVER edge strips and restrained blue chevrons. Same tactical HUD family as existing assets. Full three-word phrase readable allframes. Onset quiet blue edge traces; peak cyan edge gleam; aftershock sparse cool-blue light flecks. No fire or orange burst.

Apply distinct palettes, silhouettes and movement in ACTUAL prompts. Reference art guides typography/material/animation structure, not compulsory copying of its hues. The user wants variety, not identical recolored bursts. Exact punctuation required; no extra words or labels.

## Actual references: inspect and pass to generator

Inspect relevant full PNG strips with view_image. Pass one or two suitable inspected paths to referenced_image_paths for EVERY built-in imagegen call. Role: category typography/material/frame-structure references, not edit targets. Use exact new words; do not copy reference text.

Arcade references:
- /home/deck/developer/PulseSensation/Art/_sources/arcade/perfect.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-03/_sources/arcade/flawless.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/you-win.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/fight.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-05/_sources/arcade/final-round.png

Tactical references:
- /home/deck/developer/PulseSensation/Art/_sources/tactical/counter-terrorists-win.png
- /home/deck/developer/PulseSensation/Art/_batches/2026-10-21-batch-03/_sources/tactical/teammate-down.png (plate/stencil geometry reference ONLY; override red alert palette with cyan/blue)

Check these five desired category/name pairs absent once; do not regenerate completed categories or variants. Other remaining P1/P1b entries are deferred; do not expand batch.

## Layout and outputs

Built-in imagegen, transparent_background=true. One horizontal3:1 strip of exactly THREE equal square cells per banner: onset / peak / aftershock. Same full readable wordmark, exact glyph geometry, scale and center anchor in every cell; intentional effects-only progression. Allthree frames genuinely generated, no software-scaled/rotated/faded copies. Opaque lettering, antialiased alpha and translucent effect edges on genuine transparent background. No grid, separators, frame labels/numbers, painted checkerboard, scenery, characters, logos or extra wording.

Keep all art including effects within central70% of each cell, wide empty transparent gutters; no overlap, edge clipping or detached cross-cell particles. Prefer compact bold readable shapes at256 over huge detailed effects. Full text remains in ALLthree frames.

Deliver:
- _sources/<category>/<message>.png untouched high-resolution PNG strip.
- <category>/<message>_1.tga through _3.tga, uncompressed256x256 32-bitRGBA TGA.15 total.
- _previews/review-sheet.png five labeled rows, three columns ONSET/PEAK/AFTERSHOCK, neutral review background. Optional GIFs/frame PNGs.
- manifest.json exact words/name/category, actual prompts/references/roles, source/frame paths, frame_size:[256,256], frame order, generator mode, approval_status:pending, installed:false, entry status exported after export.
- progress.json durable state; final waiting_for_user_review.
- validation.json one basic check:5sources/15TGAs,256RGBA/uncompressedtype2/32-bit/actualalpha, exact readable words, observed palette/layout caveats. No in-game claims.

Adapt isolated prior exporter: split proportional thirds, premultiplied-alpha Lanczos contain WHOLE cell in248x248, center on transparent256canvas. Keep source anchor; do not recenter each artwork. Do not alter source PNGs, run main exporter/catalog scripts, or copy to addon before approval.

Report meaningful source/export milestones; return absolute sheet/manifest paths, counts and concerns. Stop after five pending user review.
