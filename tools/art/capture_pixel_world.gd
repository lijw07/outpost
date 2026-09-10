extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if "--game" in OS.get_cmdline_user_args():
		var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
		root.add_child(game)
		await create_timer(1).timeout
		DirAccess.make_dir_recursive_absolute("user://pixel_world")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://pixel_world/game.png")
		game.simulation.audio.set_enabled(false)
		game.queue_free()
		await process_frame
		root.get_node("UiAudio").stop_all()
		await create_timer(0.2).timeout
		quit()
		return
	var scenes := ["last_watch","dead_air","drowned_mile"]
	var variant := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = clampi(argument.get_slice("=",1).to_int(),0,2)
	var demo: Control = load("res://scenes/ui/backgrounds/"+scenes[variant]+".tscn").instantiate()
	root.add_child(demo)
	root.get_node("Settings").set_reduce_motion(false)
	for tick in 360:
		demo.simulation.step(1.0/30.0)
	demo.renderer.sync(0)
	DirAccess.make_dir_recursive_absolute("user://pixel_world")
	await process_frame
	await RenderingServer.frame_post_draw
	demo.viewport.get_texture().get_image().save_png("user://pixel_world/scene_%d.png" % variant)
	var motion := "--motion" in OS.get_cmdline_user_args()
	if motion:
		demo.set_process(false)
		DirAccess.make_dir_recursive_absolute("user://pixel_world/frames")
		for frame in 180:
			demo.simulation.advance(1.0/60.0)
			demo.renderer.sync(1.0/60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			demo.viewport.get_texture().get_image().save_png("user://pixel_world/frames/frame_%04d.png" % frame)
	demo.simulation.audio.set_enabled(false)
	demo.queue_free()
	await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("PIXEL WORLD CAPTURE: native 640x360, 3D terrain, 2D sprite cast")
	quit()
