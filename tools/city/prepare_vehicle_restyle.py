import copy,json,math,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OLD=ROOT/'output/barren_city/02_blockbench_v4_doorway';NEW=ROOT/'output/barren_city/05_vehicle_restyle'
for d in ['blockbench','gltf','textures']:shutil.copytree(OLD/d,NEW/d,dirs_exist_ok=True)
for d in ['tools','validation','review']:(NEW/d).mkdir(parents=True,exist_ok=True)
spec=json.loads((OLD/'asset_spec.json').read_text())
def cube(a,n,lo,hi,mat,group='body'):
 a['cubes'].append({'name':n,'from':lo,'to':hi,'material':mat,'group':group})
def quad(a,n,pts,mat,normal):
 u=[pts[1][i]-pts[0][i] for i in range(3)];v=[pts[2][i]-pts[0][i] for i in range(3)];cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
 if sum(cross[i]*normal[i] for i in range(3))<0:pts=list(reversed(pts))
 width=math.dist(pts[0],pts[1]);height=math.dist(pts[1],pts[2]);uv=[[0,0],[width,0],[width,height],[0,height]]
 a['meshes'].append({'name':n,'group':'coachwork','material':mat,'vertices':{str(i):p for i,p in enumerate(pts)},'faces':[{'vertices':['0','1','2','3'],'uv':{str(i):p for i,p in enumerate(uv)}}]})
def cabin(a,w,zf,zt,zb,zbt,h,mat):
 y=18
 quad(a,'raked_windscreen_surround',[[-w,y,zf],[w,y,zf],[w,h,zt],[-w,h,zt]],mat,[0,0,-1])
 quad(a,'rear_cabin',[[-w,y,zb],[w,y,zb],[w,h,zbt],[-w,h,zbt]],mat,[0,0,1])
 quad(a,'roof',[[-w,h,zt],[w,h,zt],[w,h,zbt],[-w,h,zbt]],mat,[0,1,0])
 for side in [-1,1]:quad(a,'cabin_side_'+str(side),[[side*w,y,zf],[side*w,y,zb],[side*w,h,zbt],[side*w,h,zt]],mat,[side,0,0])
 lo=.17;hi=.82
 quad(a,'windshield',[[-w+2,y+(h-y)*lo,zf+(zt-zf)*lo-.25],[w-2,y+(h-y)*lo,zf+(zt-zf)*lo-.25],[w-2,y+(h-y)*hi,zf+(zt-zf)*hi-.25],[-w+2,y+(h-y)*hi,zf+(zt-zf)*hi-.25]],'vehicle_glass',[0,0,-1])
 if a['name']=='sedan':
  quad(a,'rear_window',[[-w+2,y+(h-y)*lo,zb+(zbt-zb)*lo+.25],[w-2,y+(h-y)*lo,zb+(zbt-zb)*lo+.25],[w-2,y+(h-y)*hi,zb+(zbt-zb)*hi+.25],[-w+2,y+(h-y)*hi,zb+(zbt-zb)*hi+.25]],'vehicle_glass',[0,0,1])
 for side in [-1,1]:
  x=side*(w+.25)
  low_y=20;high_y=h-2
  front_low=zf+(zt-zf)*(low_y-y)/(h-y)+1
  front_high=zf+(zt-zf)*(high_y-y)/(h-y)+1
  rear_low=zb+(zbt-zb)*(low_y-y)/(h-y)-1
  rear_high=zb+(zbt-zb)*(high_y-y)/(h-y)-1
  ends=[(front_low,front_high,1,1),(3,3,rear_low,rear_high)] if a['name']=='sedan' else [(front_low,front_high,-12,-12)]
  for i,(lf,hf,lr,hr) in enumerate(ends):quad(a,'side_glass_'+str(side)+'_'+str(i),[[x,low_y,lf],[x,low_y,lr],[x,high_y,hr],[x,high_y,hf]],'vehicle_glass',[side,0,0])
