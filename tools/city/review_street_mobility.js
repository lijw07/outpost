(async()=>{
const fs=require('fs'),base='/Users/jaili/projects/godot/outpost/assets/models/city/street_mobility';
const catalog=JSON.parse(fs.readFileSync(base+'/catalog.json','utf8'));
newProject(Formats.free);const owned=Project;Project.name='Street mobility - complete asset review';Project.texture_width=Project.texture_height=32;
const mats={};const entries=[];
const vehicles=catalog.assets.filter(a=>a.category==='vehicle');
const props=catalog.assets.filter(a=>a.category==='street_prop');
const terrain=catalog.assets.filter(a=>a.category==='terrain');
vehicles.forEach((a,i)=>entries.push([a,(i-2)*75,-120]));
props.forEach((a,i)=>entries.push([a,(i%5-2)*85,Math.floor(i/5)*90+20]));
terrain.forEach((a,i)=>entries.push([a,(i-4.5)*44,300]));
for(const [asset,x,z]of entries){
 if(Project!==owned)throw Error('Selection changed');const d=JSON.parse(fs.readFileSync(base+'/blockbench/'+asset.id+'.bbmodel','utf8'));
 for(const t of d.textures){if(mats[t.name])continue;mats[t.name]=new Texture({...t,uuid:undefined}).fromDataURL(t.source).add(false);await new Promise(r=>setTimeout(r,15));mats[t.name].updateMaterial();}
 const g=new Group({name:asset.id,origin:[0,0,0]}).init();
 for(const el of d.elements){const e=JSON.parse(JSON.stringify(el));e.uuid=undefined;e.origin=e.origin.map((v,i)=>v+(i===0?x:i===2?z:0));for(const f of Object.values(e.faces))if(typeof f.texture==='number')f.texture=mats[d.textures[f.texture].name].uuid;
 if(e.type==='cube'){e.from=e.from.map((v,i)=>v+(i===0?x:i===2?z:0));e.to=e.to.map((v,i)=>v+(i===0?x:i===2?z:0));new Cube(e).addTo(g).init();}
 else{e.origin=el.origin;for(const v of Object.values(e.vertices)){v[0]+=x;v[2]+=z;}new Mesh(e).addTo(g).init();}}
}
Canvas.updateAll();const data=Codecs.project.compile({raw:true,bitmaps:true});fs.writeFileSync(base+'/review/street_mobility_gallery.bbmodel',JSON.stringify(data));Project.save_path=base+'/review/street_mobility_gallery.bbmodel';Project.saved=true;
return {assets:entries.length,elements:Outliner.elements.length};
})()
