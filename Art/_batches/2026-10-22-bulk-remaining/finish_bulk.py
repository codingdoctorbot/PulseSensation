import json,math,textwrap
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
BULK=Path(__file__).resolve().parent
plan=json.loads((BULK/'plan.json').read_text())
entries=[];batch_records=[];issues=[]
for batch in plan['batches']:
    folder=BULK.parent/batch['directory']
    manifest=json.loads((folder/'manifest.json').read_text())
    validation=json.loads((folder/'validation.json').read_text())
    for e in manifest['entries']:
        e.update(batch_manifest=str(folder/'manifest.json'),source_absolute=str(folder/e['source']),frames_absolute=[str(folder/f) for f in e['frames']])
        entries.append(e)
    batch_records.append({'batch':folder.name,'manifest':str(folder/'manifest.json'),'validation':str(folder/'validation.json'),
         'review_sheet':str(folder/'_previews/review-sheet.png'),'message_count':validation['actual_sources'],'frame_count':validation['actual_frames'],
         'all_basic_checks_passed':validation['all_passed'],'observations':validation['observations']})
    issues.append({'batch':folder.name,'observations':validation['observations']})
assert len(entries)==33
assert sum(b['frame_count'] for b in batch_records)==99
preview=BULK/'_previews';preview.mkdir(exist_ok=True)
cols=6;cw=270;rh=310
board=Image.new('RGB',(cols*cw,70+math.ceil(len(entries)/cols)*rh),'#272c34')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',17)
title=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',25)
draw.text((20,17),'33 NEW BANNERS — PEAK FRAMES — PENDING BULK APPROVAL',font=title,fill='#eeeeee')
for i,e in enumerate(entries):
    x=7+(i%cols)*cw;y=65+(i//cols)*rh
    rgba=Image.open(e['frames_absolute'][1]).convert('RGBA')
    bg=Image.new('RGBA',(256,256),'#353c47');bg.alpha_composite(rgba)
    board.paste(bg.convert('RGB'),(x,y))
    draw.rectangle((x,y,x+255,y+255),outline='#4c5562')
    label=e['word']+'\n'+e['category']+' / batch '+e['batch'][-2:]
    draw.multiline_text((x+4,y+260),label,font=font,fill='#eeeeee',spacing=2)
board.save(preview/'bulk-peaks.png')
manifest={'approval_status':'pending','installed':False,'message_count':33,'frame_count':99,'frame_size':[256,256],
          'generator_mode':'built-in image_gen with inspected references','batches':batch_records,'entries':entries,
          'review_board':str(preview/'bulk-peaks.png'),'review_index':str(BULK/'review-index.md')}
(BULK/'manifest.json').write_text(json.dumps(manifest,indent=2))
validation={'expected_messages':33,'actual_messages':sum(b['message_count'] for b in batch_records),
            'expected_frames':99,'actual_frames':sum(b['frame_count'] for b in batch_records),'batch_sheet_count':len(batch_records),
            'all_basic_checks_passed':all(b['all_basic_checks_passed'] for b in batch_records),
            'method':'Aggregate existing one-pass batch checks, no repeated asset validation or live-game claims.',
            'known_issues':issues,'installed':False,'approval_status':'pending'}
(BULK/'validation.json').write_text(json.dumps(validation,indent=2))
index=['# Bulk artwork review — 33 messages / 99 frames','',
       '[Peak overview]('+str(preview/'bulk-peaks.png')+')','',
       'All seven full sheets show onset, peak and aftershock. Nothing from this bulk set has been copied into the addon.','']
for b in batch_records:
    index.append('- ['+b['batch']+' — '+str(b['message_count'])+' messages]('+b['review_sheet']+')')
index+=['','## Known issues','',
        '- Some peak effects exceed the requested central70percent safe area; minor generated glyph/anchor drift remains possible.',
        '- Batch08 THWACK adds a starburst behind the swoosh.',
        '- Batch09 ONE HIT/OVERDRIVE use more burst fragments than requested; SLICE adds a crimson ring.',
        '- Batch10 ASSASSINATED is small at256; HUMILIATION is hotter/oranger than the subdued rust direction.',
        '- Batch11 DENIED is more comic starburst than stamp; MISS peak is more energetic than anticlimactic.',
        '- Batch12 PENALTY is a generic orange flash rather than a clear goal-line cue.',
        '- All exact phrases were visually read in each full sheet; no apparent word clipping or cross-cell debris observed.','',
        '[Aggregate manifest]('+str(BULK/'manifest.json')+') · [Validation notes]('+str(BULK/'validation.json')+')','']
(BULK/'review-index.md').write_text('\n'.join(index))
p=BULK/'progress.json';d=json.loads(p.read_text());d.update(status='waiting_for_bulk_review',approval_status='pending',installed=False,
    exported_messages=33,exported_frames=99,completed_batches=7,review_board='_previews/bulk-peaks.png',review_index='review-index.md');p.write_text(json.dumps(d,indent=2))
print(json.dumps({'messages':33,'frames':99,'batch_sheets':7,'all_basic_checks_passed':validation['all_basic_checks_passed'],
                  'board':str(preview/'bulk-peaks.png'),'index':str(BULK/'review-index.md')}))
