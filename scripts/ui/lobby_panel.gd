extends Control

signal back_requested
signal run_started
signal map_change_requested

@onready var _host_tab: Button = %HostTab
@onready var _join_tab: Button = %JoinTab
@onready var _host_form: VBoxContainer = %HostForm
@onready var _join_form: VBoxContainer = %JoinForm
@onready var _server_field: LineEdit = %ServerField
@onready var _host_port_field: LineEdit = %HostPortField
@onready var _code_value: Label = %CodeValue
@onready var _address_field: LineEdit = %AddressField
@onready var _join_port_field: LineEdit = %JoinPortField
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _map_value: Label = %MapValue
@onready var _status_label: Label = %StatusLabel
@onready var _start_button: Button = %StartButton

func _ready() -> void:
	var rig: Control = %ChainRig
	var open_button: Button = %OpenButton
	var connect_button: Button = %ConnectButton
	var copy_button: Button = %CopyButton
	var back_button: Button = %BackButton
	var change_map: Button = %ChangeMapButton
	_host_tab.toggled.connect(_show_host)
	_join_tab.toggled.connect(func(on: bool) -> void: _show_host(not on))
	open_button.pressed.connect(_on_open_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	_start_button.pressed.connect(run_started.emit)
	back_button.pressed.connect(_on_back_pressed)
	change_map.pressed.connect(map_change_requested.emit)
	NetSession.roster_changed.connect(_refresh)
	NetSession.status_changed.connect(_on_status)
	visibility_changed.connect(_on_visibility_changed)
	_host_port_field.text = str(NetSession.DEFAULT_PORT)
	_join_port_field.text = str(NetSession.DEFAULT_PORT)
	_address_field.text = "127.0.0.1"
	open_button.disabled = not NetSession.TRANSPORT_AVAILABLE
	connect_button.disabled = not NetSession.TRANSPORT_AVAILABLE
	copy_button.disabled = true
	_show_host(true)
	_refresh()
	rig.adopt(%Content)

func focus_first() -> void:
	_host_tab.grab_focus()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	if not NetSession.is_host():
		_server_field.text = _default_server_name()
	NetSession.seat_local_player()
	_refresh()

func _default_server_name() -> String:
	var owner_name := GameSession.character_name
	return "%s OUTPOST" % owner_name if not owner_name.is_empty() else "NEW OUTPOST"

func _show_host(hosting: bool) -> void:
	_host_form.visible = hosting
	_join_form.visible = not hosting
	_host_tab.set_pressed_no_signal(hosting)
	_join_tab.set_pressed_no_signal(not hosting)
	_map_value.get_parent().visible = hosting
	_start_button.visible = hosting

func _on_open_pressed() -> void:
	var port := _port_from(_host_port_field)
	if not NetSession.valid_port(port):
		_on_status("PORT MUST BE BETWEEN 1 AND 65535")
		return
	NetSession.host(_server_field.text, port)
	_refresh()

func _on_connect_pressed() -> void:
	NetSession.join(_address_field.text, _port_from(_join_port_field))
	_refresh()

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(NetSession.invite_code)
	_status_label.text = "INVITE CODE COPIED"

func _on_back_pressed() -> void:
	NetSession.leave()
	back_requested.emit()

func _on_status(message: String) -> void:
	_status_label.text = message

func _port_from(field: LineEdit) -> int:
	var text := field.text.strip_edges()
	return text.to_int() if text.is_valid_int() else -1

func _refresh() -> void:
	_map_value.text = GameSession.world_name if not GameSession.world_name.is_empty() else "NO MAP SELECTED"
	_code_value.text = NetSession.invite_code if not NetSession.invite_code.is_empty() else "-"
	_start_button.disabled = not NetSession.can_start()
	%CopyButton.disabled = NetSession.invite_code.is_empty()
	if not NetSession.TRANSPORT_AVAILABLE:
		_status_label.text = NetSession.UNAVAILABLE_MESSAGE
	for child in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	for index in NetSession.MAX_PLAYERS:
		_slot_list.add_child(_build_slot(index))

func _build_slot(index: int) -> Label:
	var row := Label.new()
	if index < NetSession.roster.size():
		var player: Dictionary = NetSession.roster[index]
		var tag: String = "LOCAL" if NetSession.role == NetSession.Role.OFFLINE else "HOST" if player["is_host"] else "READY" if player["ready"] else "WAITING"
		row.text = "%d.  %s      %s" % [index + 1, player["name"], tag]
	else:
		row.text = "%d.  OPEN SLOT" % (index + 1)
		row.modulate = Color(1.0, 1.0, 1.0, 0.45)
	return row

func request_back() -> void:
	_on_back_pressed()
