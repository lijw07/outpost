(async()=>{
const fs=require('fs'),base='/Users/jaili/projects/godot/outpost/assets/models/city/street_mobility';
const results=[];
for(const name of ['sedan','van','ambulance','bus','forklift']){
 const project=ModelProject.all.findLast(p=>p.save_path===base+'/blockbench/'+name+'.bbmodel');project.select();Modes.options.animate.select();
 const samples=[];
 for(const anim of ['drive_forward','reverse','turn_left','turn_right','reverse_turn_left','reverse_turn_right','preview_forward','preview_reverse','preview_turn_left','preview_turn_right']){
  const a=Animator.animations.find(a=>a.name===anim);a.select();
  for(const factor of [0,.25,.5,.75,1]){Timeline.setTime(a.length*factor);Animator.preview();const wheels=Group.all.filter(g=>g.name.startsWith('wheel_'));const root=Group.all.find(g=>g.name==='vehicle_root');samples.push({clip:anim,time:Timeline.time,root:root.mesh.position.toArray(),wheels:wheels.map(g=>({name:g.name,pivot:g.origin,rotation:g.mesh.rotation.toArray().slice(0,3)}))});}
 }
 results.push({vehicle:name,samples});
}
fs.writeFileSync(base+'/review/blockbench_pose_validation.json',JSON.stringify(results,null,2));
const sedan=ModelProject.all.findLast(p=>p.save_path===base+'/blockbench/sedan.bbmodel');sedan.select();Modes.options.animate.select();
Preview.selected.setProjectionMode(true);Preview.selected.camera.position.set(-100,65,-115);Preview.selected.controls.target.set(0,14,0);Preview.selected.controls.update();Preview.selected.camOrtho.zoom=.18;Preview.selected.camOrtho.updateProjectionMatrix();
fs.mkdirSync(base+'/review/frames',{recursive:true});let index=0;
for(const clip of ['drive_forward','turn_left','turn_right','reverse']){
 const a=Animator.animations.find(a=>a.name===clip);a.select();
 for(let frame=0;frame<12;frame++){Timeline.setTime(frame/12);Animator.preview();await new Promise(resolve=>Preview.selected.screenshot({width:800,height:600,crop:false},data=>{fs.writeFileSync(base+'/review/frames/'+String(index++).padStart(3,'0')+'.png',Buffer.from(data.split(',')[1],'base64'));resolve();}));}
}
return {vehicles_sampled:results.length,poses:results.reduce((n,r)=>n+r.samples.length,0),frames:index};
})()
