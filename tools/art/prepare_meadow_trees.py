"""Normalize simplified tree art and slice matching wood pieces and generated dust."""
from pathlib import Path
from PIL import Image
import json,numpy as np
R=Path(__file__).resolve().parents[2];P=R/'assets/environment/meadow'
from build_simple_trees import build
meta=build(P)
for species,info in meta.items():
 im=Image.open(P/'trees'/f'{species}_trunk.png').convert('RGBA'); box=im.getbbox(); info['trunk_rect']=list(box)
 # Preserve each segment's bark from the falling trunk and reuse its existing cut face.
 core=im.crop(box); n=2 if species in ['oak','young_oak'] else 3; info['pieces']=[]
 for i in range(n):
  top=round(i*core.height/n/2)*2;bottom=round((i+1)*core.height/n/2)*2
  cut=core.crop((0,top,core.width,bottom)); result=Image.new('RGBA',(core.width+8,cut.height+8));result.paste(cut,(4,4))
  cap=core.crop((0,0,core.width,min(6,core.height)))
  result.alpha_composite(cap,(4,2));result.alpha_composite(cap,(4,result.height-8))
  name=f'{species}_piece_{i}';result.save(P/'trees'/f'{name}.png');info['pieces'].append(name)
source=Image.open(P/'source/tree_dust.png').convert('RGBA');print('dust source',source.size,source.getextrema()[3])
# Native 96px cells, constant scale and ground center across six animation frames.
w,h=source.size; edges=[0,324,690,1093,1479,1834,w]; boxes=[]
for i in range(6): boxes.append(source.crop((edges[i],0,edges[i+1],h)).getbbox())
assert all(boxes)
assert all(not (np.array(source)[:,x-1:x+2,3]>=128).any() for x in edges[1:-1]), "Dust slice overlaps neighboring frame"
y0=min(b[1] for b in boxes);y1=max(b[3] for b in boxes)
frames=[]; scale=88/max(max(edges[i+1]-edges[i] for i in range(6)),y1-y0)
for i in range(6):
 cell=source.crop((edges[i],y0,edges[i+1],y1));cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
 a=np.array(cell);a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[a[:,:,3]==0]=0;cell=Image.fromarray(a)
 out=Image.new('RGBA',(96,96));out.paste(cell,((96-cell.width)//2,(96-cell.height)//2));out.save(P/'trees'/f'dust_{i}.png');frames.append(out)
(P/'trees/catalog.json').write_text(json.dumps({'species':meta,'dust_frames':6,'physics_pixels_per_meter':64},indent=2)+'\n')
print('Prepared four intact trees, ten matching wood pieces and six dust frames.')
