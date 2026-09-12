extends SceneTree

var district := Node3D.new()
var serial := 0
func _initialize() -> void:
	call_deferred("_run")

func add_asset(path: String, at: Vector3, rotation_y: float = 0) -> Node3D:
	var node: Node3D = load(path).instantiate()
	serial += 1
	node.name = "Place_%03d" % serial
	node.position = at
	node.rotation_degrees.y = rotation_y
	district.add_child(node)
	node.owner = district
	return node

func _run() -> void:
	district.name = "MeadowTown"
	root.add_child(district)
	var library := MeshLibrary.new()
	var terrain_ids := ["grass","sidewalk","road_asphalt","road_lane","dirt"]
	for i in terrain_ids.size():
		var source: Node3D = load(preload("res://scripts/world/block_library.gd").scene_path(terrain_ids[i])).instantiate()
		root.add_child(source)
		var merged := ArrayMesh.new()
		for visual in source.find_children("*","MeshInstance3D",true,false):
			for surface in visual.mesh.get_surface_count():
				var st := SurfaceTool.new()
				st.append_from(visual.mesh,surface,visual.global_transform)
				st.set_material(visual.get_active_material(surface))
				st.commit(merged)
		library.create_item(i)
		library.set_item_name(i,terrain_ids[i])
		library.set_item_mesh(i,merged)
		library.set_item_shapes(i,[merged.create_trimesh_shape(),Transform3D.IDENTITY])
		source.free()
	var ground := GridMap.new()
	ground.name = "MeadowBlocks"
	ground.mesh_library = library
	ground.cell_size = Vector3(2,2,2)
	ground.cell_center_y = false
	ground.position.y = -2
	district.add_child(ground)
	ground.owner = district
	var reservations := [Rect2(-32,0,16,14),Rect2(-2,30,16,12),Rect2(20,36,20,18),Rect2(50,2,12,10),Rect2(-40,-24,18,16),Rect2(32,-24,16,16),Rect2(52,-20,20,16),Rect2(-40,32,16,10),Rect2(54,40,18,12),Rect2(60,-50,20,16),Rect2(24,0,14,12),Rect2(-36,-44,12,10)]
	for x in range(-24,46):
		for z in range(-27,35):
			if x>=0 and x<20 and z>=0 and z<6:continue
			if x>=12 and x<20 and z==6:continue
			var point := Vector2(x*2+1,z*2+1)
			var occupied := false
			for rect in reservations:
				if rect.has_point(point):occupied = true
			var id := 0
			if z>=9 and z<=12 or (x>=-6 and x<=-4 and z<10) or (z in [-16,-15] and x>=-20):
				id = 3 if z==10 or (x==-5 and z<9) else 2
			elif (x==2 and z in [6,7]) or z==8 or z==13 or (z in [-17,-14] and x>=-20) or (x==-7 or x==-3) and z<9:id=1
			elif z==-4 and x>=-1 and x<=18:id=4
			ground.set_cell_item(Vector3i(x,0,z),id)
	var builds := [["maple_family_house",Vector3(-32,0,0)], ["corner_grocery",Vector3(-2,0,30)], ["morrow_hospital",Vector3(20,0,36)], ["cedar_cottage",Vector3(50,0,2)],["district_police_station",Vector3(-40,0,-24)],["meadow_residences",Vector3(32,0,-24)],["courtyard_apartments",Vector3(52,0,-20)],["ash_street_diner",Vector3(-40,0,32)],["fuel_stop",Vector3(54,0,40)],["oakwood_school",Vector3(60,0,-52)],["meadow_grand_hotel",Vector3(-36,0,-44)]]
	for row in builds:
		var building := add_asset("res://scenes/buildings/"+row[0]+".tscn",row[1])
		if row[0]=="meadow_grand_hotel":
			building.rotation.y=PI
			building.position+=Vector3(12,0,10)
		if row[0]=="oakwood_school":
			building.rotation.y=PI
			building.position+=Vector3(20,0,16)
		building.set_meta("district_scenery",true)
		for node in building.find_children("*","Node3D",true,false):
			if node.get_meta("terrain_block",false) and absf(node.global_position.y+2)<.01:
				ground.set_cell_item(Vector3i(floori(node.global_position.x/2),0,floori(node.global_position.z/2)),-1)
		for label in building.find_children("*","Label3D",true,false):label.double_sided=false
	reservations.clear()
	for child in district.get_children():
		if child.get_meta("district_scenery",false):
			var bounds := mesh_bounds(child)
			reservations.append(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z))
	reservations.append(Rect2(23,-1,17,16))
	for x in [-30,-18,0,18,38,56]:
		add_asset("res://assets/models/city/scenes/street_lamp.tscn",Vector3(x,0,27))
	for row in [[-24,22,90],[26,24,-90],[50,22,90]]:
		add_asset("res://assets/models/city/scenes/sedan.tscn",Vector3(row[0],0,row[1]),row[2])
	for x in [0,12,24]:add_asset("res://assets/models/city/scenes/bench.tscn",Vector3(x,0,-9),180)
	add_asset("res://assets/models/city/scenes/dry_fountain.tscn",Vector3(13,0,-16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1284
	var trees := ["meadow_oak","meadow_oak_young","meadow_oak_broad","meadow_oak_tall","meadow_oak_leaning"]
	var positions: Array[Vector2] = []
	for attempt in 900:
		var point := Vector2(rng.randf_range(-46,89),rng.randf_range(-42,67))
		if Rect2(-3,-3,43,32).has_point(point) or (point.x>-15 and point.x< -3 and point.y<29) or point.y>15 and point.y<29:continue
		if point.y>-35 and point.y< -26:continue
		if point.y>-10 and point.y< -5 and point.x>-4 and point.x<39:continue
		var blocked := false
		for rect in reservations:
			if rect.grow(4.5).has_point(point):blocked=true
		for old in positions:
			if point.distance_to(old)<4.2:blocked=true
		if blocked:continue
		positions.append(point)
		add_asset("res://assets/models/trees/scenes/"+trees[positions.size()%trees.size()]+".tscn",Vector3(point.x,0,point.y),rng.randi_range(0,3)*90)
		if positions.size()>=125:break
	var plants := ["bush_berry","bush_round","fern","flowers_daisy","flowers_lavender","grass_tufts"]
	var plant_count := 0
	for attempt in 1200:
		var point := Vector2(rng.randf_range(-46,89),rng.randf_range(-42,67))
		if Rect2(-1,-1,41,29).has_point(point) or (point.x>-15 and point.x< -3 and point.y<29) or point.y>15 and point.y<29:continue
		if point.y>-35 and point.y< -26:continue
		if point.y>-10 and point.y< -5 and point.x>-4 and point.x<39:continue
		var blocked := false
		for rect in reservations:
			if rect.grow(2).has_point(point):blocked=true
		if blocked:continue
		add_asset("res://assets/models/plants/scenes/"+plants[plant_count%plants.size()]+".tscn",Vector3(point.x,0,point.y),rng.randi_range(0,3)*90)
		plant_count+=1
		if plant_count>=300:break
	for x in range(0,24,3):
		add_asset("res://assets/models/plants/scenes/flowers_lavender.tscn",Vector3(x,0,-2))
	for z in [1,5,9,13]:
		add_asset("res://assets/models/trees/scenes/meadow_oak_young.tscn",Vector3(-2.6,0,z))
		add_asset("res://assets/models/plants/scenes/bush_berry.tscn",Vector3(43,0,z))
	preload("res://scripts/parks/park_district_layout.gd").new().apply(district)
	preload("res://scripts/world/meadow_streetscape.gd").new().apply(district)
	var packed := PackedScene.new()
	assert(packed.pack(district)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/meadow_restaurant_district.tscn")==OK)
	print("MEADOW_DISTRICT trees=",positions.size()+4," plants=",plant_count+16)
	quit()

func mesh_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for visual in node.find_children("*","MeshInstance3D",true,false):
		var box: AABB=visual.global_transform*visual.mesh.get_aabb()
		bounds=bounds.merge(box) if found else box
		found=true
	return bounds
