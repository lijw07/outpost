extends Node

@onready var root: Window = get_tree().root

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var label := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	var output := "res://output/barren_city/08_motion_fix/" + label + "/"
	if "--scaled" in OS.get_cmdline_user_args():
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_factor = 2.0
	var scene: Control = load("res://scenes/world/test_scene.tscn").instantiate()
	root.add_child(scene)
	get_tree().current_scene = scene
	scene.get_node("Controls").hide()
	for i in 30:
		await RenderingServer.frame_post_draw
	var viewport: SubViewport = scene.get_node("PixelView/SubViewport")
	var container: SubViewportContainer = scene.get_node("PixelView")
	var report := {"window": str(root.size), "root_texture": str(root.get_texture().get_image().get_size()), "root_visible": str(root.get_visible_rect()), "scale_mode": root.content_scale_mode, "scale_size": str(root.content_scale_size), "scale_factor": root.content_scale_factor, "render": str(viewport.size), "container_transform": str(container.get_global_transform_with_canvas()), "root_final_transform": str(root.get_final_transform()), "frames": []}
	var index := 0
	for action in ["move_left", "move_right", "move_up", ""]:
		if action != "":
			Input.action_press(action)
		for step in 12:
			for frame in 3:
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(output + "%03d.png" % index)
			var point: Vector2 = scene.camera.unproject_position(Vector3(1, 2, -6))
			var transform := root.get_final_transform() * container.get_global_transform_with_canvas()
			var final_point := transform * point
			report.frames.append({"i": index, "action": action, "time": Time.get_ticks_usec(), "camera": str(scene.camera.position), "player": str(scene.player.position), "point": [point.x, point.y], "final_point": [final_point.x, final_point.y]})
			index += 1
		if action != "":
			Input.action_release(action)
	var errors: Array[String] = []
	if label == "after":
		if Vector2i(root.get_texture().get_image().get_size()) != root.size or viewport.size != root.size:
			errors.append("The world is resampled before display")
		var reference := Vector2(report.frames[0].final_point[0], report.frames[0].final_point[1])
		for frame in report.frames:
			var shift := Vector2(frame.final_point[0], frame.final_point[1]) - reference
			if shift.distance_to(shift.round()) > 0.005:
				errors.append("Scenery moves by fractional screen pixels")
		if Vector2(report.frames[40].point[0], report.frames[40].point[1]).distance_to(Vector2(report.frames[47].point[0], report.frames[47].point[1])) > 0.01:
			errors.append("Camera continues drifting after stopping")
	var timing: Array[float] = []
	Input.action_press("move_right")
	var last := Time.get_ticks_usec()
	for frame in 180:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		timing.append((now - last) / 1000.0)
		last = now
	Input.action_release("move_right")
	timing.sort()
	report["frame_time_median_ms"] = timing[90]
	report["frame_time_p95_ms"] = timing[171]
	if label == "after":
		report["resize_checks"] = []
		root.mode = Window.MODE_WINDOWED
		for dimensions in [Vector2i(1280, 720), Vector2i(1023, 767), Vector2i(1600, 900)]:
			root.size = dimensions
			for frame in 10:
				await RenderingServer.frame_post_draw
			var transform := root.get_final_transform() * container.get_global_transform_with_canvas()
			var aligned := transform.is_equal_approx(Transform2D.IDENTITY)
			var native := Vector2i(root.get_texture().get_image().get_size()) == root.size and viewport.size == root.size
			report.resize_checks.append({"window": str(root.size), "native": native, "aligned": aligned})
			if not aligned or not native:
				errors.append("Resize breaks screen pixel alignment at " + str(dimensions))
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		if "--scaled" in OS.get_cmdline_user_args() and (root.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT or root.content_scale_factor != 2.0):
			errors.append("Scene does not restore display settings on exit")
	report["errors"] = errors
	FileAccess.open(output + "report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	report.erase("frames")
	print("DISPLAY_MOTION ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)
