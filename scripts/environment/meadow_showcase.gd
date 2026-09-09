extends Node2D
## All artwork is saved as placed scene nodes; this script only handles viewing and tests.
const BOARD := Vector2(3840,3040)
@onready var camera: Camera2D = $Camera2D
var _dragged := false
var _press := Vector2.ZERO

func _ready() -> void:
	await get_tree().process_frame
	_overview()
	if "--showcase-test" in OS.get_cmdline_user_args(): _verify()
	if "--showcase-capture" in OS.get_cmdline_user_args(): _capture()

func _overview() -> void:
	var view := get_viewport_rect().size-Vector2(60,130)
	camera.zoom = Vector2.ONE*minf(view.x/BOARD.x,view.y/BOARD.y)
	camera.position = BOARD/2.0-Vector2(0,45.0/camera.zoom.x)
	camera.force_update_scroll()

func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	camera.position += direction*800.0*delta/camera.zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE: _overview()
		if event.keycode == KEY_1: camera.zoom = Vector2.ONE*0.5
		if event.keycode == KEY_2: camera.zoom = Vector2.ONE
		if event.keycode == KEY_R: get_tree().reload_current_scene()
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			var factor := 1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2
			camera.zoom = Vector2.ONE*clampf(camera.zoom.x*factor,0.18,2.0)
			camera.force_update_scroll()
			camera.position += before-get_global_mouse_position()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press=event.position
				_dragged=false
			elif not _dragged:
				_test_asset(get_global_mouse_position())
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
		if event.position.distance_to(_press)>4: _dragged=true
		camera.position -= event.relative/camera.zoom.x

func _test_asset(at: Vector2) -> void:
	for art: Node2D in get_tree().get_nodes_in_group("showcase_assets"):
		if not is_ancestor_of(art): continue
		var bounds: Rect2 = art.get_meta("hit_rect")
		if not bounds.has_point(art.to_local(at)): continue
		if art.has_method("hit"):
			if art.state=="felled": art.collect_log()
			else: art.hit()
		elif art.has_method("brush_from"):
			art.brush_from(at)
		return

func _verify() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/meadow/manifest.json"))
	var seen := {}
	for art: Node2D in get_tree().get_nodes_in_group("showcase_assets"):
		if is_ancestor_of(art): seen[art.get_meta("asset_name")]=art
	assert(seen.size()==103)
	for entry: Dictionary in manifest["assets"]: assert(seen.has(entry["name"]))
	var plant: Node2D = seen["grass_dense"]
	_test_asset(plant.to_global(Vector2(0,-12)))
	assert(String(plant.animation).begins_with("brush"))
	await get_tree().create_timer(1.4).timeout
	assert(plant.animation==&"wind")
	var tree: Node2D = seen["birch_standing"]
	for i in range(3): _test_asset(tree.to_global(Vector2(0,-50)))
	await get_tree().create_timer(1.3).timeout
	assert(tree.state=="felled")
	assert(tree.get_node("Stump").visible)
	print("PASS: 103 saved, individually placed assets; plant clicks/recovery and tree clicks/felling.")
	get_tree().quit()

func _capture() -> void:
	await get_tree().create_timer(0.4).timeout
	get_window().content_scale_size=Vector2i(1920,1080)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	await get_tree().process_frame
	_overview()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/meadow/meadow_showcase.png")
	get_tree().quit()
