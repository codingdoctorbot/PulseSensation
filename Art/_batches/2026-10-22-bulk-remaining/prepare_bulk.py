import json,re
from pathlib import Path
BULK=Path(__file__).resolve().parent
ROOT=BULK.parents[2]
plan=json.loads((BULK/'plan.json').read_text())
brief=(BULK/'BRIEF.md').read_text()
refs=json.loads((BULK/'references.json').read_text())
directions={m.group(1):m.group(2) for m in re.finditer(r'^- ([a-z]+/[a-z-]+) — (.+)$',brief,re.M)}
common='''Use case: stylized-concept.
Asset type: transparent combat-popup three-frame animation strip for World of Warcraft addon.
Inputs are inspected category TYPOGRAPHY, MATERIAL and FRAME STRUCTURE references ONLY, NOT edit targets; do not copy their words, unwanted hues or oversized effect shapes. Apply the NEW wording and palette/silhouette below. Category typography must remain distinct, no identical recolored fireballs.
ONE horizontal3:1 strip, exactly THREE equal SQUARE cells in ONE row, ideally1536x512 or higher. Left onset / middle peak / right aftershock. Each cell has FULL EXACT wordmark, identical glyphgeometry, font, scale, angle, opaque letters and centered50%/50% anchor. Full readable wordmark allframes. Generate three original coherent ART states; animate surrounding effects, never software-scaled/rotated/faded copies. Onset restrained compact effects; peak brighter fuller but compact; aftershock dispersed diminishing effects. Lettering unchanged.
Genuine TRANSPARENT ALPHA, antialiased lettering edges and translucent effects edges. No painted checkerboard/background, grid, labels, frame numbers, scenery, actual characters, official logos, watermarks or extra words. Small abstract silhouettes specifically requested below are allowed.
CRITICAL: ALL art including EVERY effect fits CENTRAL70% width/height of its own cell. Make it SMALLER than reference art; wordmark about60% cellwidth, fully empty15% gutters on EVERY side including peak. Few compact bold strokes, NO cross-cell particles, overlap, clipping or detached border fragments. Clear readability at256. Two-word phrases may stack on TWO centered lines when useful.
'''
all_entries=[]
for batch in plan['batches']:
    folder=BULK.parent/batch['directory'];folder.mkdir(exist_ok=True)
    entries=[]
    for e in batch['entries']:
        assert e['key'] in directions,e['key']
        item={**e,'batch':batch['directory'],'frame_size':[256,256],
              'prompt':common+'\nVisual direction: '+directions[e['key']]+'\nText VERBATIM in ALL THREE cells: "'+e['word']+'". Exact spelling and punctuation mandatory.',
              'references':refs[e['category']], 'reference_roles':['category typography/material/frame structure only; not edit target; explicit palette override']*len(refs[e['category']]),
              'generator_mode':'built-in image_gen with inspected local category references','approval_status':'pending','installed':False,'status':'planned',
              'planned_source':'_sources/'+e['category']+'/'+e['name']+'.png'}
        entries.append(item);all_entries.append(item)
    if not (folder/'prompts.json').exists():
        (folder/'prompts.json').write_text(json.dumps(entries,indent=2))
        (folder/'progress.json').write_text(json.dumps({'status':'planned','approval_status':'pending','entries':[{k:e[k] for k in ['key','category','name','status','planned_source']} for e in entries]},indent=2))
if not (BULK/'entries.json').exists():(BULK/'entries.json').write_text(json.dumps(all_entries,indent=2))
if not (BULK/'progress.json').exists():(BULK/'progress.json').write_text(json.dumps({'status':'generating','approval_status':'pending','expected_messages':33,'expected_frames':99,'entries':[{k:e[k] for k in ['key','batch','status','planned_source']} for e in all_entries]},indent=2))
print(json.dumps({'prepared':len(all_entries),'batches':len(plan['batches'])}))
