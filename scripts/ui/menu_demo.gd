extends Control
## A live miniature survival world rendered beneath the menu, never the real save.

const PixelWorld := preload("res://scripts/pixel_world/world.gd")
var renderer: Node3D

const World := preload("res://scripts/ui/menu_demo_world.gd")
@export_range(0,2) var variant := 0
@export var location_title := "LAST WATCH"
var elapsed := 0.0
var simulation: Node2D
var viewport: SubViewport
var display: TextureRect
var status: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.disable_3d = false
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.gui_disable_input = true
	viewport.audio_listener_enable_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform = Transform2D().scaled(Vector2(0.5,0.5))
	simulation = World.new()
	simulation.variant = variant
	viewport.add_child(simulation)
	simulation.visible = false
	renderer = PixelWorld.new()
	renderer.simulation = simulation
	viewport.add_child(renderer)
	var listener := AudioListener2D.new()
	listener.position = Vector2(1360,600)
	simulation.add_child(listener)
	listener.make_current()
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status = Label.new()
	status.add_theme_font_override("font",load("res://assets/ui/font/outpost_pixel.ttf"))
	status.add_theme_font_size_override("font_size",24)
	status.add_theme_color_override("font_color",Color(0.88,0.79,0.58))
	status.add_theme_color_override("font_shadow_color",Color(0.04,0.05,0.05))
	status.add_theme_constant_override("shadow_offset_x",2)
	status.add_theme_constant_override("shadow_offset_y",2)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -880
	status.offset_right = -55
	status.offset_top = 48
	_refresh_status()
	Settings.settings_applied.connect(_apply_motion)
	_apply_motion()

func _apply_motion() -> void:
	set_process(not Settings.reduce_motion)
	if simulation != null:
		simulation.audio.set_enabled(not Settings.reduce_motion)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if Settings.reduce_motion else SubViewport.UPDATE_ALWAYS

func _process(delta: float) -> void:
	elapsed += delta
	simulation.advance(delta)
	renderer.sync(delta)
	_refresh_status()

func _refresh_status() -> void:
	status.text = "%s   /   WAVE %02d   /   SUPPLIES %02d" % [location_title,simulation.wave,simulation.supplies]
