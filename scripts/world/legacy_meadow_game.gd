extends Node2D

const MAP_SIZE := Vector2(4096, 2560)
@onready var _camera: Camera2D = $Camera2D

@onready var _marker: Node2D = $MeadowDressing/WalkMarker
@onready var _dust: Node2D = $MeadowDressing/Footsteps
var _last_step := Vector2(1984,1454)
var collected := {"flowers":0,"mushrooms":0,"wood":0}
var _pick_target: Node2D
const PICK_RADIUS := 76.0

@onready var _mode_label: Label = %ModeLabel

func _ready() -> void:
	var menu_button: Button = %MenuButton
	menu_button.pressed.connect(_pause_game)
	Settings.settings_applied.connect(_refresh_hud)
	_refresh_hud()
	for plant in get_tree().get_nodes_in_group("meadow_pickables"):
		if is_ancestor_of(plant): plant.harvested.connect(_on_harvested)
	for tree in get_tree().get_nodes_in_group("meadow_trees"):
		if is_ancestor_of(tree): tree.wood_collected.connect(func(amount: int) -> void: _on_harvested("wood",amount))
	if "--terrain-capture" in OS.get_cmdline_user_args():
		_capture_terrain()

func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_marker.position = (_marker.position + direction * 240.0 * delta).clamp(Vector2(32,32), MAP_SIZE-Vector2(32,32))
	_camera.position = _marker.position - Vector2(0,110)
	if _marker.position.distance_to(_last_step) >= 24.0:
		var ground: TileMapLayer = $MeadowTerrain/Ground
		var paths: TileMapLayer = $MeadowTerrain/Paths
		var cell := ground.local_to_map(_marker.position)
		var data := ground.get_cell_tile_data(cell)
		if paths.get_cell_source_id(cell) != -1 or (data != null and data.terrain == 1):
			_dust.step_at(_marker.global_position)
		_last_step = _marker.position
	_update_pick_target()
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
	if event.is_action_pressed("interact") and not event.is_echo():
		_update_pick_target()
		var found_wood := 0
		for tree in get_tree().get_nodes_in_group("meadow_trees"):
			if is_ancestor_of(tree): found_wood += tree.collect_wood(_marker.global_position)
		if found_wood == 0 and _pick_target != null: _pick_target.harvest()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("attack") and not event.is_echo():
		if _try_chop(get_global_mouse_position()):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := get_global_mouse_position()
		for plant: AnimatedSprite2D in get_tree().get_nodes_in_group("meadow_plants"):
			if is_ancestor_of(plant) and Rect2(plant.offset, plant.sprite_frames.get_frame_texture(plant.animation,plant.frame).get_size()).has_point(plant.to_local(at)):
				plant.brush_from(at)
				break
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause_game()

func _pause_game() -> void:
	%PauseMenu.open()

func _refresh_hud() -> void:
	%WorldHeading.text = GameSession.world_name if not GameSession.world_name.is_empty() else "THE MEADOW"
	_mode_label.text = "MEADOW PLAYGROUND" + ("  /  " + GameSession.character_name if not GameSession.character_name.is_empty() else "")
	var movement: Array[String] = []
	for action: String in ["move_up", "move_left", "move_down", "move_right"]:
		movement.append(Settings.event_display_name(Settings.get_binding(action)))
	%MovementHint.text = "%s: WALK    CLICK: BRUSH / CHOP NEARBY TREE    %s: PAUSE" % [" / ".join(movement), Settings.event_display_name(Settings.get_binding("pause"))]

func _update_pick_target() -> void:
	_pick_target = null
	var nearest := PICK_RADIUS
	for plant: Node2D in get_tree().get_nodes_in_group("meadow_pickables"):
		if not is_ancestor_of(plant) or plant.picked: continue
		var distance := _marker.global_position.distance_to(plant.global_position)
		if distance < nearest:
			nearest = distance
			_pick_target = plant
	var action := "%s: PICK FLOWERS, MUSHROOMS OR SETTLED WOOD" % Settings.event_display_name(Settings.get_binding("interact"))
	for tree in get_tree().get_nodes_in_group("meadow_trees"):
		if is_ancestor_of(tree) and tree.state == "standing" and _marker.global_position.distance_to(tree.global_position) < 100.0:
			action = "CLICK TREE: CHOP (%d HITS LEFT)" % tree.remaining_hits
			break
	if _pick_target != null:
		action = "%s: PICK %s" % [Settings.event_display_name(Settings.get_binding("interact")),_pick_target.pickup_kind.to_upper()]
	%HarvestHint.text = "FLOWERS: %d / MUSHROOMS: %d / WOOD: %d\n%s" % [collected["flowers"],collected["mushrooms"],collected["wood"],action]

func _on_harvested(kind: String, amount: int) -> void:
	collected[kind] = int(collected.get(kind,0))+amount
	_update_pick_target()

func _try_chop(at: Vector2) -> bool:
	for tree in get_tree().get_nodes_in_group("meadow_trees"):
		if not is_ancestor_of(tree) or tree.state != "standing": continue
		if _marker.global_position.distance_to(tree.global_position) > 100.0: continue
		var bounds := Rect2(tree.standing.offset,tree.standing.texture.get_size())
		if bounds.grow(12).has_point(tree.to_local(at)):
			return tree.hit(_marker.global_position)
	return false
