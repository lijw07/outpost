extends Control

@onready var world: Node3D = $PixelView/SubViewport/World
@onready var player: CharacterBody3D = $PixelView/SubViewport/World/Player
@onready var camera: Camera3D = $PixelView/SubViewport/Camera3D
@onready var sprite: Sprite3D = $PixelView/SubViewport/World/Player/Sprite3D
@onready var wireframes: Node3D = $PixelView/SubViewport/CollisionOverlay
var orbit := 0.0
var overlay_built := false
var door_open := false
var camera_target := Vector3.ZERO
var previous_player_position := Vector3.ZERO
var current_player_position := Vector3.ZERO
var previous_scale_mode := Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
var previous_scale_factor := 1.0
var destinations := [Vector3(1, 0.72, -9), Vector3(45, 0.72, -5), Vector3(45, 0.72, 79), Vector3(45, 0.72, 187)]

func _ready() -> void:
	previous_scale_mode = get_window().content_scale_mode
	previous_scale_factor = get_window().content_scale_factor
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_factor = 1.0
	get_window().size_changed.connect(_resize_pixel_view)
	Settings.settings_applied.connect(_apply_display_mode)
	destinations.clear()
	var picker: OptionButton = $Controls/VBoxContainer/SectionPicker
	for marker in world.get_node("Sections").get_children():
		destinations.append(marker.position)
	picker.item_selected.connect(_teleport)
	var drive_button := Button.new()
	drive_button.text = "Vehicle driving test"
	drive_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/world/street_mobility_test.tscn"))
	$Controls/VBoxContainer.add_child(drive_button)
	resized.connect(_resize_pixel_view)
	_resize_pixel_view()
	camera_target = player.position
	previous_player_position = player.position
	current_player_position = player.position
	_update_camera()
	if "--city-capture" in OS.get_cmdline_user_args():
		_capture_review()

func _physics_process(delta: float) -> void:
	previous_player_position = current_player_position
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := camera.global_basis.x
	var forward := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	var direction := (right * movement.x + forward * movement.y).normalized()
	player.velocity.x = direction.x * (6.0 if Input.is_action_pressed("sprint") else 3.0)
	player.velocity.z = direction.z * (6.0 if Input.is_action_pressed("sprint") else 3.0)
	if not player.is_on_floor():
		player.velocity.y -= 14.0 * delta
	else:
		player.velocity.y = -0.5
	_step_up(Vector3(player.velocity.x, 0, player.velocity.z) * delta)
	player.move_and_slide()
	if player.position.y < -5:
		_teleport(0)
	if movement.length_squared() > 0:
		sprite.frame = (1 if movement.x > 0 else 3) if absf(movement.x) > absf(movement.y) else (0 if movement.y > 0 else 2)
	current_player_position = player.position

func _process(_delta: float) -> void:
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var visual_position := previous_player_position.lerp(current_player_position, fraction)
	camera_target = visual_position
	_update_camera()
	sprite.global_position = _snap_to_pixel_grid(visual_position)

func _apply_display_mode() -> void:
	previous_scale_mode = get_window().content_scale_mode
	previous_scale_factor = get_window().content_scale_factor
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_factor = 1.0
	_resize_pixel_view()

func _exit_tree() -> void:
	var window := get_window()
	if window.size_changed.is_connected(_resize_pixel_view):
		window.size_changed.disconnect(_resize_pixel_view)
	if Settings.settings_applied.is_connected(_apply_display_mode):
		Settings.settings_applied.disconnect(_apply_display_mode)
	window.content_scale_mode = previous_scale_mode
	window.content_scale_factor = previous_scale_factor

func _resize_pixel_view() -> void:
	if size.y <= 0:
		return
	var physical_size := get_window().size
	var canvas_to_pixels := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var container: SubViewportContainer = $PixelView
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.stretch = false
	$PixelView/SubViewport.size = physical_size
	container.size = physical_size
	var pixels_to_canvas := canvas_to_pixels.affine_inverse()
	container.scale = pixels_to_canvas.get_scale()
	container.position = pixels_to_canvas.origin

