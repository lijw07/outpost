"""Register animated head/torso sockets from source pixels; never modify artwork."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / 'assets/menu/characters'

def register(data):
    for name, clip in data.items():
        if name in ('zombie', 'death'):
            continue
        source = Image.open(ROOT / clip['path'])
        keyed = source.mode == 'RGB'
        image = np.asarray(source.convert('RGBA'))
        for frame in clip['frames']:
            x, y, w, h = frame['region']
            pixels = image[y:y+h, x:x+w]
            rgb = pixels[:, :, :3].astype(float) / 255
            r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
            yy, xx = np.indices((h, w))
            hair = ((pixels[:, :, 3] > 128) & (r > g*1.15) & (b > g*.63)
                    & (b < g*.95) & (r < .53) & (r > .10) & (yy < h*.5))
            rows = np.flatnonzero(hair.sum(axis=1) >= 5)
            assert rows.size, (name, frame)
            top = int(rows[0])
            hair &= yy < top + clip['height']*.25
            hy, hx = np.nonzero(hair)
            left, right = np.percentile(hx, [3, 97])
            upper, lower = np.percentile(hy, [3, 97])
            head = [(left+right)/2, (upper+lower)/2]
            # Central waist remains stable when arms reach out with tools/timber.
            waist_y = h-clip['height']*.36
            silhouette = (pixels[:, :, 3] > 128) & (abs(yy-waist_y) < 3)
            if keyed:
                silhouette &= ~((rgb.min(axis=2) > 148/255) & (rgb.max(axis=2)-rgb.min(axis=2) < 22/255))
            _, wx = np.nonzero(silhouette)
            waist_x = float(np.median(wx)) if wx.size else frame['pivot'][0]
            torso = [waist_x*.6+head[0]*.4, head[1]+clip['height']*.32]
            frame['head'] = [round(v, 2) for v in head]
            frame['head_width'] = round(right-left+clip['height']*.06, 2)
            frame['torso'] = [round(v, 2) for v in torso]
    return data

if __name__ == '__main__':
    path = ROOT / 'frames.json'
    path.write_text(json.dumps(register(json.loads(path.read_text())), indent=2)+'\n')
    print('Registered head and torso sockets for every survivor action frame.')
