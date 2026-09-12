extends SceneTree

const BASE := "res://assets/models/test_library/"
var report: Array[Dictionary] = []
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var source_list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "sources.json"))
	for entry: Dictionary in source_list.assets:
		_one(entry)
	var result := {"assets": report, "passed": errors.is_empty(), "errors": errors}
	FileAccess.open(BASE + "catalog.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("EXISTING_ASSET_LIBRARY ", JSON.stringify({"assets": report.size(), "errors": errors}))
	quit(0 if errors.is_empty() else 1)

func _one(entry: Dictionary) -> void:
	var original := load(entry.source_scene).instantiate() as Node3D
	if original == null:
		errors.append(entry.id + ": source did not load")
		return
	var scene := Node3D.new()
	scene.name = String(entry.id).replace("/", "_").to_pascal_case()
	scene.set_meta("asset_id", entry.id)
	scene.set_meta("original_scene", entry.source_scene)
	var body := StaticBody3D.new()
	body.name = "Body"
	scene.add_child(body)
	body.owner = scene
	var model := Node3D.new()
	model.name = "Model"
	body.add_child(model)
	model.owner = scene
	var faces := PackedVector3Array()
	_copy_visuals(original, Transform3D.IDENTITY, model, scene, faces)
	original.free()
	if faces.is_empty():
		errors.append(entry.id + ": no mesh triangles")
		scene.free()
		return
	var bounds := AABB(faces[0], Vector3.ZERO)
	for point in faces:
		bounds = bounds.expand(point)
	var surface_anchor: bool = entry.id in ["structures/floor", "structures/floor_16"]
	var shift: float = -bounds.end.y if surface_anchor else -bounds.position.y
	for visual in model.get_children():
		visual.position.y += shift
	for i in faces.size():
		faces[i].y += shift
	bounds.position.y += shift
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var shape_path: String = BASE + "collision/" + entry.id + ".res"
	var scene_path: String = BASE + "scenes/" + entry.id + ".tscn"
	DirAccess.make_dir_recursive_absolute(shape_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
	var error := ResourceSaver.save(shape, shape_path)
	var collision := CollisionShape3D.new()
	collision.name = "MeshCollision"
	collision.shape = load(shape_path)
	body.add_child(collision)
	collision.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, scene_path)
	if error != OK:
		errors.append(entry.id + ": save failed")
	report.append({"id": entry.id, "category": entry.category, "source_scene": entry.source_scene, "scene": scene_path, "placement": {"anchor": "surface" if surface_anchor else "base", "source_y_translation": shift * 16}, "triangles": faces.size() / 3, "bounds_model_units": [[bounds.position.x * 16, bounds.position.y * 16, bounds.position.z * 16], [bounds.end.x * 16, bounds.end.y * 16, bounds.end.z * 16]]})
	scene.free()

func _copy_visuals(node: Node3D, parent_transform: Transform3D, model: Node3D, owner_root: Node3D, faces: PackedVector3Array) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var visual := MeshInstance3D.new()
		visual.name = String(node.name) + "_" + str(model.get_child_count())
		visual.mesh = _without_lods(node.mesh)
		visual.transform = transform
		visual.material_override = node.material_override
		visual.material_overlay = node.material_overlay
		visual.cast_shadow = node.cast_shadow
		visual.visible = node.visible
		for surface in node.mesh.get_surface_count():
			visual.set_surface_override_material(surface, node.get_surface_override_material(surface))
		model.add_child(visual)
		visual.owner = owner_root
		if node.visible:
			for point: Vector3 in node.mesh.get_faces():
				faces.append(transform * point)
	for child in node.get_children():
		if child is Node3D:
			_copy_visuals(child, transform, model, owner_root, faces)

func _without_lods(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface))
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh
