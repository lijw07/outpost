extends Node3D

const BASE := "res://assets/models/city/street_mobility/scenes/"
const IDS := ["sedan", "van", "ambulance", "bus", "forklift"]
var vehicles: Array[CharacterBody3D] = []
var active: CharacterBody3D
var active_index := 0
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var status: Label
var hint: Label
var buttons: Array[Button] = []
var night := false
var overview := false
var camera_target := Vector3(-16, 0, 0)
var spawn := Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-16, 0.08, 0))
var scene_cache := {}

func _ready() -> void:
	_build_world()
	_build_ui()
	for index in IDS.size():
		var vehicle := place(IDS[index], Vector3(-20 + index * 10, 0.08, 18)) as CharacterBody3D
		vehicles.append(vehicle)
	select_vehicle(0)
	if "--mobility-capture" in OS.get_cmdline_user_args():
		capture_review()

func place(id: String, location: Vector3, yaw := 0.0) -> Node3D:
	if not scene_cache.has(id):
		scene_cache[id] = load(BASE + id + ".tscn")
	var node: Node3D = scene_cache[id].instantiate()
	node.position = location
	node.rotation.y = yaw
	add_child(node)
	return node

func _build_world() -> void:
	for x in range(-21, 22):
		for z in range(-6, 19):
			var id := "asphalt_block"
			if z == -3 or z == 3:
				id = "sidewalk_block"
			elif z >= -2 and z <= 2 and x in [-10, 10]:
				id = "crosswalk_block"
			elif z == 0:
				id = "center_line_block"
			elif z <= -4 or z >= 15:
				id = "sidewalk_block"
			place(id, Vector3(x * 2, -2, z * 2), PI / 2 if id == "center_line_block" else 0)
	for x in [-34, -22, -10, 2, 14, 26, 38]:
		place("street_light", Vector3(x, 0, -5.8))
		place("street_light", Vector3(x, 0, 5.8))
		if x != 2:
			place("flower_planter", Vector3(x + 3, 0, -7.5))
			place("hedge_planter", Vector3(x + 3, 0, 7.5))
	place("bus_stop_shelter", Vector3(5, 0, -6.6), PI)
	place("bus_stop_sign", Vector3(8, 0, -5.4))
	for x in [-29, -14, 18, 33]:
		place("street_bench", Vector3(x, 0, -6.1), PI)
		place("trash_can", Vector3(x + 1.8, 0, -6))
	place("stop_sign", Vector3(-21.5, 0, 5.1), PI / 2)
	place("stop_sign", Vector3(21.5, 0, -5.1), -PI / 2)
	place("traffic_signal", Vector3(18, 0, 5.7))
	place("fire_hydrant", Vector3(-26, 0, 6))
	place("wheelie_bin", Vector3(11, 0, -7))
	for x in [-8, -4, 0, 4, 8]:
		place("traffic_cone", Vector3(x, 0, 27))
	for x in [-32, 32]:
		for z in [14, 18, 22, 26]:
			place("street_bollard", Vector3(x, 0, z))
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/city/street_mobility/catalog.json"))
	var index := 0
	for item in catalog.assets:
		if item.category == "vehicle":
			continue
		var point := Vector3(-36 + (index % 13) * 6, 0 if item.category != "terrain" else 0.1, -10 + (index / 13) * 43)
		place(item.id, point)
		index += 1
	var boundary := StaticBody3D.new()
	boundary.name = "TrackBoundary"
	add_child(boundary)
	for box in [Vector4(-44, 12, 1, 56), Vector4(44, 12, 1, 56), Vector4(0, -14, 90, 1), Vector4(0, 40, 90, 1)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.z, 3, box.w)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(box.x, 1.5, box.y)
		boundary.add_child(collision)
		var mesh := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = shape.size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("58654c")
		block.material = material
		mesh.mesh = block
		mesh.position = collision.position
		boundary.add_child(mesh)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91a08b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbd5ba")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("ffe6bd")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	camera.far = 160
	add_child(camera)
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.09, 0.94)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "NEIGHBORHOOD DRIVE"
	title.add_theme_font_size_override("font_size", 27)
	column.add_child(title)
	var row := HBoxContainer.new()
	column.add_child(row)
	for index in IDS.size():
		var button := Button.new()
		button.text = "%d  %s" % [index + 1, String(IDS[index]).capitalize()]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select_vehicle.bind(index))
		row.add_child(button)
		buttons.append(button)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	column.add_child(status)
	hint = Label.new()
	hint.text = "W / S  Drive / reverse    A / D  Steer    Space  Brake\nR  Reset    Tab  Next vehicle    N  Day / dusk    P  Overview    Esc  Asset library"
	hint.add_theme_font_size_override("font_size", 19)
	column.add_child(hint)

func select_vehicle(index: int) -> void:
	if vehicles.is_empty():
		return
	if active != null:
		active.controlled = false
		active.reset_at(Transform3D(Basis.IDENTITY, Vector3(-20 + active_index * 10, 0.08, 18)))
	active_index = index
	active = vehicles[index]
	active.controlled = true
	active.manual_commands = false
	active.reset_at(spawn)
	camera_target = active.position
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == index)

func _process(delta: float) -> void:
	if active == null:
		return
	if active.position.y < -4:
		active.reset_at(spawn)
	var target := Vector3(0, 0, 13) if overview else active.global_position
	camera_target = camera_target.lerp(target, 1 - exp(-8 * delta))
	camera.size = lerpf(camera.size, 66.0 if overview else 29.0, minf(delta * 8, 1))
	camera.position = camera_target + Vector3(0, 36, 32)
	camera.look_at(camera_target)
	var direction := "REVERSE" if active.speed < -0.1 else "DRIVE" if active.speed > 0.1 else "STOPPED"
	status.text = "%s  ·  %s  ·  %d km/h%s" % [String(IDS[active_index]).capitalize(), direction, roundi(absf(active.speed) * 3.6), "  ·  Q / E  Lower / raise forks" if active_index == 4 else ""]

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		select_vehicle(event.keycode - KEY_1)
	elif event.keycode == KEY_TAB:
		select_vehicle((active_index + 1) % vehicles.size())
	elif event.keycode == KEY_R:
		active.reset_at(spawn)
	elif event.keycode == KEY_N:
		night = not night
		sun.light_energy = 0.12 if night else 1.0
		environment.ambient_light_energy = 0.25 if night else 0.65
		environment.background_color = Color("202b34") if night else Color("91a08b")
	elif event.keycode == KEY_P:
		overview = not overview
	elif event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/world/test_scene.tscn")

func capture_review() -> void:
	for frame in 15:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/street_mobility")
	get_viewport().get_texture().get_image().save_png("res://output/street_mobility/godot_day.png")
