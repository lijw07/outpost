extends Node2D
## Standalone art review scene; leaves the game's existing world scene untouched.
const PACK := "res://assets/environment/meadow/"
var _plants: Array[AnimatedSprite2D] = []
var _probe := Node2D.new()
var _dust: Node2D
var _last_step := Vector2.ZERO
var _mouse_mode := false
var _rng := RandomNumberGenerator.new()
var _terrain_bits := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 9041
	var window := get_window()
	window.content_scale_size = Vector2i(1920,1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_factor = 1.0
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))
	var source_ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"tile_sources.json"))
	var tiles: TileSet = load(PACK+"meadow_tileset.tres")
	var land := TileMapLayer.new()
	land.tile_set = tiles
	add_child(land)
	for entry: Dictionary in manifest["assets"]:
		if entry.has("corners") and not _terrain_bits.has(int(entry["corners"])):
			_terrain_bits[int(entry["corners"])]=int(source_ids[entry["name"]])
	for y in range(17):
		for x in range(30):
			var corners := 0
			for i in range(4):
				var p := Vector2(x+(i%2),y+(i/2))
				var center := Vector2(16.0,8.5)
				var d := Vector2((p.x-center.x)/4.5,(p.y-center.y)/3.2)
				if d.length() > 1.0: corners |= 1<<i
			var source_id: int = _terrain_bits[corners]
			if corners == 15:
				source_id = int(source_ids["grass_%02d" % _rng.randi_range(0,3)])
			land.set_cell(Vector2i(x,y),source_id,Vector2i.ZERO)
	var paths := TileMapLayer.new()
	paths.tile_set = tiles
	add_child(paths)
	var cells := {}
	for x in range(0,12): cells[Vector2i(x,11)] = true
	for y in range(8,12): cells[Vector2i(11,y)] = true
	for x in range(11,30): cells[Vector2i(x,8)] = true
	for p: Vector2i in cells:
		var mask := 0
		for i in range(4):
			if cells.has(p+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]): mask |= 1<<i
		paths.set_cell(p,int(source_ids["path_%02d" % mask]),Vector2i.ZERO)
	var props := Node2D.new()
	props.y_sort_enabled = true
	add_child(props)
	var options: Array[Dictionary] = []
	for entry: Dictionary in manifest["assets"]:
		if entry["kind"] in ["grass","props"]:
			options.append(entry)
	for i in range(125):
		var at := Vector2(_rng.randi_range(80,1840),_rng.randi_range(200,1040))
		var tile := Vector2i(at/64.0)
		if cells.has(tile) or Rect2(760,340,520,430).has_point(at): continue
		var entry: Dictionary = options[_rng.randi_range(0,options.size()-1)]
		var prop: Node2D
		if entry.get("reactive",false):
			var plant := AnimatedSprite2D.new()
			plant.sprite_frames = load(PACK+"animations/"+entry["name"]+".tres")
			plant.centered = false
			plant.offset = Vector2(-float(entry["pivot"][0]),-float(entry["pivot"][1]))
			plant.set_script(load("res://scripts/environment/meadow_plant.gd"))
			_plants.append(plant)
			prop = plant
		else:
			var art := Sprite2D.new()
			art.texture = load("res://"+entry["path"])
			art.centered = false
			art.offset = Vector2(-float(entry["pivot"][0]),-float(entry["pivot"][1]))
			prop = art
		prop.position = at
		props.add_child(prop)
	_probe.position = Vector2(920,670)
	_probe.add_to_group("players")
	props.add_child(_probe)
	_dust = Node2D.new()
	_dust.set_script(load("res://scripts/environment/meadow_footsteps.gd"))
	add_child(_dust)
	_last_step = _probe.position
	_add_header()
	if "--meadow-test" in OS.get_cmdline_user_args():
		_run_checks()
	elif "--meadow-capture" in OS.get_cmdline_user_args():
		_capture()

func _add_header() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var band := ColorRect.new()
	band.size = Vector2(1920,116)
	band.color = Color(0.07,0.12,0.095,0.94)
	hud.add_child(band)
	var title := Label.new()
	title.text = "OUTPOST   /   THE MEADOW"
	title.position = Vector2(38,21)
	title.add_theme_font_size_override("font_size",32)
	title.modulate = Color("f2dfae")
	hud.add_child(title)
	var hint := Label.new()
	hint.text = "WASD: walk the marker   ·   Move the mouse: brush plants   ·   R: reset"
	hint.position = Vector2(40,73)
	hint.add_theme_font_size_override("font_size",19)
	hint.modulate = Color("bbcaac")
	hud.add_child(hint)

func _process(delta: float) -> void:
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if direction != Vector2.ZERO:
		_mouse_mode = false
		_probe.position += direction.normalized()*240.0*delta
	elif _mouse_mode:
		_probe.position = get_global_mouse_position()
	_probe.position = _probe.position.clamp(Vector2(12,130),Vector2(1908,1068))
	if _probe.position.distance_to(_last_step)>24.0:
		var pos := _probe.position
		if Rect2(760,350,520,400).has_point(pos) or absf(pos.y-544.0)<32 or absf(pos.y-736)<32:
			_dust.step_at(pos)
		_last_step = pos
	queue_redraw()

func _draw() -> void:
	if is_instance_valid(_probe):
		draw_arc(_probe.position.round(),13,0,TAU,24,Color("f4e7bd"),2.0)
		draw_circle(_probe.position.round(),3,Color("f4e7bd"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_mode = true
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _run_checks() -> void:
	await get_tree().process_frame
	var plant := _plants[0]
	_probe.position = plant.global_position+Vector2(-4,0)
	await get_tree().create_timer(0.08).timeout
	assert(String(plant.animation).begins_with("brush"))
	_probe.position = Vector2(1000,800)
	await get_tree().create_timer(1.3).timeout
	assert(plant.animation == &"wind")
	print("PASS: meadow plant contact and recovery.")
	get_tree().quit()

func _capture() -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/meadow/meadow_scene.png")
	get_tree().quit()
