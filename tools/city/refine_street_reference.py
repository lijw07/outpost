from pathlib import Path

p = Path(__file__).with_name('build_street_mobility.js')
s = p.read_text()
marker = "let owned;"
textures = """
painted('warm_pavers','#9b8d72',x=>{for(let row=0;row<4;row++){const y=row*8;x.fillStyle='#706650';x.fillRect(0,y,32,1);for(let xx=-16+(row%2)*8;xx<32;xx+=16){x.fillRect(xx,y,1,8);x.fillStyle='#b7a587';x.fillRect(xx+2,y+2,12,1);x.fillStyle='#8b7d63';x.fillRect(xx+2,y+6,12,1);x.fillStyle='#706650';}}});
painted('warm_wood','#836347',x=>{for(let y=0;y<32;y+=8){x.fillStyle='#503e2e';x.fillRect(0,y,32,1);x.fillStyle='#a18358';x.fillRect(1,y+1,30,1);x.fillStyle='#6b4f36';for(let i=0;i<3;i++)x.fillRect((i*13+y)%27,y+4,5,1);}});
painted('iron_dark','#303830',x=>{x.fillStyle='#475044';x.fillRect(2,0,2,32);x.fillStyle='#202820';x.fillRect(28,0,3,32);});
painted('hedge_leaves','#50652d',x=>{for(let i=0;i<45;i++){x.fillStyle=['#354720','#71833c','#93a148','#617635'][i%4];x.fillRect((i*11)%32,(i*7+Math.floor(i/4)*3)%32,3+(i%3),2+(i%2));}});
painted('flower_cream','#d2c392',x=>{x.fillStyle='#f1dfb0';x.fillRect(3,3,24,24);x.fillStyle='#c49d46';x.fillRect(12,12,8,8);});
painted('flower_gold','#b19239',x=>{x.fillStyle='#e1bb55';x.fillRect(3,3,24,24);x.fillStyle='#705834';x.fillRect(12,12,8,8);});
painted('road_center_dash','#41473f',x=>{x.fillStyle='#b99b4d';x.fillRect(15,7,2,18);});
painted('curb_pavers','#9b8d72',x=>{x.fillStyle='#b5a487';x.fillRect(0,0,4,32);x.fillStyle='#625a46';x.fillRect(4,0,1,32);for(let y=0;y<32;y+=8){x.fillRect(0,y,32,1);for(let xx=5;xx<32;xx+=9)x.fillRect(xx,y,1,8);}});
painted('curb_corner_pavers','#9b8d72',x=>{x.fillStyle='#b5a487';x.fillRect(0,0,4,32);x.fillRect(0,28,32,4);x.fillStyle='#625a46';x.fillRect(4,0,1,28);x.fillRect(4,27,28,1);for(let y=0;y<32;y+=8){x.fillRect(0,y,32,1);for(let xx=5;xx<32;xx+=9)x.fillRect(xx,y,1,8);}});
"""
if "painted('warm_pavers'" not in s:
    s = s.replace(marker, textures + marker)

helper = """
function roundPart(name,x,z,r0,r1,y0,y1,mat,parent,cap=true){const t=Texture.all.find(t=>t.name===mat+'.png');const m=new Mesh({name,vertices:{},faces:{}});for(let i=0;i<12;i++){const a=i*Math.PI/6;m.vertices['a'+i]=[x+Math.cos(a)*r0,y0,z+Math.sin(a)*r0];m.vertices['b'+i]=[x+Math.cos(a)*r1,y1,z+Math.sin(a)*r1];}for(let i=0;i<12;i++){const j=(i+1)%12,vs=['a'+i,'b'+i,'b'+j,'a'+j];m.addFaces(new MeshFace(m,{vertices:vs,uv:Object.fromEntries(vs.map((v,k)=>[v,[[0,y1-y0],[0,0],[3,0],[3,y1-y0]][k]])),texture:t.uuid}));}if(cap){m.vertices.bottom=[x,y0,z];m.vertices.top=[x,y1,z];for(let i=0;i<12;i++){const j=(i+1)%12;for(const vs of [['bottom','a'+i,'a'+j],['top','b'+j,'b'+i]])m.addFaces(new MeshFace(m,{vertices:vs,uv:Object.fromEntries(vs.map(v=>[v,[(m.vertices[v][0]-x+r0),(m.vertices[v][2]-z+r0)]])),texture:t.uuid}));}}m.addTo(parent).init();return m;}
function lantern(x,y,z,g){roundPart('lantern_foot',x,z,3.7,3,y,y+1,'iron_dark',g);cube('warm_glass',[x-2.1,y+1,z-2.1],[x+2.1,y+9,z+2.1],'lamp_glow',g,true);for(const a of [-2.6,2.1])for(const b of [-2.6,2.1])cube('lantern_frame',[x+a,y+1,z+b],[x+a+.5,y+10,z+b+.5],'iron_dark',g);roundPart('lantern_roof',x,z,4.3,1,y+10,y+13,'iron_dark',g);roundPart('finial',x,z,1,.25,y+13,y+15,'iron_dark',g);}
"""
if 'function roundPart' not in s:
    s = s.replace('function clip(', helper + 'function clip(')

