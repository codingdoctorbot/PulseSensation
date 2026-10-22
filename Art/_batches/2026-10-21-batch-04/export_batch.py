"""Isolated mechanical export of batch 04, preserving source coordinates."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
entries = json.loads((BASE/'prompts.json').read_text())
progress_path = BASE/'progress.json'
progress = json.loads(progress_path.read_text())
preview = BASE/'_previews'
preview.mkdir(exist_ok=True)
sheet = Image.new('RGB', (1024,1780), '#272c34')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',21)
small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',17)
for i, label in enumerate(['ONSET','PEAK','AFTERSHOCK']):
    draw.text((338+i*266,30),label,fill='#eeeeee',font=font,anchor='mm')
checks, source_checks = [], []
for row, entry in enumerate(entries):
    name, category, dim = entry['name'], entry['category'], entry['frame_size']
    (BASE/category).mkdir(exist_ok=True)
    source_rel = '_sources/'+category+'/'+name+'.png'
    source = Image.open(BASE/source_rel)
    source.load()
    w,h=source.size
    native_ok = min(w/3,h)>=dim
    source_checks.append({'source':source_rel,'size':[w,h],'native_cell_size':[w/3,h],
                          'required_native_cell_size':dim,'native_resolution_pass':native_ok})
    label=entry['word'].replace(' ','\n')
    draw.text((18,88+row*280),label,fill='#eeeeee',font=font,spacing=4)
    if name=='versus':
        draw.text((18,135+row*280),'512x512',fill='#bfcbe0',font=small)
    frames=[]
    for index in range(3):
        cell=source.convert('RGBA').crop((round(index*w/3),0,round((index+1)*w/3),h))
        inner=496 if dim==512 else 248
        scale=min(inner/cell.width,inner/cell.height)
        cell=cell.convert('RGBa').resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
        frame=Image.new('RGBA',(dim,dim))
        frame.alpha_composite(cell,((dim-cell.width)//2,(dim-cell.height)//2))
        rel=category+'/'+name+'_'+str(index+1)+'.tga'
        frame.save(BASE/rel,compression=None)
        frame.save(preview/(name+'_'+str(index+1)+'.png'))
        frames.append(rel)
        thumbnail=frame.convert('RGBa').resize((256,256),Image.Resampling.LANCZOS).convert('RGBA')
        bg=Image.new('RGBA',(256,256),'#353c47')
        bg.alpha_composite(thumbnail)
        x,y=210+index*266,64+row*280
        sheet.paste(bg.convert('RGB'),(x,y))
        draw.rectangle((x,y,x+255,y+255),outline='#4c5562')
        actual=Image.open(BASE/rel)
        header=(BASE/rel).read_bytes()[:18]
        alpha=actual.getchannel('A')
        checks.append({'file':rel,'expected_size':[dim,dim],'size':list(actual.size),'mode':actual.mode,
            'tga_image_type':header[2],'bits_per_pixel':header[16],'alpha_extrema':list(alpha.getextrema()),
            'transparent_pixel_count':alpha.histogram()[0],'nontransparent_bbox':actual.getbbox(),
            'pass':actual.size==(dim,dim) and actual.mode=='RGBA' and header[2]==2 and header[16]==32 and alpha.getextrema()[0]==0 and alpha.getextrema()[1]>0})
    entry.update(status='exported',source=source_rel,source_size=[w,h],native_cell_size=[w/3,h],frames=frames,
                 frame_order=['onset','peak','aftershock'],approval_status='pending')
    progress['entries'][row].update(status='exported',source=source_rel,frames=frames)
    progress['status']='exporting'
    progress_path.write_text(json.dumps(progress,indent=2))
sheet.save(preview/'review-sheet.png')
(BASE/'manifest.json').write_text(json.dumps({'batch':'2026-10-21-batch-04','approval_status':'pending','installed':False,'entries':entries},indent=2))
(BASE/'validation.json').write_text(json.dumps({'check':'one basic isolated export validation','expected_sources':6,'actual_sources':len(source_checks),
    'expected_frames':18,'actual_frames':len(checks),'source_checks':source_checks,'files':checks,
    'all_passed':len(checks)==18 and len(source_checks)==6 and all(x['pass'] for x in checks) and all(x['native_resolution_pass'] for x in source_checks),
    'observations':'Visual read pending; no in-game verification.'},indent=2))
progress['status']='awaiting_visual_read'
progress_path.write_text(json.dumps(progress,indent=2))
print(json.dumps({'sources':len(source_checks),'frames':len(checks),'format_pass':all(x['pass'] for x in checks),
    'native_resolution_pass':all(x['native_resolution_pass'] for x in source_checks),'versus_source':source_checks[-1],'review_sheet':str(preview/'review-sheet.png')}))
