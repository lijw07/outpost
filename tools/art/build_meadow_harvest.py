"""Slice ImageGen's harvested-state sheet onto each original sprite's canvas/pivot."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT/'assets/environment/meadow'
PICKABLE = {'flowers_white':2, 'flowers_yellow':3, 'flowers_purple':4, 'clover':5, 'mushrooms':6, 'shrub_flowering':13}

def build(manifest):
    original = Image.open(PACK/'source/props.png').convert('RGBA')
    edited = Image.open(PACK/'source/props_picked.png').convert('RGBA')
    assert edited.size == original.size
    pixels = np.array(edited)
    # The generated matte is a neutral checkerboard; harvested foliage is dark/chromatic.
    rgb = pixels[:,:,:3].astype(int)
    matte = (rgb.min(axis=2)>=175) & (rgb.max(axis=2)-rgb.min(axis=2)<=20)
    pixels[:,:,3] = np.where(matte,0,255)
    pixels[matte]=0
    edited = Image.fromarray(pixels)
    manifest['assets'] = [a for a in manifest['assets'] if a['kind']!='harvested']
    for name,index in PICKABLE.items():
        entry = next(a for a in manifest['assets'] if a['name']==name)
        cell = (round((index%4)*original.width/4),round((index//4)*original.height/4),round((index%4+1)*original.width/4),round((index//4+1)*original.height/4))
        ref = original.crop(cell)
        a=np.array(ref); a[:,:,3]=np.where(a[:,:,3]>=128,255,0); a[a[:,:,3]==0]=0
        bbox=Image.fromarray(a).getbbox()
        width,height=entry['size']
        scale=min((width-8)/(bbox[2]-bbox[0]),(height-8)/(bbox[3]-bbox[1]))
        size=(round((bbox[2]-bbox[0])*scale),round((bbox[3]-bbox[1])*scale))
        fragment=edited.crop(cell).crop(bbox).resize(size,Image.Resampling.NEAREST)
        result=Image.new('RGBA',(width,height))
        result.paste(fragment,((width-size[0])//2,height-4-size[1]))
        path=PACK/'harvested'/f'{name}_picked.png'; path.parent.mkdir(exist_ok=True); result.save(path)
        assert result.getbbox() and set(np.unique(np.array(result)[:,:,3])) <= {0,255}
        entry['harvest']={'picked_path':str(path.relative_to(ROOT)),'item':'mushrooms' if name=='mushrooms' else 'flowers','amount':1}
        manifest['assets'].append({'name':name+'_picked','kind':'harvested','path':str(path.relative_to(ROOT)),'size':entry['size'],'pivot':entry['pivot'],'source_asset':name})
    return manifest

if __name__=='__main__':
    manifest=build(json.loads((PACK/'manifest.json').read_text()))
    (PACK/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS: six picked states sliced using original crop, scale, canvas and foot pivot.')