lines = s.splitlines()
for i,line in enumerate(lines):
    if line.startswith('for(const double of'):
        lines[i] = """for(const double of [false,true])await prop(double?'street_light_double':'street_light',['iron_dark','lamp_glow'],g=>{roundPart('plinth',0,0,3.8,3,0,3,'iron_dark',g);roundPart('pedestal',0,0,2,1.2,3,11,'iron_dark',g);roundPart('slender_column',0,0,1.1,.7,11,50,'iron_dark',g);roundPart('collar',0,0,1.5,1.5,46,48,'iron_dark',g);if(double){cube('cross_arm',[-11,48,-.6],[11,49,.6],'iron_dark',g);for(const x of [-10,10]){cube('brace',[Math.min(0,x),46,-.45],[Math.max(0,x),47,.45],'iron_dark',g);lantern(x,49,0,g);}}else lantern(0,49,0,g);});"""
    elif line.startswith("await prop('trash_can'"):
        lines[i] = """await prop('trash_can',['iron_dark'],g=>{roundPart('base',0,0,5.8,5.8,0,2,'iron_dark',g);roundPart('barrel',0,0,5.2,5.8,2,18,'iron_dark',g,false);roundPart('inner_liner',0,0,4.7,5.1,2,17.7,'iron_dark',g,false);for(let i=0;i<12;i++){const a=i*Math.PI/6,x=Math.cos(a)*5.5,z=Math.sin(a)*5.5;cube('vertical_rib',[x-.25,2,z-.25],[x+.25,17,z+.25],'iron_dark',g);}const rim=roundPart('open_rim',0,0,6,6,17,18.5,'iron_dark',g,false);roundPart('rim_inner',0,0,5,5,17,18.5,'iron_dark',g,false);for(let i=0;i<12;i++){const a=i*Math.PI/6,b=(i+1)*Math.PI/6,m=new Mesh({name:'rim_top',vertices:{a:[6*Math.cos(a),18.5,6*Math.sin(a)],b:[5*Math.cos(a),18.5,5*Math.sin(a)],c:[5*Math.cos(b),18.5,5*Math.sin(b)],d:[6*Math.cos(b),18.5,6*Math.sin(b)]},faces:{}});m.addFaces(new MeshFace(m,{vertices:['a','b','c','d'],uv:{a:[0,0],b:[0,1],c:[3,1],d:[3,0]},texture:Texture.all[0].uuid}));m.addTo(g).init();}});"""
    elif line.startswith("await prop('street_bench'"):
        lines[i] = """await prop('street_bench',['iron_dark','warm_wood'],g=>{for(const x of [-14,12]){cube('front_leg',[x,0,-4],[x+1.5,12,-2.5],'iron_dark',g);cube('rear_leg',[x,0,3.5],[x+1.5,22,5],'iron_dark',g);cube('seat_support',[x,10,-5],[x+1.5,12,5],'iron_dark',g);cube('armrest',[x-.5,17,-5],[x+2,18,5],'warm_wood',g);cube('armrest_post',[x,12,-4],[x+1,17,-3],'iron_dark',g);}for(const z of [-5,-1.5,2])cube('seat_slat',[-18,12,z],[18,13.5,z+3],'warm_wood',g);for(const y of [16.5,20])cube('back_slat',[-18,y,4.5],[18,y+3,5.5],'warm_wood',g);});"""
    elif line.startswith("await prop('bus_stop_shelter'"):
        lines[i] = line.replace("[metal,dark,'vehicle_glass','wood'", "['iron_dark','roof','warm_wood',metal,dark,'vehicle_glass','wood'").replace(",metal,g)",",'iron_dark',g)").replace("[33,46,13],dark,g)","[33,46,13],'roof',g)").replace(",'wood',g)",",'warm_wood',g)")
    elif line.startswith('for(const [name,top]of'):
        lines[i] = line.replace("['sidewalk_block','concrete']", "['sidewalk_block','warm_pavers'],['center_line_block','road_center_dash'],['sidewalk_curb_block','curb_pavers'],['sidewalk_corner_block','curb_corner_pavers']")
s = '\n'.join(lines) + '\n'
extras = """
for(const flowers of [false,true])await prop(flowers?'flower_planter':'hedge_planter',['brick_red','dirt','hedge_leaves','flower_cream','flower_gold'],g=>{cube('planter_base',[-16,0,-6],[16,1,6],'brick_red',g);cube('soil',[-15,1,-5],[15,7,5],'dirt',g);for(const x of [-16,14.5])cube('end_wall',[x,1,-6],[x+1.5,8,6],'brick_red',g);for(const z of [-6,4.5])cube('long_wall',[-14.5,1,z],[14.5,8,z+1.5],'brick_red',g);for(let i=0;i<5;i++){const x=-12+i*6;cube('leaf_cluster',[x-3,7,-3.5],[x+3.5,flowers?12:17,3.5],'hedge_leaves',g);if(!flowers)cube('leaf_top',[x-2,17,-2],[x+2,19+(i%2),2],'hedge_leaves',g);if(flowers){for(const z of [-2,2]){cube('stem',[x,10,z],[x+.5,15+(i%2),z+.5],'hedge_leaves',g);cube('blossom',[x-1,14+(i%2),z-1],[x+2,15.5+(i%2),z+2],i%2?'flower_gold':'flower_cream',g,true);}}}});
await prop('iron_fence',['iron_dark'],g=>{for(const x of [-15,14]){cube('post',[x,0,-1],[x+1,24,1],'iron_dark',g);roundPart('post_cap',x+.5,0,1.2,.2,24,26,'iron_dark',g);}for(const y of [4,19])cube('rail',[-14,y,-.5],[14,y+1,.5],'iron_dark',g);for(let x=-11;x<=11;x+=4)cube('picket',[x,3,-.4],[x+.7,22,.4],'iron_dark',g);});
"""
if "prop('iron_fence'" not in s:
    s = s.replace('for(const [name,top]of', extras + 'for(const [name,top]of')
p.write_text(s)
