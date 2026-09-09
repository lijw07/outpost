extends Control

signal continue_requested
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
	%ContinueButton.pressed.connect(continue_requested.emit)
	visibility_changed.connect(_refresh_continue)
	_refresh_continue()
	_play_button.pressed.connect(play_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	extras_button.pressed.connect(extras_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	rig.adopt(content)

func focus_first() -> void:
	if %ContinueButton.visible:
		%ContinueButton.grab_focus()
	else:
		_play_button.grab_focus()

func _refresh_continue() -> void:
	if not is_node_ready():
		return
	var last := GameSession.last_session()
	%ContinueButton.visible = not last.is_empty()
	%ContinueHint.visible = not last.is_empty()
	if not last.is_empty():
		%ContinueHint.text = "%s / %s" % [last.survivor.character_name, last.world.world_name]
