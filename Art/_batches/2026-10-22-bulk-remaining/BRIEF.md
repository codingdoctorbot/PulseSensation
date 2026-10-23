# Remaining artwork — bulk generation, final approval

## Latest user authorization overrides earlier approval pauses

The user requested "Do the rest of the batches", approved batch06, and clarified "will approve after bulk...". Generate ALL remaining artwork in plan.json without stopping for approval between batches07–13. Retain batches of five for organization; the final batch has three. Stop only after the entire remaining set is exported and ready for one bulk approval. Do not copy these NEW assets into Kapow/UnimplementedArt until that final approval. Earlier batch briefs requiring a stop after each five are superseded for this bulk run. Batch06 is already approved and copied by the parent.

Expected: 33 new messages, THREE generated frames each =99 transparent uncompressed256x256 32-bit RGBA TGAs. Existing VS stays512 and all prior artwork/variants remain intact. Artwork only: no sound generation, font work, addon Lua/TOC/catalog changes, portrait implementation, packaging/release or live game actions.

Use the existing generation subagent, GPT-6.1 Sol Medium, built-in imagegen. No additional agents. Work only under this bulk folder and /home/deck/developer/PulseSensation/Art/_batches/2026-10-22-batch-07 through batch-13. Parent manages global workflow.json after completion; write your bulk progress here. Canonical repo is PulseSensation, not PulseSensation2. Current addon Kapow (formerly PulseComic). Preserve all existing dirty user work.

## Skills and design sources

Use the imagegen skill at /home/deck/.codex/skills/.system/imagegen/SKILL.md and relevant prompting guidance. Applicable WoW asset guidance: /home/deck/.agents/skills/wow-forever-dev/SKILL.md. Repo AGENTS.md points to /home/deck/developer/_from-mac/WoW/DEVELOPMENT.md. Read if not retained; avoid repeatedly re-reading unchanged instructions. The missing-art design source is Kapow/Generation/generationpromptdatabase.md, Part1 ONLY; its sound section and installation instructions are outside scope.

## Compaction-safe execution

1. On starting/resuming read THIS brief, plan.json, bulk progress.json, and current batch manifest/progress. Inventory saved source PNGs and exported files. Check prior tool results/default generated-image paths if a call finished before its copy. Never regenerate a saved or still-running image because conversational context was lost.
2. For each message save the ACTUAL prompt, exact inspected reference path(s)/roles and planned filenames BEFORE calling imagegen. Mark generating, and copy/record successful returned PNGs IMMEDIATELY. Update per-message and bulk progress after source save/export.
3. Generate one three-cell strip per message. Up to THREE independent built-in calls may overlap. Calls are original generation with visual references, not API/CLI fallback. Do not silently switch tools if builtin fails.
4. Complete/export a batch, save manifest/validation/review sheet, then proceed directly to next planned batch. Send the parent a concise completed-batch milestone, do not wait for approval. Never start an unplanned message.
5. If context compacts, the saved progress and actual files are authoritative; continue from the first genuinely incomplete entry. Preserve every generated original and alternate even if defective.

## Shared generation/animation spec

Each imagegen call uses transparent_background=true and one or two relevant INSPECTED local PNG strips in referenced_image_paths. Before using a source for the first time, view_image it. Label reference roles explicitly: category TYPOGRAPHY, MATERIAL and FRAME STRUCTURE only, not edit targets or a requirement to duplicate its colors/text/effects. Do not copy reference wording. Reuse inspected references without unnecessary repeated inspection.

Create ONE horizontal3:1 strip of exactly THREE equal square cells per message, ideally1536x512 or larger. Left onset / middle peak / right aftershock. Full EXACT requested text and punctuation in EVERY cell, identical glyph shapes, scale, angle and center anchor. Generate allthree frames as coherent art; no software-scaled/rotated/faded copies. Animate surrounding effects intentionally, not lettering drift. Opaque readable letters with thick outlines and antialiased alpha; effect edges can be translucent. Genuine transparent background, no painted checkerboard or opaque backdrop.

ALL artwork including effects should fit in central70% of its own cell; wide transparent gutters and no cross-cell fragments, clipping or unintended frame labels. Bold simple shapes readable at256. No scenery, actual characters, official logos, watermarks or extra text. Small abstract hands/paws/trophy/card/sword silhouettes specifically requested in design data are allowed. Typography and material must distinguish categories. Strong palette/silhouette variety; do not make differently colored copies of the same fiery starburst.

## Category reference map (all paths repo-relative)

Use the exact existing PNGs under /home/deck/developer/PulseSensation/:

