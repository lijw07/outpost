extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size / 2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	for frame in 5:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/street_mobility/" + name + ".png")

func run() -> void:
	var scene = load("res://scenes/world/street_mobility_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await frames(30)
	await capture("godot_day")
	for index in 5:
		await click(scene.buttons[index])
		check(scene.active_index == index, "Mouse selects vehicle %d" % index)
		check(scene.active.controlled and not scene.active.manual_commands, "Selected vehicle takes player input")
	await key(KEY_1, true)
	await key(KEY_1, false)
	var before: Vector3 = scene.active.position
	Input.action_press("move_up")
	await frames(60)
	Input.action_release("move_up")
	check(scene.active.position.x > before.x + 1, "Player input drives along road")
	await key(KEY_SPACE, true)
	await frames(35)
	check(absf(scene.active.speed) < 0.05, "Space stops the vehicle")
	await key(KEY_SPACE, false)
	before = scene.active.position
	Input.action_press("move_down")
	await frames(60)
	Input.action_release("move_down")
	check(scene.active.position.x < before.x - 1, "Player input reverses along road")
	check("REVERSE" in scene.status.text, "HUD reports reverse")
	await key(KEY_R, true)
	await key(KEY_R, false)
	Input.action_press("move_up")
	Input.action_press("move_left")
	await frames(45)
	Input.action_release("move_up")
	Input.action_release("move_left")
	check(scene.active.rotation.y > -PI / 2 + 0.1, "Player steering turns the car")
	await capture("godot_turn")
	await key(KEY_5, true)
	await key(KEY_5, false)
	await key(KEY_E, true)
	await frames(65)
	await key(KEY_E, false)
	check(scene.active.fork_height > 0.8, "E raises forks through player controls")
	await capture("godot_forklift")
	await key(KEY_Q, true)
	await frames(80)
	await key(KEY_Q, false)
	check(scene.active.fork_height < 0.05, "Q lowers forks through player controls")
	await key(KEY_N, true)
	await key(KEY_N, false)
	check(scene.night and scene.sun.light_energy < 0.2, "N changes daylight to dusk")
	await capture("godot_dusk")
	await key(KEY_P, true)
	await key(KEY_P, false)
	await frames(60)
	check(scene.overview and scene.camera.size > 65, "P opens overview")
	await capture("godot_overview")
	var bin = scene.place("wheelie_bin", Vector3(0, 0, 20))
	bin.toggle_lid()
	await frames(60)
	check(bin.lid_open, "Bin opens through fixture API")
	var lids: Array = bin.find_children("*", "AnimatableBody3D", true, false)
	check(lids.size() == 1, "Animated bin retains its moving collider")
	if lids.size() == 1:
		check(absf(lids[0].global_rotation.x) > 0.5, "Lid collider follows the open animation")
	var traffic = scene.place("traffic_signal", Vector3(2, 0, 20))
	traffic.signal_clock = 7
	await frames(2)
	check(traffic.animation_player.current_animation == "green", "Signal selects green phase")
	traffic.signal_clock = 11
	await frames(2)
	check(traffic.animation_player.current_animation == "amber", "Signal selects amber phase")
	traffic.signal_clock = 0
	await frames(2)
	check(traffic.animation_player.current_animation == "red", "Signal selects red phase")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	FileAccess.open("res://output/street_mobility/playthrough_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MOBILITY_PLAYTHROUGH ", JSON.stringify(report))
	scene.queue_free()
	await frames(5)
	quit(0 if failures.is_empty() else 1)