for a in spec['assets']:
 if a['category']!='vehicle':continue
 name=a['name'];old=copy.deepcopy(a)
 paint={'sedan':'vehicle_rust','van':'vehicle_olive','ambulance':'vehicle_cream','bus':'vehicle_ochre','forklift':'vehicle_ochre'}[name]
 if name in ['sedan','van','ambulance']:
  w,L={'sedan':(14,32),'van':(15,35),'ambulance':(16,38)}[name];wheel=L-13
  a['cubes']=[copy.deepcopy(c) for c in old['cubes'] if c['name']=='lug'];a['meshes']=copy.deepcopy(old['meshes'])
  cube(a,'underbody',[-w+3,5,-L],[w-3,14,L],'vehicle_trim')
  cube(a,'belt_body',[-w,14,-L],[w,18,L],paint)
  for side in [-1,1]:
   x0,x1=(-w,-w+3) if side<0 else (w-3,w)
   for za,zb in [(-L,-wheel-8),(-wheel+8,wheel-8),(wheel+8,L)]:cube(a,'fender_lower',[x0,6,za],[x1,14,zb],paint)
   x0,x1=(-w-.5,-w) if side<0 else (w,w+.5)
   cube(a,'sill_trim',[x0,5,-wheel+8],[x1,7,wheel-8],'vehicle_trim')
   cube(a,'belt_trim',[x0,16,-L+1],[x1,17,L-1],'vehicle_trim')
   cube(a,'front_door_seam',[x0,7,1],[x1,16,1.5],'vehicle_trim')
   cube(a,'door_handle',[x0,18,-2],[x1,19,1],'vehicle_metal')
   mirror_z=-9 if name=='sedan' else -17
   cube(a,'mirror',[side*(w+1)-1,22,mirror_z],[side*(w+1)+1,24,mirror_z+3],'vehicle_trim')
   xa,xb=(-w,-w+2.25) if side<0 else (w-2.25,w)
   cube(a,'mirror_mount',[xa,22,mirror_z+1],[xb,22.75,mirror_z+2],'vehicle_trim')
  if name=='sedan':
   cube(a,'hood',[-w+1,18,-L+1],[w-1,19,-14],paint)
   cube(a,'trunk',[-w+1,18,21],[w-1,19,L-1],paint)
   cabin(a,w-2,-14,-7,21,14,29,paint)
  else:
   h=34 if name=='van' else 37
   cabin(a,w-1,-L+5,-L+12,L-1,L-1,h,paint)
   for side in [-1,1]:
    x0,x1=(-w-.25,-w+1.25) if side<0 else (w-1.25,w+.25)
    cube(a,'cargo_panel',[x0,19,-10],[x1,h-2,L-3],paint)
    cube(a,'cargo_door_split',[x0,19,14],[x1, h-2,14.5],'vehicle_trim')
    cube(a,'cargo_handle',[x0,23,12],[x1,24,15],'vehicle_metal')
    if name=='ambulance':
     cube(a,'rescue_stripe',[x0,18,-L+4],[x1,20,L-2],'vehicle_rust')
     cube(a,'rescue_vertical',[x0,24,3],[x1,32,5],'vehicle_rust')
     cube(a,'rescue_horizontal',[x0,27,0],[x1,29,8],'vehicle_rust')
   cube(a,'rear_door_seam',[-.25,18,L-.875],[.25,h-1,L-.5],'vehicle_trim')
   for x0,x1 in [(-w+3,-1.5),(1.5,w-3)]:cube(a,'rear_door_window',[x0,24,L-.875],[x1,h-3,L-.5],'vehicle_glass')
   cube(a,'roof_cap',[-w,h+.125,-L+12],[w,h+1,L],paint)
   if name=='ambulance':
    cube(a,'lightbar_mount',[-10,h+1,-L+15],[10,h+2,-L+20],'vehicle_trim')
    cube(a,'lightbar',[-9,h+2,-L+15],[9,h+4,-L+20],'vehicle_rust')
  for front in [-1,1]:
   z0,z1=(-L-1,-L) if front<0 else (L,L+1)
   cube(a,'bumper_'+str(front),[-w,5,z0],[w,8,z1],'vehicle_metal')
   for x0,x1 in [(-w+2,-w+7),(w-7,w-2)]:cube(a,'lamp_'+str(front),[x0,10,z0],[x1,13,z1],'vehicle_cream' if front<0 else 'vehicle_rust')
  cube(a,'grille',[-6,9,-L-.5],[6,14,-L],'vehicle_trim')
  for y in [10,12]:cube(a,'grille_bar',[-5,y,-L-.75],[5,y+.5,-L-.5],'vehicle_metal')
  cube(a,'license_plate',[-3,5.5,-L-1.25],[3,7.5,-L-1],'vehicle_cream')
 else:
  for c in a['cubes']:
   c['material']={'yellow':paint,'paint':'vehicle_olive','glass':'vehicle_glass','metal':'vehicle_metal','rubber':'vehicle_trim','cream':'vehicle_cream','rust':'vehicle_rust'}.get(c['material'],c['material'])
  if name=='bus':
   for side in [-1,1]:
    x0,x1=(-17.5,-17) if side<0 else (17,17.5)
    for y in [14,17]:cube(a,'side_rub_rail',[x0,y,-56],[x1,y+1,56],'vehicle_trim')
   cube(a,'roof_edge',[-17,39,-44],[17,41,48],'vehicle_cream')
  else:
   cube(a,'rear_counterweight',[-12,7,14],[12,20,18],paint)
   for x in [-7,-3,1,5]:cube(a,'rear_vent',[x,11,18],[x+1,17,18.25],'vehicle_trim')
 for c in a['cubes']:
  if c['name']=='lug':c['material']='vehicle_metal'
 for m in a['meshes']:
  m['material']={'rubber':'vehicle_trim','metal':'vehicle_metal'}.get(m['material'],m['material'])
 a['purpose']='Restyled to the warm, muted structural palette: framed panels, deliberate large pixel clusters, rounded tires and readable vehicle silhouette.'
