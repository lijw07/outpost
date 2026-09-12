extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	OS.low_processor_usage_mode=false
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for frame in 10:await process_frame
	scene.set_process(false)
	scene.hud.visible=false
	scene.viewport.size=Vector2i(960,640)
	scene.camera_target=Vector3(-7,0,18)
	scene.zoom=34
	scene._update_camera()
	Engine.time_scale=4
	for frame in 240:await physics_frame
	Engine.time_scale=1
	DirAccess.make_dir_recursive_absolute("res://output/restaurant/review/traffic_frames")
	for frame in 32:
		for tick in 9:await physics_frame
		await process_frame
		RenderingServer.force_draw(false)
		scene.viewport.get_texture().get_image().save_png("res://output/restaurant/review/traffic_frames/%03d.png"%frame)
	scene.queue_free()
	for frame in 5:await process_frame
	print("TRAFFIC_CAPTURE_COMPLETE")
	quit()
