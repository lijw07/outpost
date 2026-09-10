"""Measure connected sprite silhouettes; write frame registration, never edit artwork.

Needs Pillow and NumPy. Original transparent source PNGs remain untouched.
"""
from collections import deque
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / 'assets/menu/characters'

def measure(path, columns=4, rows=4, action="walk"):
    image = Image.open(path)
    if action in ('shoot', 'move_shoot') and image.mode == 'RGB':
        # Match the runtime shader's neutral-background key without editing source art.
        rgb = np.asarray(image).astype(int)
        mask = ~((rgb.min(axis=2) > 148) & (rgb.max(axis=2)-rgb.min(axis=2) < 22))
    else:
        assert image.mode == 'RGBA', 'Sprites require real transparency'
        mask = np.asarray(image.getchannel('A')) > 128
    height, width = mask.shape
    visited = mask.copy()
    components = []
    for y in range(height):
        for x in range(width):
            if not visited[y, x]:
                continue
            visited[y, x] = False
            queue = deque([(x, y)])
            left = right = x
            top = bottom = y
            area = 0
            while queue:
                px, py = queue.popleft()
                area += 1
                left, right = min(left, px), max(right, px)
                top, bottom = min(top, py), max(bottom, py)
                for nx, ny in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                    if 0 <= nx < width and 0 <= ny < height and visited[ny, nx]:
                        visited[ny, nx] = False
                        queue.append((nx, ny))
            if area > 2000:
                components.append((left, top, right+1, bottom+1))
    assert len(components) == columns*rows, f'{path.name}: expected {columns*rows} isolated sprites, got {len(components)}'
    components.sort(key=lambda box: (box[1]+box[3])/2)
    frames = []
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(components[row*columns:row*columns+columns]))
    reference_height = float(np.median([box[3]-box[1] for box in ordered[::columns]]))
    for index, (left, top, right, bottom) in enumerate(ordered):
        # A fixed band above the ankles excludes reaching arms, timber and hammers.
        band_top = max(top, bottom-int(reference_height*.30))
        band_bottom = max(top+1, bottom-int(reference_height*.20))
        band = mask[band_top:band_bottom, left:right]
        _, xs = np.nonzero(band)
        center = float(np.median(xs)) if len(xs) else (right-left)/2
        pivot_y = bottom-top
        if action == 'death' and index%columns == columns-1:
            direction = index//columns
            center = (right-left)*(.15 if direction == 1 else .85 if direction == 3 else .5)
            pivot_y = (bottom-top)*(.25 if direction == 0 else .7)
        frame = {'region': [left, top, right-left, bottom-top], 'pivot': [round(center), round(pivot_y)]}
        if action in ('shoot', 'move_shoot'):
            direction=index//columns
            if direction in (1,3):
                muzzle_x=right-2 if direction==1 else left+1
                ys=np.flatnonzero(mask[top:bottom,muzzle_x])
                muzzle=[muzzle_x-left,round(float(np.median(ys)))]
            elif direction==2:
                xs=np.flatnonzero(mask[top+1,left:right])
                muzzle=[round(float(np.median(xs))),1]
            else:
                muzzle=[round(center),round((bottom-top)*.78)]
            frame['muzzle']=muzzle
        frames.append(frame)
    return {'path': path.name, 'height': reference_height, 'frames': frames}

if __name__ == '__main__':
    from register_menu_anchors import register
    result = {key: measure(ROOT / name, action=action) for key, name, action in [('survivor','survivor_walk.png','walk'),('zombie','zombie_walk.png','walk'),('carry','survivor_carry.png','carry'),('build','survivor_build.png','build'),('death','zombie_death.png','death'),('shoot','survivor_shoot.png','shoot'),('move_shoot','survivor_move_shoot.png','move_shoot')]}
    (ROOT / 'frames.json').write_text(json.dumps(register(result), indent=2) + '\n')
    camp_root = ROOT.parent / 'camp'
    camp = measure(camp_root / 'outlined_camp.png', columns=5, rows=2, action='prop')
    (camp_root / 'frames.json').write_text(json.dumps(camp, indent=2) + '\n')
    print('Registered 112 action frames and ten camp props; source artwork unchanged.')
