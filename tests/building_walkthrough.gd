extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = load("res://scenes/world/buildings_test_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var errors: Array[String] = []
	var visits: Array[Dictionary] = []
	var buildings: Node3D = scene.world.get_node("Buildings")
	for index in buildings.get_child_count():
		scene._teleport(index)
		var building = buildings.get_child(index)
		for frame in 5:
			await physics_frame
		Input.action_press("move_up")
		for frame in 28:
			await physics_frame
		Input.action_release("move_up")
		var event := InputEventKey.new()
		event.keycode = KEY_F
		event.pressed = true
		scene._unhandled_input(event)
		Input.action_press("move_up")
		for frame in 100:
			await physics_frame
		Input.action_release("move_up")
		for frame in 5:
			await physics_frame
		var position: Vector3 = building.to_local(scene.player.global_position)
		var entered: bool = position.z > 0.3 and building.occupied_floor == 0 and not building.get_node("Roof").visible
		if not entered:
			errors.append(building.building_title + ": entry or automatic roof hiding failed at " + str(position))
		visits.append({"building": building.building_title, "entered": entered, "position": str(position)})
	var apartment = buildings.get_child(2)
	scene.player.position = apartment.position + Vector3(8, 0.72, 5.5)
	scene.player.velocity = Vector3.ZERO
	scene.previous_player_position = scene.player.position
	scene.current_player_position = scene.player.position
	for frame in 5:
		await physics_frame
	Input.action_press("move_up")
	for frame in 240:
		await physics_frame
	Input.action_release("move_up")
	for frame in 5:
		await physics_frame
	var top: Vector3 = apartment.to_local(scene.player.global_position)
	if absf(top.y - 4.7) > 0.05 or top.z < 14.3 or apartment.occupied_floor != 1:
		errors.append("Apartment stairs or upper-floor cutaway failed at " + str(top))
	for frame in 5:
		await RenderingServer.frame_post_draw
	scene.get_node("PixelView/SubViewport").get_texture().get_image().save_png("res://output/buildings/review/walked_upstairs.png")
	scene._teleport(0)
	for frame in 5:
		await physics_frame
	if not apartment.get_node("Roof").visible:
		errors.append("Apartment roof did not restore when leaving")
	var report := {"passed": errors.is_empty(), "errors": errors, "visits": visits, "upper_landing": str(top)}
	FileAccess.open("res://output/buildings/validation/walkthrough.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BUILDING_WALKTHROUGH ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
