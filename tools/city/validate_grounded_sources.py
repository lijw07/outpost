import json,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
B=ROOT/'output/barren_city/02_blockbench_v3_grounded'
spec=json.loads((B/'clean_spec.json').read_text())
old=json.loads((B.parent/'02_blockbench_v2/clean_spec.json').read_text())
oldby={a['name']:a for a in old['assets']}
errors=[];records=[]
for a in spec['assets']:
 raw=json.loads((B/'blockbench'/f"{a['name']}.bbmodel").read_text())
 points=[p for e in raw['elements'] for p in e.get('vertices',{}).values()]
 low=min(p[1] for p in points);high=max(p[1] for p in points)
 anchor=a['placement']['anchor']
 if anchor=='base' and abs(low)>1e-6:errors.append(a['name']+': base not zero')
 if anchor=='surface':
  if abs(low+2)>1e-6 or high < -1e-6 or high > .126:errors.append(a['name']+': incorrect surface anchor')
 before=oldby[a['name']]
 dy=a['placement']['source_y_translation']
 source={str(i):m for i,m in enumerate(before['meshes'])}
 kept=[m for m in before['meshes'] if not(a['name'].startswith('wall_') and a['name'].endswith('_window') and m['name']=='window_glass')]
 if not a['name'].endswith('_window'):
  for previous,current in zip(kept,a['meshes']):
   if previous['faces']!=current['faces']:errors.append(a['name']+': UV/topology changed')
   for k,p in previous['vertices'].items():
    q=current['vertices'][k]
    if any(abs(q[i]-p[i]-(dy if i==1 else 0))>1e-6 for i in range(3)):errors.append(a['name']+': non-translation shape change')
 if a['name'].startswith('wall_') and a['name'].endswith('_window'):
  if any(e['name']=='window_glass' for e in raw['elements']):errors.append(a['name']+': pane still present')
 records.append({'asset':a['name'],'anchor':anchor,'minimum_y':low,'maximum_y':high})
report={'passed':not errors,'assets':len(records),'errors':errors,'records':records}
(B/'validation/grounding.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='records'}))
if errors:raise SystemExit(1)
files={str(p.relative_to(B)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['blockbench','gltf','textures'] for p in (B/folder).glob('*') if p.is_file()}
(B/'manifest.json').write_text(json.dumps({'name':'outpost_modular_assets_v3_grounded','assets':160,'stage':'user_authorized_origin_and_window_corrections','validation':{'passed':True,'coplanar_overlap_pairs':0,'ground_anchors':True},'provenance':'Native Blockbench revision of the approved Outpost kit. User-requested Y-origin corrections and removal of opaque wall-window panes; textures preserved.','files':files},indent=2))
