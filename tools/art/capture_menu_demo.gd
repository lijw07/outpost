extends SceneTree
## Capture deterministic gameplay footage in a disposable review profile.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendered, disposable outpost-ui-checks profile.")
		quit(2)
		return
	var settings := root.get_node("Settings")
	settings.set_reduce_motion(true)
	settings.set_bus_volume("Master",0.0)
	DirAccess.make_dir_recursive_absolute("user://demo_frames")
	var view := SubViewport.new()
	view.size = Vector2i(960,540)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.canvas_transform = Transform2D().scaled(Vector2(0.5,0.5))
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	view.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.size = Vector2(1920,1080)
	for frame in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	for location_index in 3:
		var background: Control = menu.get_node("Background")
		background.show_location(location_index)
		var demo: Control = background.location
		demo.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Begin with action underway, then record genuine consecutive simulation steps.
		for tick in 45:
			demo.simulation.step(1.0/30.0)
		for frame in 240:
			demo.simulation.advance(0.05)
			demo._refresh_status()
			await process_frame
			await RenderingServer.frame_post_draw
			var output := "user://demo_frames/frame_%04d.png" % (location_index * 240 + frame)
			view.get_texture().get_image().save_png(output)
		print("CAPTURE: location ",location_index," ",demo.simulation.stats)
	view.queue_free()
	await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("CAPTURE: 720 frames at 20 fps saved to ",OS.get_user_data_dir().path_join("demo_frames"))
	quit()
