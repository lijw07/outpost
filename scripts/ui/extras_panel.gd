extends Control

signal back_requested

@onready var _back_button: Button = %BackButton

func _ready() -> void:
	var rig: Control = %ChainRig
	var content: Control = %Content
	_back_button.pressed.connect(back_requested.emit)
	rig.adopt(content)

func focus_first() -> void:
	_back_button.grab_focus()
