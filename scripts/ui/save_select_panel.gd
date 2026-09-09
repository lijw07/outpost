extends Control

const TRASH_ICON := preload("res://assets/ui/icons/icon_trash.png")
const SLOT_ROW := preload("res://scripts/ui/slot_row.gd")
const VISIBLE_SLOTS := 3

signal save_chosen
signal back_requested

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _empty_hint: Label = %EmptyHint
@onready var _new_game_button: Button = %NewGameButton
@onready var _name_row: HBoxContainer = %NameRow
@onready var _name_field: LineEdit = %NameField
@onready var _create_button: Button = %CreateButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _pager: HBoxContainer = %Pager
@onready var _page_label: Label = %PageLabel
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _cancel_button: Button = %CancelButton
@onready var _delete_confirm: Control = %DeleteConfirm
@onready var _delete_question: Label = %DeleteQuestion

var _pending_delete := {}
var _page := 0

func _ready() -> void:
	var back_button: Button = %BackButton
	_new_game_button.pressed.connect(_show_name_entry)
	_create_button.pressed.connect(_create_save)
	_name_field.text_submitted.connect(_on_name_submitted)
	_name_field.text_changed.connect(_on_name_changed)
	back_button.pressed.connect(request_back)
	var confirm_button: Button = %ConfirmDeleteButton
	var cancel_button: Button = %CancelDeleteButton
	confirm_button.pressed.connect(_confirm_delete)
	cancel_button.pressed.connect(_cancel_delete)
	_cancel_button.pressed.connect(_cancel_name_entry)
	_prev_button.pressed.connect(_turn_page.bind(-1))
	_next_button.pressed.connect(_turn_page.bind(1))
	visibility_changed.connect(_on_visibility_changed)
	_delete_confirm.cancelled.connect(_cancel_delete)
	_delete_confirm.hide()
	_name_row.hide()
	refresh()
	var rig: Control = %ChainRig
	rig.adopt(%Content)
	_align_footer.call_deferred()

func _align_footer() -> void:
	var separation: float = _slot_list.get_theme_constant("separation")
	_scroll.custom_minimum_size.y = SLOT_ROW.ROW_HEIGHT * VISIBLE_SLOTS \
		+ separation * (VISIBLE_SLOTS - 1)

func focus_first() -> void:
	if _slot_list.get_child_count() > 0:
		var first: Button = _slot_list.get_child(0).get_node("Select")
		first.grab_focus()
		return
	_new_game_button.grab_focus()

func refresh() -> void:
	for child in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	var entries := SaveManager.list_saves()
	var pages: int = maxi(1, ceili(float(entries.size()) / float(VISIBLE_SLOTS)))
	_page = clampi(_page, 0, pages - 1)
	_empty_hint.visible = entries.is_empty()
	var first := _page * VISIBLE_SLOTS
	for index in range(first, mini(first + VISIBLE_SLOTS, entries.size())):
		_slot_list.add_child(_build_slot(entries[index]))
	_pager.visible = entries.size() > VISIBLE_SLOTS
	_page_label.text = "PAGE %d / %d" % [_page + 1, pages]
	_prev_button.disabled = _page == 0
	_next_button.disabled = _page >= pages - 1
	_new_game_button.disabled = not SaveManager.can_create()
	%SlotSummary.text = "SURVIVORS %d / %d" % [entries.size(), SaveManager.MAX_SLOTS]
	if _new_game_button.disabled:
		%SlotSummary.text += " - DELETE ONE TO MAKE ROOM"

func _turn_page(step: int) -> void:
	_page += step
	refresh()
	focus_first.call_deferred()

func _build_slot(save: Dictionary) -> HBoxContainer:
	var row := SLOT_ROW.build(self, save["character_name"],
		"LAST PLAYED %s" % SaveManager.format_timestamp(save["last_played"]),
		SLOT_ROW.name_column(self, _name_field.max_length), TRASH_ICON, "DELETE SURVIVOR")
	row.get_node("Select").pressed.connect(_on_slot_pressed.bind(save))
	row.get_node("Delete").pressed.connect(_ask_delete.bind(save))
	return row

func _on_visibility_changed() -> void:
	if visible:
		_name_row.hide()
		_delete_confirm.hide()
		_pending_delete = {}
		refresh()

func _ask_delete(save: Dictionary) -> void:
	_pending_delete = save
	_delete_question.text = "DELETE %s?" % save["character_name"]
	_delete_confirm.show()

func _cancel_delete() -> void:
	_pending_delete = {}
	_delete_confirm.hide()

func _confirm_delete() -> void:
	if not _pending_delete.is_empty():
		SaveManager.delete_save(_pending_delete["id"])
	_pending_delete = {}
	_delete_confirm.hide()
	refresh()
	focus_first.call_deferred()

func _show_name_entry() -> void:
	_name_row.show()
	_name_field.text = ""
	_create_button.disabled = true
	_name_field.grab_focus()

func _cancel_name_entry() -> void:
	_name_row.hide()
	_name_field.text = ""
	_new_game_button.grab_focus()

func _on_name_changed(new_text: String) -> void:
	var caret := _name_field.caret_column
	var clean := SaveManager.sanitize_name(new_text, false)
	if clean != new_text:
		_name_field.text = clean
		_name_field.caret_column = SaveManager.sanitize_name(new_text.substr(0, caret), false).length()
	_create_button.disabled = clean.strip_edges().is_empty()

func _on_name_submitted(_new_text: String) -> void:
	_create_save()

func _create_save() -> void:
	var save := SaveManager.create_save(_name_field.text)
	if save.is_empty():
		return
	_name_row.hide()
	_start(save)

func _on_slot_pressed(save: Dictionary) -> void:
	_start(save)

func _start(save: Dictionary) -> void:
	GameSession.save_id = save["id"]
	GameSession.character_name = save["character_name"]
	save_chosen.emit()

func request_back() -> void:
	if _delete_confirm.visible:
		_cancel_delete()
	elif _name_row.visible:
		_cancel_name_entry()
	else:
		back_requested.emit()
