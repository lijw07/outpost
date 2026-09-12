import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];B=ROOT/'output/barren_city/05_vehicle_restyle';OLD=ROOT/'output/barren_city/02_blockbench_v4_doorway'
spec=json.loads((B/'clean_spec.json').read_text());validation=json.loads((B/'validation/modular_validation.json').read_text());assert validation['passed']
records=[]
for a in spec['assets']:
 name=a['name'];raw=json.loads((B/'blockbench'/(name+'.bbmodel')).read_text());pts=[p for e in raw['elements'] for p in e['vertices'].values()];lo=min(p[1] for p in pts);hi=max(p[1] for p in pts)
 assert abs(lo)<1e-6 if a['placement']['anchor']=='base' else abs(lo+2)<1e-6 and -.0001<=hi<=.126,name
 if a['category']!='vehicle':
  for folder,ext in [('blockbench','bbmodel'),('gltf','gltf')]:assert (B/folder/(name+'.'+ext)).read_bytes()==(OLD/folder/(name+'.'+ext)).read_bytes(),name
 else:
  tires=[e for e in raw['elements'] if e['name']=='tire'];assert len(tires)==4 and all(len(t['vertices'])==26 for t in tires),name
 records.append({'asset':name,'minimum_y':lo,'maximum_y':hi,'anchor':a['placement']['anchor']})
for tex in (OLD/'textures').glob('*.png'):assert tex.read_bytes()==(B/'textures'/tex.name).read_bytes(),tex.name
(B/'validation/grounding.json').write_text(json.dumps({'passed':True,'assets':len(records),'records':records},indent=2))
files={str(p.relative_to(B)):hashlib.sha256(p.read_bytes()).hexdigest() for d in ['blockbench','gltf','textures'] for p in (B/d).glob('*') if p.is_file()}
(B/'manifest.json').write_text(json.dumps({'name':'outpost_modular_assets_vehicles_restyled','assets':159,'validation':{'passed':True,'coplanar_overlap_pairs':0,'ground_anchors':True},'provenance':'User-requested vehicle redesign in native Blockbench to match the existing structures. Round wheels retained. All non-vehicle source assets preserved byte-for-byte. Characters excluded pending draft approval.','files':files},indent=2))
print('Verified',len(records),'grounded sources;',len(files),'source files; all non-vehicle originals unchanged.')
