import json,sys
from pathlib import Path
BULK=Path(__file__).resolve().parent
folder=BULK.parent/sys.argv[1]
observations=json.loads(sys.argv[2])
p=folder/'validation.json';v=json.loads(p.read_text());v.update(expected_sources=len(json.loads((folder/'prompts.json').read_text())),actual_sources=len(list((folder/'_sources').glob('*/*.png'))),observations=observations,verification_scope='One normal offline export/visual check; no in-game verification, no installation, no retries.')
p.write_text(json.dumps(v,indent=2))
p=folder/'progress.json';d=json.loads(p.read_text());d.update(status='waiting_for_bulk_review',approval_status='pending',review_sheet='_previews/review-sheet.png');p.write_text(json.dumps(d,indent=2))
p=BULK/'progress.json';d=json.loads(p.read_text());keys={e['key'] for e in json.loads((folder/'manifest.json').read_text())['entries']}
for e in d['entries']:
    if e['key'] in keys:e.update(status='exported',manifest=str(folder/'manifest.json'))
d['exported_messages']=sum(e['status']=='exported' for e in d['entries']);d['exported_frames']=3*d['exported_messages'];d['current_completed_batch']=folder.name;p.write_text(json.dumps(d,indent=2))
print(json.dumps({'batch':folder.name,'batch_frames':v['actual_frames'],'exported_messages':d['exported_messages'],'exported_frames':d['exported_frames'],'all_basic_checks_pass':v['all_passed']}))
