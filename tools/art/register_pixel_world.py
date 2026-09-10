"""Measure generated sprite regions without altering source artwork."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]/'assets/pixel_world'
def runs(mask, gap=12):
    indices=np.flatnonzero(mask)
    result=[]
    for i in indices:
        if not result or i-result[-1][1]>gap: result.append([int(i),int(i)])
        else: result[-1][1]=int(i)
    return [(a,b+1) for a,b in result if b-a>20]
def register(name):
    image=np.array(Image.open(ROOT/f'{name}_source.png').convert('RGBA'))
    alpha=image[:,:,3]>128
    rows=runs(alpha.sum(axis=1)>5)
    assert len(rows)==4,(name,rows)
    frames=[]
    for y0,y1 in rows:
        columns=runs(alpha[y0:y1].sum(axis=0)>3)
        while len(columns)>4:
            i=min(range(len(columns)-1), key=lambda j:columns[j+1][0]-columns[j][1])
            columns[i:i+2]=[(columns[i][0],columns[i+1][1])]
        assert len(columns)==4,(name,columns)
        for x0,x1 in columns:
            yy,xx=np.nonzero(alpha[y0:y1,x0:x1])
            x,y=x0+int(xx.min()),y0+int(yy.min())
            w,h=int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)
            if name in ['characters','clothing']: target_h=24; target_w=round(w/h*target_h)
            elif name=='gunviews':
                extent=16 if len(frames)%4 in [0,3] else 10
                scale=extent/max(w,h);target_w=round(w*scale);target_h=round(h*scale)
            elif name=='props':
                extent=[40,40,40,36,20,16,18,18,16,14,12,12,32,22,12,22][len(frames)]
                scale=extent/max(w,h); target_w=round(w*scale);target_h=round(h*scale)
            else:
                scale=16/max(w,h);target_w=round(w*scale);target_h=round(h*scale)
            frames.append({'region':[x,y,w,h],'size':[max(2,target_w),max(2,target_h)]})
    return {'path':f'{name}_source.png','frames':frames}
data={name:register(name) for name in ['characters','props','weapons','clothing','gunviews','variations'] if (ROOT/f'{name}_source.png').exists()}
(ROOT/'atlas.json').write_text(json.dumps(data,indent=2)+'\n')
print({name:len(value['frames']) for name,value in data.items()})
