extends SceneTree

var samples: Array[Dictionary] = []
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate := "--candidate" in OS.get_cmdline_user_args()
	var folder := "res://output/barren_city/04_motion/" + ("candidate" if candidate else "baseline")
	if "--native-output" in OS.get_cmdline_user_args():
		folder = "res://output/barren_city/07_presentation/motion"
	DirAccess.make_dir_recursive_absolute(folder)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var scene: Control = load("res://scenes/world/test_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.set_process(false)
	var viewport: SubViewport = scene.get_node("PixelView/SubViewport")
	scene.get_node("PixelView").stretch = false
	viewport.size = Vector2i(640, 360)
	var camera: Camera3D = scene.camera
	var player: CharacterBody3D = scene.player
	scene.sprite.visible = false
	camera.size = 22.5
	for i in 8:
		await RenderingServer.frame_post_draw
	if candidate:
		scene.resized.disconnect(scene._resize_pixel_view)
	viewport.size = Vector2i(640, 360)
	for i in 3:
		await RenderingServer.frame_post_draw
	for frame in 48:
		scene.camera_target = Vector3(-1 + frame * 0.0125, 0.7, -1)
		scene._update_camera()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder + "/pan_%03d.png" % frame)
		var point := camera.unproject_position(Vector3.ZERO)
		samples.append({"frame": frame, "screen_x": point.x, "screen_y": point.y})
	var max_phase_drift := 0.0
	var origin := Vector2(samples[0].screen_x, samples[0].screen_y)
	for sample in samples:
		var shift := Vector2(sample.screen_x, sample.screen_y) - origin
		max_phase_drift = maxf(max_phase_drift, shift.distance_to(shift.round()))
	if candidate and max_phase_drift > 0.002:
		errors.append("Static scenery drifts across fractional render pixels")
	if candidate:
		scene.resized.connect(scene._resize_pixel_view)
		for angle in [0.0, PI / 8, PI / 4, PI / 2, PI]:
			scene.orbit = angle
			for zoom in [8.0, 22.5, 55.0]:
				camera.size = zoom
				var reference := Vector2.ZERO
				for step in 10:
					scene.camera_target = Vector3(254 + step * 0.013, 0.7, 32 + step * 0.021)
					scene._update_camera()
					var projected := camera.unproject_position(Vector3(254, 0, 32))
					if step == 0:
						reference = projected
					var offset := projected - reference
					if offset.distance_to(offset.round()) > 0.003:
						errors.append("Rotated or zoomed camera loses pixel alignment")
		for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1023, 767)]:
			root.size = resolution
			for frame in 5:
				await process_frame
			scene._resize_pixel_view()
			if "--native-output" in OS.get_cmdline_user_args() and viewport.size != root.size:
				errors.append("Scene does not render at the window's native resolution")
			var output_scale: float = scene.get_node("PixelView").scale.y * root.size.y / scene.size.y
			if absf(output_scale - roundf(output_scale)) > 0.001:
				errors.append("Render pixels scale unevenly at " + str(resolution))
		root.size = Vector2i(1280, 720)
		for frame in 5:
			await process_frame
		scene._resize_pixel_view()
		scene.orbit = 0
		camera.size = 22.5
	scene.sprite.visible = true
	scene._teleport(0)
	scene.set_physics_process(true)
	scene.set_process(true)
	for i in 30:
		await physics_frame
	Input.action_press("move_left")
	var timing: Array[float] = []
	var last_time := Time.get_ticks_usec()
	var motion: Array[Dictionary] = []
	for frame in 180:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		timing.append((now - last_time) / 1000.0)
		last_time = now
		var point := camera.unproject_position(Vector3.ZERO)
		motion.append({"frame": frame, "physics_frame": Engine.get_physics_frames(), "screen_x": point.x, "screen_y": point.y, "player_x": player.position.x})
	Input.action_release("move_left")
	timing.sort()
	var report := {"passed": errors.is_empty(), "errors": errors, "pan_max_phase_drift_pixels": max_phase_drift, "render_frame_ms_median": timing[timing.size() / 2], "render_frame_ms_p95": timing[int(timing.size() * 0.95)], "samples": samples, "motion": motion}
	FileAccess.open(folder + "/motion.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MOTION_CHECK ", JSON.stringify({"passed": errors.is_empty(), "phase_drift": max_phase_drift, "median_ms": report.render_frame_ms_median, "p95_ms": report.render_frame_ms_p95}))
	quit(0 if errors.is_empty() else 1)
