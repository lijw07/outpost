"""Prepare pixel-grid oak models without changing any geometry or hidden faces."""
import base64
import copy
import json
import pathlib
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'output/tree_restyle/before/live'
DEST = ROOT / 'output/tree_restyle/pixel_candidates'
TEXTURES = ROOT / 'assets/models/trees/textures'
NAMESPACE = uuid.UUID('2370c74c-6547-4f66-a7f9-a35f881f2b90')
SHADES = ('mid', 'light', 'shade', 'deep')


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    report = []
    for path in sorted(SOURCE.glob('*.bbmodel')):
        model = json.loads(path.read_text())
        original_elements = copy.deepcopy(model['elements'])
        original_texture = model['textures'][0]
        model['textures'] = [original_texture]
        for shade in SHADES:
            filename = 'oak_leaf_' + shade + '.png'
            model['textures'].append({
                'name':filename,'uuid':str(uuid.uuid5(NAMESPACE,filename)),
                'id':str(len(model['textures'])), 'width':16,'height':16,'uv_width':16,'uv_height':16,
                'render_mode':'default','render_sides':'auto','mode':'bitmap',
                'source':'data:image/png;base64,' + base64.b64encode((TEXTURES / filename).read_bytes()).decode(),
            })
        for element in model['elements']:
            if not element['name'].startswith('leaves'):
                continue
            low, high = element['from'], element['to']
            dx, dy, dz = [high[i] - low[i] for i in range(3)]
            for side, face in element['faces'].items():
                if face.get('texture') is None:
                    continue
                if side in ('up','down'):
                    u, v, width, height = low[0] % 16, low[2] % 16, dx, dz
                elif side in ('east','west'):
                    u, v, width, height = low[2] % 16, -high[1] % 16, dz, dy
                else:
                    u, v, width, height = low[0] % 16, -high[1] % 16, dx, dy
                face['texture'] = {'up':2,'down':4,'north':3,'west':3,'south':1,'east':1}[side]
                face['uv'] = [u,v,u+width,v+height]
        for before, after in zip(original_elements, model['elements']):
            assert before['uuid'] == after['uuid']
            assert before['from'] == after['from'] and before['to'] == after['to']
            assert before.get('rotation') == after.get('rotation')
            for side in before['faces']:
                assert (before['faces'][side].get('texture') is None) == (after['faces'][side].get('texture') is None)
            if not before['name'].startswith('leaves'):
                assert before == after
        (DEST / path.name).write_text(json.dumps(model,indent=2))
        report.append({'name':path.stem,'cubes':len(model['elements']),'geometry_unchanged':True,
                       'trunk_unchanged':True,'leaf_texture_pixels_per_model_unit':1})
    (DEST / 'validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    build()
