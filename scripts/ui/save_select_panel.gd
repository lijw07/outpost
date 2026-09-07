extends Control

signal save_chosen
signal back_requested

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _empty_hint: Label = %EmptyHint
@onready var _new_game_button: Button = %NewGameButton
@onready var _name_row: HBoxContainer = %NameRow
@onready var _name_field: LineEdit = %NameField
@onready var _create_button: Button = %CreateButton

func _ready() -> void:
	var back_button: Button = %BackButton
	_new_game_button.pressed.connect(_show_name_entry)
	_create_button.pressed.connect(_create_save)
	_name_field.text_submitted.connect(_on_name_submitted)
	_name_field.text_changed.connect(_on_name_changed)
	back_button.pressed.connect(back_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	_name_row.hide()
	refresh()
	var rig: Control = %ChainRig
	rig.adopt(%Content)

func focus_first() -> void:
	if _slot_list.get_child_count() > 0:
		var first := _slot_list.get_child(0) as Button
		if first != null:
			first.grab_focus()
			return
	_new_game_button.grab_focus()

func refresh() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	var saves := SaveManager.list_saves()
	_empty_hint.visible = saves.is_empty()
	for save: Dictionary in saves:
		_slot_list.add_child(_build_slot(save))
	_new_game_button.disabled = not SaveManager.can_create()

func _build_slot(save: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(760, 76)
	button.text = "%s      LAST PLAYED %s" % [save["character_name"],
		SaveManager.format_timestamp(save["last_played"])]
	button.pressed.connect(_on_slot_pressed.bind(save))
	return button

func _on_visibility_changed() -> void:
	if visible:
		_name_row.hide()
		refresh()

func _show_name_entry() -> void:
	_name_row.show()
	_name_field.text = ""
	_create_button.disabled = true
	_name_field.grab_focus()

func _on_name_changed(new_text: String) -> void:
	var clean := SaveManager.sanitize_name(new_text)
	if clean != new_text:
		_name_field.text = clean
		_name_field.caret_column = clean.length()
	_create_button.disabled = clean.is_empty()

func _on_name_submitted(_new_text: String) -> void:
	_create_save()

func _create_save() -> void:
	var save := SaveManager.create_save(_name_field.text)
	if save.is_empty():
		return
	_name_row.hide()
	_start(save)

func _on_slot_pressed(save: Dictionary) -> void:
	SaveManager.touch(save["id"])
	_start(save)

func _start(save: Dictionary) -> void:
	GameSession.save_id = save["id"]
	GameSession.character_name = save["character_name"]
	save_chosen.emit()
