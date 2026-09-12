extends SceneTree

const BASE := "res://assets/models/city/"
var errors: Array[String] = []
var checks := 0
var ray_checks := 0
var instances: Array[Node3D] = []
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "catalog.json"))
	var existing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/test_library/catalog.json"))
	catalog.assets.append_array(existing.assets)
	for i in catalog.assets.size():
		var entry: Dictionary = catalog.assets[i]
		var asset := load(entry.scene).instantiate() as Node3D
		root.add_child(asset)
		asset.position = Vector3((i % 16) * 24, 0, (i / 16) * 24)
		asset.rotation.y = 0.37 if i % 2 else 0.0
		instances.append(asset)
	await physics_frame
	await physics_frame
	for asset in instances:
		_verify(asset)
	for asset in instances:
		if asset.has_node("Hinge"):
			asset.get_node("Hinge").rotation.y = deg_to_rad(75)
	await physics_frame
	await physics_frame
	for asset in instances:
		if asset.has_node("Hinge"):
			_verify(asset)
	await _doorway_motion_checks()
	await _window_opening_checks()
	var report := {"passed": errors.is_empty(), "assets": instances.size(), "geometry_comparisons": checks, "physics_ray_checks": ray_checks, "errors": errors, "records": records}
	FileAccess.open("res://output/barren_city/03_godot/validation/collisions.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_COLLISION_TEST ", JSON.stringify({"passed": errors.is_empty(), "assets": instances.size(), "geometry_comparisons": checks, "physics_ray_checks": ray_checks, "errors": errors}))
	for asset in instances:
		asset.free()
	quit(0 if errors.is_empty() else 1)

func _verify(asset: Node3D) -> void:
	var mesh_faces := PackedVector3Array()
	var shape_faces := PackedVector3Array()
	for body in asset.get_children():
		if not body is StaticBody3D:
			continue
		_collect(body.get_node("Model"), mesh_faces)
		var collision: CollisionShape3D = body.get_node("MeshCollision")
		for point in (collision.shape as ConcavePolygonShape3D).get_faces():
			shape_faces.append(collision.global_transform * point)
	var matches := mesh_faces.size() == shape_faces.size()
	if matches:
		for i in mesh_faces.size():
			if not mesh_faces[i].is_equal_approx(shape_faces[i]):
				matches = false
				break
	checks += 1
	if not matches:
		errors.append(asset.name + ": collision triangles differ from rendered mesh")
	if mesh_faces.is_empty():
		return
	var bounds := AABB(mesh_faces[0], Vector3.ZERO)
	for point in mesh_faces:
		bounds = bounds.expand(point)
	var rays := 0
	for axis in 3:
		for fraction in [0.2137, 0.4861, 0.7633]:
			var start := bounds.position + bounds.size * Vector3(fraction, fraction, fraction)
			var end := start
			start[axis] = bounds.position[axis] - 1
			end[axis] = bounds.end[axis] + 1
			_check_ray(asset, mesh_faces, start, end)
			_check_ray(asset, mesh_faces, end, start)
			rays += 2
	records.append({"asset": asset.name, "triangle_count": mesh_faces.size() / 3, "geometry_matches": matches, "rays": rays})

func _collect(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for point: Vector3 in node.mesh.get_faces():
			faces.append(node.global_transform * point)
	for child in node.get_children():
		_collect(child, faces)

func _check_ray(asset: Node3D, faces: PackedVector3Array, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var distance := start.distance_to(end)
	var expected := INF
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(start, direction, faces[i], faces[i + 1], faces[i + 2])
		if hit != null:
			var d := start.distance_to(hit)
			if d <= distance:
				expected = minf(expected, d)
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.hit_back_faces = true
	var result := asset.get_world_3d().direct_space_state.intersect_ray(query)
	ray_checks += 1
	if is_inf(expected) != result.is_empty():
		errors.append(asset.name + ": mesh/physics ray hit mismatch")
	elif not result.is_empty() and absf(start.distance_to(result.position) - expected) > 0.003:
		errors.append(asset.name + ": physics ray distance differs from mesh")

func _doorway_motion_checks() -> void:
	var door := load(BASE + "scenes/doorway_wood.tscn").instantiate() as Node3D
	root.add_child(door)
	door.position = Vector3(-40, 0, 0)
	var walker := CharacterBody3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.4
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	walker.add_child(shape)
	root.add_child(walker)
	walker.position = Vector3(-40, 0.75, -2)
	await physics_frame
	await physics_frame
	if not walker.test_move(walker.global_transform, Vector3(0, 0, 4)):
		errors.append("Closed door does not block player capsule")
	door.get_node("Hinge").rotation.y = deg_to_rad(90)
	await physics_frame
	await physics_frame
	if walker.test_move(walker.global_transform, Vector3(0, 0, 4)):
		errors.append("Open door/frame blocks player capsule through opening")
	var shifted := walker.global_transform
	shifted.origin.x += 0.8
	if not walker.test_move(shifted, Vector3(0, 0, 4)):
		errors.append("Door jamb does not block player capsule")
	records.append({"test": "doorway_capsule", "radius": 0.22, "height": 1.4, "checks": 3})
	walker.free()
	door.free()

func _window_opening_checks() -> void:
	var paths: Array[String] = []
	for material in ["brick", "plaster", "wood", "brick_red", "corrugated"]:
		paths.append(BASE + "scenes/wall_" + material + "_window.tscn")
	paths.append("res://assets/models/test_library/scenes/structures/wall_window.tscn")
	var models: Array[Node3D] = []
	for i in paths.size():
		var wall := load(paths[i]).instantiate() as Node3D
		wall.position = Vector3(-80, 0, i * 4)
		root.add_child(wall)
		models.append(wall)
	await physics_frame
	await physics_frame
	for wall in models:
		for x in [-0.3, 0.3]:
			for y in [0.875, 1.4375]:
				var start := wall.position + Vector3(x, y, -1)
				var end := wall.position + Vector3(x, y, 1)
				var result := wall.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end))
				if not result.is_empty():
					errors.append(wall.name + ": invisible collision in window opening")
		var bar_start := wall.position + Vector3(0, 0.875, -1)
		var bar_end := wall.position + Vector3(0, 0.875, 1)
		if wall.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(bar_start, bar_end)).is_empty():
			errors.append(wall.name + ": visible window frame missing collision")
		records.append({"test": "open_window", "asset": wall.name, "empty_panes_checked": 4, "solid_frame_checked": true})
		wall.free()
