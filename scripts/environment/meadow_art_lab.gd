extends Control
## Standalone gallery of every exported meadow asset, with actual animation controllers.
const PACK := "res://assets/environment/meadow/"
var _assets: Array = []
var _cards: Array[Button] = []
var _selected := -1
var _filter := ""
var _category := "all"
var _grid: GridContainer
var _title: Label
var _meta: Label
var _status: Label
var _frame_text: Label
var _frame: HSlider
var _states: OptionButton
var _play: Button
var _preview_panel: PanelContainer
var _viewport: SubViewport
var _stage: Node2D
var _animated: AnimatedSprite2D
var _tree: Node2D
var _dust: Node2D
var _brush_left: Button
var _brush_right: Button
var _hit: Button
var _collect: Button
var _dust_button: Button
var _pan := Vector2.ZERO
var _zoom := 2
var _background := Color("30383a")
var _count: Label
var _preview_box: SubViewportContainer

func _ready() -> void:
	_assets = JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))["assets"]
	_build_ui()
	_build_cards()
	_select(0)
	await get_tree().process_frame
	get_window().content_scale_size = Vector2i(1920,1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if "--meadow-lab-test" in OS.get_cmdline_user_args(): _run_checks()
	if "--meadow-lab-capture" in OS.get_cmdline_user_args(): _capture()

func _label(text: String, font_size := 18) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color("e8e5d6"))
	return result

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("141d1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	margin.add_child(layout)
	layout.add_child(_label("OUTPOST  /  MEADOW ART LAB",28))
	layout.add_child(_label("Choose any asset to inspect it. Test wind, step through frames, brush plants, or chop and reset a tree.",17))
	var main := HSplitContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.split_offset = 730
	layout.add_child(main)
	var gallery := VBoxContainer.new()
	gallery.custom_minimum_size.x = 700
	main.add_child(gallery)
	var search := LineEdit.new()
	search.placeholder_text = "Find an asset..."
	search.custom_minimum_size.y = 42
	search.text_changed.connect(func(value: String) -> void: _filter=value.to_lower(); _filter_cards())
	gallery.add_child(search)
	var categories := OptionButton.new()
	for name in ["All assets","Ground","Transitions","Paths","Grass","Props","Trees","Effects"]: categories.add_item(name)
	categories.item_selected.connect(func(index: int) -> void:
		_category=["all","terrain","transitions","paths","grass","props","trees","effects"][index]
		_filter_cards())
	gallery.add_child(categories)
	_count = _label("")
	gallery.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gallery.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",8)
	_grid.add_theme_constant_override("v_separation",8)
	scroll.add_child(_grid)
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 830
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation",12)
	main.add_child(inspector)
	_title = _label("",26)
	_meta = _label("",16)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(_title)
	inspector.add_child(_meta)
	_preview_panel = PanelContainer.new()
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_background()
	inspector.add_child(_preview_panel)
	_preview_box = SubViewportContainer.new()
	_preview_box.stretch = true
	_preview_box.custom_minimum_size = Vector2(500,460)
	_preview_panel.add_child(_preview_box)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_preview_box.add_child(_viewport)
	_stage = Node2D.new()
	_viewport.add_child(_stage)
	_preview_box.resized.connect(_center_preview)
	_preview_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pan += event.relative
			_center_preview())
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation",10)
	inspector.add_child(options)
	options.add_child(_label("Zoom",16))
	var zoom := OptionButton.new()
	for n in [1,2,3,4]: zoom.add_item("%dx"%n)
	zoom.select(1)
	zoom.item_selected.connect(func(index: int) -> void: _zoom=index+1; _center_preview())
	options.add_child(zoom)
	options.add_child(_label("Background",16))
	var background := OptionButton.new()
	for name in ["Charcoal","Light","Meadow"]: background.add_item(name)
	background.item_selected.connect(func(index: int) -> void:
		_background=[Color("30383a"),Color("b9b9b3"),Color("687d4b")][index]
		_set_background())
	options.add_child(background)
	options.add_child(_button("Reset asset",func() -> void: _select(_selected)))
	var animation_row := HBoxContainer.new()
	animation_row.add_theme_constant_override("separation",10)
	inspector.add_child(animation_row)
	_states = OptionButton.new()
	_states.custom_minimum_size.x = 180
	_states.item_selected.connect(_choose_animation)
	animation_row.add_child(_states)
	_play = _button("Pause",_toggle_play)
	animation_row.add_child(_play)
	animation_row.add_child(_button("Previous frame",func() -> void: _step_frame(-1)))
	animation_row.add_child(_button("Next frame",func() -> void: _step_frame(1)))
	var frame_row := HBoxContainer.new()
	inspector.add_child(frame_row)
	_frame = HSlider.new()
	_frame.min_value = 1
	_frame.step = 1
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.value_changed.connect(func(value: float) -> void:
		if is_instance_valid(_animated):
			_animated.pause()
			_animated.frame = int(value)-1)
	frame_row.add_child(_frame)
	_frame_text = _label("",16)
	_frame_text.custom_minimum_size.x = 180
	frame_row.add_child(_frame_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	inspector.add_child(actions)
	_brush_left = _button("Brush left",func() -> void: _brush(true))
	_brush_right = _button("Brush right",func() -> void: _brush(false))
	_hit = _button("Hit tree",func() -> void: if is_instance_valid(_tree): _tree.hit())
	_collect = _button("Collect log",func() -> void: if is_instance_valid(_tree): _tree.collect_log())
	_dust_button = _button("Dust burst",func() -> void: if is_instance_valid(_dust): _dust.step_at(_dust.global_position))
	for button in [_brush_left,_brush_right,_hit,_collect,_dust_button]: actions.add_child(button)
	_status = _label("",17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 54
	inspector.add_child(_status)

func _build_cards() -> void:
	for i in range(_assets.size()):
		var asset: Dictionary = _assets[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(164,178)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.tooltip_text = asset["name"]+"\n"+asset["path"]
		card.pressed.connect(_select.bind(i))
		_grid.add_child(card)
		_cards.append(card)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left=8; box.offset_top=8; box.offset_right=-8; box.offset_bottom=-8
		card.add_child(box)
		var picture := TextureRect.new()
		picture.texture = load("res://"+asset["path"])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size.y = 118
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)
		var name_label := _label(asset["name"],13)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var dimensions := _label("%d x %d"%[asset["size"][0],asset["size"][1]],12)
		dimensions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(dimensions)
	_filter_cards()

func _filter_cards() -> void:
	var count := 0
	for i in range(_cards.size()):
		var asset: Dictionary = _assets[i]
		_cards[i].visible = (_category=="all" or asset["kind"]==_category) and (_filter.is_empty() or _filter in String(asset["name"]))
		if _cards[i].visible: count+=1
	_count.text = "%d of %d assets"%[count,_assets.size()]

func _select(index: int) -> void:
	_selected = index
	for i in range(_cards.size()): _cards[i].set_pressed_no_signal(i==index)
	_pan = Vector2.ZERO
	_animated = null; _tree = null; _dust = null
	for child in _stage.get_children(): child.free()
	var asset: Dictionary = _assets[index]
	_title.text = String(asset["name"]).replace("_"," ").capitalize()
	_meta.text = "%d x %d px  |  %s\n%s"%[asset["size"][0],asset["size"][1],asset["kind"],asset["path"]]
	var name: String = asset["name"]
	var is_tree: bool = asset["kind"]=="trees" and name.ends_with("_standing")
	var has_animation := FileAccess.file_exists(PACK+"animations/"+name+".tres")
	if is_tree:
		_tree = load("res://scenes/environment/meadow/"+String(asset["tree"])+".tscn").instantiate()
		_stage.add_child(_tree)
		_tree.position.y = float(asset["size"][1])/2.0-10.0
		_animated = _tree.get_node("Pivot/Crown")
	elif has_animation:
		_animated = AnimatedSprite2D.new()
		_animated.sprite_frames = load(PACK+"animations/"+name+".tres")
		if asset.get("reactive",false):
			_animated.set_script(load("res://scripts/environment/meadow_plant.gd"))
		_stage.add_child(_animated)
		_animated.play(&"wind")
	else:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://"+asset["path"])
		_stage.add_child(sprite)
	_states.clear()
	if is_instance_valid(_animated):
		for state in _animated.sprite_frames.get_animation_names():
			_states.add_item(String(state).replace("_"," ").capitalize())
			_states.set_item_metadata(_states.item_count-1,state)
	else: _states.add_item("Static image")
	_states.disabled = not is_instance_valid(_animated)
	_play.disabled = not is_instance_valid(_animated)
	_frame.editable = is_instance_valid(_animated)
	_brush_left.visible = asset.get("reactive",false)
	_brush_right.visible = _brush_left.visible
	_hit.visible = is_tree
	_collect.visible = is_tree
	_dust_button.visible = asset["kind"] in ["terrain","transitions","paths","effects"]
	if _dust_button.visible:
		_dust = Node2D.new()
		_dust.set_script(load("res://scripts/environment/meadow_footsteps.gd"))
		_stage.add_child(_dust)
	_center_preview()
	_process(0.0)

func _center_preview() -> void:
	if not is_instance_valid(_stage): return
	_stage.position = (_preview_box.size/2.0+_pan).floor()
	_stage.scale = Vector2.ONE*_zoom

func _set_background() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _background
	_preview_panel.add_theme_stylebox_override("panel",style)

func _choose_animation(index: int) -> void:
	if is_instance_valid(_animated): _animated.play(_states.get_item_metadata(index))

func _toggle_play() -> void:
	if not is_instance_valid(_animated): return
	if _animated.is_playing(): _animated.pause()
	else: _animated.play()

func _step_frame(delta: int) -> void:
	if not is_instance_valid(_animated): return
	_animated.pause()
	_animated.frame = posmod(_animated.frame+delta,_animated.sprite_frames.get_frame_count(_animated.animation))

func _brush(left: bool) -> void:
	if is_instance_valid(_animated) and _animated.has_method("brush_from"):
		_animated.brush_from(_animated.global_position+Vector2(20 if left else -20,0))

func _process(_delta: float) -> void:
	if not is_instance_valid(_status) or _selected<0: return
	if is_instance_valid(_animated):
		var total := _animated.sprite_frames.get_frame_count(_animated.animation)
		_frame.set_block_signals(true)
		_frame.max_value = total
		_frame.value = _animated.frame+1
		_frame.set_block_signals(false)
		_frame_text.text = "Frame %d / %d"%[_animated.frame+1,total]
		_play.text = "Pause" if _animated.is_playing() else "Play"
		for i in range(_states.item_count):
			if _states.get_item_metadata(i)==_animated.animation: _states.select(i)
	else:
		_frame_text.text = "Static image"
		_frame.set_value_no_signal(1)
	if is_instance_valid(_tree):
		_status.text = "Tree: %s  |  Hits remaining: %d. Reset asset restores the tree."%[_tree.state,_tree.remaining_hits]
		_hit.disabled = _tree.state!="standing"
		_collect.disabled = _tree.state!="felled"
	elif _brush_left.visible:
		_status.text = "Brush tests use the plant's interaction animation, followed by recovery and wind. Pause or drag the frame slider to inspect pixels."
	else:
		_status.text = "Drag the preview to pan. Inspect on different backgrounds at 1x to 4x. Frames are numbered from 1."

func _find_asset(name: String) -> int:
	for i in range(_assets.size()):
		if _assets[i]["name"]==name: return i
	return -1

func _run_checks() -> void:
	assert(_cards.size()==103)
	for i in range(_assets.size()):
		_select(i)
		assert(_stage.get_child_count()>0)
	_select(_find_asset("birch_crown"))
	_animated.pause()
	_animated.frame = 6
	_step_frame(1)
	assert(_animated.frame==7)
	_step_frame(1)
	assert(_animated.frame==0)
	_select(_find_asset("grass_dense"))
	_brush(true)
	assert(_animated.animation==&"brush_left")
	await get_tree().create_timer(1.4).timeout
	assert(_animated.animation==&"wind")
	_select(_find_asset("oak_standing"))
	_tree.hit(3)
	await get_tree().create_timer(1.3).timeout
	assert(_tree.state=="felled")
	assert(_tree.collect_log())
	_select(_selected)
	assert(_tree.state=="standing")
	_select(_find_asset("soil_00"))
	_dust.step_at(_dust.global_position)
	assert(_dust.motes.size()==7)
	_category="trees"
	_filter_cards()
	assert(_cards.filter(func(card: Button) -> bool: return card.visible).size()==28)
	print("PASS: 103 gallery assets load; frame stepping/wrap, brush/recovery, tree hit/fall/collect/reset, dust and filtering.")
	get_tree().quit()

func _capture() -> void:
	_select(_find_asset("birch_crown"))
	_animated.pause()
	_animated.frame = 6
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/meadow/meadow_art_lab.png")
	get_tree().quit()
