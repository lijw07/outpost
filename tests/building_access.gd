extends SceneTree

var errors: Array[String] = []
var records: Array[Dictionary] = []
var capsule := CapsuleShape3D.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capsule.radius = 0.23
	capsule.height = 1.4
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/buildings/catalog.json"))
	for entry in catalog.buildings:
		await _verify(entry)
	var report := {"passed": errors.is_empty(), "errors": errors, "buildings": records}
	FileAccess.open("res://output/buildings/validation/access.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BUILDING_ACCESS ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func _verify(entry: Dictionary) -> void:
	var building: Node3D = load(entry.scene).instantiate()
	root.add_child(building)
	building.set_all_doors_open(true)
	var walker := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	walker.add_child(shape)
	root.add_child(walker)
	walker.position = Vector3(-50, 0.75, -50)
	await physics_frame
	await physics_frame
	var space := building.get_world_3d().direct_space_state
	var reached_rooms := 0
	for level in int(entry.floors):
		var passable := {}
		var y := level * 4.0
		for x in range(-2, int(entry.footprint[0] * 2) + 3):
			for z in range(-2, int(entry.footprint[1] * 2) + 3):
				var foot := Vector3(x * 0.5, y, z * 0.5)
				var ground_query := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.1, foot - Vector3.UP * 0.16)
				var ground := space.intersect_ray(ground_query)
				if ground.is_empty() or ground.normal.y < 0.9:
					continue
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform.origin = foot + Vector3.UP * 0.75
				query.collision_mask = 1
				if space.intersect_shape(query, 1).is_empty():
					passable[Vector2i(x,z)] = true
		var start := Vector2i(roundi(entry.entry[0] * 2), -1) if level == 0 else Vector2i(16,30)
		if not passable.has(start):
			errors.append(entry.id + ": entrance/landing is obstructed on floor " + str(level))
			continue
		var reached := {start: true}
		var queue: Array[Vector2i] = [start]
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell + delta
				if not passable.has(next) or reached.has(next):
					continue
				var origin := Transform3D(Basis.IDENTITY, Vector3(cell.x * 0.5, y + 0.75, cell.y * 0.5))
				if walker.test_move(origin, Vector3(delta.x * 0.5, 0, delta.y * 0.5)):
					continue
				reached[next] = true
				queue.append(next)
		if entry.id == "courtyard_apartments":
			var map_text := ""
			for z in range(-2, int(entry.footprint[1] * 2) + 3):
				for x in range(-2, int(entry.footprint[0] * 2) + 3):
					map_text += "o" if reached.has(Vector2i(x,z)) else ("." if passable.has(Vector2i(x,z)) else "#")
				map_text += "\n"
			FileAccess.open("res://output/buildings/validation/courtyard_map.txt", FileAccess.WRITE).store_string(map_text)
		for room in entry.rooms:
			if room.level != level:
				continue
			var near := false
			for cell in reached:
				if Vector2(cell.x * 0.5, cell.y * 0.5).distance_to(Vector2(room.point[0], room.point[2])) <= 0.8:
					near = true
					break
			if near:
				reached_rooms += 1
			else:
				errors.append(entry.id + ": cannot reach " + room.name)
	var triangle_checks := 0
	for body in building.find_children("*", "StaticBody3D", true, false):
		var meshes: Array = body.find_children("*", "MeshInstance3D", true, false)
		var collisions: Array = body.find_children("*", "CollisionShape3D", true, false)
		if meshes.is_empty() or collisions.is_empty():
			continue
		var visible_faces: Array[String] = []
		for mesh in meshes:
			var points: PackedVector3Array = mesh.mesh.get_faces()
			append_faces(visible_faces, points, body.global_transform.affine_inverse() * mesh.global_transform)
		var collision_faces: Array[String] = []
		for collision in collisions:
			if collision.shape is ConcavePolygonShape3D:
				append_faces(collision_faces, collision.shape.get_faces(), body.global_transform.affine_inverse() * collision.global_transform)
		visible_faces.sort()
		collision_faces.sort()
		if visible_faces != collision_faces:
			errors.append(entry.id + ": mesh/collision geometry differs at " + str(body.get_path()))
		triangle_checks += 1
	records.append({"id": entry.id, "reachable_rooms": reached_rooms, "rooms": entry.rooms.size(), "mesh_collision_checks": triangle_checks})
	walker.free()
	building.free()
	await physics_frame

func append_faces(target: Array[String], points: PackedVector3Array, transform: Transform3D) -> void:
	for i in range(0,points.size(),3):
		var triangle: Array[String] = []
		for j in 3:
			var point := transform * points[i+j]
			triangle.append("%d,%d,%d" % [roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000)])
		triangle.sort()
		target.append(";".join(triangle))
