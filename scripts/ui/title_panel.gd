extends Control

signal play_requested
signal settings_requested
signal extras_requested
signal quit_requested

@onready var _play_button: Button = %PlayButton

func _ready() -> void:
	var rig: Control = %ChainRig
	var content: Control = %Content
	var settings_button: Button = %SettingsButton
	var extras_button: Button = %ExtrasButton
	var quit_button: Button = %QuitButton
	_play_button.pressed.connect(play_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	extras_button.pressed.connect(extras_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	rig.adopt(content)

func focus_first() -> void:
	_play_button.grab_focus()
