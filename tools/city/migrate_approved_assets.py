import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'output/barren_city/09_terrain_blocks'
DEST=ROOT/'assets/models/city'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((SOURCE/'manifest.json').read_text())
prior=json.loads((DEST/'source.lock.json').read_text()).get('files',{}) if (DEST/'source.lock.json').exists() else {}
assert manifest['validation']['passed'] and manifest['assets']==159
spec=json.loads((SOURCE/'clean_spec.json').read_text())
retired={a['name'] for a in spec['assets'] if a.get('placement',{}).get('terrain_block',False)}
manifest['files']={rel:sha for rel,sha in manifest['files'].items() if not (Path(rel).parent.name in ['gltf','blockbench'] and Path(rel).stem in retired)}
for rel,sha in manifest['files'].items():
 source=SOURCE/rel;target=DEST/rel
 assert source.is_file() and digest(source)==sha,rel
 assert not target.is_symlink(),target
 if target.exists():assert digest(target) in [sha,prior.get(rel)],'Destination was edited: '+str(target)
for rel,sha in manifest['files'].items():
 target=DEST/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(SOURCE/rel,target)
 assert digest(target)==sha,rel
(DEST/'blockbench/.gdignore').touch()
spec=json.loads((SOURCE/'clean_spec.json').read_text())
catalog=[]
for a in spec['assets']:
 if a['name'] in retired:continue
 points=[p for m in a['meshes'] for p in m['vertices'].values()]
 catalog.append({'id':a['name'],'category':a['category'],'model':'res://assets/models/city/gltf/'+a['name']+'.gltf','scene':'res://assets/models/city/scenes/'+a['name']+'.tscn','bounds_model_units':[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]],'placement':a.get('placement',{})})
(DEST/'catalog.json').write_text(json.dumps({'tile_pixels':32,'tile_size_godot':2,'assets':catalog},indent=2))
(DEST/'source.lock.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'approved':True,'provenance':manifest['provenance'],'source_manifest_sha256':digest(SOURCE/'manifest.json'),'files':manifest['files']},indent=2))
print('Verified and migrated',len(manifest['files']),'approved files; catalog contains',len(catalog),'assets.')
