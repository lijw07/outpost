extends Control

signal back_requested

const KEY_BIND_ROW := preload("res://scenes/ui/components/key_bind_row.tscn")
const WINDOW_MODE_LABELS: Array[String] = ["WINDOWED", "BORDERLESS FULLSCREEN", "FULLSCREEN"]
const CONFIRM_SECONDS := 10

@onready var _window_mode_option: Control = %WindowModeOption
@onready var _resolution_option: Control = %ResolutionOption
@onready var _vsync_check: CheckBox = %VsyncCheck
@onready var _bind_list: GridContainer = %BindList
@onready var _footer_hint: Label = %FooterHint
@onready var _confirm: Control = %DisplayConfirm
@onready var _countdown_label: Label = %Countdown
@onready var _countdown_timer: Timer = %CountdownTimer
@onready var _volume_sliders: Dictionary = {"Master": %MasterSlider, "Music": %MusicSlider, "SFX": %SfxSlider}
@onready var _volume_values: Dictionary = {"Master": %MasterValue, "Music": %MusicValue, "SFX": %SfxValue}
@onready var _tabs: Array[Button] = [%DisplayTab, %AudioTab, %ControlsTab]
@onready var _sections: Array[Control] = [%DisplaySection, %AudioSection, %ControlsSection]

var _section := 0
var _seconds_left := 0
var _pending_action := ""
var _pending_event: InputEvent

func _ready() -> void:
	for label: String in WINDOW_MODE_LABELS:
		_window_mode_option.add_item(label)
	for preset: Vector2i in Settings.resolutions:
		_resolution_option.add_item(Settings.resolution_label(preset))
	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_vsync_check.toggled.connect(Settings.set_vsync)
	%ReduceMotionCheck.toggled.connect(Settings.set_reduce_motion)
	for bus_name: String in _volume_sliders:
		_volume_sliders[bus_name].value_changed.connect(_on_volume_changed.bind(bus_name))
	for index in _tabs.size():
		_tabs[index].pressed.connect(_show_section.bind(index))
	%ResetAllButton.pressed.connect(_reset_section)
	%BackButton.pressed.connect(request_back)
	%KeepButton.pressed.connect(_keep_display)
	%RevertButton.pressed.connect(_revert_display)
	_confirm.cancelled.connect(_revert_display)
	%ConflictConfirm.cancelled.connect(_cancel_conflict)
	%SwapButton.pressed.connect(_resolve_conflict.bind(true))
	%ReplaceButton.pressed.connect(_resolve_conflict.bind(false))
	%CancelBindingButton.pressed.connect(_cancel_conflict)
	_countdown_timer.timeout.connect(_on_countdown_tick)
	Settings.settings_applied.connect(_refresh)
	Settings.display_preview_started.connect(_start_countdown)
	visibility_changed.connect(_on_visibility_changed)
	for action: String in Settings.REMAPPABLE_ACTIONS:
		var row := KEY_BIND_ROW.instantiate()
		row.setup(action, Settings.REMAPPABLE_ACTIONS[action])
		row.listening_changed.connect(_on_listening_changed)
		row.binding_requested.connect(_on_binding_requested)
		_bind_list.add_child(row)
	_refresh()
	%ChainRig.adopt(%Content)
	_show_section(0)

func focus_first() -> void:
	_tabs[_section].grab_focus()

func _show_section(index: int) -> void:
	_cancel_listening()
	_window_mode_option.close()
	_resolution_option.close()
	_section = index
	for i in _sections.size():
		_sections[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)
	%Scroll.scroll_vertical = 0
	%ResetAllButton.text = "RESET " + ["DISPLAY", "AUDIO", "CONTROLS"][index]
	_footer_hint.text = "CHANGES SAVE AUTOMATICALLY"

func _on_listening_changed(active: bool) -> void:
	_footer_hint.text = "PRESS ESC TO CANCEL" if active else "CHANGES SAVE AUTOMATICALLY"

func _cancel_listening() -> bool:
	var listening := false
	for row in _bind_list.get_children():
		listening = listening or row._listening
		row.cancel_listening()
	return listening

func _refresh() -> void:
	_window_mode_option.selected = int(Settings.window_mode)
	_resolution_option.selected = Settings.get_resolution_index()
	_vsync_check.set_pressed_no_signal(Settings.vsync_enabled)
	%ReduceMotionCheck.set_pressed_no_signal(Settings.reduce_motion)
	for bus_name: String in _volume_sliders:
		var slider: HSlider = _volume_sliders[bus_name]
		slider.set_value_no_signal(Settings.get_bus_volume(bus_name) * 100.0)
		_volume_values[bus_name].text = "%d%%" % roundi(slider.value)
	for row in _bind_list.get_children():
		row.refresh()

func _on_window_mode_selected(index: int) -> void:
	Settings.preview_display(index, Settings.resolution)

func _on_resolution_selected(index: int) -> void:
	Settings.preview_display(int(Settings.window_mode), Settings.resolutions[index])

func _start_countdown() -> void:
	if not is_visible_in_tree():
		return
	_seconds_left = CONFIRM_SECONDS
	_countdown_label.text = "REVERTING IN %d" % _seconds_left
	_confirm.show()
	_countdown_timer.start()

func _on_countdown_tick() -> void:
	_seconds_left -= 1
	_countdown_label.text = "REVERTING IN %d" % _seconds_left
	if _seconds_left <= 0:
		_revert_display()

func _keep_display() -> void:
	_countdown_timer.stop()
	_confirm.hide()
	Settings.confirm_display()

func _revert_display() -> void:
	_countdown_timer.stop()
	_confirm.hide()
	Settings.revert_display()

func _on_volume_changed(value: float, bus_name: String) -> void:
	Settings.set_bus_volume(bus_name, value / 100.0)
	_volume_values[bus_name].text = "%d%%" % roundi(value)

func _reset_section() -> void:
	match _section:
		0: Settings.reset_display()
		1: Settings.reset_audio()
		2: Settings.reset_bindings()

func _on_binding_requested(action: String, event: InputEvent) -> void:
	var conflict: String = Settings.binding_conflict(action, event)
	if conflict.is_empty():
		Settings.set_binding(action, event)
		return
	_pending_action = action
	_pending_event = event.duplicate()
	%ConflictQuestion.text = "%s IS USED BY %s" % [Settings.event_display_name(event), Settings.REMAPPABLE_ACTIONS[conflict]]
	%ConflictDetails.text = "SWAP WITH %s, OR REPLACE AND UNBIND %s." % [Settings.REMAPPABLE_ACTIONS[action], Settings.REMAPPABLE_ACTIONS[conflict]]
	%ConflictConfirm.show()

func _resolve_conflict(swap: bool) -> void:
	if _pending_event != null:
		Settings.set_binding(_pending_action, _pending_event, swap)
	_cancel_conflict()

func _cancel_conflict() -> void:
	%ConflictConfirm.hide()
	_pending_action = ""
	_pending_event = null

func request_back() -> void:
	if _confirm.visible:
		_revert_display()
	elif %ConflictConfirm.visible:
		_cancel_conflict()
	elif not _cancel_listening():
		back_requested.emit()

func _on_visibility_changed() -> void:
	if not is_node_ready() or is_visible_in_tree():
		return
	_cancel_listening()
	_cancel_conflict()
	if _confirm.visible:
		_revert_display()
