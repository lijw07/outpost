extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene: Control = load("res://scenes/world/test_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.get_node("Controls").hide()
	for i in 15:
		await RenderingServer.frame_post_draw
	scene._resize_pixel_view()
	scene.camera_target = Vector3(-1, 0.7, -1)
	scene.camera.size = 18
	scene._update_camera()
	for i in 8:
		await RenderingServer.frame_post_draw
	var label := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	root.get_texture().get_image().save_png("res://output/barren_city/07_presentation/" + label + ".png")
	var viewport: SubViewport = scene.get_node("PixelView/SubViewport")
	var pixel_width: float = scene.camera.unproject_position(Vector3(1, 0, 0)).distance_to(scene.camera.unproject_position(Vector3(1.0625, 0, 0)))
	var report := {"window": str(root.size), "render": str(viewport.size), "texture_pixel_screen_width": pixel_width, "native_resolution": viewport.size == root.size}
	FileAccess.open("res://output/barren_city/07_presentation/" + label + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PRESENTATION ", JSON.stringify(report))
	quit(1 if label == "after" and not report.native_resolution else 0)
