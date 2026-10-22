"""Isolated mechanical export; no generation, installation or source edits."""
import json,sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(sys.argv[1]).resolve()
entries = json.loads((BASE / 'prompts.json').read_text())
progress_path = BASE / 'progress.json'
progress = json.loads(progress_path.read_text())
out = BASE / 'escalation'
preview = BASE / '_previews'
out.mkdir(exist_ok=True)
preview.mkdir(exist_ok=True)
sheet = Image.new('RGB', (1024, 100+280*len(entries)), '#272c34')
draw = ImageDraw.Draw(sheet)
font_path = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
font = ImageFont.truetype(font_path, 21)
small = ImageFont.truetype(font_path, 17)
for index, label in enumerate(['ONSET', 'PEAK', 'AFTERSHOCK']):
    draw.text((210 + index * 266 + 128, 30), label, fill='#eeeeee', font=font, anchor='mm')
checks = []
for row, entry in enumerate(entries):
    name = entry['name']
    category = entry['category']
    (BASE / category).mkdir(exist_ok=True)
    source_rel = '_sources/' + category + '/' + name + '.png'
    source = Image.open(BASE / source_rel)
    source.load()
    w, h = source.size
    frames = []
    draw.text((18, 88 + row * 280), entry['word'].replace(' ', '\n'), fill='#eeeeee', font=font, spacing=5)
    for frame_index in range(3):
        # Fixed proportional thirds preserve the original anchors and scale.
        cell = source.convert('RGBA').crop((round(frame_index*w/3), 0, round((frame_index+1)*w/3), h))
        scale = min(248 / cell.width, 248 / cell.height)
        size = (round(cell.width * scale), round(cell.height * scale))
        cell = cell.convert('RGBa').resize(size, Image.Resampling.LANCZOS).convert('RGBA')
        frame = Image.new('RGBA', (256, 256))
        frame.alpha_composite(cell, ((256-cell.width)//2, (256-cell.height)//2))
        rel = category + '/' + name + '_' + str(frame_index+1) + '.tga'
        frame.save(BASE / rel, compression=None)
        frames.append(rel)
        frame.save(preview / (name + '_' + str(frame_index+1) + '.png'))
        x, y = 210 + frame_index*266, 64 + row*280
        bg = Image.new('RGBA', (256,256), '#353c47')
        bg.alpha_composite(frame)
        sheet.paste(bg.convert('RGB'), (x,y))
        draw.rectangle((x,y,x+255,y+255), outline='#4c5562')
        actual = Image.open(BASE / rel)
        header = (BASE / rel).read_bytes()[:18]
        alpha = actual.getchannel('A')
        checks.append({'file':rel, 'size':list(actual.size), 'mode':actual.mode,
                       'tga_image_type':header[2], 'bits_per_pixel':header[16],
                       'alpha_extrema':list(alpha.getextrema()),
                       'transparent_pixel_count':alpha.histogram()[0],
                       'nontransparent_bbox':actual.getbbox(),
                       'pass':actual.size==(256,256) and actual.mode=='RGBA' and header[2]==2 and header[16]==32 and alpha.getextrema()[0]==0 and alpha.getextrema()[1]>0})
    entry.update(key=category+'/'+name, status="exported", source=source_rel, source_size=[w,h], frames=frames,
                 frame_order=['onset','peak','aftershock'], approval_status='pending')
    progress['entries'][row].update(status='exported', source=source_rel, frames=frames)
    progress['status'] = 'exporting'
    progress_path.write_text(json.dumps(progress, indent=2))
sheet.save(preview / 'review-sheet.png')
(BASE / 'manifest.json').write_text(json.dumps({'batch':BASE.name, 'approval_status':'pending', 'installed':False, 'entries':entries}, indent=2))
(BASE / 'validation.json').write_text(json.dumps({'check':'one basic isolated export validation', 'expected_frames':3*len(entries), 'actual_frames':len(checks), 'all_passed':len(checks)==3*len(entries) and all(x['pass'] for x in checks), 'files':checks, 'observations':'Visual inspection pending; offline format validation only, no in-game verification.'}, indent=2))
progress['status']='awaiting_bulk_visual_read'
progress_path.write_text(json.dumps(progress, indent=2))
print(json.dumps({'sources':len(entries), 'frames':len(checks), 'all_passed':all(x['pass'] for x in checks), 'review_sheet':str(preview/'review-sheet.png')}))