(NEW/'asset_spec.json').write_text(json.dumps(spec,separators=(',',':')))
shutil.copyfile(OLD/'tools/clean_surfaces.py',NEW/'tools/clean_surfaces.py');subprocess.run(['python3',str(NEW/'tools/clean_surfaces.py')],check=True)
clean=json.loads((NEW/'clean_spec.json').read_text());prior=json.loads((OLD/'clean_spec.json').read_text());priorby={a['name']:a for a in prior['assets']}
clean['assets']=[a if a['category']=='vehicle' else priorby[a['name']] for a in clean['assets']]
(NEW/'clean_spec.json').write_text(json.dumps(clean,separators=(',',':')))
builder=(OLD/'tools/build_in_blockbench.js').read_text().replace(str(OLD),str(NEW))
palettes={'vehicle_olive':['#3f4534','#60674c','#7d8265'],'vehicle_ochre':['#514536','#827762','#a18f69'],'vehicle_cream':['#685f4d','#9c967d','#bbb69b'],'vehicle_rust':['#463e34','#765747','#97735b'],'vehicle_trim':['#302c25','#41392f','#514536'],'vehicle_metal':['#41483d','#69705d','#8c907b'],'vehicle_glass':['#28302c','#3e4d46','#647164']}
builder=builder.replace('const font=', 'Object.assign(palettes,'+json.dumps(palettes)+');\nconst font=')
builder=builder.replace("else if(name==='glass'){","else if(name==='vehicle_glass'){ctx.fillStyle=p[0];ctx.fillRect(0,0,32,2);ctx.fillRect(0,0,2,32);ctx.fillStyle=p[2];ctx.fillRect(3,3,12,2);ctx.fillRect(3,5,5,1);}\nelse if(name==='glass'){")
(NEW/'tools/build_in_blockbench.js').write_text(builder);names=[a['name'] for a in spec['assets'] if a['category']=='vehicle'];(NEW/'tools/batch.json').write_text(json.dumps({'names':names,'start':'vehicles'}))
for f in ['validate_modular.py']:shutil.copyfile(OLD/'tools'/f,NEW/'tools'/f)
shutil.copyfile(OLD/'validation/approved_rowhouse.json',NEW/'validation/approved_rowhouse.json')
(NEW/'request.json').write_text(json.dumps({'request':'Match vehicle artwork to the structures; retain round wheels and 32x32 pixel texture density. Character is separate draft-only work.','vehicles':names,'previous_source':str(OLD.relative_to(ROOT))},indent=2))
print('Prepared',names)
