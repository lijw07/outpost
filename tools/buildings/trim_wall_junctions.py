"""Subtract duplicate wall faces in assembled scenes, preserving interpolated UVs."""
import json, math
from pathlib import Path
from collections import defaultdict
BASE=Path(__file__).resolve().parents[2]/'output/buildings/validation'
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def signed(poly,axes):
 i,j=axes
 return sum(p[i]*q[j]-q[i]*p[j] for p,q in zip(poly,poly[1:]+poly[:1]))/2

def half(poly,a,b,axes,sign):
 i,j=axes
 def side(p):return sign*((b[i]-a[i])*(p[j]-a[j])-(b[j]-a[j])*(p[i]-a[i]))
 inside=[];outside=[]
 for p,q in zip(poly,poly[1:]+poly[:1]):
  sp,sq=side(p),side(q)
  if sp>=-1e-9:inside.append(p)
  if sp<=1e-9:outside.append(p)
  if (sp>1e-9 and sq< -1e-9) or (sp< -1e-9 and sq>1e-9):
   t=sp/(sp-sq);v=[p[k]+t*(q[k]-p[k]) for k in range(5)];inside.append(v);outside.append(v)
 return inside,outside

def subtract(poly,cutter,axes):
 sign=1 if signed(cutter,axes)>0 else -1
 remainder=poly;outside=[]
 for a,b in zip(cutter,cutter[1:]+cutter[:1]):
  remainder,fragment=half(remainder,a,b,axes,sign)
  if len(fragment)>2 and abs(signed(fragment,axes))>1e-9:outside.append(fragment)
  if len(remainder)<3 or abs(signed(remainder,axes))<1e-9:return [poly]
 return outside

def box(poly,axes):return [min(p[i] for p in poly) for i in axes]+[max(p[i] for p in poly) for i in axes]
def overlap(a,b):return a[0]<b[2]-1e-8 and a[2]>b[0]+1e-8 and a[1]<b[3]-1e-8 and a[3]>b[1]+1e-8
patches={}
for name,meshes in json.loads((BASE/'surfaces.json').read_text()).items():
 planes=defaultdict(list);changes=[]
 for mesh in meshes:
  if '/Walls/' not in mesh['asset']:continue
  surfaces=[];changed=False
  for surface in mesh['surfaces']:
   faces=[]
   for tri in surface:
    n=cross([tri[1][i]-tri[0][i] for i in range(3)],[tri[2][i]-tri[0][i] for i in range(3)]);length=math.sqrt(sum(x*x for x in n))
    if length<1e-9:continue
    n=[x/length for x in n];key=tuple(round(x,4) for x in n+[sum(n[i]*tri[0][i] for i in range(3))]);axis=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=axis];bbox=box(tri,axes)
    fragments=[tri]
    for asset,cutter,cb in planes[key]:
     if asset==mesh['asset'] or not overlap(bbox,cb):continue
     fragments=[piece for poly in fragments for piece in subtract(poly,cutter,axes)]
     if not fragments:break
    if abs(sum(abs(signed(p,axes)) for p in fragments)-abs(signed(tri,axes)))>1e-8:changed=True
    for poly in fragments:
     for k in range(1,len(poly)-1):
      face=[poly[0],poly[k],poly[k+1]]
      if abs(signed(face,axes))>1e-9:faces.append(face)
    planes[key].append((mesh['asset'],tri,bbox))
   surfaces.append(faces)
  if changed:changes.append({'node':mesh['node'],'asset':mesh['asset'],'surfaces':surfaces})
 patches[name]=changes
 print(name,len(changes),'wall meshes trimmed')
(BASE/'wall_patches.json').write_text(json.dumps(patches))
