extends Control

signal item_selected(index: int)

const MAX_ROWS := 12
const SEAM_OVERLAP := 14.0
const EDGE_MARGIN := 18.0

@export var row_height := 64.0

@onready var _toggle: Button = %Toggle
@onready var _list: PanelContainer = %List
@onready var _scroll: ScrollContainer = %Scroll
@onready var _rows: VBoxContainer = %Rows

var _labels: PackedStringArray = PackedStringArray()
var _selected := -1

var selected: int:
	get:
		return _selected
	set(value):
		_selected = clampi(value, -1, _labels.size() - 1)
		_refresh_toggle()
		_mark_current()

var item_count: int:
	get:
		return _labels.size()

func _ready() -> void:
	_toggle.pressed.connect(_on_toggle_pressed)
	_list.hide()
	custom_minimum_size.y = row_height
	_reparent_list.call_deferred()

func _reparent_list() -> void:
	var host := _overlay()
	if host == null or _list.get_parent() == host:
		return
	_list.get_parent().remove_child(_list)
	host.add_child(_list)

func _overlay() -> Control:
	return _ancestor_in_group("ui_overlay")

func _ancestor_in_group(group: StringName) -> Control:
	var node: Node = get_parent()
	while node != null:
		var control := node as Control
		if control != null and control.is_in_group(group):
			return control
		node = node.get_parent()
	return null

func clear() -> void:
	_labels = PackedStringArray()
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_selected = -1
	_refresh_toggle()

func add_item(text: String) -> void:
	_labels.append(text)
	var row := Button.new()
	row.text = text
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = row_height
	row.theme_type_variation = &"DropdownRow"
	row.focus_mode = Control.FOCUS_NONE
	row.pressed.connect(_on_row_pressed.bind(_labels.size() - 1))
	_rows.add_child(row)
	if _selected < 0:
		selected = 0
	else:
		_mark_current()

func focus_first() -> void:
	_toggle.grab_focus()

func is_open() -> bool:
	return _list.visible

func close() -> void:
	if _list.visible:
		_list.hide()

func _mark_current() -> void:
	var rows := _rows.get_children()
	for index in rows.size():
		var row := rows[index] as Button
		row.theme_type_variation = &"DropdownRowCurrent" if index == _selected else &"DropdownRow"

func _refresh_toggle() -> void:
	_toggle.text = _labels[_selected] if _selected >= 0 and _selected < _labels.size() else ""

func _on_toggle_pressed() -> void:
	if _list.visible:
		close()
		return
	_open()

func _open() -> void:
	for other in get_tree().get_nodes_in_group("dropdowns"):
		if other != self:
			other.close()
	_layout_list()
	_list.show()
	var visible_rows := _scroll.custom_minimum_size.y / row_height
	_scroll.scroll_vertical = int(maxf(0.0, (_selected - visible_rows * 0.5 + 0.5) * row_height))

func _layout_list() -> void:
	var box := _list.get_theme_stylebox("panel")
	var chrome := box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
	var bounds := _bounds()
	var top := global_position.y
	var room_below := bounds.end.y - (top + size.y) - EDGE_MARGIN
	var room_above := top - bounds.position.y - EDGE_MARGIN
	var opens_down := room_below >= room_above
	var room: float = (room_below if opens_down else room_above) + SEAM_OVERLAP
	var fits := floori((room - chrome) / row_height)
	var rows := clampi(mini(_labels.size(), MAX_ROWS), 1, maxi(fits, 1))
	var height := rows * row_height + chrome
	_scroll.custom_minimum_size.y = rows * row_height
	_list.size = Vector2(size.x, height)
	var offset := Vector2(0.0, size.y - SEAM_OVERLAP if opens_down else SEAM_OVERLAP - height)
	_list.position = _anchor_origin() + offset

func _anchor_origin() -> Vector2:
	var host := _list.get_parent() as Control
	if host == null or host == self:
		return Vector2.ZERO
	return (host.get_global_transform().affine_inverse() * get_global_transform()).origin

func _bounds() -> Rect2:
	var plate := _ancestor_in_group("ui_plate")
	return plate.get_global_rect() if plate != null else get_viewport_rect()

func _on_row_pressed(index: int) -> void:
	close()
	if index == _selected:
		return
	selected = index
	item_selected.emit(index)

func _input(event: InputEvent) -> void:
	if not _list.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var local: Vector2 = _list.get_global_transform().affine_inverse() * click.global_position
	if Rect2(Vector2.ZERO, _list.size).has_point(local):
		return
	if _toggle.get_global_rect().has_point(click.global_position):
		return
	get_viewport().set_input_as_handled()
	close()
