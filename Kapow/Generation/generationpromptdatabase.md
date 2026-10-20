# KAPOW! generation prompt database

What still has to be generated, with ready prompts. Two kinds:

1. **Banners (art):** three-frame transparent sprite strips, made with ChatGPT image generation, the same way the
   47 existing messages were made (their exact prompts are in `Art/_metadata/manifest.json`).
2. **Sounds:** high-fidelity announcer lines and effects for the sound pools (`Kapow/Sounds/<pool>/`).

Priorities: **P1** fills an event that today shows text only. **P2** is the Street Fighter-style Roadfighter set.
**P3** rounds out a category so each one covers hits, kills, streaks, fight start/end and failures.

Already generated (do not redo): CRITICAL, LIMIT BREAK, ANNIHILATED · KRAKOOM, WHAM, SPLAT, BOOM, ZAP, SMASH, CRASH,
POW, OVERKILL, K.O. · COUNTER, PERFECT, SUPER COMBO · OBLITERATED, SHADOW STRIKE, EXECUTED · FRAGGED, GIBBED,
RAMPAGE · DOUBLE KILL, MULTIKILL · WHIFF, NOPE, BONK, BOING · COUNTER-TERRORISTS WIN, TERRORISTS WIN, BOMB PLANTED,
BOMB DEFUSED, HEADSHOT, CLUTCH, ACE · GOAL, HAT-TRICK, TOP BINS, WHAT A SAVE, OFFSIDE, RED CARD, OWN GOAL, VAR CHECK
· WHEEE, FACEPLANT, TIMBER, GRAVITY WINS.

---

## Part 1 — Banners (art)

### How to make one

Paste the template below into ChatGPT image generation, replacing `{STYLE}` with the category's style line and
`{WORD}` with the banner word, exactly as written (spelling is mandatory). One message per request.

Then:

1. Save the transparent PNG strip as `Art/_sources/<category>/<message>.png` (message = lowercase, hyphens).
2. Export the three 256x256 TGA frames: `python3 Art/_metadata/export_assets.py` (Pillow), giving
   `Art/<category>/<message>_1.tga … _3.tga`.
3. Add the message to `Art/_metadata/manifest.json` (key, word, style, prompt, frames, categories).
4. `python3 scripts/make-art-catalog.py`: the art appears in KAPOW's Art menu. Apply a theme again to pick it up.

### The template (from the manifest, unchanged)

```text
Use case: stylized-concept. Asset type: transparent combat popup animation sprite strip for a World of Warcraft addon. Create ONE horizontal sprite strip containing exactly THREE equal SQUARE cells in a single row, 3:1 aspect ratio, preferably 1536x512. No visible grid, no separators, no labels, no frame numbers. Each cell contains the SAME wordmark, exactly the same font, spelling, position and scale centered at 50% width and 50% height of its cell. The wordmark remains fully visible and unchanged in all three cells. The artwork is a standalone text plus explosive effects sticker on a genuinely transparent background. Each sticker must stay entirely inside its cell with at least 8% transparent margin on every edge. Frame 1 left: tight punchy burst with a few effects. Frame 2 middle: peak explosive burst and brighter effects. Frame 3 right: aftershock with spread out fragments, effects diminishing but text unchanged. All three frames are full-color and opaque on lettering with antialiased alpha on outside edges. Clear thick outlines and high readability when each cell is displayed at only 256x256. No characters, no scene, no background color, no checkerboard painted in, no extra words, no logos or watermarks.
CRITICAL LAYOUT RULE: Make the art SMALLER than the cell. Each word plus ALL effects must fit inside the central 70% width and 70% height of its own cell. Leave WIDE empty transparent gutters between every sticker and around canvas edges. Three isolated stickers, no overlaps. Lettering should take 60% cell width. Prefer flat bold readable shapes over tiny detail.
Visual direction: {STYLE}
Text (verbatim, in each of the THREE cells): "{WORD}". Exact spelling is mandatory.
```

For words of three or more words, add: `Stack the text on two centered lines, the line break where natural.`

### Category style lines (from the manifest)