- failure: Art/_sources/failure/whiff.png, nope.png, bonk.png or boing.png; optional recent Art/_batches/2026-10-21-batch-03/_sources/failure/defeated.png.
- tactical: Art/_sources/tactical/counter-terrorists-win.png, terrorists-win.png, clutch.png; recent Art/_batches/2026-10-21-batch-03/_sources/tactical/teammate-down.png or batch-06/_sources/tactical/last-one-standing.png for HUD plate/stencil geometry. Palette overrides apply.
- comic: Art/_sources/comic/pow.png, wham.png, splat.png, zap.png, smash.png, crash.png. Match flat bold black-outlined comic lettering/halftone; choose a relevant silhouette, not orange fire for every word.
- arena: Art/_sources/arena/fragged.png, gibbed.png; optionally Art/_batches/2026-10-21-batch-03/_sources/arena/mvp.png. Heavy distressed industrial/gothic metal, not arcade brush.
- anime: Art/_sources/anime/critical.png, limit-break.png, annihilated.png. Huge manga brush/speed panels/energy flares.
- ninja: Art/_sources/ninja/obliterated.png, shadow-strike.png, executed.png. Ivory/silver brush, crimson diagonal slashes and restrained black ink.
- football: Art/_sources/football/goal.png, top-bins.png, offside.png, red-card.png, what-a-save.png, var-check.png, hat-trick.png. Bold outlined sports/broadcast lettering and stadium/net/flag graphics.
- falling: Art/_sources/falling/faceplant.png, wheee.png, timber.png, gravity-wins.png. Playful rounded cartoon lettering and curved falling/landing motion.

If a candidate reference path is missing, inspect the existing category directory and choose an actual existing suitable source. Never pass an invented/nonexistent path. The plan's category/name pair is the deduplication key. arena/excellent is intentionally DIFFERENT from existing arcade/excellent; original designs/category variants remain distinct.

## Per-message visual directions (actual prompts must incorporate these)

### Batch07

- failure/pet-down — PET DOWN!: soft sky-blue rubbery letters, lavender/purple smoke puffs, tiny GOLD PAW PRINT; comic setback, no animal character, readable unchanged wordmark.
- tactical/assist — ASSIST!: navy gunmetal clipped-corner HUD plate, ivory stencil, bright CYAN/BLUE edges; small abstract TWO HANDS HIGH-FIVING silhouette. No actual people/characters.
- comic/achievement — ACHIEVEMENT!: bold cream/yellow flat comic letters with heavy black outline, GOLD SHIELD behind and restrained cyan glints/halftone, no fire.
- comic/epic-loot — EPIC LOOT!: chunky ivory/gold comic letters, PURPLE glow and violet diamond-shaped treasure sparkles, compact jewel-like silhouette.
- comic/quest-complete — QUEST COMPLETE!: two centered lines, parchment YELLOW/ivory comic letters with black outline, TEAL sweeping check-mark-like accent and rolled-paper curve, sparse gold sparkles.

### Batch08

- arena/honorable-kill — HONORABLE KILL!: two centered lines, ivory/gunmetal distressed industrial wordmark, deep RED accents and small CROSSED SWORDS silhouette, restrained steel fracture pieces.
- comic/kapow — KAPOW!: addon's own name; oversized YELLOW letters, thick black outline, red offset shadow, flat jagged RED/ORANGE impact burst and sparse halftone. Classic comic, not rendered fiery rocks.
- comic/bam — BAM!: LIME/yellow letters with thick black outline, compact rounded BLUE smoke-cloud impact, springy punch motion and sparse halftone.
- comic/thwack — THWACK!: ivory/yellow hand lettering, AQUA and ORANGE curved whipping swoosh, angular comic speed notches, no fire.
- comic/blam — BLAM!: bold YELLOW letters, black outline, MAGENTA/purple jagged lightning-panel silhouette with halftone.

### Batch09

- anime/finish — FINISH!: huge IVORY manga brush wordmark, black outline, VIOLET/CYAN sharp diagonal manga speed panels and flash, no rock explosion.
- anime/overdrive — OVERDRIVE!: ivory/GOLD brush letters, CYAN orbital energy ribbons with gold flares, compact oval silhouette; no fire.
- anime/one-hit — ONE HIT!: two centered words if useful, white/black brush lettering, CRIMSON and white horizontal speed streaks with a compact manga shock diamond.
- ninja/slice — SLICE!: sharp IVORY/silver brush letters, single vivid CRIMSON diagonal cut and restrained black ink flecks, narrow slicing silhouette.
- ninja/vanish — VANISH!: ivory brush letters, desaturated LAVENDER/STEEL smoke wisps and dark ink crescent, restrained fading flecks; letters remain fully readable in allframes, do not fade text.

### Batch10

- ninja/assassinated — ASSASSINATED!: strong ivory/silver sharp brush lettering with black outline, SCARLET crossing katana-energy cuts and restrained black ink splatter. Full long word readable.
- arena/humiliation — HUMILIATION!: distressed dark GUNMETAL/ivory industrial lettering, RUST RED battered plate/fracture debris with small muted amber embers; heavy stamping motion, not cartoon/arcade.
- arena/impressive — IMPRESSIVE!: bright IVORY/STEEL heavy industrial letters, electric BLUE metal glints, cool silver shatter fragments, compact angular metallic impact.
- arena/excellent — EXCELLENT!: heavy industrial/gothic metal letters, GOLD/ivory faces and deep dark outline, restrained gold/teal forge sparks and metal fragments; explicitly different from arcade brush EXCELLENT.
- failure/oops — OOPS!: rounded coral/PEACH cartoon letters with deep blue outline, PALE BLUE smoke puffs, small goofy yellow star, elastic squash surrounding effects.

