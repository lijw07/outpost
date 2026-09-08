extends Control

const TRASH_ICON := preload("res://assets/ui/icons/icon_trash.png")
const SLOT_ROW := preload("res://scripts/ui/slot_row.gd")

signal world_chosen
signal back_requested

@onready var _world_list: VBoxContainer = %WorldList
@onready var _empty_hint: Label = %EmptyHint
@onready var _new_world_button: Button = %NewWorldButton
@onready var _name_row: HBoxContainer = %NameRow
@onready var _name_field: LineEdit = %NameField
@onready var _create_button: Button = %CreateButton
@onready var _cancel_button: Button = %CancelButton
@onready var _delete_confirm: Control = %DeleteConfirm
@onready var _delete_question: Label = %DeleteQuestion

var _pending_delete := {}

func _ready() -> void:
	var back_button: Button = %BackButton
	var confirm_button: Button = %ConfirmDeleteButton
	var cancel_button: Button = %CancelDeleteButton
	_new_world_button.pressed.connect(_show_name_entry)
	_create_button.pressed.connect(_create_world)
	_name_field.text_submitted.connect(_on_name_submitted)
	_name_field.text_changed.connect(_on_name_changed)
	back_button.pressed.connect(back_requested.emit)
	confirm_button.pressed.connect(_confirm_delete)
	cancel_button.pressed.connect(_cancel_delete)
	_cancel_button.pressed.connect(_cancel_name_entry)
	visibility_changed.connect(_on_visibility_changed)
	_delete_confirm.hide()
	_name_row.hide()
	refresh()
	var rig: Control = %ChainRig
	rig.adopt(%Content)

func focus_first() -> void:
	if _world_list.get_child_count() > 0:
		var first: Button = _world_list.get_child(0).get_node("Select")
		first.grab_focus()
		return
	_new_world_button.grab_focus()

func refresh() -> void:
	for child in _world_list.get_children():
		child.queue_free()
	var worlds := WorldManager.list_worlds()
	_empty_hint.visible = worlds.is_empty()
	for world: Dictionary in worlds:
		_world_list.add_child(_build_slot(world))
	_new_world_button.disabled = not WorldManager.can_create()

func _build_slot(world: Dictionary) -> HBoxContainer:
	var row := SLOT_ROW.build(world["world_name"], WorldManager.seed_label(world["seed"]),
		SLOT_ROW.name_column(self, _name_field.max_length), TRASH_ICON, "DELETE WORLD")
	row.get_node("Select").pressed.connect(_on_slot_pressed.bind(world))
	row.get_node("Delete").pressed.connect(_ask_delete.bind(world))
	return row

func _on_visibility_changed() -> void:
	if visible:
		_name_row.hide()
		_delete_confirm.hide()
		refresh()

func _show_name_entry() -> void:
	_name_row.show()
	_name_field.text = ""
	_create_button.disabled = true
	_name_field.grab_focus()

func _cancel_name_entry() -> void:
	_name_row.hide()
	_name_field.text = ""
	_new_world_button.grab_focus()

func _on_name_changed(new_text: String) -> void:
	var clean := WorldManager.sanitize_name(new_text)
	if clean != new_text:
		_name_field.text = clean
		_name_field.caret_column = clean.length()
	_create_button.disabled = clean.is_empty()

func _on_name_submitted(_new_text: String) -> void:
	_create_world()

func _create_world() -> void:
	var world := WorldManager.create_world(_name_field.text)
	if world.is_empty():
		return
	_name_row.hide()
	_start(world)

func _ask_delete(world: Dictionary) -> void:
	_pending_delete = world
	_delete_question.text = "DELETE %s?" % world["world_name"]
	_delete_confirm.show()
	%CancelDeleteButton.grab_focus()

func _cancel_delete() -> void:
	_pending_delete = {}
	_delete_confirm.hide()

func _confirm_delete() -> void:
	if not _pending_delete.is_empty():
		WorldManager.delete_world(_pending_delete["id"])
	_pending_delete = {}
	_delete_confirm.hide()
	refresh()

func _on_slot_pressed(world: Dictionary) -> void:
	WorldManager.touch(world["id"])
	_start(world)

func _start(world: Dictionary) -> void:
	GameSession.world_id = world["id"]
	GameSession.world_name = world["world_name"]
	GameSession.world_seed = world["seed"]
	world_chosen.emit()