| Category | Font | `{STYLE}` |
|---|---|---|
| anime | Knewave | Anime combat impact: bold white manga brush lettering with heavy black ink outline, electric violet and cyan lightning, sharp speed slashes, intensely energetic. |
| comic | Bangers | Classic comic book impact: oversized yellow hand lettered text with thick black ink outlines and red offset shadow, jagged orange red starburst, sparse halftone dots, wild explosive asymmetry. |
| arcade (Roadfighter) | Russo One | 1990s arcade fighting game impact: aggressively slanted cream yellow brush lettering with thick navy black outline, saturated red to orange flame streaks, punchy blue accent sparks. |
| ninja (Shadow Clan) | Shojumaru | Dark ninja action game impact: brutally expressive ivory brush lettering with thick black outline, crimson ink splatter and silver diagonal katana slash, angular silhouette and tiny restrained blood red droplets. |
| arena (Boomer Shooter) | Metal Mania | 1990s gothic arena shooter impact: large chunky distressed gunmetal lettering, bright ivory faces and heavy black outline, hot orange fissures, rust red shards, sparks and a compact violent explosive silhouette. |
| escalation | Black Ops One | Arena shooter escalation level N: bold condensed ivory and steel lettering with thick black outline, orange ember burst, two diagonal slash marks, compact metallic impact. Same family as DOUBLE KILL, MULTIKILL and RAMPAGE. *(Raise the energy with the level: level 1 small embers, level 5 molten white-hot core and more slash marks.)* |
| failure | Lilita One | Funny comic failure impact: oversized slightly deflated sky blue lettering with heavy black outline, pale blue airy swoosh and small dashed motion lines, one tiny embarrassed yellow star, goofy anticlimactic missed punch energy. Readable bold sticker. |
| tactical (Strike Squad) | Black Ops One | Tactical shooter HUD banner: ivory-white heavy stencil letters over a dark NAVY gunmetal plate with cool silver bevels, cyan edge strips and two restrained blue chevrons. A clipped-corner shield-like rectangle with a shallow V bottom. Onset: small blue edge traces; peak: cyan edge gleam; aftershock: sparse cool-blue light flecks. *(Use red/orange accents instead of blue for bad news.)* |
| football (Soccer League) | Graduate | Football broadcast graphic: huge WHITE and electric LIME bold italic sports lettering with thick deep NAVY outline, a GREEN sweeping streak and a few green and white confetti pieces. Onset: compressed streak; peak: sweeping streak; aftershock: sparse drifting confetti. |
| falling | Bubblegum Sans | Playful cartoon falling graphic: huge WHITE and SKY BLUE rubbery rounded lettering with thick deep BLUE outline, airy pale blue motion streaks and a few white dots. No person or face. Onset: motion starts; peak: strongest motion; aftershock: broken streaks trail away. |

### P1 — events that show text only today

| Event (KAPOW) | Category | Message file | `{WORD}` | Note |
|---|---|---|---|---|
| firstblood | escalation | first-blood | FIRST BLOOD! | level 1, add a single red droplet |
| triple | escalation | triple-kill | TRIPLE KILL! | level 2 |
| mega | escalation | mega-kill | MEGA KILL! | level 3 |
| ultra | escalation | ultra-kill | ULTRA KILL! | level 4 |
| monster | escalation | monster-kill | MONSTER KILL! | level 5 |
| ludicrous | escalation | ludicrous-kill | LUDICROUS KILL! | level 5, white-hot |
| spree5 | escalation | killing-spree | KILLING SPREE! | level 2 |
| spree15 | escalation | dominating | DOMINATING! | level 3 |
| spree20 | escalation | unstoppable | UNSTOPPABLE! | level 4 |
| spree25 | escalation | godlike | GODLIKE! | level 5, add a faint golden halo |
| spree30 | escalation | wicked-sick | WICKED SICK! | level 5, add toxic green sparks |
| mvp | arena | mvp | MVP! | gold star instead of fissures |
| flawless | arcade | flawless | FLAWLESS! | |
| youdied | failure | defeated | DEFEATED! | avoid other games' trademark phrases |
| teammate | tactical | teammate-down | TEAMMATE DOWN! | red/orange accents |
| laststanding | tactical | last-one-standing | LAST ONE STANDING! | two lines |
| petdown | failure | pet-down | PET DOWN! | add a tiny paw print |

### P1b — the new Arcade and Moments events (text only today)

| Event (KAPOW) | Category | Message file | `{WORD}` | Note |
|---|---|---|---|---|
| countgo | arcade | fight | FIGHT! | same file as P2 `fight` |
| duelstart | arcade | round-1-fight | ROUND 1 ... FIGHT! | two lines |
| duelwin | arcade | you-win | YOU WIN | same file as P2 `you-win` |
| duellose | arcade | you-lose | YOU LOSE | same file as P2 `you-lose` |
| bosspull | arcade | round-1-fight | ROUND 1 ... FIGHT! | shares duelstart's art |
| assist | tactical | assist | ASSIST! | blue accents, two hands high-fiving silhouette |
| record | arcade | new-record | NEW RECORD! | gold, small trophy |
| achievement | comic | achievement | ACHIEVEMENT! | gold shield shape behind |
| epicloot | comic | epic-loot | EPIC LOOT! | purple glow, treasure sparkle |
| quest | comic | quest-complete | QUEST COMPLETE! | parchment-yellow accents |
| honorkill | arena | honorable-kill | HONORABLE KILL! | red, crossed swords |
| (FINISH IT! overlay) | arcade | finish-it | FINISH IT! | for a future art version of the overlay |

