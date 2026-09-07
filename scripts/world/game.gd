extends Control

@onready var _mode_label: Label = %ModeLabel

func _ready() -> void:
	var menu_button: Button = %MenuButton
	menu_button.pressed.connect(_return_to_menu)
	if GameSession.is_coop:
		_mode_label.text = "CO-OP  UP TO %d PLAYERS" % GameSession.MAX_PLAYERS
	else:
		_mode_label.text = "SINGLE PLAYER  -  %s" % GameSession.character_name

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_return_to_menu()

func _return_to_menu() -> void:
	GameSession.return_to_menu()
