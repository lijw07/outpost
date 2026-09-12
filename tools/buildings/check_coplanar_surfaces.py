import json, math, sys
from pathlib import Path
from collections import defaultdict
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'output/buildings/validation'
data=json.loads((BASE/'surfaces.json').read_text())
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def area(poly):return abs(sum(p[0]*q[1]-q[0]*p[1] for p,q in zip(poly,poly[1:]+poly[:1])))/2 if len(poly)>2 else 0

def clip(poly,window):
 sign=1 if sum(p[0]*q[1]-q[0]*p[1] for p,q in zip(window,window[1:]+window[:1]))>0 else -1
 for a,b in zip(window,window[1:]+window[:1]):
  def side(p):return sign*((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]))
  out=[]
  for p,q in zip(poly,poly[1:]+poly[:1]):
   sp,sq=side(p),side(q)
   if sp>=-1e-9:out.append(p)
   if sp*sq<0:
    t=sp/(sp-sq);out.append([p[i]+t*(q[i]-p[i]) for i in [0,1]])
  poly=out
  if len(poly)<3:return []
 return poly
results=[]
for name,meshes in data.items():
 planes=defaultdict(list);collisions=defaultdict(float)
 for mesh in meshes:
  for tri in mesh['triangles']:
   n=cross([tri[1][i]-tri[0][i] for i in range(3)],[tri[2][i]-tri[0][i] for i in range(3)]);length=math.sqrt(sum(x*x for x in n))
   if length<1e-9:continue
   n=[x/length for x in n];d=sum(n[i]*tri[0][i] for i in range(3));key=tuple(round(x,4) for x in n+[d]);axis=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=axis];poly=[[p[i] for i in axes] for p in tri];box=[min(p[i] for p in poly) for i in [0,1]]+[max(p[i] for p in poly) for i in [0,1]]
   for old_asset,old_poly,old_box in planes[key]:
    if old_asset==mesh['asset'] or box[0]>=old_box[2]-1e-7 or box[2]<=old_box[0]+1e-7 or box[1]>=old_box[3]-1e-7 or box[3]<=old_box[1]+1e-7:continue
    overlap=area(clip(poly,old_poly))
    if overlap>1e-6:collisions[tuple(sorted([old_asset,mesh['asset']]))]+=overlap
   planes[key].append((mesh['asset'],poly,box))
 results.append({'building':name,'overlaps':[{'a':p[0],'b':p[1],'area':round(a,6)} for p,a in collisions.items()]})
report={'passed':all(not r['overlaps'] for r in results),'scope':'Same-facing coplanar positive-area triangle overlap between separately placed assets, at the exported door pose. Opposing hidden contact faces are excluded.','buildings':results}
(BASE/('coplanar_open.json' if '--open-doors' in sys.argv else 'coplanar_closed.json')).write_text(json.dumps(report,indent=2))
for row in results:
 print(row['building'],len(row['overlaps']))
 for o in row['overlaps'][:12]:print(' ',o)
raise SystemExit(0 if report['passed'] else 1)
