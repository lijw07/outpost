extends SceneTree

var errors: Array[String] = []
var ray_count := 0
var transitions := preload("res://scripts/world/terrain_transitions.gd").new()

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/blocks/transitions/catalog.json"))
	var imports := 0
	for entry in catalog.assets:
		var data := transitions.variant(entry.base,entry.neighbors)
		var scene: Node3D = load(entry.scene).instantiate()
		world.add_child(scene)
		await physics_frame
		await physics_frame
		for z in 32:
			for x in 32:
				var point := Vector3((x+0.5)/16.0-1,3,(z+0.5)/16.0-1)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*4))
				ray_count += 1
				check(not hit.is_empty() and absf(hit.position.y-float(data.heights[z*32+x])/16.0)<0.001,entry.id+": collider differs from rendered height at "+str(Vector2i(x,z)))
		var model: Node3D = load(entry.model).instantiate()
		world.add_child(model)
		var bounds := AABB()
		var found := false
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
		check(found and bounds.position.is_equal_approx(Vector3(-1,0,-1)) and absf(bounds.end.y-entry.top_y)<0.001 and absf(bounds.size.x-2)<0.001 and absf(bounds.size.z-2)<0.001,entry.id+": Blockbench glTF bounds mismatch")
		imports += 1
		model.free()
		scene.free()
	for mask in 256:
		var neighbors := ["","","","","","","",""]
		for bit in 8:
			if mask & (1 << bit):
				neighbors[bit] = "grass"
		var data := transitions.variant("dirt",neighbors)
		check(data.mesh.get_aabb().size.is_equal_approx(Vector3(2,2,2)),"Eight-neighbor combination has wrong bounds: "+str(mask))
	var before: Node3D = load("res://output/streetscape/before/meadow_restaurant_district.tscn").instantiate()
	var after: Node3D = load("res://scenes/world/meadow_restaurant_district.tscn").instantiate()
	world.add_child(before)
	world.add_child(after)
	var old_grid: GridMap = before.get_node("MeadowBlocks")
	var new_grid: GridMap = after.get_node("MeadowBlocks")
	var foundations: Dictionary = {}
	for node in after.find_children("*","Node3D",true,false):
		if node.get_meta("terrain_block",false) and absf(node.global_position.y+2)<.01:
			foundations[Vector3i(floori(node.global_position.x/2),0,floori(node.global_position.z/2))] = true
	var placement_before: Node3D = load("res://output/streetscape/before/placement_pass.tscn").instantiate()
	for child in placement_before.get_children():
		if not child.get_meta("district_scenery",false):
			continue
		check(after.has_node(NodePath(child.name)),"Missing district object: "+child.name)
		if child is Node3D and after.has_node(NodePath(child.name)):
			var expected: Transform3D = child.transform
			check(expected.is_equal_approx(after.get_node(NodePath(child.name)).transform),"District object moved: "+child.name)
	placement_before.free()
	for cell in old_grid.get_used_cells():
		if new_grid.get_cell_item(cell) < 0:
			check(foundations.has(cell),"District ground missing: "+str(cell))
			continue
		var old_name := old_grid.mesh_library.get_item_name(old_grid.get_cell_item(cell)).split(":")[0]
		var new_name := new_grid.mesh_library.get_item_name(new_grid.get_cell_item(cell)).split(":")[0]
		var expected := old_name
		if new_name == "sidewalk" and old_name in ["grass","grass_flowers","dirt"]:
			expected = "sidewalk"
		if (cell.x in [-8,-2,23,41] and cell.z >= 9 and cell.z <= 12) or (cell.z == 7 and cell.x >= -6 and cell.x <= -4):
			expected = "road_crossing"
		elif (cell.z == 10 and cell.x >= -7 and cell.x <= -3) or (cell.x == -5 and cell.z == 8):
			expected = "road_asphalt"
		check(expected==new_name,"Unexpected terrain change: "+str(cell))
	var item_count := new_grid.mesh_library.get_item_list().size()
	var boundary_count := 0
	var names_before: Dictionary = {}
	for cell in new_grid.get_used_cells():
		names_before[cell] = new_grid.mesh_library.get_item_name(new_grid.get_cell_item(cell))
		if ":" in new_grid.mesh_library.get_item_name(new_grid.get_cell_item(cell)):
			boundary_count += 1
	var repeated := transitions.apply_district(after)
	for cell in names_before:
		var name_now := new_grid.mesh_library.get_item_name(new_grid.get_cell_item(cell))
		if name_now != names_before[cell]:
			print("REAPPLY_DIFF ",cell," ",names_before[cell]," -> ",name_now)
	check(new_grid.mesh_library.get_item_list().size()==item_count,"Reapplying transitions accumulates duplicate mesh variants")
	check(repeated.changed_cells==boundary_count,"Reapplying transitions changes boundary coverage: %s -> %s" % [boundary_count,repeated.changed_cells])
	var report := {"passed":errors.is_empty(),"errors":errors,"assets":catalog.assets.size(),"imported_native_exports":imports,"collision_rays":ray_count,"eight_neighbor_masks":256,"district_cells":old_grid.get_used_cells().size(),"district_objects":before.get_child_count()}
	FileAccess.open("res://output/terrain_transitions/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TERRAIN_TRANSITIONS ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
