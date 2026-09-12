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
	environment.environment.ambient_light_color = Color("#bcc5af")
	environment.environment.ambient_light_energy = 0.75
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#fff2d7")
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#434d38")
	plane.material = material
	ground.mesh = plane
	ground.position.y = -0.04
	world.add_child(ground)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/buildings/catalog.json"))
	for entry in catalog.buildings:
		var building: Node3D = load(entry.scene).instantiate()
		world.add_child(building)
		building.set_physics_process(false)
		var width: float = entry.footprint[0]
		var depth: float = entry.footprint[1]
		var target := Vector3(width / 2, 0.8, depth / 2 - 1)
		camera.size = maxf(width, depth) * 1.15 + 6
		camera.position = target + Vector3(width * 0.55, width * 0.85, -depth * 1.2)
		camera.look_at(target)
		for frame in 5:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://output/buildings/review/" + entry.id + "_exterior.png")
		building.interior_preview = true
		building.set_all_doors_open(true)
		camera.position = target + Vector3(width * 0.25, width * 1.4, -depth * 0.95)
		camera.look_at(target)
		for frame in 5:
			await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://output/buildings/review/" + entry.id + "_interior.png")
		if entry.floors > 1:
			building.preview_floor = 1
			camera.position.y += 4
			camera.look_at(target + Vector3.UP * 4)
			for frame in 5:
				await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://output/buildings/review/" + entry.id + "_upper.png")
		building.free()
	print("BUILDING_RENDERS all catalog images saved")
	quit()
