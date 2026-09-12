import copy,json,shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'output/barren_city/02_blockbench_v2'
NEW=ROOT/'output/barren_city/02_blockbench_v3_grounded'
SURFACES={'road_asphalt','road_lane','road_crossing','sidewalk','gravel','dirt','grass','sand'}
def surface(name):return name.startswith('floor_') or name in SURFACES
for folder in ['blockbench','gltf','textures','review','tools','validation']:
 (NEW/folder).mkdir(parents=True,exist_ok=True)
clean=json.loads((OLD/'clean_spec.json').read_text())
raw=json.loads((OLD/'asset_spec.json').read_text())
offsets={};report=[]
for a in clean['assets']:
 points=[p for m in a['meshes'] for p in m['vertices'].values()]
 low=min(p[1] for p in points)
 if a['name'].startswith('wall_') and a['name'].endswith('_window'):
  a['meshes']=[m for m in a['meshes'] if m['name']!='window_glass']
 dy=-2 if surface(a['name']) else -low
 offsets[a['name']]=dy
 for m in a['meshes']:
  for p in m['vertices'].values():p[1]+=dy
 a['placement']={'origin':'walking surface at Y=0' if surface(a['name']) else 'lowest support at Y=0','anchor':'surface' if surface(a['name']) else 'base','units_per_tile':32,'texture_pixels_per_unit':1,'source_y_translation':dy}
 if a['name'].startswith('wall_') and a['name'].endswith('_window'):a['placement']['open_window']=True
 if a['name'].startswith('door_'):a['placement']['hinge']=[-9,0,0];a['placement']['opening_units']=[20,29]
 if surface(a['name']):a['placement']['top_surface_y']=0
 report.append({'name':a['name'],'anchor':a['placement']['anchor'],'old_min_y':low,'translation_y':dy,'new_min_y':low+dy})
by={a['name']:a for a in clean['assets']}
for a in raw['assets']:
 dy=offsets[a['name']]
 if a['name'].startswith('wall_') and a['name'].endswith('_window'):
  a['cubes']=[c for c in a['cubes'] if c['name']!='window_glass']
 for b in a.get('cubes',[]):b['from'][1]+=dy;b['to'][1]+=dy
 for m in a.get('meshes',[]):
  for p in m['vertices'].values():p[1]+=dy
 a['placement']=copy.deepcopy(by[a['name']]['placement'])
for name,data in [('clean_spec.json',clean),('asset_spec.json',raw)]:
 (NEW/name).write_text(json.dumps(data,separators=(',',':')))
for name in ['build_in_blockbench.js','capture_in_blockbench.js','clean_surfaces.py']:
 text=(OLD/'tools'/name).read_text().replace(str(OLD),str(NEW))
 (NEW/'tools'/name).write_text(text)
(NEW/'validation/grounding_changes.json').write_text(json.dumps(report,indent=2))
print('Ground anchor changes:',[(r['name'],r['translation_y']) for r in report if r['translation_y']])

import subprocess
subprocess.run(['python3',str(NEW/'tools/clean_surfaces.py')],check=True)
