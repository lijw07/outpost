extends Control

const FADE_SECONDS := 0.9
const MUSIC_VOLUME_DB := -8.0
@onready var _title_panel: Control = $Screens/TitlePanel
@onready var _mode_select_panel: Control = $Screens/ModeSelectPanel
@onready var _settings_panel: Control = $Screens/SettingsPanel
@onready var _extras_panel: Control = $Screens/ExtrasPanel
@onready var _save_select_panel: Control = $Screens/SaveSelectPanel
@onready var _lobby_panel: Control = $Screens/LobbyPanel
@onready var _world_select_panel: Control = $Screens/WorldSelectPanel
@onready var _music: AudioStreamPlayer = $MenuMusic

var _history: Array[Control] = []
var _current: Control
var _busy := false
var _choosing_lobby_world := false
var _music_fade: Tween

func _ready() -> void:
	UiFocus.navigation_started.connect(_focus_current)
	_music.stream.loop = true
	_music.play()
	_fade_music(MUSIC_VOLUME_DB, 2.0)
	_title_panel.continue_requested.connect(_continue_game)
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
	_lobby_panel.map_change_requested.connect(_choose_lobby_world)
	_world_select_panel.world_chosen.connect(_on_world_chosen)
	_world_select_panel.back_requested.connect(_go_back)
	for panel: Control in [_title_panel, _mode_select_panel, _settings_panel, _extras_panel, _save_select_panel, _lobby_panel, _world_select_panel]:
		panel.hide()
	_current = _title_panel
	_title_panel.show()

func _input(event: InputEvent) -> void:
	UiFocus.observe(event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _history.is_empty():
		get_viewport().set_input_as_handled()
		UiAudio.play_back()
		if _current.has_method("request_back"):
			_current.request_back()
		else:
			_go_back()

func _focus_current() -> void:
	if not _busy and _current != null and get_viewport().gui_get_focus_owner() == null:
		_current.call("focus_first")

func _show_panel(panel: Control) -> void:
	if _busy or panel == _current:
		return
	_history.push_back(_current)
	await _swap_to(panel)

func _go_back() -> void:
	if _busy or _history.is_empty():
		return
	if _current == _lobby_panel:
		NetSession.leave()
	if _current == _world_select_panel:
		_choosing_lobby_world = false
	await _swap_to(_history.pop_back())

func _swap_to(panel: Control) -> void:
	_busy = true
	for dropdown in get_tree().get_nodes_in_group("dropdowns"):
		dropdown.close()
	await _hoist_current()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_current.hide()
	_current = panel
	panel.show()
	if UiFocus.using_keyboard:
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
	NetSession.leave()
	GameSession.is_coop = coop
	GameSession.world_id = ""
	GameSession.world_name = ""
	GameSession.world_seed = 0
	_show_panel(_save_select_panel)

func _on_save_chosen() -> void:
	_show_panel(_lobby_panel if GameSession.is_coop else _world_select_panel)

func _choose_lobby_world() -> void:
	if _busy:
		return
	_choosing_lobby_world = true
	_show_panel(_world_select_panel)

func _continue_game() -> void:
	if not _busy and GameSession.restore_last_session():
		_launch()

func _on_world_chosen() -> void:
	if _choosing_lobby_world:
		_go_back()
		return
	_launch()

func _launch() -> void:
	if _busy:
		return
	_busy = true
	await _hoist_current()
	await _fade_to_black()
	GameSession.start_game()

func _fade_music(target_db: float, seconds: float) -> Tween:
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", target_db, seconds)
	return _music_fade

func _exit_tree() -> void:
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	_music.stop()
	_music.stream = null

func _fade_to_black() -> void:
	var duration := 0.35 if Settings.reduce_motion else FADE_SECONDS
	var tween := _fade_music(-60.0, duration)
	if not Settings.reduce_motion:
		var fade: ColorRect = %Fade
		fade.color = Color(0.0, 0.0, 0.0, 0.0)
		fade.show()
		tween.parallel().tween_property(fade, "color:a", 1.0, duration)
	await tween.finished
	_music.stop()

func _quit() -> void:
	if _busy:
		return
	_busy = true
	var music_fade := _fade_music(-60.0, 0.45)
	await _hoist_current()
	if music_fade.is_running():
		await music_fade.finished
	_music.stop()
	UiAudio.stop_all()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
