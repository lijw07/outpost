(async()=>{
const fs=require('fs'),base='/Users/jaili/projects/godot/outpost/assets/models/city/street_mobility';
newProject(Formats.free);const owned=Project;Project.name='Warm neighborhood - street reference study';Project.texture_width=Project.texture_height=32;
const mats={},cache={},entries=[];
for(let row=0;row<5;row++)for(let col=0;col<12;col++){
 const x=(col-5.5)*32,z=(row-2)*32;let name=row===0||row===4?'sidewalk_block':row===2?'center_line_block':'asphalt_block';
 if((col===2||col===9)&&(row>=1&&row<=3))name='crosswalk_block';
 entries.push([name,x,0,z,name==='center_line_block'?90:0]);
}

for(const x of [-160,-32,160])for(const z of [-51,51])entries.push(['street_light',x,32,z,0]);
entries.push(['sedan',-45,32,24,-90],['van',65,32,-24,90]);
entries.push(['bus_stop_shelter',85,32,-52,180],['bus_stop_sign',130,32,-40,0]);
entries.push(['street_bench',-65,32,-49,180],['trash_can',-95,32,-45,0]);
entries.push(['street_bench',50,32,49,0],['trash_can',78,32,49,0]);
entries.push(['stop_sign',-118,32,38,90],['fire_hydrant',-165,32,38,0]);
for(const x of [-144,-112,-16,16,48,144,176])entries.push(['flower_planter',x,32,-62,0]);
for(const x of [-144,-112,-80,-48,-16,16,112,144,176])entries.push(['hedge_planter',x,32,62,0]);
for(const x of [-160,-128,-96,-64,-32,0,32,64,96,128,160])entries.push(['iron_fence',x,32,67,0]);
for(const entry of entries){if(entry[2]===32 && !['sedan','van'].includes(entry[0]))entry[3]+=Math.sign(entry[3])*16;const [name,x,y,z,yaw]=entry;
 if(Project!==owned)throw Error('Selection changed');const d=cache[name]||(cache[name]=JSON.parse(fs.readFileSync(base+'/blockbench/'+name+'.bbmodel','utf8')));
 for(const t of d.textures){if(mats[t.name])continue;mats[t.name]=new Texture({...t,uuid:undefined}).fromDataURL(t.source).add(false);await new Promise(r=>setTimeout(r,15));mats[t.name].updateMaterial();}
 const g=new Group({name:name+'_'+x+'_'+z,origin:[0,0,0]}).init();const rad=yaw*Math.PI/180;
 function point(v){return [v[0]*Math.cos(rad)+v[2]*Math.sin(rad)+x,v[1]+y,-v[0]*Math.sin(rad)+v[2]*Math.cos(rad)+z];}
 for(const el of d.elements){const e=JSON.parse(JSON.stringify(el));e.uuid=undefined;for(const f of Object.values(e.faces))if(typeof f.texture==='number')f.texture=mats[d.textures[f.texture].name].uuid;
 if(e.type==='cube'){const a=point(e.from),b=point(e.to);e.from=a.map((v,i)=>Math.min(v,b[i]));e.to=a.map((v,i)=>Math.max(v,b[i]));e.origin=point(e.origin);const dirs=['north','west','south','east'],old={...e.faces};const shift=((Math.round(yaw/90)%4)+4)%4;for(let i=0;i<4;i++)e.faces[dirs[(i+shift)%4]]=old[dirs[i]];e.faces.up.rotation=((e.faces.up.rotation||0)+yaw+360)%360;e.faces.down.rotation=((e.faces.down.rotation||0)-yaw+360)%360;new Cube(e).addTo(g).init();}
 else{for(const k in e.vertices)e.vertices[k]=point(e.vertices[k]);new Mesh(e).addTo(g).init();}}
}
Canvas.updateAll();const raw=Codecs.project.compile({raw:true,bitmaps:true});raw.outpost={stage:'Reference-inspired Blockbench street assembly for visual review',terrain_dimensions:[32,32,32],instances:entries.length,style_reference:'style_reference.png'};fs.writeFileSync(base+'/review/reference_street.bbmodel',JSON.stringify(raw));Project.save_path=base+'/review/reference_street.bbmodel';Project.saved=true;
return {instances:entries.length,elements:Outliner.elements.length};
})()
