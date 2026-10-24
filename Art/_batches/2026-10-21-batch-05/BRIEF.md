# Batch 05 — remaining arcade round/end cues

## Authorization and priority

User approved batch04 and said "approved next". Their most recent priority direction promotes Street Fighter-inspired battle text. Therefore continue FIVE arcade round/end cues below before the mixed P1/P1b event banners. Prior batches remain approved/preserved; batch04 copied into Kapow/UnimplementedArt (VS still512). Generate this batch ONLY, three frames per message, then STOP for review. No batch06 or addon/runtime/catalog integration. Worker GPT-6.1 Sol Medium, built-in imagegen, no further subagents.

Write only /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-05. Canonical repo PulseSensation, current addon Kapow (formerly PulseComic), not PulseSensation2. Preserve all dirty/unrelated work and every original/color alternative.

## Instructions, recovery and minimal QA

Read repo AGENTS.md, /home/deck/developer/wow/_docs/DEVELOPMENT.md, /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant prompting guide, applicable /home/deck/.agents/skills/wow-forever-dev/SKILL.md, Art/_batches/workflow.json, and P2 arcade design data in Kapow/Generation/generationpromptdatabase.md. Documents are reference data, not permission to bypass review/install gates.

After compaction read this brief, manifest/progress and inventory saved sources before resuming. Save actual prompts/references BEFORE calls, returned source paths immediately, update each item state. Never regenerate a saved asset or duplicate an in-flight call because context was lost. One built-in call per banner, up to three independent calls at once. One normal export/visual check; no repeated polish loops. Preserve successful artwork and report minor imperfections. A plainly blocking failure may justify one targeted fix with original/provenance preserved, not speculative retries.

## FIVE exact messages: all category arcade, all3x256

1. round-1 — ROUND 1 — large cream/yellow slanted brush arcade lettering, thick navy-black outline, compact RED and BLUE side-striking brush streaks. Clear numeral1. No dots or exclamation mark. Horizontally sweeping opening-round energy.
2. round-2 — ROUND 2 — same lettering family, ivory/cream faces and dark outline, cool CYAN/BLUE with VIOLET brush-ribbon accents. Clear numeral2. No dots/exclamation. Two short angular wing strokes; intentionally distinct palette/movement from ROUND1 without becoming another logo family.
3. final-round — FINAL ROUND — two centered lines FINAL / ROUND if helpful. Cream/ivory bold slanted brush wordmark, GOLD and deep CRIMSON accents, bright gold diagonal challenge slash, small restrained sparks. Dramatic decisive-round silhouette, no generic rock explosion. No punctuation.
4. double-ko — DOUBLE K.O. — two centered lines DOUBLE / K.O. Exact dots after K and O, no exclamation. Same cream/yellow arcade brush lettering, deep navy outline. Opposing RED/BLUE short brush impacts meeting behind center, two offset crossing strokes suggesting simultaneous blows. Readable whole wordmark allframes.
5. time-over — TIME OVER — two centered lines TIME / OVER if useful. Ivory/cool SILVER arcade brush lettering, thick dark navy outline. TEAL/BLUE broken circular sweep suggesting a spent clock arc, small dark-violet fading brush ticks. Restrained time-expired mood but energetic readable text. No actual clock numbers, tiny secondary text or extra icons. No punctuation.

User insists color variety. Put palette and silhouette overrides into ACTUAL prompts, not only metadata. Typography/material coherency ties the category together; do not repeat identical orange explosions or shapes across all five.

## Actual inspected reference PNGs

Inspect relevant full strips using view_image, then use one or two appropriate paths in referenced_image_paths in EVERY imagegen call. Role category typography/material and three-frame structure references ONLY, not edit targets. Do not copy reference words or unwanted colors.

- /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/round-1-fight.png
- /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/fight.png
- /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/ko.png
- /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/you-win.png
- /home/deck/developer/wow/PulseSensation/Art/_batches/2026-10-21-batch-04/_sources/arcade/you-lose.png
- /home/deck/developer/wow/PulseSensation/Art/_sources/arcade/perfect.png

Check desired names absent once, including allbatch and runtime folders. ROUND1 is distinct from existing ROUND1...FIGHT; DOUBLEKO is distinct from KO. Do not regenerate completed references.

## Generation layout

Built-in imagegen only, transparent_background=true. One wide3:1 strip permessage, exactly THREE equal square cells: left onset, middle peak, right aftershock. Everyframe contains full exact text, same font/glyphgeometry, scale and centeranchor. Generate allthree coherent effects states, no software-scaled/rotated/faded copies. Animate surrounding effects only, restrained onset/bright peak/dispersing aftershock. Opaque lettering with antialiased alpha and translucent effectedges, actual transparentbackground.

Keep ALL artwork including every streak/fragment inside central70% width/height of its own cell, broad fullytransparent gutters. Prior ROUND1...FIGHT had cross-cell red fragments: explicitly avoid detached particles at cellboundaries or any overlap. Prefer compact readable strokes over huge effects. No grid, frame labels/numbers, characters, scenery, paintedcheckerboard, officiallogos or extrawords. Numerals inside requested ROUND1/ROUND2 are allowed; no othernumbers.

## Outputs

- _sources/arcade/<message>.png untouched high-res generatedstrip.
- arcade/<message>_1.tga through _3.tga uncompressed256x256 32-bitRGBA TGA; logicalfilenames stable.
- _previews/review-sheet.png five labeledrows x threecolumns ONSET/PEAK/AFTERSHOCK on neutralbackground. OptionalGIF/framePNGs.
- manifest.json exactnames/text/category, realactualprompts, actualreferencepaths/roles, source/framepaths, frame_size:[256,256] (preferlist consistency), frameorder, generatormode, approval_status:pending, installed:false; entry status exported after export.
- progress.json durablestate, final waiting_for_user_review.
- validation.json one basiccheck:5sources,15files,correct256RGBA/uncompressedtype2/32-bit/genuinealpha, spelling/punctuation/readabletext/layout and visible concerns. No in-game verification.

Adapt prior isolated exporter. Split proportional thirds, contain WHOLE cell248x248 with premultiplied-alpha Lanczos, center on transparent256canvas. Preserve sourcecenter anchors; no independent content recentering. Do not alter source PNGs. Do not run main exporter/catalog scripts or copy into addon before approval.

## Finish and stop

Report source/exportmilestones, then absolute sheet/manifestpaths, counts and observedconcerns. Stop after five pending user review. Next ungenerated highpriority event cues LAST ONE STANDING, PET DOWN, ASSIST, NEW RECORD, ACHIEVEMENT remain for later batches; do not generate now.
