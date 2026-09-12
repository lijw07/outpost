extends SceneTree

var failures: Array[String] = []
var checks: Array[String] = []
var results: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks.append(label)
	if not value:
		failures.append(label)

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 2, 100)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -1
	ground.add_child(collision)
	arena.add_child(ground)
	for id in ["sedan", "van", "ambulance", "bus", "forklift"]:
		var vehicle = load("res://assets/models/city/street_mobility/scenes/" + id + ".tscn").instantiate()
		vehicle.controlled = true
		arena.add_child(vehicle)
		vehicle.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 10)))
		vehicle.set_commands(0, 0)
		await frames(15)
		check(vehicle.is_on_floor() and absf(vehicle.position.y) < 0.08, id + ": grounded on tire collision")
		vehicle.set_commands(1, 0)
		await frames(60)
		var forward_distance: float = 10 - vehicle.position.z
		check(forward_distance > 1, id + ": forward movement")
		check(absf(vehicle.wheels[0].rotation.x) > 0.05, id + ": wheels follow actual travel")
		vehicle.set_commands(0, 0, true)
		await frames(40)
		check(absf(vehicle.speed) < 0.05, id + ": braking stops vehicle")
		var start: Vector3 = vehicle.position
		vehicle.set_commands(-1, 0)
		await frames(60)
		check(vehicle.position.z - start.z > 1, id + ": reversing")
		vehicle.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 10)))
		vehicle.set_commands(1, 1)
		await frames(75)
		var left_yaw: float = vehicle.rotation.y
		check(left_yaw > 0.03 and vehicle.position.x < -0.03, id + ": forward left turn")
		check(signf(vehicle.steering_pivots[0].rotation.y) == (-1.0 if id == "forklift" else 1.0), id + ": correct steering axle direction")
		vehicle.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 10)))
		vehicle.set_commands(-1, 1)
		await frames(75)
		check(vehicle.rotation.y < -0.03, id + ": steering reverses yaw while backing")
		if id == "forklift":
			vehicle.set_fork_height(1)
			check(is_equal_approx(vehicle.fork_visual.position.y - vehicle.fork_origin.y, 1), "forklift: visual lift")
			var fork_shapes := 0
			for child in vehicle.get_children():
				if child is CollisionShape3D and child.has_meta("fork_origin"):
					check(is_equal_approx(child.position.y - child.get_meta("fork_origin").y, 1), "forklift: collision follows forks")
					fork_shapes += 1
			check(fork_shapes == 2, "forklift: separate colliders for both forks")
		results.append({"vehicle": id, "forward_distance": forward_distance, "left_yaw": left_yaw})
		vehicle.free()
	var driver = load("res://assets/models/city/street_mobility/scenes/sedan.tscn").instantiate()
	driver.controlled = true
	arena.add_child(driver)
	driver.reset_at(Transform3D(Basis.IDENTITY, Vector3(0, .08, 6)))
	var wall := StaticBody3D.new()
	var wall_mesh := BoxShape3D.new()
	wall_mesh.size = Vector3(10, 3, 1)
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = wall_mesh
	wall_shape.position = Vector3(0, 1.5, 0)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	driver.set_commands(1, 0)
	await frames(150)
	check(driver.position.z > 2.3 and driver.position.z < 3.1, "vehicle body stops at wall without tunneling")
	check(absf(driver.speed) < 0.15, "blocked vehicle does not accumulate speed")
	driver.set_commands(-1, 0)
	await frames(60)
	check(driver.position.z > 3.5, "vehicle can reverse away after collision")
	arena.free()
	await process_frame
	var report := {"passed": failures.is_empty(), "checks": checks.size(), "failures": failures, "measurements": results}
	DirAccess.make_dir_recursive_absolute("res://output/street_mobility")
	FileAccess.open("res://output/street_mobility/driving_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("DRIVING_VALIDATION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
