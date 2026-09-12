extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400,1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252e29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c4c5ad")
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	viewport.add_child(camera)
	for original in [false]:
		var path := "res://output/terrain_transitions/before/meadow_restaurant_district.tscn" if original else "res://scenes/world/meadow_restaurant_district.tscn"
		var district: Node3D = load(path).instantiate()
		world.add_child(district)
		for view in [{"id":"district_street","target":Vector3(-8,0,19),"size":23.0},{"id":"district_path","target":Vector3(13,0,-7),"size":20.0}]:
			var target: Vector3 = view.target
			camera.size = view.size
			camera.position = target + Vector3(4,25,27)
			camera.look_at(target)
			for frame in 5:
				await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://output/terrain_transitions/review/"+view.id+("_before" if original else "_after")+".png")
		district.free()
	print("DISTRICT_RENDER_COMPLETE")
	quit()
