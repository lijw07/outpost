extends SceneTree
var errors:Array=[]
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,text:String)->void:
	if not ok:errors.append(text)
func capture(scene, filename:String, target:Vector3, size3:float)->void:
	scene.viewport.size=Vector2i(1600,1000)
	scene.camera_target=target;scene.zoom=size3;scene._update_camera()
	check(scene.camera.project_ray_origin(Vector2(scene.viewport.size.x*.5,scene.viewport.size.y-1)).y>0,"Wide camera clips the walking surface")
	for i in 5:await RenderingServer.frame_post_draw
	scene.viewport.get_texture().get_image().save_png("res://output/coast/review/"+filename+".png")
func _run()->void:
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in 8:await process_frame
	scene.set_process(false)
	var district:Node3D=scene.world.get_node("MeadowTown")
	var coast:Node3D=district.get_node("CoastalQuarter")
	var terrain:GridMap=coast.get_node("CoastalTerrain")
	var pier:GridMap=coast.get_node("TimberPier")
	var ground:GridMap=district.get_node("MeadowBlocks")
	for cell in terrain.get_used_cells():
		check(ground.get_cell_item(cell)==-1,"Coastal terrain duplicates underlying ground")
		check(pier.get_cell_item(cell)==-1,"Pier overlaps coast floor")
	for cell in pier.get_used_cells():check(ground.get_cell_item(cell)==-1,"Pier duplicates ground")
	check(coast.has_node("HarborCottage"),"Harbor office missing")
	var space:=coast.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.4
	await physics_frame
	for p in [Vector2(47,29),Vector2(47,40),Vector2(47,55),Vector2(47,57),Vector2(63,57),Vector2(63,63),Vector2(63,71),Vector2(61,75),Vector2(59,83),Vector2(55,87),Vector2(71,87),Vector2(63,95),Vector2(63,101),Vector2(83,29),Vector2(83,37),Vector2(85,55)]:
		var foot:=Vector3(p.x,0,p.y)
		var ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.14,foot-Vector3.UP*.18)
		check(not space.intersect_ray(ray).is_empty(),"Missing walking surface at "+str(p))
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=foot+Vector3.UP*.82
		check(space.intersect_shape(query,1).is_empty(),"Obstructed promenade or pier at "+str(p))
	for visitor in coast.get_node("PromenadeVisitors").get_children():
		var a:Vector3=visitor.route[0];var b:Vector3=visitor.route[1]
		for i in ceili(a.distance_to(b)*2)+1:
			var t:=minf(1.0,float(i)*.5/a.distance_to(b))
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=a.lerp(b,t)+Vector3.UP*.82
			if not space.intersect_shape(query,1).is_empty():errors.append("Visitor route obstructed: "+visitor.name);break
	var owned_limit:=Rect2(-4,-4,44,20)
	var helper=preload("res://scripts/parks/park_district_layout.gd").new()
	for node in coast.get_node("GardensAndStreetFurniture").get_children():check(not helper.bounds(node).intersects(owned_limit),"Coastal prop obstructs future restaurant land")
	for grid in [terrain,pier]:
		for id in grid.mesh_library.get_item_list():
			check(grid.mesh_library.get_item_shapes(id)[0].get_faces()==grid.mesh_library.get_item_mesh(id).get_faces(),"Coast terrain collision differs from mesh")
	if DisplayServer.get_name()!="headless":
		scene.hud.visible=false
		if is_instance_valid(scene.plot_caption):scene.plot_caption.visible=false
		if is_instance_valid(scene.plot_overlay):scene.plot_overlay.visible=false
		await capture(scene,"coastal_neighborhood",Vector3(22,0,33),88)
		await capture(scene,"waterfront",Vector3(28,0,76),75)
		await capture(scene,"garden_and_restaurant",Vector3(17,0,0),55)
		scene.hud.visible=true
		await capture(scene,"playable_coast",Vector3(28,0,76),75)
	var report:={"passed":errors.is_empty(),"errors":errors,"coastal_tiles":terrain.get_used_cells().size(),"pier_tiles":pier.get_used_cells().size()}
	FileAccess.open("res://output/coast/validation/scene.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COAST_QA ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