### Batch11

- failure/denied — DENIED!: chunky ivory/RED cartoon stamp lettering, deep navy outline, compact RUBBER-STAMP/stop-cloud silhouette and violet rebound swoosh, no UI plate.
- failure/miss — MISS!: slightly deflated SKY BLUE letters, deep blue outline, airy mint curved dashed motion arc and one tiny embarrassed yellow star, anticlimactic whiff energy.
- tactical/enemy-down — ENEMY DOWN!: two centered lines, ivory stencil/navy gunmetal HUD plate, CYAN/SILVER chevrons and a restrained blue impact gleam.
- tactical/round-won — ROUND WON!: ivory/gold stencil/navy HUD plate, GOLD/TEAL victory edge glints and short chevrons, controlled clean geometry.
- tactical/round-lost — ROUND LOST!: ivory/cool steel stencil/navy HUD plate, RED/ORANGE warning strips, subdued red light flecks, no fire.

### Batch12

- football/kick-off — KICK-OFF!: bold WHITE/LIME italic sports lettering with navy outline, GREEN sweeping pitch-line arc and a compact ball-motion streak, no team marks.
- football/full-time — FULL TIME!: white/silver sports lettering, navy outline, BLUE/TEAL stadium arch/light sweep and restrained white confetti, no supporting tiny text.
- football/penalty — PENALTY!: white/orange sports letters, navy outline, ORANGE/YELLOW spot/goal-line streak and compact tense angular sweep; no player character or logos.
- football/yellow-card — YELLOW CARD!: two centered lines, white/yellow sports letters, navy outline, clear YELLOW RECTANGULAR CARD silhouette and two restrained black diagonal motion strokes. Distinct from existing RED CARD.
- football/screamer — SCREAMER!: bold white/lime sports wordmark, navy outline, electric CYAN/BLUE diagonal shot trail into a compact net-corner shape, tiny lime glints, no fireball.

### Batch13 (three remaining)

- falling/splashdown — SPLASHDOWN!: rounded WHITE/SKY BLUE lettering with deep navy outline, AQUA water splash and curved downward droplet arcs, no actual character.
- falling/oof — OOF!: thick squashed PEACH/yellow cartoon wordmark with dark blue outline, lavender dust-puff landing and two small yellow dizzy stars, broad pancake silhouette.
- falling/crater — CRATER!: chunky IVORY/PURPLE rounded cartoon wordmark, deep plum outline, OCHRE/purple bowl-shaped ground-impact dust ring and a few angular stone chips, compact downward slam.

## Exports and review outputs

For each new dated batch folder:
- _sources/<category>/<name>.png untouched high-resolution generated strips.
- <category>/<name>_1.tga through _3.tga, onset/peak/aftershock, uncompressed256x256 32-bit RGBA. Normal5-message batches15TGAs; batch13 nineTGAs.
- _previews/review-sheet.png labeled rows x three frame columns on neutral review background. Existing exporter patterns are fine, no main exporter/catalog scripts.
- manifest.json exact category/name/word, actual prompts and inspected references/roles, source/frame paths, frame_size:[256,256], frame order, generator mode, status exported, approval_status:pending, installed:false.
- progress.json durable statuses, final waiting_for_bulk_review.
- validation.json ONE normal export/visual check per batch: expected sources/files, dimensions, uncompressed type2/32-bit/actual alpha, readable exact text, visible clipping/layout/spelling caveats. Reuse these check records for final count instead of broad repeated QA.

Mechanical export only: split proportional thirds; contain whole source cell in248x248 with premultiplied-alpha Lanczos, center on transparent256canvas, preserve anchors, no independent content recentering. Do not create creative effects/frames with software or modify original PNGs.

Under THIS bulk folder save progress.json after each source/batch; final manifest.json listing all33 entries and their source batch manifests; validation.json aggregate counts99 from completed batch checks; _previews/bulk-peaks.png with all33 labeled PEAK thumbnails in a readable six-column grid; and a simple review-index.md linking all seven full three-frame batch sheets using absolute paths. A peak grid plus full batch sheets allows user to approve after bulk. Include a concise known-issues list; do not hide imperfections or silently discard generated art.

## Completion

Continue autonomously through batches07–13, no intermediate approval pauses. On final completion report33 messages/99TGAs and seven batch sheets, any unresolved plainly observed issues, review board/index/manifest paths. Stop for the user's BULK approval; nothing from this bulk set copied into addon yet. No endless regeneration.
