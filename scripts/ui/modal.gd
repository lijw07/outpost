extends Control

signal cancelled

@export var initial_focus: NodePath
var _previous_focus: Control
var _keyboard_navigation := false

func _ready() -> void:
	add_to_group("modal_dialogs")
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().gui_focus_changed.connect(_guard_focus)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_previous_focus = get_viewport().gui_get_focus_owner()
		_focus_default()
	elif is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus(not _keyboard_navigation)

func _focus_default() -> void:
	var target := get_node_or_null(initial_focus) as Control
	if target != null:
		# Keep the safe default action without making mouse-opened dialogs look hovered.
		target.grab_focus(not _keyboard_navigation)

func _guard_focus(control: Control) -> void:
	if is_visible_in_tree() and (control == null or not is_ancestor_of(control)):
		_focus_default.call_deferred()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_keyboard_navigation = false
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction:
		_keyboard_navigation = true
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
		return
	var step := 0
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		step = 1
	elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		step = -1
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var buttons: Array[Control] = []
	for node in find_children("*", "BaseButton", true, false):
		if node.is_visible_in_tree() and not node.disabled:
			buttons.append(node)
	if not buttons.is_empty():
		var index := buttons.find(get_viewport().gui_get_focus_owner())
		buttons[posmod(index + step, buttons.size())].grab_focus()
