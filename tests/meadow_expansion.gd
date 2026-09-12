extends SceneTree
var errors:Array[String]=[]
var checked_routes:=0
var checked_points:=0
func _initialize():call_deferred("run")
func check(ok,message):
 if not ok:errors.append(message)
func walk_point(space,point,label):
 checked_points+=1
 var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.12,point-Vector3.UP*.22)
 check(not space.intersect_ray(ray).is_empty(),"Missing floor: "+label+" "+str(point))
 var shape=CapsuleShape3D.new();shape.radius=.20;shape.height=1.4
 var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform.origin=point+Vector3.UP*.82
 var hit=space.intersect_shape(q,1)
 if not hit.is_empty():errors.append("Blocked: "+label+" "+str(point)+" "+str(hit[0].collider.get_path()))
func run():
 var s=load("res://scenes/world/meadow_preview.tscn").instantiate();root.add_child(s);current_scene=s
 for i in 8:await process_frame
 s.set_process(false)
 var d=s.world.get_node("MeadowTown");var coast=d.get_node("CoastalQuarter");var expansion=d.get_node("MeadowExpansion")
 var ground=d.get_node("MeadowBlocks");var terrain=coast.get_node("CoastalTerrain");var pier=coast.get_node("TimberPier")
 check(expansion.has_node("MeadowMall"),"Mall missing")
 check(expansion.has_node("retail_lane_assembly"),"Retail lane missing")
 for name in ["BaitBoathouse","MooredRowboat","MooredFishingBoat"]:check(coast.has_node("ApprovedWaterfrontDetails/"+name),name+" missing")
 for cell in terrain.get_used_cells():
  check(ground.get_cell_item(cell)==-1,"Duplicate coast floor "+str(cell));check(pier.get_cell_item(cell)==-1,"Overlapping pier floor "+str(cell))
 for cell in pier.get_used_cells():check(ground.get_cell_item(cell)==-1,"Duplicate pier ground "+str(cell))
 for x in range(-47,-24):check(terrain.get_cell_item(Vector3i(x,0,28))>=0,"Western promenade gap")
 var space=coast.get_world_3d().direct_space_state
 await physics_frame
 for p in [Vector3(-44,0,-34),Vector3(-43,0,-35),Vector3(-43,0,-36),Vector3(-43,0,-37),Vector3(-44,0,-39),Vector3(-44,0,-45),Vector3(-50,2,-45),Vector3(-44,0,-17),Vector3(-40,0,-10),Vector3(-44,0,0),Vector3(-45,0,-4.5),Vector3(-45,0,-6),Vector3(-45,0,-8),Vector3(-53,0,-6),Vector3(-61,0,-6),Vector3(70,0,81.5),Vector3(70,0,80),Vector3(-14,0,-22),Vector3(-75,0,58),Vector3(-55,0,58),Vector3(63,0,63),Vector3(63,0,71),Vector3(61,0,75),Vector3(59,0,83),Vector3(55,0,87),Vector3(71,0,87),Vector3(63,0,95),Vector3(63,0,99)]:walk_point(space,p,"Public access")
 for n in s.find_children("*","Node3D",true,false):
  if n.get_script()!=load("res://scripts/meadow/district_visitor.gd"):continue
  checked_routes+=1
  var a:Vector3=n.route[0];var b:Vector3=n.route[1]
  for i in ceili(a.distance_to(b)*2)+1:
   var t=minf(1.0,float(i)*.5/a.distance_to(b));walk_point(space,a.lerp(b,t),str(n.get_path()))
 var report={"passed":errors.is_empty(),"errors":errors,"walking_samples":checked_points,"visitor_routes":checked_routes,"coastal_tiles":terrain.get_used_cells().size(),"pier_tiles":pier.get_used_cells().size(),"tile_blockbench_units":32,"tile_godot_units":2}
 FileAccess.open("res://output/meadow_scene_integration/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("EXPANSION_QA ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
