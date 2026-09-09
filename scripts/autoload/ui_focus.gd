extends Node
## Keeps keyboard focus available without showing it as a mouse hover.

signal navigation_started

const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev",
]

var using_keyboard := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_sync_focus)

func _input(event: InputEvent) -> void:
	observe(event)

func observe(event: InputEvent) -> void:
	if event is InputEventMouse:
		using_keyboard = false
		_sync_focus(get_viewport().gui_get_focus_owner())
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction:
		using_keyboard = true
		for action in NAVIGATION_ACTIONS:
			if event.is_action_pressed(action):
				var focused := get_viewport().gui_get_focus_owner()
				if focused != null:
					focused.grab_focus()
				navigation_started.emit()
				break

func _sync_focus(control: Control) -> void:
	if not using_keyboard and control is BaseButton and control.has_focus(true):
		control.grab_focus(true)
