import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/city/street_mobility'
catalog = json.loads((BASE / 'catalog.json').read_text())
records = []
used_textures = set()
for asset in catalog['assets']:
    model = json.loads((BASE / 'blockbench' / (asset['id'] + '.bbmodel')).read_text())
    groups = {g['uuid']: g for g in model['groups']}
    elements = {e['uuid']: e for e in model['elements']}
    refs = []
    def walk(nodes):
        for node in nodes:
            if isinstance(node, str):
                refs.append(node)
            else:
                assert node['uuid'] in groups
                walk(node['children'])
    walk(model['outliner'])
    assert collections.Counter(refs) == collections.Counter(elements.keys()), asset['id']
    for anim in model.get('animations', []):
        assert anim['length'] > 0
        for uuid, track in anim['animators'].items():
            assert uuid in groups
            assert all(0 <= key['time'] <= anim['length'] + .00001 for key in track['keyframes'])
    points = []
    for element in elements.values():
        points.extend(element['vertices'].values() if 'vertices' in element else [element['from'], element['to']])
    minimum = [min(p[i] for p in points) for i in range(3)]
    maximum = [max(p[i] for p in points) for i in range(3)]
    assert abs(minimum[1]) < .00001, (asset['id'], minimum)
    if asset['category'] == 'terrain':
        assert [maximum[i] - minimum[i] for i in range(3)] == [32, 32, 32]
        assert len(elements) == 1
    if asset['category'] == 'vehicle':
        original = json.loads((ROOT / 'assets/models/city/blockbench' / (asset['id'] + '.bbmodel')).read_text())
        assert len(original['elements']) == len(elements)
        for element in original['elements']:
            assert element['vertices'] == elements[element['uuid']]['vertices'], asset['id']
        assert len([g for g in groups.values() if g['name'].startswith('wheel_')]) == 4
        assert len([g for g in groups.values() if g['name'].startswith('steer_')]) == 2
    used_textures.update(t['name'] for t in model['textures'])
    assert model['resolution'] == {'width': 32, 'height': 32}
    records.append({'id': asset['id'], 'bounds': [minimum, maximum], 'animations': len(model.get('animations', [])), 'passed': True})

inventory = []
for path in sorted((ROOT / 'assets').rglob('*.bbmodel')):
    if BASE in path.parents:
        continue
    data = json.loads(path.read_text())
    inventory.append({'path': str(path.relative_to(ROOT)), 'elements': len(data.get('elements', [])), 'animations': len(data.get('animations', [])), 'resolution': data.get('resolution'), 'category': data.get('outpost', {}).get('category')})
(BASE / 'review/asset_inventory.json').write_text(json.dumps({'existing_models': len(inventory), 'libraries': dict(collections.Counter(str(Path(a['path']).parent.parent) for a in inventory)), 'models': inventory}, indent=2))
(BASE / 'review/native_validation.json').write_text(json.dumps({'passed': True, 'assets': records}, indent=2))
files = {str(p.relative_to(BASE)): hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['blockbench', 'gltf', 'textures', 'scenes'] for p in (BASE / folder).glob('*') if p.is_file() and not p.name.endswith('.import')}
sources = {a['id']: hashlib.sha256((ROOT / 'assets/models/city/blockbench' / (a['id'] + '.bbmodel')).read_bytes()).hexdigest() for a in catalog['assets'] if a['category'] == 'vehicle'}
manifest = json.loads((BASE / 'manifest.json').read_text()) if (BASE / 'manifest.json').exists() else {}
manifest.update({'name': 'outpost_street_mobility', 'version': 1, 'authored_with': 'Blockbench native Group, Mesh, Cube, Animation and glTF exporter', 'provenance': 'Existing Outpost vehicle mesh geometry retained; newly authored street props and block textures. No provider or third-party downloads.', 'request': 'All existing cars need movement animations including turning and reversing; build street signs, lights, bus stops, trash cans and crosswalks in Blockbench; terrain must be 32x32x32 blocks.', 'vehicle_sources_sha256': sources, 'files_sha256': files, 'validation': {'native': 'review/native_validation.json', 'blockbench_poses': 'review/blockbench_pose_validation.json', 'engine_import': 'review/godot_import_validation.json'}})
(BASE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'passed': True, 'existing_models_inventoried': len(inventory), 'assets_validated': len(records), 'files_hashed': len(files)}))
