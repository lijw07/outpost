extends Control

const FADE_SECONDS := 0.9
const NAVIGATION_ACTIONS: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right",
	"ui_focus_next", "ui_focus_prev"]
const KEYBOARD_CONTROLS: Array[String] = ["LineEdit", "Range", "CheckBox", "CheckButton"]

@onready var _title_panel: Control = $Screens/TitlePanel
@onready var _mode_select_panel: Control = $Screens/ModeSelectPanel
@onready var _settings_panel: Control = $Screens/SettingsPanel
@onready var _extras_panel: Control = $Screens/ExtrasPanel
@onready var _save_select_panel: Control = $Screens/SaveSelectPanel
@onready var _lobby_panel: Control = $Screens/LobbyPanel
@onready var _world_select_panel: Control = $Screens/WorldSelectPanel

var _history: Array[Control] = []
var _current: Control
var _navigating_by_keyboard := false
var _busy := false

func _ready() -> void:
	_title_panel.play_requested.connect(_show_panel.bind(_mode_select_panel))
	_title_panel.settings_requested.connect(_show_panel.bind(_settings_panel))
	_title_panel.extras_requested.connect(_show_panel.bind(_extras_panel))
	_title_panel.quit_requested.connect(_quit)
	_mode_select_panel.mode_selected.connect(_start_game)
	_mode_select_panel.back_requested.connect(_go_back)
	_settings_panel.back_requested.connect(_go_back)
	_extras_panel.back_requested.connect(_go_back)
	_save_select_panel.save_chosen.connect(_on_save_chosen)
	_save_select_panel.back_requested.connect(_go_back)
	_lobby_panel.run_started.connect(_launch)
	_lobby_panel.back_requested.connect(_go_back)
	_lobby_panel.map_change_requested.connect(_show_panel.bind(_world_select_panel))
	_world_select_panel.world_chosen.connect(_on_world_chosen)
	_world_select_panel.back_requested.connect(_go_back)
	for panel: Control in [_title_panel, _mode_select_panel, _settings_panel, _extras_panel, _save_select_panel, _lobby_panel, _world_select_panel]:
		panel.hide()
	_current = _title_panel
	_title_panel.show()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_navigating_by_keyboard = false
		_release_idle_focus()
	elif _is_navigation(event) and not _navigating_by_keyboard:
		_navigating_by_keyboard = true
		_focus_current()

func _is_navigation(event: InputEvent) -> bool:
	for action in NAVIGATION_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _history.is_empty():
		get_viewport().set_input_as_handled()
		UiAudio.play_back()
		_go_back()

func _release_idle_focus() -> void:
	if Input.get_mouse_button_mask() != 0:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or _takes_keys(focused):
		return
	focused.release_focus()

func _takes_keys(control: Control) -> bool:
	for type: String in KEYBOARD_CONTROLS:
		if control.is_class(type):
			return true
	var parent := control.get_parent()
	return parent != null and parent.is_in_group("dropdowns")

func _focus_current() -> void:
	if _current != null and get_viewport().gui_get_focus_owner() == null:
		_current.call("focus_first")

func _show_panel(panel: Control) -> void:
	if _busy or panel == _current:
		return
	_history.push_back(_current)
	await _swap_to(panel)

func _go_back() -> void:
	if _busy or _history.is_empty():
		return
	await _swap_to(_history.pop_back())

func _swap_to(panel: Control) -> void:
	_busy = true
	await _hoist_current()
	_current.hide()
	_current = panel
	panel.show()
	if _navigating_by_keyboard:
		_focus_current()
	_busy = false

func _hoist_current() -> void:
	var rig := _current.get_node_or_null("ChainRig")
	if rig == null:
		return
	rig.hoist()
	await rig.hoisted

func _start_game(coop: bool) -> void:
	if _busy:
		return
	GameSession.is_coop = coop
	_show_panel(_save_select_panel)

func _on_save_chosen() -> void:
	_show_panel(_world_select_panel)

func _on_world_chosen() -> void:
	if GameSession.is_coop:
		_show_panel(_lobby_panel)
		return
	_launch()

func _launch() -> void:
	if _busy:
		return
	_busy = true
	await _hoist_current()
	await _fade_to_black()
	GameSession.start_game()

func _fade_to_black() -> void:
	var fade: ColorRect = %Fade
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.show()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_SECONDS)
	await tween.finished

func _quit() -> void:
	if _busy:
		return
	_busy = true
	await _hoist_current()
	get_tree().quit()