### P2 — Roadfighter set (Street Fighter vibes)

All in the **arcade** category (cream-yellow slanted brush lettering, red-orange flames). Used by the Roadfighter
theme: ROUND and FIGHT on fight start, YOU WIN / YOU LOSE on fight end, K.O. on kills.

| Message file | `{WORD}` | Use |
|---|---|---|
| round-1 | ROUND 1 | fight start |
| round-2 | ROUND 2 | fight start (second fight) |
| final-round | FINAL ROUND | fight start when low health (future) |
| fight | FIGHT! | fight start |
| ko | K.O. | kill (arcade version of comic K.O.!) |
| double-ko | DOUBLE K.O. | two kills at once |
| you-win | YOU WIN | fight end |
| you-lose | YOU LOSE | you died |
| time-over | TIME OVER | fight ended with no kills |
| great | GREAT! | crit |
| excellent | EXCELLENT! | crit kill |

### P3 — rounding out each category

| Category | Message file | `{WORD}` | Fits event |
|---|---|---|---|
| comic | kapow | KAPOW! | crit kill (the addon's own name; top pick) |
| comic | bam | BAM! | crit |
| comic | thwack | THWACK! | kill |
| comic | blam | BLAM! | double kill |
| anime | finish | FINISH! | kill |
| anime | overdrive | OVERDRIVE! | spree |
| anime | one-hit | ONE HIT! | crit kill |
| ninja | slice | SLICE! | crit |
| ninja | vanish | VANISH! | interrupt |
| ninja | assassinated | ASSASSINATED! | kill |
| arena | humiliation | HUMILIATION! | kill with a low hit |
| arena | impressive | IMPRESSIVE! | crit |
| arena | excellent | EXCELLENT! | double kill |
| failure | oops | OOPS! | interrupted |
| failure | denied | DENIED! | interrupted |
| failure | miss | MISS! | dodge / parry |
| tactical | enemy-down | ENEMY DOWN! | kill |
| tactical | round-won | ROUND WON! | fight end |
| tactical | round-lost | ROUND LOST! | wipe |
| football | kick-off | KICK-OFF! | fight start |
| football | full-time | FULL TIME! | fight end |
| football | penalty | PENALTY! | interrupted |
| football | yellow-card | YELLOW CARD! | dodge / parry |
| football | screamer | SCREAMER! | crit kill |
| falling | splashdown | SPLASHDOWN! | landing in water |
| falling | oof | OOF! | hard landing |
| falling | crater | CRATER! | fell to death |

---

## Part 2 — Sounds

### Delivery spec (every file)

- **Master:** 48 kHz, 24-bit WAV, kept outside the addon.
- **Delivered to the addon:** Ogg Vorbis, quality 7 (about 224 kbps), 48 kHz; mono for voice, stereo allowed for
  effects. WoW plays `.ogg` and `.mp3`.
- **Loudness:** about −14 LUFS integrated, true peak no higher than −1 dBTP. All files in a pool level-matched.
- **Length:** 0.4–2.5 s. Leading silence under 20 ms, 30 ms fade-out, reverb tail under 400 ms.
- **Variants:** 3–5 per pool, so the random pick does not repeat. Name them `<pool>_01.ogg`, `<pool>_02.ogg` …
- **Install:** put them in `Kapow/Sounds/<pool>/` (optional `label.txt` with the pool's name), then run
  `python3 scripts/make-sound-catalog.py`. Each pool becomes "Random: …" in every Sound menu; the pools
  `fightstart`, `victory` and `alert` join the game-sound pools KAPOW already has.
- **Originality:** original voices and effects only. Describe a style ("1990s Japanese arcade fighting-game
  announcer"); do not imitate or clone a real announcer, actor or game's recorded lines.

### Voice direction: Roadfighter announcer (Street Fighter vibes)

> Original male announcer for a 1990s Japanese arcade fighting game. Deep, booming, very energetic, shouted at full
> power into a vintage arcade cabinet microphone. Strong Japanese-English accent with clipped, staccato syllables
> ("FAI-TO!", "RAUN-DO WAN"). Slight tape saturation and 12-bit sampler grit, short bright room reverb. No music.

### Pools

| Pool folder | Used by (event, theme) | Variants | Prompt |
|---|---|---|---|
| fightstart | Fight start (`random:fightstart`, Roadfighter, Strike Squad) | 5 | Roadfighter announcer shouting "FIGHT!" ("FAI-TO!"), one word, explosive attack, 0.6–0.9 s. Variants: plain, extra long vowel, with a quick drum hit, with a crowd gasp, double "FIGHT! FIGHT!" |
| round | Fight start, before FIGHT (future: "ROUND 1 … FIGHT!") | 4 | Roadfighter announcer: "ROUND ONE", "ROUND TWO", "ROUND THREE", "FINAL ROUND". Dramatic pause shape, 1.0–1.4 s each |
| ko | Killing blow (Roadfighter theme) | 4 | Roadfighter announcer: "K.O.!" shouted with a heavy echo, plus a deep cinematic boom under it, 1.2–1.8 s |
| perfect | Flawless, crit kill | 3 | Roadfighter announcer: "PERFECT!" triumphant, rising pitch, 0.8–1.2 s |
| victory | Fight end (`random:victory`) | 4 | Roadfighter announcer: "YOU WIN!" with a short 8-bit style victory sting under it (original melody), 1.5–2.5 s |
| youlose | You died | 3 | Roadfighter announcer: "YOU LOSE…" low, disappointed, with a descending synth tone, 1.2–1.8 s |
| arena-firstblood | First blood | 3 | Original deep gritty arena-shooter announcer, distorted metal-PA voice: "FIRST BLOOD!", 0.8–1.2 s |
| arena-multikill | Double … ludicrous kill (one pool per word, or one mixed pool) | 3 each | Same arena announcer: "DOUBLE KILL!", "TRIPLE KILL!", "MULTI KILL!", "MEGA KILL!", "ULTRA KILL!", "MONSTER KILL!", "LUDICROUS KILL!" — rising intensity with the number |
| arena-spree | Killing spree … wicked sick | 3 each | Same arena announcer: "KILLING SPREE!", "RAMPAGE!", "DOMINATING!", "UNSTOPPABLE!", "GODLIKE!", "WICKED SICK!" |
| mvp | MVP | 3 | Stadium announcer: "M-V-P!" over a short crowd cheer, 1.0–1.6 s |
| interrupt | You interrupted (NOPE streaks) | 4 | Cartoon "nope" effects: a sharp record-scratch stop, a buzzer "eh-eh", a quick slide-whistle up, a punchy "denied" stamp thud. 0.3–0.6 s, no voice |
| interrupted | You were interrupted | 3 | Comic fail sting: short sad-trombone "wah-wah" (two notes), a deflating balloon, a cartoon bonk. 0.5–0.9 s |
| comic-hit | Crit / kill hit sounds (Experimental tab) | 5 | Comic-book punch effects: meaty cartoon punch with a whoosh, a "pow" thump with a cymbal tick, a rubbery smack. 0.2–0.4 s, punchy transient, no voice |
| falling | Falling / hard landing / fell to death | 4 | Descending cartoon slide whistle (1.2 s), a wobbly "boing" landing, a wet cartoon splat, a heavy thud with comedic debris |
| football | Soccer League theme | 4 | Referee whistle (short, long), stadium crowd "GOAL!" roar burst, crowd "ooh" near-miss. 0.6–2.0 s |
| tactical | Strike Squad theme | 4 | Radio-filtered squad callouts by an original voice: "ENEMY DOWN!", "GO GO GO!", "TEAMMATE DOWN!", with radio squelch on and off |
| alert | Last one standing, wipe (`random:alert`) | 3 | Tense warning stingers: low brass hit with a heartbeat, a rising siren swell, a taiko double hit. 0.8–1.5 s |
| countdown | Countdown 3, 2, 1 (Arcade) | 3 | Roadfighter announcer: "THREE", "TWO", "ONE", tight and punchy, 0.4–0.6 s each (one file per number, named 3/2/1) |
| combo | Combo banner | 4 | Roadfighter announcer: "COMBO!", "SUPER COMBO!", "ULTRA COMBO!", "C-C-C-COMBO BREAKER" style stutter (original wording), 0.7–1.2 s |
| record | New personal record | 3 | Bright arcade "NEW RECORD!" voice over a rising chiptune arpeggio (original), 1.0–1.6 s |
| finishit | FINISH IT! overlay (future sound) | 3 | Deep menacing announcer: "FINISH IT!" with reverb tail, 0.8–1.2 s |
| uwu | UwU mode on crits (Experimental tab › UwU sound) | 6 | Original cute, playful anime-style voice (adult performer, light and bubbly, not childlike): "uwu~", "owo~", "ara ara~", "nya~", "kawaii~", "rawr x3". Soft breathy attack, a little giggle on one variant, 0.4–0.9 s, tiny sparkle chime under two variants |

### Sound prompt template

```text
Create a short, high-fidelity game sound effect.
Purpose: {what it announces, e.g. "the start of a fight in a fighting-game themed combat popup addon"}.
Content: {exact words or effect}.
Voice / style: {voice direction above, or effect description}.
Length: {seconds}. Clean start (no silence), quick 30 ms fade-out, short tail.
Mix: loud and present, no background music, no clipping, true peak below -1 dBTP.
Deliver as 48 kHz 24-bit WAV, mono for voice, stereo for effects.
Original voice and sound design; do not imitate any existing game, announcer or actor.
```
