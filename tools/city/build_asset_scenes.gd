extends SceneTree

const BASE := "res://assets/models/city/"
const REPORT := "res://output/barren_city/03_godot/validation/build.json"
var failures: Array[String] = []
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "scenes")
	DirAccess.make_dir_recursive_absolute(BASE + "collision")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "catalog.json"))
	for entry: Dictionary in catalog.assets:
		if "--terrain-blocks" in OS.get_cmdline_user_args() and not entry.placement.get("terrain_block", false):
			continue
		_build_one(entry)
	var report := {"scene_count": records.size(), "passed": failures.is_empty(), "errors": failures, "assets": records}
	FileAccess.open(REPORT, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_BUILD ", JSON.stringify({"scene_count": records.size(), "errors": failures}))
	quit(0 if failures.is_empty() else 1)

func _build_one(entry: Dictionary) -> void:
	var source := load(entry.model) as PackedScene
	if source == null:
		failures.append(entry.id + ": model failed to import")
		return
	if entry.placement.get("unified_doorway", false):
		_build_unified_doorway(entry, source)
		return
	var scene := Node3D.new()
	scene.name = String(entry.id).to_pascal_case()
	var body: StaticBody3D
	var hinged: bool = entry.id == "door_metal"
	if hinged:
		body = AnimatableBody3D.new()
		body.sync_to_physics = false
		body.name = "Hinge"
		body.position = Vector3(-9.0 / 16.0, 0, 0)
		body.set_meta("closed_angle_degrees", 0.0)
		body.set_meta("open_angle_degrees", 90.0)
	else:
		body = StaticBody3D.new()
		body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 1
	scene.add_child(body)
	body.owner = scene
	var model := source.instantiate() as Node3D
	model.name = "Model"
	body.add_child(model)
	model.owner = scene
	if hinged:
		model.position = -body.position
	var faces := PackedVector3Array()
	var meshes: Array[MeshInstance3D] = []
	_collect(model, Transform3D.IDENTITY, faces, meshes)
	if faces.is_empty():
		failures.append(entry.id + ": no triangles")
		scene.free()
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision_path: String = BASE + "collision/" + entry.id + ".res"
	var error := ResourceSaver.save(shape, collision_path)
	if error != OK:
		failures.append(entry.id + ": collision save failed")
	var collision := CollisionShape3D.new()
	collision.name = "MeshCollision"
	collision.shape = load(collision_path)
	body.add_child(collision)
	collision.owner = scene
	scene.set_meta("asset_id", entry.id)
	scene.set_meta("tile_size", 2.0)
	scene.set_meta("placement_anchor", entry.placement.anchor)
	if entry.placement.get("terrain_block", false):
		scene.set_meta("terrain_block", true)
	scene.set_meta("collision_source", "all imported mesh triangles with accumulated transforms")
	var packed := PackedScene.new()
	error = packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, entry.scene)
	if error != OK:
		failures.append(entry.id + ": scene save failed")
	records.append({"id": entry.id, "meshes": meshes.size(), "triangles": faces.size() / 3, "hinged": hinged})
	scene.free()

func _build_unified_doorway(entry: Dictionary, source: PackedScene) -> void:
	var scene := Node3D.new()
	scene.name = "DoorwayWood"
	scene.set_meta("asset_id", entry.id)
	scene.set_meta("placement_anchor", "base")
	scene.set_meta("tile_size", 2.0)
	var frame := StaticBody3D.new()
	frame.name = "Body"
	var hinge := AnimatableBody3D.new()
	hinge.name = "Hinge"
	hinge.sync_to_physics = false
	hinge.position = Vector3(entry.placement.hinge[0], entry.placement.hinge[1], entry.placement.hinge[2]) / 16.0
	for body in [frame, hinge]:
		scene.add_child(body)
		body.owner = scene
		var model := Node3D.new()
		model.name = "Model"
		body.add_child(model)
		model.owner = scene
	var original := source.instantiate() as Node3D
	_copy_door_parts(original, Transform3D.IDENTITY, frame.get_node("Model"), hinge.get_node("Model"), scene, hinge.position)
	original.free()
	var triangles := 0
	for body in [frame, hinge]:
		var faces := PackedVector3Array()
		var meshes: Array[MeshInstance3D] = []
		_collect(body.get_node("Model"), Transform3D.IDENTITY, faces, meshes)
		if faces.is_empty():
			failures.append(entry.id + ": missing doorway component " + body.name)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var path: String = BASE + "collision/" + entry.id + "_" + String(body.name).to_lower() + ".res"
		if ResourceSaver.save(shape, path) != OK:
			failures.append(entry.id + ": collision save failed")
		var collision := CollisionShape3D.new()
		collision.name = "MeshCollision"
		collision.shape = load(path)
		body.add_child(collision)
		collision.owner = scene
		triangles += faces.size() / 3
	var packed := PackedScene.new()
	packed.pack(scene)
	if ResourceSaver.save(packed, entry.scene) != OK:
		failures.append(entry.id + ": scene save failed")
	records.append({"id": entry.id, "triangles": triangles, "hinged": true, "unified_doorway": true})
	scene.free()

func _copy_door_parts(node: Node3D, parent_transform: Transform3D, frame_model: Node3D, leaf_model: Node3D, scene: Node3D, pivot: Vector3, in_leaf: bool = false) -> void:
	var relative := parent_transform * node.transform
	in_leaf = in_leaf or node.name == "door_hinge"
	if node is MeshInstance3D and node.mesh != null:
		var visual := MeshInstance3D.new()
		visual.name = node.name
		visual.mesh = node.mesh
		visual.transform = relative
		if in_leaf:
			visual.position -= pivot
		var parent := leaf_model if in_leaf else frame_model
		parent.add_child(visual)
		visual.owner = scene
	for child in node.get_children():
		if child is Node3D:
			_copy_door_parts(child, relative, frame_model, leaf_model, scene, pivot, in_leaf)

func _collect(node: Node3D, parent_transform: Transform3D, faces: PackedVector3Array, meshes: Array[MeshInstance3D]) -> void:
	var relative := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		meshes.append(node)
		for point: Vector3 in node.mesh.get_faces():
			faces.append(relative * point)
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				if material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
					failures.append(node.name + ": imported texture filtering is not nearest")
	for child in node.get_children():
		if child is Node3D:
			_collect(child, relative, faces, meshes)
