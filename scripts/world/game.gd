extends Node2D

const Simulation := preload("res://scripts/ui/menu_demo_world.gd")
const PixelWorld := preload("res://scripts/pixel_world/world.gd")
var simulation: Node2D
var renderer: Node3D
var world_view: SubViewport
var display: TextureRect
var collected := {"flowers":0,"mushrooms":0,"wood":0}

func _ready() -> void:
	world_view = SubViewport.new()
	world_view.size = Vector2i(480,270)
	world_view.own_world_3d = true
	world_view.gui_disable_input = true
	world_view.audio_listener_enable_2d = true
	add_child(world_view)
	simulation = Simulation.new()
	world_view.add_child(simulation)
	simulation.visible = false
	renderer = PixelWorld.new()
	renderer.simulation = simulation
	renderer.interactive = true
	world_view.add_child(renderer)
	renderer.player.position = PixelWorld.point(Vector2(1250,600))
	var survivor := SaveManager.read_save(GameSession.save_id)
	renderer.player.set_appearance(survivor.get("appearance",{}),survivor.get("equipment",{}))
	renderer.camera.size = 16.875
	renderer.collected.connect(_on_harvested)
	var listener := AudioListener2D.new()
	renderer.player_actor.add_child(listener)
	listener.make_current()
	display = TextureRect.new()
	display.texture = world_view.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	get_viewport().size_changed.connect(_resize)
	_resize()
	%MenuButton.pressed.connect(_pause_game)
	Settings.settings_applied.connect(_refresh_hud)
	_refresh_hud()
	_refresh_harvest_hint()

func _resize() -> void:
	display.size = get_viewport_rect().size
	world_view.size = Vector2i(roundi(270*display.size.x/maxf(display.size.y,1)),270)

func _physics_process(delta: float) -> void:
	simulation.advance(delta)
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	var cursor: Vector2 = renderer.cursor_world(get_viewport().get_mouse_position()/display.size*Vector2(world_view.size))
	renderer.move_player(direction,delta,cursor)
	renderer.sync(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_pause_game()
	elif event.is_action_pressed("interact") and not event.is_echo():
		renderer.interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack") and not event.is_echo():
		renderer.interact(true)
		get_viewport().set_input_as_handled()

func _pause_game() -> void:
	%PauseMenu.open()

func _refresh_hud() -> void:
	%WorldHeading.text = GameSession.world_name if not GameSession.world_name.is_empty() else "THE OUTPOST"
	%ModeLabel.text = "OUTPOST" + ("  /  " + GameSession.character_name if not GameSession.character_name.is_empty() else "")
	var movement: Array[String] = []
	for action: String in ["move_up","move_left","move_down","move_right"]:
		movement.append(Settings.event_display_name(Settings.get_binding(action)))
	%MovementHint.text = "%s: WALK    %s: MELEE / CHOP    %s: PAUSE" % [" / ".join(movement),Settings.event_display_name(Settings.get_binding("attack")),Settings.event_display_name(Settings.get_binding("pause"))]
	_refresh_harvest_hint()

func _refresh_harvest_hint() -> void:
	%HarvestHint.text = "FLOWERS: %d / MUSHROOMS: %d / WOOD: %d\n%s: PICK NEARBY PLANTS OR SETTLED WOOD" % [collected.flowers,collected.mushrooms,collected.wood,Settings.event_display_name(Settings.get_binding("interact"))]

func _on_harvested(kind: String, amount: int) -> void:
	collected[kind] = int(collected.get(kind,0))+amount
	_refresh_harvest_hint()
