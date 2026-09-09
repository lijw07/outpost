extends Node2D

const MAP_SIZE := Vector2(4096, 2560)
@onready var _camera: Camera2D = $Camera2D

@onready var _mode_label: Label = %ModeLabel

func _ready() -> void:
	var menu_button: Button = %MenuButton
	menu_button.pressed.connect(_return_to_menu)
	if GameSession.is_coop:
		_mode_label.text = "CO-OP  UP TO %d PLAYERS" % GameSession.MAX_PLAYERS
	else:
		_mode_label.text = "SINGLE PLAYER" if GameSession.character_name.is_empty() else "SINGLE PLAYER  -  %s" % GameSession.character_name
	if "--terrain-capture" in OS.get_cmdline_user_args():
		_capture_terrain()

func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_camera.position += direction * 500.0 * delta
	var half_view := get_viewport_rect().size / _camera.zoom / 2.0
	for axis in range(2):
		if half_view[axis] * 2.0 >= MAP_SIZE[axis]:
			_camera.position[axis] = MAP_SIZE[axis] / 2.0
		else:
			_camera.position[axis] = clampf(_camera.position[axis], half_view[axis], MAP_SIZE[axis] - half_view[axis])

func _capture_terrain() -> void:
	await get_tree().create_timer(0.4).timeout
	get_window().content_scale_size = Vector2i(1920,1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/meadow/terrain_in_game.png")
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_return_to_menu()

func _return_to_menu() -> void:
	GameSession.return_to_menu()
