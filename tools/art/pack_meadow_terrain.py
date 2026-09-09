"""Pack the existing native terrain slices into Godot atlas sheets, losslessly."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/environment/meadow'
manifest = json.loads((PACK / 'manifest.json').read_text())
atlases = PACK / 'terrain_atlases'
atlases.mkdir(exist_ok=True)
entries = []
for source_id, (kind, columns) in enumerate([('terrain', 8), ('transitions', 6), ('paths', 4)]):
    tiles = [a for a in manifest['assets'] if a['kind'] == kind]
    sheet = Image.new('RGBA', (columns * 64, ((len(tiles) + columns - 1) // columns) * 64))
    for i, tile in enumerate(tiles):
        art = Image.open(ROOT / tile['path']).convert('RGBA')
        assert art.size == (64, 64), tile['name']
        xy = [i % columns, i // columns]
        sheet.paste(art, (xy[0] * 64, xy[1] * 64))
        entries.append(dict(tile, source_id=source_id, atlas_coords=xy))
    target = atlases / f'{kind}.png'
    sheet.save(target)
    saved = Image.open(target)
    for i, tile in enumerate(tiles):
        x, y = (i % columns) * 64, (i // columns) * 64
        assert saved.crop((x, y, x + 64, y + 64)).tobytes() == Image.open(ROOT / tile['path']).convert('RGBA').tobytes()
(atlases / 'slices.json').write_text(json.dumps({'tile_size': 64, 'tiles': entries}, indent=2) + '\n')
print(f'PASS: {len(entries)} exact 64x64 slices packed into three terrain atlases.')
