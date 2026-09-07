extends HBoxContainer

@onready var _action_label: Label = %ActionLabel
@onready var _bind_button: Button = %BindButton

var _action := ""
var _display_name := ""
var _listening := false

func setup(action: String, display_name: String) -> void:
	_action = action
	_display_name = display_name

func _ready() -> void:
	_bind_button.pressed.connect(_start_listening)
	_action_label.text = _display_name
	set_process_input(false)
	refresh()

func refresh() -> void:
	if _listening:
		return
	_bind_button.text = Settings.event_display_name(Settings.get_binding(_action))

func _input(event: InputEvent) -> void:
	if not _listening:
		return
	if event is InputEventKey and (event as InputEventKey).is_echo():
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return
	if not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	_listening = false
	set_process_input(false)
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		refresh()
		return
	Settings.set_binding(_action, event)
	refresh()

func _start_listening() -> void:
	if _listening:
		return
	_listening = true
	_bind_button.text = "PRESS A KEY"
	set_process_input(true)
