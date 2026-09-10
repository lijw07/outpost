"""Register generated layer regions and shared character sockets; keep sources intact."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]/'assets/characters/modular'
def runs(mask):
    result=[]
    for i in np.flatnonzero(mask):
        if not result or i-result[-1][1]>16: result.append([int(i),int(i)])
        else: result[-1][1]=int(i)
    return [(a,b+1) for a,b in result if b-a>20]
def register(name):
    alpha=np.array(Image.open(ROOT/f'{name}_source.png').convert('RGBA'))[:,:,3]>180
    rows=runs(alpha.sum(axis=1)>10)
    assert len(rows)==(2 if name=='base' else 4),(name,rows)
    frames=[]
    for row,(y0,y1) in enumerate(rows):
        columns=runs(alpha[y0:y1].sum(axis=0)>5)
        while len(columns)>4:
            i=min(range(len(columns)-1),key=lambda j:columns[j+1][0]-columns[j][1])
            columns[i:i+2]=[(columns[i][0],columns[i+1][1])]
        assert len(columns)==4,(name,row,columns)
        for facing,(x0,x1) in enumerate(columns):
            yy,xx=np.nonzero(alpha[y0:y1,x0:x1]);x,y=x0+int(xx.min()),y0+int(yy.min());w,h=int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)
            side=facing in (1,3)
            if name=='base': size=[round(w/h*24),24];top=6
            elif name=='tops': size=[7 if side else 12,8];top=17
            elif name=='hair': size=[14,11 if row!=1 else 12];top=4
            elif name=='bottoms': size=[6 if side else 10,7 if row<2 else 3 if row==2 else 5];top=23 if row<2 else 27 if row==2 else 25
            elif name=='civilian':
                size=[6 if side else 10,[7,4,4,3][row]];top=[23,23,26,27][row]
            elif name=='gear':
                size=([14,8] if row<2 else [7 if side else 10,9] if row==2 else [7 if side else 11,8]);top=5 if row<2 else 17
            else:
                size=[[15,14],[8 if side else 14,9],[7 if side else 12,8],[7 if side else 11,10]][row];top=[4,17,22,17][row]
            frames.append({'region':[x,y,w,h],'size':size,'at':[(24-size[0])//2,top]})
    return {'path':f'{name}_source.png','frames':frames}
result={name:register(name) for name in ['base','tops','hair','bottoms','gear','ghillie','civilian']}
(ROOT/'atlas.json').write_text(json.dumps(result,indent=2)+'\n')
print({key:len(value['frames']) for key,value in result.items()})
