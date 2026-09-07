extends Control

signal back_requested

const KEY_BIND_ROW := preload("res://scenes/ui/components/key_bind_row.tscn")
const WINDOW_MODE_LABELS: Array[String] = ["WINDOWED", "BORDERLESS FULLSCREEN", "FULLSCREEN"]
const CONFIRM_SECONDS := 10

@onready var _window_mode_option: Control = %WindowModeOption
@onready var _resolution_option: Control = %ResolutionOption
@onready var _vsync_check: CheckBox = %VsyncCheck
@onready var _bind_list: VBoxContainer = %BindList
@onready var _confirm: Control = %DisplayConfirm
@onready var _countdown_label: Label = %Countdown
@onready var _countdown_timer: Timer = %CountdownTimer
@onready var _volume_sliders: Dictionary = {
	"Master": %MasterSlider,
	"Music": %MusicSlider,
	"SFX": %SfxSlider,
}
@onready var _volume_values: Dictionary = {
	"Master": %MasterValue,
	"Music": %MusicValue,
	"SFX": %SfxValue,
}

func _ready() -> void:
	for label: String in WINDOW_MODE_LABELS:
		_window_mode_option.add_item(label)
	_populate_resolutions()
	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_vsync_check.toggled.connect(Settings.set_vsync)
	for bus_name: String in _volume_sliders:
		var slider: HSlider = _volume_sliders[bus_name]
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
	var reset_all: Button = %ResetAllButton
	var back_button: Button = %BackButton
	var keep_button: Button = %KeepButton
	var revert_button: Button = %RevertButton
	reset_all.pressed.connect(Settings.reset_all)
	back_button.pressed.connect(back_requested.emit)
	keep_button.pressed.connect(_keep_display)
	revert_button.pressed.connect(_revert_display)
	_countdown_timer.timeout.connect(_on_countdown_tick)
	_confirm.hide()
	Settings.settings_applied.connect(_refresh)
	_build_bind_rows()
	_refresh()
	var rig: Control = %ChainRig
	rig.adopt(%Content)

func focus_first() -> void:
	_window_mode_option.focus_first()

func _populate_resolutions() -> void:
	_resolution_option.clear()
	for preset: Vector2i in Settings.resolutions:
		_resolution_option.add_item(Settings.resolution_label(preset))

func _build_bind_rows() -> void:
	for action: String in Settings.REMAPPABLE_ACTIONS:
		var row := KEY_BIND_ROW.instantiate()
		row.setup(action, Settings.REMAPPABLE_ACTIONS[action])
		_bind_list.add_child(row)

func _refresh() -> void:
	_window_mode_option.selected = int(Settings.window_mode)
	_resolution_option.selected = Settings.get_resolution_index()
	_vsync_check.set_pressed_no_signal(Settings.vsync_enabled)
	for bus_name: String in _volume_sliders:
		var slider: HSlider = _volume_sliders[bus_name]
		var value_label: Label = _volume_values[bus_name]
		slider.set_value_no_signal(Settings.get_bus_volume(bus_name) * 100.0)
		value_label.text = "%d%%" % roundi(slider.value)
	for row in _bind_list.get_children():
		row.call("refresh")

var _restore_window_mode := 0
var _restore_resolution := Vector2i.ZERO
var _seconds_left := 0

func _on_window_mode_selected(index: int) -> void:
	_try_display(index, Settings.resolution)

func _on_resolution_selected(index: int) -> void:
	_try_display(int(Settings.window_mode), Settings.resolutions[index])

func _try_display(mode: int, size: Vector2i) -> void:
	if not _confirm.visible:
		_restore_window_mode = int(Settings.window_mode)
		_restore_resolution = Settings.resolution
	Settings.preview_display(mode, size)
	_refresh()
	_start_countdown()

func _start_countdown() -> void:
	_seconds_left = CONFIRM_SECONDS
	_show_countdown()
	_confirm.show()
	%KeepButton.grab_focus()
	_countdown_timer.start()

func _show_countdown() -> void:
	_countdown_label.text = "REVERTING IN %d" % _seconds_left

func _on_countdown_tick() -> void:
	_seconds_left -= 1
	_show_countdown()
	if _seconds_left <= 0:
		_revert_display()

func _keep_display() -> void:
	_end_countdown()
	Settings.save_settings()

func _revert_display() -> void:
	_end_countdown()
	Settings.preview_display(_restore_window_mode, _restore_resolution)
	_refresh()

func _end_countdown() -> void:
	_countdown_timer.stop()
	_confirm.hide()

func _on_volume_changed(value: float, bus_name: String) -> void:
	Settings.set_bus_volume(bus_name, value / 100.0)
	var value_label: Label = _volume_values[bus_name]
	value_label.text = "%d%%" % roundi(value)
