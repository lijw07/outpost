extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = load("res://scenes/world/test_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player: CharacterBody3D = scene.get_node("PixelView/SubViewport/World/Player")
	for i in 10:
		await physics_frame
	Input.action_press("move_up")
	for i in 90:
		await physics_frame
	Input.action_release("move_up")
	var closed_position := player.position
	if closed_position.z > -6.3 or closed_position.z < -7.2:
		errors.append("Player did not stop at the closed door")
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.pressed = true
	Input.parse_input_event(event)
	for i in 3:
		await physics_frame
	Input.action_press("move_up")
	for i in 140:
		await physics_frame
	Input.action_release("move_up")
	var inside_position := player.position
	if inside_position.z < -4 or absf(inside_position.y - 0.7) > 0.04:
		errors.append("Player could not walk through the door onto the floor")
	for i in 5:
		await RenderingServer.frame_post_draw
	scene.get_node("PixelView/SubViewport").get_texture().get_image().save_png("res://output/barren_city/03_godot/review/walk_inside.png")
	var section_checks := 0
	var picker: OptionButton = scene.get_node("Controls/VBoxContainer/SectionPicker")
	for index in picker.item_count:
		picker.item_selected.emit(index)
		for frame in 30:
			await physics_frame
		if player.position.distance_to(scene.destinations[index]) > 0.1:
			errors.append("Section landing is not grounded: " + picker.get_item_text(index))
		section_checks += 1
	var anchor_checks := _check_anchors()
	var report := {"passed": errors.is_empty(), "errors": errors, "closed_door_stop": str(closed_position), "walked_inside": str(inside_position), "section_checks": section_checks, "anchor_checks": anchor_checks}
	FileAccess.open("res://output/barren_city/03_godot/validation/walkthrough.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_WALKTHROUGH ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func _check_anchors() -> int:
	var checked := 0
	for path in ["res://assets/models/city/catalog.json", "res://assets/models/test_library/catalog.json"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for entry in catalog.assets:
			var asset: Node3D = load(entry.scene).instantiate()
			root.add_child(asset)
			var minimum := INF
			var maximum := -INF
			var surface_vertices := 0
			for node in asset.find_children("*", "MeshInstance3D", true, false):
				for vertex in node.mesh.get_faces():
					var point: Vector3 = node.global_transform * vertex
					minimum = minf(minimum, point.y)
					maximum = maxf(maximum, point.y)
					if absf(point.y) < 0.00001:
						surface_vertices += 1
			if entry.category == "blocks" and (absf(minimum) > 0.00001 or absf(maximum - 2.0) > 0.00001):
				errors.append(entry.id + ": full terrain block must stand above ground from Y=0 to Y=2")
			if entry.placement.get("terrain_block", false) and (absf(minimum) > 0.00001 or maximum < 1.99999 or maximum > 2.008):
				errors.append(entry.id + ": terrain module is not a full base-anchored block")
			if entry.placement.anchor == "surface":
				if surface_vertices < 3 or maximum > 0.008:
					errors.append(entry.id + ": walking surface is not at Y=0")
			elif absf(minimum) > 0.00001:
				errors.append(entry.id + ": base is not at Y=0")
			checked += 1
			asset.free()
	return checked
