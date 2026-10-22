import json,sys,shutil,fcntl
from pathlib import Path
BULK=Path(__file__).resolve().parent
batch,name,generated=sys.argv[1:]
folder=BULK.parent/batch
entries=json.loads((folder/'prompts.json').read_text())
entry=next(e for e in entries if e['name']==name)
dest=folder/entry['planned_source'];dest.parent.mkdir(parents=True,exist_ok=True)
if generated!='GENERATING':
    if dest.exists():raise RuntimeError('Refusing source overwrite: '+str(dest))
    shutil.copy2(generated,dest)
    (folder/(name+'-generation.json')).write_text(json.dumps({'generated_path':generated,'source':entry['planned_source'],'status':'source_saved'},indent=2))
status='generating' if generated=='GENERATING' else 'source_saved'
with (BULK/'progress.lock').open('w') as lock:
    fcntl.flock(lock,fcntl.LOCK_EX)
    for path in [folder/'progress.json',BULK/'progress.json']:
        d=json.loads(path.read_text());e=next(e for e in d['entries'] if e['key']==entry['key']);e.update(status=status)
        if generated!='GENERATING':e.update(source=entry['planned_source'],generated_path=generated)
        d['status']='generating';path.write_text(json.dumps(d,indent=2))
print(json.dumps({'key':entry['key'],'status':status}))
