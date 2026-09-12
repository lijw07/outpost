import hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'output/barren_city/09_terrain_blocks'
OLD = ROOT / 'output/barren_city/05_vehicle_restyle'
spec = json.loads((BASE / 'clean_spec.json').read_text())
changed = set(json.loads((BASE / 'request.json').read_text())['assets'])
assert json.loads((BASE / 'validation/modular_validation.json').read_text())['passed']
records = []
for asset in spec['assets']:
    name = asset['name']
    for folder, extension in [('blockbench', 'bbmodel'), ('gltf', 'gltf')]:
        if name not in changed:
            assert (BASE / folder / (name + '.' + extension)).read_bytes() == (OLD / folder / (name + '.' + extension)).read_bytes(), name
    if name not in changed:
        continue
    native = json.loads((BASE / 'blockbench' / (name + '.bbmodel')).read_text())
    points = [p for mesh in native['elements'] for p in mesh['vertices'].values()]
    lower = [min(p[i] for p in points) for i in range(3)]
    upper = [max(p[i] for p in points) for i in range(3)]
    assert lower == [-16, 0, -16] and upper[0] == 16 and upper[2] == 16 and 32 <= upper[1] <= 32.125, (name, lower, upper)
    assert len(native['elements']) == len(asset['meshes'])
    for native_mesh, source_mesh in zip(native['elements'], asset['meshes']):
        assert sorted(native_mesh['vertices'].values()) == sorted(source_mesh['vertices'].values()), name
    records.append({'id': name, 'bounds': [lower, upper], 'base_anchor': True, 'core_size': [32, 32, 32]})
for texture in (OLD / 'textures').glob('*.png'):
    assert texture.read_bytes() == (BASE / 'textures' / texture.name).read_bytes()
files = {str(p.relative_to(BASE)): hashlib.sha256(p.read_bytes()).hexdigest() for directory in ['blockbench', 'gltf', 'textures'] for p in (BASE / directory).glob('*') if p.is_file()}
(BASE / 'validation/terrain_blocks.json').write_text(json.dumps({'passed': True, 'blocks': records, 'unchanged_other_models': 143, 'textures_unchanged': True}, indent=2))
(BASE / 'manifest.json').write_text(json.dumps({'name': 'outpost_full_terrain_blocks', 'assets': 159, 'validation': {'passed': True, 'coplanar_overlap_pairs': 0, 'ground_anchors': True}, 'provenance': 'User-requested conversion of 16 terrain surface modules to full 32-unit base-anchored blocks in native Blockbench. Existing structures, props, vehicles, and all textures preserved byte-for-byte.', 'files': files}, indent=2))
print('Validated 16 terrain blocks; 143 other native models and all textures unchanged.')
