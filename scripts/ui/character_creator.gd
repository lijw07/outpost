extends Control
const Appearance := preload("res://scripts/characters/appearance.gd")
const Preview := preload("res://scripts/characters/preview.gd")
signal created(save: Dictionary)
signal cancelled
var profile := Appearance.defaults()
var name_field: LineEdit
var preview: Control
var create_button: Button
var status: Label
var _groups: Array[Control] = []
var _tabs: Array[Button] = []
var _values: Dictionary = {}
var _swatches: Dictionary = {}
var _direction: Label

func _ready() -> void:
	theme = load("res://assets/ui/outpost_theme.tres")
	var rig: Control = %ChainRig
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",20)
	rig.adopt(content)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",40)
	content.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 350
	left.add_theme_constant_override("separation",12)
	columns.add_child(left)
	left.add_child(_label("YOUR SURVIVOR",26,true))
	preview = Preview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview)
	_direction = _label("FRONT",24,true)
	left.add_child(_direction)
	var turns := HBoxContainer.new()
	turns.add_theme_constant_override("separation",12)
	left.add_child(turns)
	turns.add_child(_button("LEFT",func() -> void: _turn(-1)))
	turns.add_child(_button("RIGHT",func() -> void: _turn(1)))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",14)
	columns.add_child(right)
	right.add_child(_label("SURVIVOR NAME",24))
	name_field = LineEdit.new()
	name_field.name = "CharacterName"
	name_field.custom_minimum_size.y = 68
	name_field.max_length = SaveManager.MAX_NAME_LENGTH
	name_field.placeholder_text = "ENTER A NAME"
	name_field.text_changed.connect(_name_changed)
	name_field.text_submitted.connect(func(_text: String) -> void: submit())
	right.add_child(name_field)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",14)
	right.add_child(tabs)
	for index in 2:
		var tab := _button(["APPEARANCE","STARTER CLOTHES"][index],_select_tab.bind(index))
		tab.toggle_mode = true
		tabs.add_child(tab)
		_tabs.append(tab)
	var keys := [["sex","skin","hair","hair_color","eye_color"],["top","top_color","pants","pants_color","shoes","shoes_color"]]
	for group in keys:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = 312
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(scroll)
		_groups.append(scroll)
		var options := VBoxContainer.new()
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_theme_constant_override("separation",8)
		scroll.add_child(options)
		for key: String in group:
			options.add_child(_selector(key))
	var note := _label("START WITH EVERYDAY CLOTHES.\nFIND HATS, BAGS, MILITARY GEAR AND ARMOR IN THE WORLD.",22)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	status = _label("",22)
	content.add_child(status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",20)
	content.add_child(footer)
	footer.add_child(_button("CANCEL",func() -> void: cancelled.emit()))
	create_button = _button("CREATE SURVIVOR",submit)
	footer.add_child(create_button)
	_select_tab(0)
	_refresh()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 62
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",24)
	button.pressed.connect(callback)
	return button

func _label(text: String, font_size := 24, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _selector(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	var label := _label(Appearance.LABELS[key],22)
	label.custom_minimum_size.x = 215
	row.add_child(label)
	var previous := _button("PREV",cycle.bind(key,-1))
	previous.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	previous.custom_minimum_size = Vector2(90,44)
	previous.add_theme_font_size_override("font_size",18)
	_compact(previous)
	previous.tooltip_text = "PREVIOUS "+Appearance.LABELS[key]
	row.add_child(previous)
	var value := _button("",cycle.bind(key,1))
	value.custom_minimum_size.y = 44
	value.add_theme_font_size_override("font_size",22)
	_compact(value)
	value.tooltip_text = "NEXT "+Appearance.LABELS[key]
	row.add_child(value)
	_values[key] = value
	var next := _button("NEXT",cycle.bind(key,1))
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.custom_minimum_size = Vector2(90,44)
	next.add_theme_font_size_override("font_size",18)
	_compact(next)
	next.tooltip_text = value.tooltip_text
	row.add_child(next)
	if key.ends_with("color") or key == "skin":
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24,24)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		_swatches[key] = swatch
	return row

func open() -> void:
	profile = Appearance.defaults()
	name_field.text = ""
	preview.facing = 0
	_direction.text = "FRONT"
	status.text = ""
	_select_tab(0)
	_refresh()
	show()
	name_field.grab_focus()

func cycle(key: String, step: int) -> void:
	var choices: Array = Appearance.OPTIONS[key]
	profile[key] = choices[posmod(choices.find(profile[key])+step,choices.size())]
	_refresh()

func _select_tab(index: int) -> void:
	for group in _groups.size():
		_groups[group].visible = group == index
		_tabs[group].set_pressed_no_signal(group == index)

func _turn(step: int) -> void:
	preview.facing = posmod(preview.facing+step,4)
	_direction.text = ["FRONT","RIGHT","BACK","LEFT"][preview.facing]
	preview.queue_redraw()

func _refresh() -> void:
	for key: String in _values:
		_values[key].text = str(profile[key]).replace("_"," ").to_upper()
	for key: String in _swatches:
		_swatches[key].color = Appearance.color(profile[key],key == "skin")
	preview.refresh(profile)
	create_button.disabled = name_field.text.strip_edges().is_empty() or not SaveManager.can_create()

func _name_changed(text: String) -> void:
	var caret := name_field.caret_column
	var clean := SaveManager.sanitize_name(text,false)
	if clean != text:
		name_field.text = clean
		name_field.caret_column = SaveManager.sanitize_name(text.substr(0,caret),false).length()
	_refresh()

func submit() -> void:
	if name_field.text.strip_edges().is_empty():
		status.text = "GIVE YOUR SURVIVOR A NAME."
		return
	var save := SaveManager.create_save(name_field.text,profile)
	if save.is_empty():
		status.text = "COULD NOT CREATE SURVIVOR. CHECK FREE SLOTS AND TRY AGAIN."
		return
	created.emit(save)

func _compact(button: Button) -> void:
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := theme.get_stylebox(state,"Button").duplicate() as StyleBox
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state,style)
