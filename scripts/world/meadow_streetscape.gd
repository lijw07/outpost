extends RefCounted

const Blocks := preload("res://scripts/world/block_library.gd")
const Bounds := preload("res://scripts/parks/park_district_layout.gd")
var district: Node3D
var group: Node3D
var ground: GridMap
var paved: Array[Rect2] = []
var serial := 0

func pave(rect: Rect2i) -> void:
	var sidewalk := -1
	for item in ground.mesh_library.get_item_list():
		if ground.mesh_library.get_item_name(item) == "sidewalk":
			sidewalk = item
	assert(sidewalk >= 0)
	for x in range(rect.position.x,rect.end.x):
		for z in range(rect.position.y,rect.end.y):
			var cell := Vector3i(x,0,z)
			var item := ground.get_cell_item(cell)
			if item < 0:
				continue
			var type := ground.mesh_library.get_item_name(item).split(":")[0]
			if type in ["grass","grass_flowers","dirt","sidewalk"]:
				ground.set_cell_item(cell,sidewalk)
				paved.append(Rect2(x*2,z*2,2,2))

func prop(path: String, position: Vector3, scale3: Vector3 = Vector3.ONE, turn: float = 0.0, parent: Node3D = group) -> Node3D:
	var node: Node3D = load(path).instantiate()
	serial += 1
	node.name = "StreetDetail_%03d" % serial
	node.position = position
	node.scale = scale3
	node.rotation.y = turn
	parent.add_child(node)
	node.owner = district
	return node

func planter(at: Vector3, turn: float = 0.0) -> void:
	var bed := Node3D.new()
	bed.name = "FlowerBox_%02d" % group.get_child_count()
	group.add_child(bed)
	bed.owner = district
	bed.position = at
	bed.rotation.y = turn
	prop("res://assets/models/city/scenes/open_crate.tscn",Vector3.ZERO,Vector3(1.25,.4,.55),0,bed)
	for x in [-.55,.55]:
		prop("res://assets/models/plants/scenes/bush_round.tscn",Vector3(x,.25,0),Vector3(.6,.45,.5),0,bed)
		prop("res://assets/models/plants/scenes/flowers_daisy.tscn",Vector3(x,.45,-.05),Vector3(.62,.62,.55),0,bed)

func apply(target: Node3D) -> Dictionary:
	district = target
	ground = district.get_node("MeadowBlocks")
	var old := district.get_node_or_null("MeadowStreetscape")
	if old != null:
		old.free()
	group = Node3D.new()
	group.name = "MeadowStreetscape"
	group.set_meta("streetscape",true)
	district.add_child(group)
	group.owner = district
	ground.mesh_library = ground.mesh_library.duplicate()
	var road_ids: Dictionary = {}
	for item in ground.mesh_library.get_item_list():
		road_ids[ground.mesh_library.get_item_name(item)] = item
	for x in range(-24,46):
		for z in range(9,13):
			ground.set_cell_item(Vector3i(x,0,z),road_ids["road_lane" if z == 10 else "road_asphalt"])
	for rect in [Rect2i(-24,7,70,2),Rect2i(-24,13,70,2),Rect2i(-8,-27,1,35),Rect2i(-2,-27,1,25),Rect2i(0,-13,12,1),Rect2i(12,-12,1,9),Rect2i(-2,-4,21,1),Rect2i(-16,-4,1,2),Rect2i(-16,-3,9,1),Rect2i(27,6,2,1),Rect2i(40,6,2,1),Rect2i(14,27,2,1)]:
		pave(rect)
	var removed := 0
	var helper := Bounds.new()
	for child in district.get_children():
		if not child is Node3D or child == group:
			continue
		var path: String = child.scene_file_path
		if not ("/plants/" in path or "/trees/" in path):
			continue
		var rect := Rect2(Vector2(child.position.x,child.position.z)-Vector2.ONE*.4,Vector2.ONE*.8) if "/trees/" in path else helper.bounds(child)
		if paved.any(func(walk): return walk.intersects(rect)):
			child.free()
			removed += 1
	var coast := district.get_node_or_null("CoastalQuarter")
	if coast != null:
		var public_routes := [Rect2(-48,16,140,2),Rect2(-48,18,140,8),Rect2(-48,26,140,2),Rect2(-14,-54,8,72)]
		for plant in coast.get_node("GardensAndStreetFurniture").get_children():
			var id: String = plant.get_meta("asset_id","")
			if not (id.begins_with("plants/") or id.begins_with("trees/")):
				continue
			var rect := Rect2(Vector2(plant.global_position.x,plant.global_position.z)-Vector2.ONE*.4,Vector2.ONE*.8) if id.begins_with("trees/") else helper.bounds(plant)
			if public_routes.any(func(route): return route.intersects(rect)):
				plant.free()
		var packed_coast := PackedScene.new()
		assert(packed_coast.pack(coast) == OK)
		assert(ResourceSaver.save(packed_coast,"res://scenes/coast/meadow_waterfront.tscn") == OK)
	for point in [Vector3(-40,0,15),Vector3(-34,0,15),Vector3(44,0,15),Vector3(49,0,15),Vector3(65,0,15),Vector3(71,0,15),Vector3(88,0,15),Vector3(-37,0,29),Vector3(-28,0,29),Vector3(16,0,29),Vector3(40,0,29),Vector3(54,0,29),Vector3(72,0,29)]:
		planter(point)
	for z in [-24,-12,1,11]:
		planter(Vector3(-15,0,z),PI/2)
	for x in [-36,-18,0,18,38,56,74,89]:
		prop("res://assets/models/city/scenes/street_lamp.tscn",Vector3(x,0,17.8),Vector3(.7,.82,.7),PI)
	for z in [-22,-6,5]:
		prop("res://assets/models/city/scenes/street_lamp.tscn",Vector3(-12.7,0,z),Vector3(.7,.82,.7),PI/2)
	for point in [Vector3(-35,0,29),Vector3(18,0,29),Vector3(70,0,29),Vector3(68,0,15)]:
		prop("res://assets/models/city/scenes/bench.tscn",point,Vector3(.85,.85,.85),PI if point.z < 20 else 0.0)
	var cover := district.get_node_or_null("MeadowUnderstory")
	if cover != null:
		cover.free()
	helper._landscape(district,ground)
	preload("res://scripts/world/terrain_transitions.gd").new().apply_district(district)
	return {"paved_cells":paved.size(),"relocated_foliage_count":removed,"details":serial}
