import copy, json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / 'output/barren_city/05_vehicle_restyle'
NEW = ROOT / 'output/barren_city/09_terrain_blocks'
for directory in ['blockbench', 'gltf', 'textures']:
    shutil.copytree(OLD / directory, NEW / directory, dirs_exist_ok=True)
for directory in ['tools', 'validation', 'review']:
    (NEW / directory).mkdir(parents=True, exist_ok=True)
spec = json.loads((OLD / 'clean_spec.json').read_text())
names = []
for asset in spec['assets']:
    if asset.get('placement', {}).get('anchor') != 'surface':
        continue
    names.append(asset['name'])
    for mesh in asset['meshes']:
        original = copy.deepcopy(mesh['vertices'])
        for vertex in mesh['vertices'].values():
            vertex[1] = 0 if vertex[1] == -2 else vertex[1] + 32
        for face in mesh['faces']:
            ys = {original[key][1] for key in face['vertices']}
            if -2 in ys and 0 in ys:
                for key in face['vertices']:
                    face['uv'][key][1] = 32 - mesh['vertices'][key][1]
    asset['placement'] = {'origin': 'block base at Y=0', 'anchor': 'base', 'units_per_tile': 32, 'texture_pixels_per_unit': 1, 'top_surface_y': 32, 'terrain_block': True}
    asset['purpose'] = 'Full 32-unit terrain block with 32x32 face texel density; road markings retain their existing tiny raised paint detail.'
(NEW / 'clean_spec.json').write_text(json.dumps(spec, separators=(',', ':')))
(NEW / 'request.json').write_text(json.dumps({'request': 'Convert terrain surface modules into full blocks; preserve existing structures.', 'assets': names, 'source': str(OLD.relative_to(ROOT))}, indent=2))
for file in ['validate_modular.py']:
    shutil.copyfile(OLD / 'tools' / file, NEW / 'tools' / file)
shutil.copyfile(OLD / 'validation/approved_rowhouse.json', NEW / 'validation/approved_rowhouse.json')
builder = (OLD / 'tools/build_in_blockbench.js').read_text().replace(str(OLD), str(NEW))
start = builder.index('const palettes=')
end = builder.index('const selected=')
builder = builder[:start] + "const sources=Object.fromEntries(fs.readdirSync(base+'/textures').filter(n=>n.endsWith('.png')).map(n=>[n.slice(0,-4),'data:image/png;base64,'+fs.readFileSync(base+'/textures/'+n).toString('base64')]));\n" + builder[end:]
(NEW / 'tools/build_in_blockbench.js').write_text(builder)
(NEW / 'tools/batch.json').write_text(json.dumps({'names': names, 'start': 'terrain_blocks'}))
print('Prepared', len(names), 'terrain blocks:', ', '.join(names))
