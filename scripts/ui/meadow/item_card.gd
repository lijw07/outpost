@tool
extends Button

signal item_requested(id: StringName)

const UI = preload("res://scripts/ui/meadow/ui.gd")
const ItemData = preload("res://scripts/ui/meadow/item_data.gd")
@export var item: ItemData:
	set(value):
		if item != null and item.changed.is_connected(_on_item_changed): item.changed.disconnect(_on_item_changed)
		item = value
		if item != null: item.changed.connect(_on_item_changed)
		if is_node_ready(): _refresh()
@export var compact := false:
	set(value):
		if compact == value: return
		compact = value
		if is_node_ready(): _refresh()
var balance := 2147483647

func _ready() -> void:
	theme_type_variation = &"ItemCard"
	toggle_mode = true
	pressed.connect(func():
		if item != null:
			set_pressed_no_signal(true)
			item_requested.emit(item.id))
	_refresh()

func set_state(coins: int, selected_id: StringName) -> void:
	balance = coins
	if item == null: return
	disabled = coins < item.price
	set_pressed_no_signal(item.id == selected_id)
	tooltip_text = "%s\n%s · %d × %d tiles" % [item.title, item.price_text(), item.footprint.x, item.footprint.y]
	if not item.description.is_empty(): tooltip_text += "\n" + item.description
	if disabled: tooltip_text += "\nNeed %d more coins" % (item.price - coins)
	modulate = Color(1, 1, 1, .58) if disabled else Color.WHITE

func _refresh() -> void:
	for child in get_children(): child.free()
	if item == null: return
	custom_minimum_size = Vector2(154, 74 if compact else 132)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	var content := BoxContainer.new()
	content.vertical = not compact
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	content.add_child(UI.icon(item.icon, 42 if compact else 50))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(copy)
	var title := UI.label(item.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var price := UI.label(item.price_text(), &"Caption")
	price.horizontal_alignment = title.horizontal_alignment
	copy.add_child(price)
	UI.ignore_children(self)
	set_state(balance, item.id if button_pressed else &"")

func _on_item_changed() -> void:
	if is_node_ready(): _refresh()