func _step_up(motion: Vector3) -> void:
	if not player.is_on_floor() or motion.length_squared() < 0.000001:
		return
	if not player.test_move(player.global_transform, motion):
		return
	var rise := Vector3.UP * 0.2
	if player.test_move(player.global_transform, rise):
		return
	var raised := player.global_transform.translated(rise)
	if player.test_move(raised, motion):
		return
	var landing := KinematicCollision3D.new()
	if player.test_move(raised.translated(motion), Vector3.DOWN * 0.24, landing):
		if landing.get_normal().y > 0.5:
			player.position.y += 0.2

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_teleport(event.keycode - KEY_1)
		elif event.keycode == KEY_C:
			if not overlay_built:
				_build_collision_overlay()
			wireframes.visible = not wireframes.visible
		elif event.keycode == KEY_F:
			var door: Node3D = world.get_node("Assembly/Door")
			if player.position.distance_to(door.position) < 3:
				door_open = not door_open
				door.get_node("Hinge").rotation.y = PI / 2 if door_open else 0.0
				if overlay_built:
					for child in wireframes.get_children():
						child.free()
					_build_collision_overlay()
		elif event.keycode == KEY_Q:
			orbit -= PI / 8
		elif event.keycode == KEY_E:
			orbit += PI / 8
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(8, camera.size - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(55, camera.size + 2)

func _teleport(index: int) -> void:
	if index < 0 or index >= destinations.size():
		return
	$Controls/VBoxContainer/SectionPicker.select(index)
	player.position = destinations[index]
	player.velocity = Vector3.ZERO
	previous_player_position = player.position
	current_player_position = player.position
	camera_target = player.position
	_update_camera()
	sprite.global_position = _snap_to_pixel_grid(player.position)

func _update_camera() -> void:
	var offset := Vector3(0, 18, -18).rotated(Vector3.UP, orbit)
	camera.position = camera_target + offset
	camera.basis = Basis.looking_at(-offset.normalized(), Vector3.UP)
	camera.position = _snap_to_pixel_grid(camera.position)

func _snap_to_pixel_grid(point: Vector3) -> Vector3:
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var pixels := viewport_size.y if camera.keep_aspect == Camera3D.KEEP_HEIGHT else viewport_size.x
	var units_per_pixel := camera.size / maxf(pixels, 1.0)
	var right := camera.basis.x
	var up := camera.basis.y
	var horizontal := point.dot(right)
	var vertical := point.dot(up)
	return point + right * (snappedf(horizontal, units_per_pixel) - horizontal) + up * (snappedf(vertical, units_per_pixel) - vertical)

func _build_collision_overlay() -> void:
	var wire_material := StandardMaterial3D.new()
	wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_material.albedo_color = Color(0.45, 1.0, 0.65)
	wire_material.no_depth_test = true
	for collision in world.find_children("*", "CollisionShape3D", true, false):
		if collision.get_parent().name == "PreviewGround" or not collision.shape is ConcavePolygonShape3D:
			continue
		var faces: PackedVector3Array = collision.shape.get_faces()
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, wire_material)
		for i in range(0, faces.size(), 3):
			for edge in 3:
				mesh.surface_add_vertex(collision.global_transform * faces[i + edge])
				mesh.surface_add_vertex(collision.global_transform * faces[i + (edge + 1) % 3])
		mesh.surface_end()
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		wireframes.add_child(instance)
	overlay_built = true

func _capture_review() -> void:
	set_physics_process(false)
	set_process(false)
	$PixelView.stretch = false
	$PixelView/SubViewport.size = Vector2i(960, 640)
	var target := Vector3(-1, 0.7, -1)
	camera.position = target + Vector3(-10, 19, -20)
	camera.look_at(target)
	camera.size = 20
	for i in 5:
		await RenderingServer.frame_post_draw
	var viewport: SubViewport = $PixelView/SubViewport
	viewport.get_texture().get_image().save_png("res://output/barren_city/03_godot/review/assembly.png")
	_build_collision_overlay()
	wireframes.visible = true
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://output/barren_city/03_godot/review/collision_overlay.png")
	wireframes.visible = false
	var door: Node3D = world.get_node("Assembly/Door")
	door.get_node("Hinge").rotation.y = PI / 2
	camera.position = Vector3(1, 7, -12)
	camera.look_at(Vector3(1, 0.8, -5))
	camera.size = 8
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://output/barren_city/03_godot/review/open_door.png")
	door.get_node("Hinge").rotation.y = 0
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://output/barren_city/03_godot/review/closed_door.png")
	var proof := Node3D.new()
	world.add_child(proof)
	proof.position = Vector3(-25, 0, 0)
	var proof_sofa: Node3D = load("res://assets/models/city/scenes/sofa.tscn").instantiate()
	proof.add_child(proof_sofa)
	var proof_window: Node3D = load("res://assets/models/city/scenes/wall_wood_window.tscn").instantiate()
	proof.add_child(proof_window)
	proof_window.position.z = 6
	for view in [{"name": "trees", "target": Vector3(254, 1, 32), "size": 24.0}, {"name": "terrain", "target": Vector3(254, 0, 0), "size": 24.0}, {"name": "structures", "target": Vector3(260, 0.7, 202), "size": 38.0}, {"name": "characters", "target": Vector3(66, 0.7, 232), "size": 24.0}, {"name": "open_windows", "target": Vector3(-1, 1, 6.125), "size": 9.0}, {"name": "sofa_grounded", "target": Vector3(-3.5, 0.3, 0), "size": 5.0}]:
		var target_point: Vector3 = view.target
		camera.position = target_point + Vector3(-8, 12, -18)
		if view.name == "sofa_grounded":
			target_point = proof.position + Vector3(0, 0.45, 0)
			camera.position = target_point + Vector3(-3, 1.2, -5)
		elif view.name == "open_windows":
			target_point = proof_window.global_position + Vector3(0, 1, 0)
			camera.position = target_point + Vector3(-1, 0.5, -5)
			view.size = 3.5
		camera.look_at(target_point)
		camera.size = view.size
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://output/barren_city/03_godot/review/" + view.name + ".png")
	proof.queue_free()
	_resize_pixel_view()
	set_physics_process(true)
	set_process(true)
	_teleport(0)
	if "--city-capture-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
