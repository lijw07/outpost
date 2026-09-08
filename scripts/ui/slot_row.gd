extends RefCounted

const ROW_HEIGHT := 76.0
const DELETE_WIDTH := 112.0
const CLEARANCE := 22.0
const SEPARATION := 16
const COLUMN_GAP := 40

static func build(name_text: String, value_text: String, name_column: float,
		trash_icon: Texture2D, delete_tooltip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	row.add_child(_select(name_text, value_text, name_column))
	row.add_child(_delete(trash_icon, delete_tooltip))
	var clearance := Control.new()
	clearance.custom_minimum_size = Vector2(CLEARANCE, 0.0)
	row.add_child(clearance)
	return row

static func name_column(source: Control, characters: int) -> float:
	var font := source.get_theme_font("font", "Button")
	var font_size := source.get_theme_font_size("font_size", "Button")
	return font.get_string_size("W".repeat(characters),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

static func _select(name_text: String, value_text: String, name_column_width: float) -> Button:
	var select := Button.new()
	select.name = "Select"
	select.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.clip_contents = true
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	columns.add_child(_column("Name", name_text, HORIZONTAL_ALIGNMENT_LEFT, name_column_width))
	columns.add_child(_column("Value", value_text, HORIZONTAL_ALIGNMENT_RIGHT, 0.0))
	select.add_child(columns)
	select.mouse_entered.connect(_tint.bind(select, true))
	select.mouse_exited.connect(_tint.bind(select, false))
	select.focus_entered.connect(_tint.bind(select, true))
	select.focus_exited.connect(_tint.bind(select, false))
	return select

static func _column(node_name: String, text: String, alignment: HorizontalAlignment,
		width: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if width > 0.0:
		label.custom_minimum_size.x = width
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func _delete(icon: Texture2D, tooltip: String) -> Button:
	var remove := Button.new()
	remove.name = "Delete"
	remove.custom_minimum_size = Vector2(DELETE_WIDTH, ROW_HEIGHT)
	remove.icon = icon
	remove.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remove.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	remove.tooltip_text = tooltip
	return remove

static func _tint(select: Button, active: bool) -> void:
	var key := "font_hover_color" if active else "font_color"
	var color: Color = select.get_theme_color(key, "Button")
	for node in select.find_children("*", "Label", true, false):
		(node as Label).add_theme_color_override("font_color", color)
