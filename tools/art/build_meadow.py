"""Slice the generated meadow masters, normalize joins and bake pixel animations."""
from pathlib import Path
import json
import math
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/environment/meadow'
OUT = ROOT / 'output/meadow'
RESAMPLE = Image.Resampling.NEAREST
MANIFEST = {'tile_size': 64, 'design_size': [1920, 1080], 'assets': [], 'animations': {}}


def source(name):
    return Image.open(PACK / 'source' / f'{name}.png').convert('RGBA')


def cell(im, x, y, cols=4, rows=4, inset=0):
    return im.crop((round(x*im.width/cols)+inset, round(y*im.height/rows)+inset,
                    round((x+1)*im.width/cols)-inset, round((y+1)*im.height/rows)-inset))


def export(name, im, kind, **meta):
    path = PACK / kind / f'{name}.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    MANIFEST['assets'].append(dict(name=name, path=str(path.relative_to(ROOT)),
                                  kind=kind, size=list(im.size), **meta))
    return im


def sprite(im, size):
    a = np.array(im)
    a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
    a[a[:, :, 3] == 0] = 0
    im = Image.fromarray(a)
    bbox = im.getbbox()
    if bbox is None:
        raise ValueError('Empty source sprite')
    im = im.crop(bbox)
    scale = min((size[0]-8)/im.width, (size[1]-8)/im.height)
    im = im.resize((max(1, round(im.width*scale)), max(1, round(im.height*scale))), RESAMPLE)
    result = Image.new('RGBA', size)
    result.paste(im, ((size[0]-im.width)//2, size[1]-4-im.height))
    return result


def seal_base(a):
    # The same boundary pixel profiles recur on opposing sides of every variant.
    a = a.copy()
    horizontal = ((a[0].astype(int)+a[-1].astype(int))//2).astype('uint8')
    vertical = ((a[:, 0].astype(int)+a[:, -1].astype(int))//2).astype('uint8')
    for k in range(1):
        a[k] = horizontal
        a[-k-1] = horizontal
        a[:, k] = vertical
        a[:, -k-1] = vertical
    corners = a[0, 0].copy()
    for y in [slice(0, 1), slice(-1, None)]:
        for x in [slice(0, 1), slice(-1, None)]: a[y, x] = corners
    return a


def terrain():
    im = source('ground')
    tiles = [np.array(cell(im, i%4, i//4, inset=3).resize((64, 64), RESAMPLE)) for i in range(16)]
    for a in tiles: a[:, :, 3] = 255
    bases = [seal_base(tiles[0]), seal_base(tiles[8])]
    yy, xx = np.indices((64, 64))
    distance = np.minimum.reduce([xx, yy, 63-xx, 63-yy])
    for i, a in enumerate(tiles):
        base = bases[i//8]
        # Dither only the narrow join band; interior painted texture is retained.
        edge = (distance < 1) | ((distance < 4) & ((xx*13+yy*7)%4 > distance))
        a[edge] = base[edge]
        export(('grass' if i < 8 else 'soil')+f'_{i%8:02}', Image.fromarray(a), 'terrain', corners=15 if i<8 else 0)
    transition = source('transitions')
    masks = [3, 12, 5, 10, 1, 2, 4, 8, 14, 13, 11, 7, 15, 15, 0, 0]
    saved_masks = []
    for i, bits in enumerate(masks):
        raw = np.array(cell(transition, i%4, i//4, inset=3).resize((64, 64), RESAMPLE))
        mask = raw[:, :, 1].astype(int) > raw[:, :, 0].astype(int)
        # Keep the generated irregular silhouette, align its four mating edges.
        for row in range(3):
            mask[row, :32] = bool(bits & 1); mask[row, 32:] = bool(bits & 2)
            mask[-1-row, :32] = bool(bits & 4); mask[-1-row, 32:] = bool(bits & 8)
            mask[:32, row] = bool(bits & 1); mask[32:, row] = bool(bits & 4)
            mask[:32, -1-row] = bool(bits & 2); mask[32:, -1-row] = bool(bits & 8)
        saved_masks.append(mask)
        a = np.where(mask[:, :, None], bases[0], bases[1])
        export(f'transition_{i:02}', Image.fromarray(a), 'transitions', corners=bits)
    # Complete the two diagonal corner combinations for terrain painting.
    for i, bits in enumerate([6, 9]):
        mask = (saved_masks[5] | saved_masks[6]) if bits == 6 else (saved_masks[4] | saved_masks[7])
        a = np.where(mask[:, :, None], bases[0], bases[1])
        export(f'transition_{16+i:02}', Image.fromarray(a), 'transitions', corners=bits)
    return bases


def paths():
    im = source('paths')
    raw = []
    for i in range(16):
        a = np.array(cell(im, i%4, i//4).resize((64, 64), RESAMPLE))
        a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
        a[a[:, :, 3] == 0] = 0
        raw.append(Image.fromarray(a))
    # Correct the generated dead-end orientations using the unambiguous north cap.
    for index, turns in [(2, 3), (4, 2), (8, 1)]:
        raw[index] = raw[1].rotate(turns*90)
    horizontal = np.array(raw[10])
    profile = horizontal[:,32].copy()
    # Pair the cross-section to make rotated junction joins identical.
    profile = profile.copy()
    for x in range(32): profile[63-x] = profile[x]
    # Exclude isolated grass tips so repeating joins do not extrude thin lines.
    profile[:21] = 0
    profile[43:] = 0
    for i, tile in enumerate(raw):
        a = np.array(tile)
        for edge, bit in [('n', 1), ('e', 2), ('s', 4), ('w', 8)]:
            if not i & bit: continue
            for k in range(6):
                if edge == 'n': a[k] = profile
                if edge == 's': a[63-k] = profile
                if edge == 'w': a[:, k] = profile
                if edge == 'e': a[:, 63-k] = profile
        # No visible debris on a side that is meant to terminate inside this tile.
        if not i & 1: a[:2] = 0
        if not i & 4: a[-2:] = 0
        if not i & 8: a[:, :2] = 0
        if not i & 2: a[:, -2:] = 0
        export(f'path_{i:02}', Image.fromarray(a), 'paths', connections=i)


def row_bend(im, amount, squash=0.0, canopy=False):
    a = np.array(im); h, w = a.shape[:2]
    result = np.zeros_like(a)
    root = h-5
    for y in range(h):
        weight = max(0.0, (root-y)/max(root, 1))
        if canopy: weight = max(0.0, (weight-0.26)/0.74)
        dx = round(amount * weight*weight)
        target_y = min(h-1, y+round(squash*weight*min(h*0.18, 13)))
        lo, hi = max(0, dx), min(w, w+dx)
        if hi > lo: result[target_y, lo:hi] = a[y, lo-dx:hi-dx]
    return Image.fromarray(result)


def bake(name, im, canopy=False):
    amplitude = 2 if canopy else (3 if im.height <= 64 else 4)
    wind = [row_bend(im, math.sin(i*math.tau/8)*amplitude, canopy=canopy) for i in range(8)]
    animations = {'wind': wind}
    if not canopy:
        animations['brush'] = [row_bend(im, t*7, t*0.6) for t in [0, .35, .65, .9, 1, 1]]
        animations['recover'] = [row_bend(im, t*7, max(0,t)*0.6) for t in [1, .7, .35, -.15, -.07, 0]]
        animations['brush_left'] = [row_bend(im, -t*7, t*0.6) for t in [0, .35, .65, .9, 1, 1]]
        animations['recover_left'] = [row_bend(im, -t*7, max(0,t)*0.6) for t in [1, .7, .35, -.15, -.07, 0]]
    info = {}
    for state, frames in animations.items():
        atlas = Image.new('RGBA', (im.width*len(frames), im.height))
        for i, frame in enumerate(frames): atlas.paste(frame, (im.width*i, 0))
        path = PACK / 'animation_atlases' / f'{name}_{state}.png'
        path.parent.mkdir(exist_ok=True)
        atlas.save(path)
        info[state] = dict(path=str(path.relative_to(ROOT)), count=len(frames), fps=8 if state=='wind' else 12,
                           loop=state=='wind', size=list(im.size))
    MANIFEST['animations'][name] = info


def props():
    names = ['grass_short','grass_tall','flowers_white','flowers_yellow','flowers_purple','clover',
             'mushrooms','fern','rock_small','rock_mossy','pebbles','boulder','shrub','shrub_flowering','stump_old','branch']
    im = source('props')
    for i, name in enumerate(names):
        size = (96, 96) if name in ['boulder','shrub','shrub_flowering'] else (64, 64)
        a = sprite(cell(im, i%4, i//4), size)
        animated = i in [0,1,2,3,4,5,7,12,13]
        export(name, a, 'props', pivot=[size[0]//2, size[1]-4], reactive=animated)
        if animated: bake(name, a)
    names = ['grass_sparse','grass_dense','grass_seedheads','grass_flattened','grass_dry','grass_mixed','grass_clover','grass_reedlike']
    im = source('grass')
    for i, name in enumerate(names):
        size = (64, 96) if i in [2,7] else (64,64)
        a = sprite(cell(im, i%4, i//4, rows=2), size)
        export(name, a, 'grass', pivot=[size[0]//2,size[1]-4], reactive=True)
        bake(name, a)


def tree_source_slices():
    """Reject a source boundary that cuts through visible neighboring artwork."""
    spec = json.loads((ROOT/'tools/art/meadow_tree_slices.json').read_text())
    im = Image.open(ROOT/spec['source']).convert('RGBA')
    assert list(im.size) == spec['source_size'], 'Tree source changed; re-audit slices'
    visible = np.array(im)[:, :, 3] >= spec['alpha_threshold']
    cuts = spec['column_boundaries']
    result = {}
    for layer, (top, bottom) in spec['rows'].items():
        for x in cuts[1:-1]:
            assert not visible[top:bottom,x-2:x+2].any(), f'{layer}: source boundary intersects artwork at {x}'
        for i, name in enumerate(spec['species']):
            left, right = cuts[i:i+2]
            columns = visible[top:bottom,left:right].any(axis=0)
            starts = np.flatnonzero(columns & ~np.r_[False,columns[:-1]])
            assert len(starts) == 1, f'{name} {layer}: neighboring fragment or changed source layout'
            result[name, layer] = im.crop((left,top,right,bottom))
    return result, spec['species']


def trees():
    slices, names = tree_source_slices()
    MANIFEST['trees'] = {}
    for i, name in enumerate(names):
        crown_size = [(192,144),(144,160),(128,112),(160,144)][i]
        stump_size = (48,48) if i==2 else (64,64)
        crown = sprite(slices[name, 'crown'], crown_size)
        stump = sprite(slices[name, 'stump'], stump_size)
        trunk_source = slices[name, 'trunk']
        sa=np.array(stump)[:,:,3]>0
        ys,xs=np.where(sa)
        cut_y=int(ys.min()+max(2,(ys.max()-ys.min())*.13))
        row=np.where(sa[cut_y])[0]
        diameter=max(int(np.count_nonzero(sa[y])) for y in range(int(ys.min()), cut_y+3))
        # Match the shaft to the actual cut-face width, not the stump's flared roots.
        trunk=sprite(trunk_source,(diameter+8,96 if i!=2 else 72))
        bbox=trunk.getbbox(); target_width=diameter
        shaft=trunk.crop(bbox).resize((target_width,bbox[3]-bbox[1]),RESAMPLE)
        trunk=Image.new('RGBA',(diameter+8,shaft.height+8));trunk.paste(shaft,(4,4))
        log=trunk.transpose(Image.Transpose.ROTATE_270)
        # Cover the exposed saw cuts only while the tree is standing. Reuse the
        # shaft's own bark pixels, then reveal the original cut faces on felling.
        ta=np.array(trunk)
        joined=ta.copy()
        bark=ta[trunk.height//2-4:trunk.height//2+4,4:-4]
        for y in list(range(4,12))+list(range(trunk.height-11,trunk.height-4)):
            for x in range(4,trunk.width-4):
                if joined[y,x,3]: joined[y,x]=bark[y%8,x-4]
        joined_trunk=Image.fromarray(joined)
        st=np.array(stump)
        # The upper ellipse is hidden behind living bark until the cut completes.
        for y in range(int(ys.min()),cut_y+5):
            for x in range(stump.width):
                if st[y,x,3]:
                    bx=min(diameter-1,max(0,x-(stump.width-diameter)//2))
                    st[y,x]=bark[y%8,bx]
        joined_stump=Image.fromarray(st)
        ca=np.array(crown)
        # Remove the generated cut-face at the bottom of the branch socket.
        bottom=crown.getbbox()[3]
        ca[bottom-4:bottom]=0
        crown=Image.fromarray(ca)
        base_y=-stump.height+4+cut_y
        crown_y=base_y-(trunk.height-8)+18
        MANIFEST['trees'][name]={'trunk_base_y':base_y,'crown_base_y':crown_y,'cut_diameter':diameter,
                                  'stump_size':list(stump.size),'crown_size':list(crown.size),'trunk_size':list(trunk.size)}
        for state,a in [('crown',crown),('trunk',trunk),('stump',stump),('log',log),('trunk_joined',joined_trunk),('stump_joined',joined_stump)]:
            export(name+'_'+state,a,'trees',pivot=[a.width//2,a.height-4],tree=name)
        top=crown_y-crown.height+4
        size=(max(crown.width,stump.width)+16,math.ceil((-top+12)/16)*16)
        standing=Image.new('RGBA',size)
        foot_y=size[1]-4
        for a,offset in [(joined_stump,0),(joined_trunk,base_y),(crown,crown_y)]:
            standing.alpha_composite(a,((size[0]-a.width)//2,round(foot_y+offset-a.height+4)))
        export(name+'_standing',standing,'trees',pivot=[size[0]//2,foot_y],tree=name)
        bake(name+'_crown',crown,canopy=True)
        if i==0:
            # Small source-art leaf chip for the foliage-shedding particle emitter.
            chip=crown.crop((crown.width//2-3,26,crown.width//2+3,32))
            export('leaf_chip',chip,'effects')


def contact_sheet():
    assets = MANIFEST['assets']
    canvas = Image.new('RGB', (1440, 54+math.ceil(len(assets)/8)*166), '#1c2924')
    draw = ImageDraw.Draw(canvas)
    draw.text((24,18), 'OUTPOST  /  MEADOW STARTER SET  /  1080p design baseline', fill='#e9dfbd')
    for i, entry in enumerate(assets):
        x=24+(i%8)*176; y=54+(i//8)*166
        im=Image.open(ROOT/entry['path'])
        scale=min(2,160/im.width,128/im.height)
        im=im.resize((round(im.width*scale),round(im.height*scale)),RESAMPLE)
        canvas.paste(im,(x,y),im)
        draw.text((x,y+133),entry['name'],fill='#d7cdaa')
    canvas.crop((0,0,1440,54+math.ceil(len(assets)/8)*166)).save(OUT/'meadow_catalog.png')
    # A short visible preview of the actual exported wind/contact frames.
    names=['grass_dense','grass_seedheads','flowers_white','shrub','oak_crown']
    frames=[]
    for t in range(40):
        c=Image.new('RGB',(1000,380),'#344d30'); d=ImageDraw.Draw(c)
        d.text((20,18),'OUTPOST / Wind, brush-through and recovery',fill='#f4e6ba')
        for j,name in enumerate(names):
            states=MANIFEST['animations'][name]
            state='wind' if t<16 or name=='oak_crown' else ('brush' if t<22 else 'recover' if t<28 else 'wind')
            info=states[state];w,h=info['size'];idx=(t if state=='wind' else t-16 if state=='brush' else t-22)%info['count']
            im=Image.open(ROOT/info['path']).crop((idx*w,0,(idx+1)*w,h))
            scale=1 if h>128 else 2
            im=im.resize((w*scale,h*scale),RESAMPLE)
            c.paste(im,(j*195+(190-im.width)//2,325-im.height),im)
            d.text((j*195+12,345),name+' / '+state,fill='#f4e6ba')
        frames.append(c)
    frames[0].save(OUT/'meadow_motion.gif',save_all=True,append_images=frames[1:],duration=110,loop=0,disposal=2)


def verify():
    for group in ['grass','soil']:
        images=[np.array(Image.open(PACK/'terrain'/f'{group}_{i:02}.png')) for i in range(8)]
        for a in images:
            assert np.array_equal(a[0],images[0][-1]), 'Vertical ground seam'
            assert np.array_equal(a[:,0],images[0][:,-1]), 'Horizontal ground seam'
    for item in MANIFEST['assets']:
        im=Image.open(ROOT/item['path'])
        assert list(im.size)==item['size']
        assert set(np.unique(np.array(im)[:,:,3])) <= {0,255}
    ground = [e for e in MANIFEST['assets'] if 'corners' in e]
    for e in ground:
        a=np.array(Image.open(ROOT/e['path'])); ab=e['corners']
        assert a.shape[:2] == (64,64)
        for f in ground:
            b=np.array(Image.open(ROOT/f['path'])); bb=f['corners']
            if (bool(ab&2),bool(ab&8)) == (bool(bb&1),bool(bb&4)):
                assert np.array_equal(a[:,-1],b[:,0]), 'Transition east-west seam'
            if (bool(ab&4),bool(ab&8)) == (bool(bb&1),bool(bb&2)):
                assert np.array_equal(a[-1],b[0]), 'Transition north-south seam'
    paths=[np.array(Image.open(PACK/'paths'/f'path_{i:02}.png')) for i in range(16)]
    for i,a in enumerate(paths):
        for j,b in enumerate(paths):
            if i&2 and j&8: assert np.array_equal(a[:,-1],b[:,0]), 'Path east-west seam'
            if i&4 and j&1: assert np.array_equal(a[-1],b[0]), 'Path north-south seam'
        for bit,edge in [(1,a[0]),(2,a[:,-1]),(4,a[-1]),(8,a[:,0])]:
            if not i&bit: assert not edge[:,3].any(), 'Unconnected path edge'
    for name in MANIFEST['trees']:
        trunk=Image.open(PACK/'trees'/f'{name}_trunk.png')
        log=Image.open(PACK/'trees'/f'{name}_log.png')
        assert np.array_equal(np.array(trunk.transpose(Image.Transpose.ROTATE_270)),np.array(log)), 'Log changed bark'
    for states in MANIFEST['animations'].values():
        roots=None
        for info in states.values():
            a=np.array(Image.open(ROOT/info['path'])); w,h=info['size']
            assert a.shape[:2] == (h,w*info['count'])
            assert set(np.unique(a[:,:,3])) <= {0,255}
            for n in range(info['count']):
                foot=a[-8:,n*w:(n+1)*w]
                if roots is None: roots=foot
                assert np.array_equal(foot,roots), 'Animation foot pivot moved'
    print(f"Built {len(MANIFEST['assets'])} static sprites/tiles and {len(MANIFEST['animations'])} animation sets; pixel/ground seam checks passed.")


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--trees-only', action='store_true', help='Re-slice trees and rebuild their wind frames without rewriting terrain or props')
    args = parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.trees_only:
        MANIFEST = json.loads((PACK/'manifest.json').read_text())
        MANIFEST['assets'] = [a for a in MANIFEST['assets'] if a['kind'] != 'trees' and a['name'] != 'leaf_chip']
        MANIFEST['animations'] = {name: info for name, info in MANIFEST['animations'].items() if name not in ['oak_crown','birch_crown','young_oak_crown','deadwood_crown']}
    else:
        terrain(); paths(); props()
    trees(); verify()
    (PACK/'manifest.json').write_text(json.dumps(MANIFEST,indent=2)+'\n')
    contact_sheet()
