extends SceneTree

const BASE := "res://assets/models/city/"
var scene: Control
var world: Node3D
var assembly: Node3D
var ground_holes: Array[Rect2] = []
var sections: Node3D

func _initialize() -> void:
	call_deferred("_build")

func _add(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = scene
	return node

func _piece(id: String, position: Vector3, rotation_y: float = 0, parent: Node = null, label: String = "") -> Node3D:
	var asset: Node3D = load(preload("res://scripts/world/block_library.gd").asset_path(id)).instantiate()
	asset.name = label if not label.is_empty() else id
	asset.position = position
	if parent == null and asset.get_meta("terrain_block", false):
		asset.position.y -= 2.0
	asset.rotation.y = rotation_y
	_add(asset, parent if parent != null else assembly)
	return asset

func _build() -> void:
	scene = Control.new()
	scene.name = "TestScene"
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.set_script(load("res://scripts/world/test_scene.gd"))
	var container := SubViewportContainer.new()
	container.name = "PixelView"
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.stretch = true
	container.stretch_shrink = 1
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(container, scene)
	var viewport := SubViewport.new()
	viewport.name = "SubViewport"
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	_add(viewport, container)
	world = Node3D.new()
	world.name = "World"
	_add(world, viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#252e29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#bcc5af")
	environment.environment.ambient_light_energy = 0.75
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_add(environment, viewport)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("#fff2d7")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	_add(sun, viewport)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.5
	camera.near = 0.2
	camera.far = 110
	camera.current = true
	_add(camera, viewport)
	var wire := Node3D.new()
	wire.name = "CollisionOverlay"
	wire.visible = false
	_add(wire, viewport)
	sections = Node3D.new()
	sections.name = "Sections"
	_add(sections, world)
	_section("Assembly", Vector3(1, 0.72, -9))
	_section("City construction", Vector3(45, 0.72, -5))
	_section("City props", Vector3(45, 0.72, 79))
	_section("Vehicles", Vector3(45, 0.72, 187))
	assembly = Node3D.new()
	assembly.name = "Assembly"
	_add(assembly, world)
	for x in 6:
		for z in 6:
			var tile := "floor_wood" if x < 4 or z < 4 else "floor_bath_tile"
			_piece(tile, Vector3(-5 + x * 2, 0, -5 + z * 2))
	for x in 6:
		_piece("wall_wood_window" if x % 2 == 0 else "wall_wood_solid", Vector3(-5 + x * 2, 0, 6.125))
		if x != 3:
			_piece("wall_brick_half", Vector3(-5 + x * 2, 0, -6.125))
	for z in 6:
		_piece("wall_brick_red_window" if z % 2 == 0 else "wall_brick_red_solid", Vector3(-6.125, 0, -5 + z * 2), PI / 2)
		_piece("wall_plaster_solid", Vector3(6.125, 0, -5 + z * 2), PI / 2)
	_piece("doorway_wood", Vector3(1, 0, -6.125), 0, null, "Door")
	_piece("sofa", Vector3(-3.5, 0, 0))
	_piece("rug", Vector3(-3.5, 0.001, -2))
	_piece("coffee_table", Vector3(-3.5, 0.02, -2))
	_piece("bookcase", Vector3(-5.3, 0, 3), -PI / 2)
	_piece("bed", Vector3(3.5, 0, 3.1), PI)
	_piece("nightstand", Vector3(5, 0, 4.3))
	_piece("kitchen_counter", Vector3(-4, 0, 5.4))
	_piece("sink_counter", Vector3(-2, 0, 5.4))
	_piece("stove", Vector3(0, 0, 5.4))
	_piece("fridge", Vector3(1.5, 0, 5.3))
	_piece("table", Vector3(3.5, 0, -1.7))
	_piece("chair", Vector3(3.5, 0, -3))
	_piece("chair", Vector3(3.5, 0, -0.3), PI)
	_piece("dishes", Vector3(3.5, 1.0625, -1.7))
	_piece("sedan", Vector3(-11, 0, -8), 0.25)
	_piece("van", Vector3(-11, 0, 0), -0.15)
	_piece("street_lamp", Vector3(-7, 0, -8))
	_piece("gondola_stocked", Vector3(10, 0, -2))
	_piece("produce_bin", Vector3(12, 0, -2))
	_piece("open_crate", Vector3(10, 0, 1))
	_piece("tire_stack", Vector3(-12, 0, 4))
	for x in range(-8, 9):
		for z in range(-7, -4):
			_piece("road_lane" if z == -6 and x % 2 == 0 else "road_asphalt", Vector3(x * 2, 0, z * 2))
	ground_holes.append(Rect2(-6, -6, 12, 12))
	ground_holes.append(Rect2(-17, -15, 34, 6))
	_catalog()
	_existing_catalog()
	_visual_references()
	_floor()
	_player()
	var panel := PanelContainer.new()
	panel.name = "Controls"
	panel.position = Vector2(20, 20)
	_add(panel, scene)
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	_add(box, panel)
	var label := Label.new()
	label.text = "TEST SCENE\nWASD walk · Shift sprint · F door · C collisions\nQ / E rotate view · Wheel zoom"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#eee8cb"))
	_add(label, box)
	var options := OptionButton.new()
	options.name = "SectionPicker"
	for marker in sections.get_children():
		options.add_item(marker.get_meta("title"))
	_add(options, box)
	var packed := PackedScene.new()
	packed.pack(scene)
	var error := ResourceSaver.save(packed, "res://scenes/world/test_scene.tscn")
	print("CITY_PREVIEW ", error_string(error))
	scene.free()
	quit(0 if error == OK else 1)

func _section(title: String, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = title.to_pascal_case()
	marker.position = position
	marker.set_meta("title", title)
	_add(marker, sections)

func _subtract(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	if not rect.intersects(hole):
		return [rect]
	var hit := rect.intersection(hole)
	var candidates: Array[Rect2] = [
		Rect2(rect.position.x, rect.position.y, hit.position.x - rect.position.x, rect.size.y),
		Rect2(hit.end.x, rect.position.y, rect.end.x - hit.end.x, rect.size.y),
		Rect2(hit.position.x, rect.position.y, hit.size.x, hit.position.y - rect.position.y),
		Rect2(hit.position.x, hit.end.y, hit.size.x, rect.end.y - hit.end.y)]
	var out: Array[Rect2] = []
	for candidate in candidates:
		if candidate.size.x > 0.00001 and candidate.size.y > 0.00001:
			out.append(candidate)
	return out

func _floor() -> void:
	var rectangles: Array[Rect2] = [Rect2(-40, -35, 380, 340)]
	for hole in ground_holes:
		var next: Array[Rect2] = []
		for rect in rectangles:
			next.append_array(_subtract(rect, hole))
		rectangles = next
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for rect in rectangles:
		var corners := [Vector3(rect.position.x, 0, rect.position.y), Vector3(rect.position.x, 0, rect.end.y), Vector3(rect.end.x, 0, rect.end.y), Vector3(rect.end.x, 0, rect.position.y)]
		for i in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[i])
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var body := StaticBody3D.new()
	body.name = "PreviewGround"
	_add(body, world)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#434d38")
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	_add(visual, body)
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	_add(collision, body)

func _catalog() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "catalog.json"))
	var count := {"construction": 0, "prop": 0, "vehicle": 0}
	var offset := {"construction": 0, "prop": 84, "vehicle": 192}
	var group := Node3D.new()
	group.name = "Catalog"
	_add(group, world)
	for entry: Dictionary in catalog.assets:
		var index: int = count[entry.category]
		count[entry.category] += 1
		var position := Vector3(45 + (index % 12) * 12, 0, offset[entry.category] + (index / 12) * 12)
		_piece(entry.id, position, 0, group)
		if entry.get("placement", {}).get("anchor", "base") == "surface":
			var lo: Array = entry.bounds_model_units[0]
			var hi: Array = entry.bounds_model_units[1]
			ground_holes.append(Rect2(position.x + lo[0] / 16.0, position.z + lo[2] / 16.0, (hi[0] - lo[0]) / 16.0, (hi[2] - lo[2]) / 16.0))
		var label := Label3D.new()
		label.name = String(entry.id).replace("/", "_") + "_Label"
		label.text = String(entry.id).replace("_", " ")
		label.position = position + Vector3(0, float(entry.bounds_model_units[1][1]) / 16 + 0.45, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.015
		label.modulate = Color("#e0dcc0")
		_add(label, group)

func _existing_catalog() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/test_library/catalog.json"))
	var groups := ["blocks", "trees", "tree_parts", "rocks", "plants", "mushrooms", "structures", "assemblies"]
	var titles := ["Terrain", "Trees", "Tree parts", "Rocks", "Plants", "Mushrooms", "Existing structures", "Existing house"]
	var group := Node3D.new()
	group.name = "ExistingAssets"
	_add(group, world)
	for family in groups.size():
		var origin := Vector3(230, 0, family * 32)
		_section(titles[family], origin + Vector3(0, 0.72, -6))
		var index := 0
		for entry: Dictionary in catalog.assets:
			if entry.category != groups[family]:
				continue
			var position := origin + Vector3((index % 8) * 12, 0, (index / 8) * 7)
			var asset: Node3D = load(entry.scene).instantiate()
			asset.name = String(entry.id).replace("/", "_")
			asset.position = position
			_add(asset, group)
			var lo: Array = entry.bounds_model_units[0]
			var hi: Array = entry.bounds_model_units[1]
			if entry.placement.anchor == "surface":
				ground_holes.append(Rect2(position.x + lo[0] / 16.0, position.z + lo[2] / 16.0, (hi[0] - lo[0]) / 16.0, (hi[2] - lo[2]) / 16.0))
			_catalog_label(String(entry.id).get_file(), position + Vector3(0, hi[1] / 16.0 + 0.45, 0), group)
			index += 1

func _catalog_label(title: String, position: Vector3, parent: Node) -> void:
	var label := Label3D.new()
	label.text = title.replace("_", " ")
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.015
	label.modulate = Color("#e0dcc0")
	_add(label, parent)

func _visual_references() -> void:
	var group := Node3D.new()
	group.name = "CharactersAndDecals"
	_add(group, world)
	_section("Characters", Vector3(45, 0.72, 225))
	var index := 0
	for id in ["survivor", "soldier", "police", "zombie"]:
		for direction in 4:
			var sprite := Sprite3D.new()
			sprite.name = id + "_" + str(direction)
			sprite.texture = load("res://assets/characters/" + id + ".png")
			sprite.hframes = 4
			sprite.frame = direction
			sprite.pixel_size = 0.0625
			sprite.position = Vector3(45 + index * 12 + direction * 2, 0.7, 232)
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			_add(sprite, group)
		_catalog_label(id, Vector3(48 + index * 12, 2.2, 232), group)
		index += 1
	_section("Blood decals", Vector3(45, 0.72, 258))
	for i in 12:
		var decal := Sprite3D.new()
		decal.name = "Blood" + str(i + 1)
		decal.texture = load("res://assets/ui/decals/blood_splatter_%02d.png" % (i + 1))
		decal.pixel_size = 0.015625
		decal.position = Vector3(45 + (i % 6) * 8, 0.02, 265 + (i / 6) * 8)
		decal.rotation.x = -PI / 2
		decal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_add(decal, group)
		_catalog_label("Blood %02d" % (i + 1), decal.position + Vector3(0, 0.6, -2), group)

func _player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(1, 0.73, -9)
	player.floor_snap_length = 0.2
	player.safe_margin = 0.002
	_add(player, world)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.4
	collision.shape = capsule
	_add(collision, player)
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.texture = load("res://assets/characters/survivor.png")
	sprite.hframes = 4
	sprite.pixel_size = 0.0625
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_add(sprite, player)
