extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#252e29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#c4c5ad")
	environment.environment.ambient_light_energy = 0.75
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#fff2d7")
	world.add_child(sun)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.5
	camera.position = Vector3(14, 18, 23)
	camera.look_at(Vector3(5, 0.4, 5))
	camera.current = true
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/blocks/catalog.json"))
	var index := 0
	var failures: Array[String] = []
	for entry in catalog.assets:
		if not entry.placement.get("terrain_block", false):
			continue
		var block: Node3D = load(entry.scene).instantiate()
		world.add_child(block)
		block.position = Vector3((index % 4) * 3.4, 0, (index / 4) * 3.4)
		var label := Label3D.new()
		label.text = entry.id.replace("floor_", "").replace("_", " ")
		label.font_size = 32
		label.pixel_size = 0.009
		label.modulate = Color("#eee8cb")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = block.position + Vector3(0, 2.5, 0)
		world.add_child(label)
		await physics_frame
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(block.position + Vector3(0.5, 3, 0.5), block.position + Vector3(0.5, -1, 0.5))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf(hit.position.y - 2.0) > 0.008:
			failures.append(entry.id + ": block top collision incorrect")
		index += 1
	for frame in 8:
		await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://output/barren_city/09_terrain_blocks/review/terrain_blocks.png")
	FileAccess.open("res://output/barren_city/09_terrain_blocks/validation/godot_blocks.json", FileAccess.WRITE).store_string(JSON.stringify({"blocks": index, "errors": failures, "passed": failures.is_empty()}, "\t"))
	print("TERRAIN_BLOCKS ", index, " errors=", failures)
	quit(0 if failures.is_empty() else 1)
