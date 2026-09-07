extends Control

signal mode_selected(coop: bool)
signal back_requested

@onready var _single_player_button: Button = %SinglePlayerButton

func _ready() -> void:
	var rig: Control = %ChainRig
	var content: Control = %Content
	var coop_button: Button = %CoopButton
	var back_button: Button = %BackButton
	_single_player_button.pressed.connect(_on_mode_pressed.bind(false))
	coop_button.pressed.connect(_on_mode_pressed.bind(true))
	back_button.pressed.connect(back_requested.emit)
	rig.adopt(content)

func focus_first() -> void:
	_single_player_button.grab_focus()

func _on_mode_pressed(coop: bool) -> void:
	mode_selected.emit(coop)
