extends SceneTree

const BASE := "res://assets/models/city/scenes/"
const OUT := "res://scenes/buildings/"
var scene: Node3D
var levels: Array[Node3D] = []
var serial := 0

func _initialize() -> void:
	call_deferred("_run")

func add(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = scene
	return node

func group(name: String, parent: Node) -> Node3D:
	var found := parent.get_node_or_null(NodePath(name))
	if found != null:
		return found
	var node := Node3D.new()
	node.name = name
	return add(node, parent)

func piece(id: String, position: Vector3, parent: Node, rotation_y: float = 0) -> Node3D:
	var node: Node3D = load(preload("res://scripts/world/block_library.gd").asset_path(id)).instantiate()
	serial += 1
	node.name = id.to_pascal_case() + "_%03d" % serial
	node.position = position
	node.rotation_degrees.y = rotation_y
	add(node, parent)
	if id == "doorway_wood":
		node.set_meta("building_door", true)
	return node

func _run() -> void:
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://output/buildings/building_specs.json"))
	var catalogue: Array[Dictionary] = []
	for spec in specs.buildings:
		_build(spec)
		catalogue.append({"id": spec.id, "title": spec.title, "scene": OUT + spec.id + ".tscn", "footprint": [spec.width, spec.depth], "floors": spec.levels, "rooms": spec.rooms, "entry": spec.entry})
	FileAccess.open(OUT + "catalog.json", FileAccess.WRITE).store_string(JSON.stringify({"buildings": catalogue}, "\t"))
	print("BUILDINGS_BUILT ", catalogue.size())
	quit()

func _build(spec: Dictionary) -> void:
	scene = Node3D.new()
	scene.name = String(spec.id).to_pascal_case()
	scene.set_script(load("res://scripts/buildings/modular_building.gd"))
	scene.building_title = spec.title
	scene.floor_count = spec.levels
	scene.set_meta("building_id", spec.id)
	scene.set_meta("placement", "Ground-floor walking surface at Y=0; terrain foundation extends down to Y=-2")
	serial = 0
	levels.clear()
	var floors := group("Floors", scene)
	for index in int(spec.levels):
		levels.append(group("Level%d" % index, floors))
	for tile in spec.floors:
		piece(tile.id, Vector3(tile.x, tile.level * 4 - 2, tile.z), group("Foundation", levels[tile.level]))
	for part in spec.pieces:
		var parent := group(part.group, levels[part.level])
		piece(part.id, Vector3(part.position[0], part.position[1], part.position[2]), parent, part.rotation)
	var rooms := group("Rooms", scene)
	for entry in spec.rooms:
		var marker := Marker3D.new()
		marker.name = String(entry.name).validate_node_name()
		marker.position = Vector3(entry.point[0], entry.point[1], entry.point[2])
		marker.set_meta("floor", entry.level)
		add(marker, rooms)
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	entrance.position = Vector3(spec.entry[0], 0, spec.entry[2] - 2)
	add(entrance, scene)
	var roof := group("Roof", scene)
	var roof_y: float = (spec.levels - 1) * 4 + 2.005
	if spec.pitched:
		_pitched_roof(spec.width, spec.depth, roof_y, roof)
	else:
		for point in spec.roof_tiles:
			var edge: bool = point[0] == 1 or point[0] == spec.width - 1 or point[1] == 1 or point[1] == spec.depth - 1
			var turn := 0.0
			if point[0] == 1:
				turn = -90
			elif point[0] == spec.width - 1:
				turn = 90
			elif point[1] == spec.depth - 1:
				turn = 180
			piece("roof_edge" if edge else "roof_flat", Vector3(point[0], roof_y, point[1]), roof, turn)
		for x in [3, spec.width - 3]:
			piece("roof_vent", Vector3(x, roof_y + 0.1875, spec.depth - 3), roof)
	for entry in spec.signs:
		var label := Label3D.new()
		label.name = "FacadeSign" + str(serial)
		serial += 1
		label.text = entry.text
		label.font = load("res://assets/ui/font/outpost_pixel.ttf")
		label.font_size = 32
		label.pixel_size = 0.014
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.modulate = Color("#ded3af")
		label.outline_modulate = Color("#292e25")
		label.outline_size = 8
		label.rotation.y = PI
		label.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
		add(label, levels[0])
	var area := Area3D.new()
	area.name = "InteriorArea"
	area.collision_layer = 0
	area.collision_mask = 1
	add(area, scene)
	var shape := BoxShape3D.new()
	shape.size = Vector3(spec.width, spec.levels * 4, spec.depth)
	var collision := CollisionShape3D.new()
	collision.name = "InteriorBounds"
	collision.shape = shape
	collision.position = Vector3(spec.width / 2.0, spec.levels * 2.0, spec.depth / 2.0)
	add(collision, area)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, OUT + spec.id + ".tscn")
	assert(error == OK, "Building save failed: " + spec.id)
	scene.free()

func _pitched_roof(width: float, depth: float, y: float, parent: Node3D) -> void:
	var left := -0.4
	var right := width + 0.4
	var front := -0.4
	var back := depth + 0.4
	var ridge := y + width * 0.17
	var center := width / 2
	var surfaces := SurfaceTool.new()
	surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[Vector3(left,y,front),Vector3(center,ridge,front),Vector3(center,ridge,back),Vector3(left,y,back)], [Vector3(center,ridge,front),Vector3(right,y,front),Vector3(right,y,back),Vector3(center,ridge,back)], [Vector3(left,y,front),Vector3(right,y,front),Vector3(center,ridge,front)], [Vector3(right,y,back),Vector3(left,y,back),Vector3(center,ridge,back)]]
	for polygon in faces:
		var uv: Array[Vector2] = []
		for point in polygon:
			uv.append(Vector2(point.x / 2, point.z / 2) if polygon.size() == 4 else Vector2(point.x / 2, (point.y - y) / 2))
		for i in range(1, polygon.size() - 1):
			for index in [0, i + 1, i]:
				surfaces.set_uv(uv[index])
				surfaces.add_vertex(polygon[index])
	surfaces.generate_normals()
	var mesh := surfaces.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/models/city/textures/roof.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.name = "PitchedRoof"
	add(body, parent)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	add(visual, body)
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	add(collision, body)
