extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _bounds(node: Node, bounds: AABB = AABB()) -> AABB:
	if node is MeshInstance3D and node.mesh != null:
		var local: AABB = node.global_transform * node.get_aabb()
		bounds = local if bounds.size == Vector3.ZERO else bounds.merge(local)
	for child in node.get_children(): bounds = _bounds(child, bounds)
	return bounds

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(128,128)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff1d4")
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	var catalog: Dictionary = load("res://scripts/restaurant/restaurant_model.gd").CATALOG
	for id in catalog:
		if "--seating-only" in OS.get_cmdline_user_args() and id not in ["dining","chair"]:continue
		var asset: String = catalog[id].asset
		var path: String = load("res://scripts/world/block_library.gd").asset_path(asset)
		if asset.begins_with("nature:"): path = "res://assets/models/test_library/scenes/plants/" + asset.trim_prefix("nature:") + ".tscn"
		if asset.begins_with("tree:"): path = "res://assets/models/test_library/scenes/trees/" + asset.trim_prefix("tree:") + ".tscn"
		if id == "plant": path = "res://assets/models/test_library/scenes/plants/bush_berry.tscn"
		var prop: Node3D = load(path).instantiate()
		world.add_child(prop)
		if id == "door": prop.get_node("Hinge").rotation.y = PI / 2
		var bounds := _bounds(prop)
		var center := bounds.get_center()
		camera.position = center + Vector3(4,3,5)
		camera.look_at(center)
		camera.size = maxf(bounds.size.length() * 1.05, 1)
		for frame in 3: await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://assets/ui/meadow/thumbnails/%s.png" % id)
		prop.free()
	print("MEADOW_THUMBNAILS_OK")
	quit()
