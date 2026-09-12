import json,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];old=root/'output/barren_city/02_blockbench_v3_grounded';new=root/'output/barren_city/02_blockbench_v4_doorway'
new.mkdir(exist_ok=True)
for folder in ['blockbench','gltf','textures']:
 shutil.copytree(old/folder,new/folder,dirs_exist_ok=True)
for folder in ['tools','validation','review']:(new/folder).mkdir(exist_ok=True)
spec=json.loads((old/'asset_spec.json').read_text());spec['assets']=[a for a in spec['assets'] if a['name'] not in ['door_wood','wall_wood_door']]
a={'name':'doorway_wood','category':'construction','purpose':'One placeable framed panel door with a fixed frame and movable leaf, created natively in Blockbench.','cubes':[],'meshes':[],'placement':{'origin':'frame base at Y=0','anchor':'base','units_per_tile':32,'texture_pixels_per_unit':1,'source_y_translation':0,'hinge':[-9.75,0,0],'hinge_group':'door_leaf','opening_units':[20,29.5],'unified_doorway':True}}
def box(name,lo,hi,mat,group):a['cubes'].append({'name':name,'from':lo,'to':hi,'material':mat,'group':group})
for side in [-1,1]:
 x0,x1=(-16,-10) if side<0 else (10,16)
 box('frame_side_'+str(side),[x0,0,-2],[x1,32,2],'wood','frame')
 x0,x1=(-12,-10) if side<0 else (10,12)
 for face in [-1,1]:
  z0,z1=(-3,-2) if face<0 else (2,3)
  box('trim_side_'+str(side)+'_'+str(face),[x0,0,z0],[x1,30,z1],'wood_dark','frame')
box('frame_lintel',[-10,29.5,-2],[10,32,2],'wood','frame')
for face in [-1,1]:
 z0,z1=(-3,-2) if face<0 else (2,3)
 box('trim_lintel_'+str(face),[-12,30,z0],[12,32,z1],'wood_dark','frame')
for name,x0,x1 in [('hinge_stile',-9.75,-7.75),('latch_stile',7.75,9.75)]:box(name,[x0,.125,-1],[x1,29.25,1],'wood_dark','door_leaf')
for name,y0,y1 in [('bottom_rail',.125,2.625),('middle_rail',13.5,15.5),('top_rail',26.75,29.25)]:box(name,[-7.75,y0,-1],[7.75,y1,1],'wood_dark','door_leaf')
box('center_mullion',[-.625,2.625,-1],[.625,26.75,1],'wood_dark','door_leaf')
for x0,x1 in [(-7.75,-.625),(.625,7.75)]:
 for y0,y1 in [(2.625,13.5),(15.5,26.75)]:box('recessed_panel_'+str(x0)+'_'+str(y0),[x0,y0,-.625],[x1,y1,.625],'wood','door_leaf')
for face in [-1,1]:
 z0,z1=(-1.5,-1) if face<0 else (1,1.5)
 box('handle_plate_'+str(face),[7.8,12,z0],[9.4,16,z1],'metal','door_leaf')
 z0,z1=(-2.25,-1.5) if face<0 else (1.5,2.25)
 box('handle_lever_'+str(face),[5.75,13.75,z0],[8.9,14.5,z1],'brass','door_leaf')
for y in [4,23]:box('hinge_'+str(y),[-9.75,y,-1.5],[-8.75,y+3,-1],'metal','door_leaf')
spec['assets'].insert(23,a)
(new/'asset_spec.json').write_text(json.dumps(spec,separators=(',',':')))
shutil.copyfile(old/'tools/clean_surfaces.py',new/'tools/clean_surfaces.py')
subprocess.run(['python3',str(new/'tools/clean_surfaces.py')],check=True)
clean=json.loads((new/'clean_spec.json').read_text())
for asset in clean['assets']:
 if asset['name']=='doorway_wood':
  for m in asset['meshes']:
   if m['group']=='door_leaf' and m['material'].startswith('wood'):
    for f in m['faces']:
     for k,uv in f['uv'].items():f['uv'][k]=[uv[1],uv[0]]
(new/'clean_spec.json').write_text(json.dumps(clean,separators=(',',':')))
builder=(old/'tools/build_in_blockbench.js').read_text().replace(str(old),str(new))
builder=builder.replace("for(const g of Object.values(groups))g.addTo(doorGroup);","for(const g of Object.values(groups)){if(!asset.placement.hinge_group||g.name===asset.placement.hinge_group)g.addTo(doorGroup);}")
(new/'tools/build_in_blockbench.js').write_text(builder)
(new/'tools/batch.json').write_text(json.dumps({'names':['doorway_wood'],'start':'doorway'}))
Path('/tmp/outpost_doorway_native.json').write_text(json.dumps({'code':builder}))
for name in ['door_wood','wall_wood_door']:
 for folder,ext in [('blockbench','bbmodel'),('gltf','gltf')]: (new/folder/(name+'.'+ext)).unlink()
(new/'request.json').write_text(json.dumps({'request':'Replace separate wood door and frame with one unified Blockbench doorway, preserving pixel theme and working hinge.','retired':['door_wood','wall_wood_door'],'replacement':'doorway_wood','assets':159,'prior_source':str(old.relative_to(root))},indent=2))
print('Prepared native doorway build:',len(a['cubes']),'parts; total kit',len(spec['assets']))
