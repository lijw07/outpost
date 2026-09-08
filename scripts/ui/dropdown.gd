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
var _opens_down := true

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
	set_process(false)
	custom_minimum_size.y = row_height

func _reparent_list() -> void:
	var host := _overlay()
	if host == null or _list.get_parent() == host:
		return
	_list.get_parent().remove_child(_list)
	host.add_child(_list)

func _overlay() -> Control:
	var plate := _ancestor_in_group("ui_plate")
	if plate == null:
		return null
	for sibling in plate.get_parent().get_children():
		var control := sibling as Control
		if control != null and control.is_in_group("ui_overlay"):
			return control
	return null

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
	row.clip_text = true
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
	if not _list.visible:
		return
	_list.hide()
	set_process(false)

func _process(_delta: float) -> void:
	if _toggle_hidden_by_scroll():
		close()
		return
	_place_list()

func _toggle_hidden_by_scroll() -> bool:
	var scroll := _ancestor_scroll()
	if scroll == null:
		return false
	return not scroll.get_global_rect().has_point(get_global_rect().get_center())

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
	_reparent_list()
	_size_list()
	_place_list()
	_list.show()
	set_process(true)
	var visible_rows := _scroll.custom_minimum_size.y / row_height
	_scroll.scroll_vertical = int(maxf(0.0, (_selected - visible_rows * 0.5 + 0.5) * row_height))

func _size_list() -> void:
	var box := _list.get_theme_stylebox("panel")
	var chrome := box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
	var bounds := _bounds()
	var top := global_position.y
	var room_below := bounds.end.y - (top + size.y) - EDGE_MARGIN
	var room_above := top - bounds.position.y - EDGE_MARGIN
	_opens_down = room_below >= room_above
	var room: float = (room_below if _opens_down else room_above) + SEAM_OVERLAP
	var fits := floori((room - chrome) / row_height)
	var rows := clampi(mini(_labels.size(), MAX_ROWS), 1, maxi(fits, 1))
	_scroll.custom_minimum_size.y = rows * row_height
	_list.size = Vector2(size.x, rows * row_height + chrome)

func _place_list() -> void:
	var anchor := _anchor_transform()
	var offset := Vector2(0.0,
		size.y - SEAM_OVERLAP if _opens_down else SEAM_OVERLAP - _list.size.y)
	_list.rotation = anchor.get_rotation()
	_list.position = anchor * offset

func _anchor_transform() -> Transform2D:
	var host := _list.get_parent() as Control
	if host == null or host == self:
		return Transform2D.IDENTITY
	return host.get_global_transform().affine_inverse() * get_global_transform()

func _bounds() -> Rect2:
	var plate := _ancestor_in_group("ui_plate")
	var limit := plate.get_global_rect() if plate != null else get_viewport_rect()
	var scroll := _ancestor_scroll()
	return limit.intersection(scroll.get_global_rect()) if scroll != null else limit

func _ancestor_scroll() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		var scroll := node as ScrollContainer
		if scroll != null:
			return scroll
		node = node.get_parent()
	return null

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
	if _inside_list(click.global_position) or _toggle.get_global_rect().has_point(click.global_position):
		return
	get_viewport().set_input_as_handled()
	close()

func _inside_list(point: Vector2) -> bool:
	var local: Vector2 = _list.get_global_transform().affine_inverse() * point
	return Rect2(Vector2.ZERO, _list.size).has_point(local)
