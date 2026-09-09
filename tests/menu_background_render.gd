extends SceneTree
## GPU checks and review captures. Use a disposable outpost-ui-checks profile.
## Run without --headless; PNGs are written to user://menu_captures/.

var viewport: SubViewport
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count := 4) -> void:
	for frame in count:
		await process_frame
		await RenderingServer.frame_post_draw

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func capture(filename: String) -> Image:
	var picture := viewport.get_texture().get_image()
	check(picture.save_png("user://menu_captures/" + filename + ".png") == OK, "capture " + filename)
	return picture

func audio_peak(capture_effect: AudioEffectCapture) -> float:
	var buffer := capture_effect.get_buffer(capture_effect.get_frames_available())
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return peak

func check_audio(landscape: Control) -> void:
	var settings := root.get_node("Settings")
	var sfx := AudioServer.get_bus_index("SFX")
	var original_send := AudioServer.get_bus_send(sfx)
	# Godot sends buses toward lower indexes; insert the recorder before SFX.
	AudioServer.add_bus(1)
	var review_bus := 1
	sfx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_name(review_bus,"MenuReviewCapture")
	AudioServer.set_bus_send(review_bus,"Master")
	var capture_effect := AudioEffectCapture.new()
	AudioServer.add_bus_effect(review_bus,capture_effect)
	AudioServer.set_bus_send(sfx,"MenuReviewCapture")
	settings.set_bus_volume("SFX",1.0)
	settings.set_reduce_motion(false)
	var sound: Node2D = landscape.simulation.audio
	await create_timer(0.15).timeout
	capture_effect.clear_buffer()
	sound.emit_sound("rifle",Vector2(1360,600))
	sound.emit_sound("hammer",Vector2(1310,600))
	await create_timer(0.35).timeout
	check(audio_peak(capture_effect) > 0.001,"positional gameplay sounds reach the SFX output")
	check(sound.players.size() == 10 and sound.ambience.playing,"sound playback uses a bounded pool and looping camp ambience")
	settings.set_bus_volume("SFX",0.0)
	await create_timer(0.15).timeout
	capture_effect.clear_buffer()
	sound.advance(1.0)
	sound.emit_sound("rifle",Vector2(1360,600))
	await create_timer(0.25).timeout
	check(audio_peak(capture_effect) < 0.00001,"the SFX slider completely mutes menu gameplay audio")
	settings.set_bus_volume("SFX",1.0)
	settings.set_reduce_motion(true)
	var stopped: bool = not sound.ambience.playing
	for player in sound.players:
		stopped = stopped and not player.playing
	check(stopped,"freezing the demo stops ongoing gameplay sounds and ambience")
	AudioServer.set_bus_send(sfx,original_send)
	AudioServer.remove_bus(review_bus)

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		push_error("Use a rendered Godot instance with an isolated outpost-ui-checks profile.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute("user://menu_captures")
	var settings := root.get_node("Settings")
	settings.set_bus_volume("Master", 0.0)
	settings.set_reduce_motion(true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	viewport.add_child(menu)
	await frames()
	var background: Control = menu.get_node("Background")
	for index in 3:
		background.show_location(index)
		await frames()
		capture("menu_%d" % index)
		menu.get_node("Screens").hide()
		settings.set_reduce_motion(false)
		await frames(12)
		var before := capture("landscape_%d_a" % index)
		await create_timer(0.8).timeout
		await frames()
		var after := capture("landscape_%d_b" % index)
		check(before.get_data() != after.get_data(), "location %d produces animated pixels" % index)
		settings.set_reduce_motion(true)
		await frames()
		before = viewport.get_texture().get_image()
		await frames(12)
		after = viewport.get_texture().get_image()
		check(before.get_data() == after.get_data(), "location %d freezes every effect with Reduce Motion" % index)
		menu.get_node("Screens").show()
		await menu._show_panel(menu._settings_panel)
		await frames()
		capture("settings_%d" % index)
		await menu._go_back()
		await frames()
	for dimensions in [Vector2i(2560, 1080), Vector2i(1440, 1080), Vector2i(1280, 720)]:
		viewport.size = dimensions
		await frames()
		capture("layout_%dx%d" % [dimensions.x, dimensions.y])
		check(background.size == Vector2(dimensions), "background follows viewport size")
		check(background.location.size == Vector2(dimensions), "landscape covers resized viewport")
		var rig: Control = menu._title_panel.get_node("ChainRig")
		var left_link: Sprite2D = rig._link_pool[0][0]
		check(is_equal_approx(left_link.position.x, rig.size.x * 0.5 - rig._chain_x), "resting chains follow resized menu with Reduce Motion")
	await check_audio(background.location)
	viewport.queue_free()
	await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("RENDER CHECK: ", checks, " checks, ", failures, " failed; ", OS.get_user_data_dir().path_join("menu_captures"))
	quit(1 if failures else 0)
