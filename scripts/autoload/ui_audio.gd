extends Node

const HOVER_PATH := "res://assets/audio/ui/ui_chain_tap.wav"
const CLICK_PATH := "res://assets/audio/ui/ui_chain_clank.wav"
const BACK_PATH := "res://assets/audio/ui/ui_chain_drop.wav"
const RATTLE_PATH := "res://assets/audio/ui/ui_chain_rattle.wav"
const HOIST_PATH := "res://assets/audio/ui/ui_chain_hoist.wav"

const BACK_LABELS: Array[String] = ["BACK", "QUIT"]

var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _back_player: AudioStreamPlayer
var _rattle_player: AudioStreamPlayer
var _hoist_player: AudioStreamPlayer

func _ready() -> void:
	_hover_player = _create_player(HOVER_PATH, -11.0)
	_click_player = _create_player(CLICK_PATH, -5.0)
	_back_player = _create_player(BACK_PATH, -5.0)
	_rattle_player = _create_player(RATTLE_PATH, -8.0)
	_hoist_player = _create_player(HOIST_PATH, -9.0)
	get_tree().node_added.connect(_wire)
	_wire_existing_tree.call_deferred()

func play_hover() -> void:
	_play(_hover_player, randf_range(0.94, 1.08))

func play_click() -> void:
	_play(_click_player, randf_range(0.97, 1.04))

func play_back() -> void:
	_play(_back_player, 1.0)

func play_rattle(pitch := 1.0) -> void:
	_play(_rattle_player, pitch)

func play_hoist() -> void:
	_play(_hoist_player, randf_range(0.97, 1.05))

func _play(player: AudioStreamPlayer, pitch: float) -> void:
	if player.stream == null:
		return
	player.pitch_scale = pitch
	player.play()

func _create_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = ResourceLoader.load(path) as AudioStream
	player.bus = "SFX"
	player.volume_db = volume_db
	add_child(player)
	return player

func _wire_existing_tree() -> void:
	_wire_branch(get_tree().root)

func _wire_branch(node: Node) -> void:
	_wire(node)
	for child in node.get_children():
		_wire_branch(child)

func _wire(node: Node) -> void:
	_wire_button(node)
	_wire_tabs(node)
	_wire_range(node)
	_wire_popup(node)

func _wire_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.mouse_entered.is_connected(play_hover):
		return
	button.mouse_entered.connect(play_hover)
	button.focus_entered.connect(play_hover)
	button.pressed.connect(_on_button_pressed.bind(button))

func _wire_tabs(node: Node) -> void:
	var container := node as TabContainer
	if container != null and not container.tab_hovered.is_connected(_on_tab_hovered):
		container.tab_hovered.connect(_on_tab_hovered)
		container.tab_selected.connect(_on_tab_selected)
		return
	var bar := node as TabBar
	if bar != null and not bar.tab_hovered.is_connected(_on_tab_hovered):
		bar.tab_hovered.connect(_on_tab_hovered)
		bar.tab_selected.connect(_on_tab_selected)

func _wire_range(node: Node) -> void:
	var slider := node as Slider
	if slider == null or slider.mouse_entered.is_connected(play_hover):
		return
	slider.mouse_entered.connect(play_hover)
	slider.focus_entered.connect(play_hover)
	slider.drag_ended.connect(_on_drag_ended)

func _wire_popup(node: Node) -> void:
	var popup := node as PopupMenu
	if popup == null or popup.id_focused.is_connected(_on_menu_focused):
		return
	popup.id_focused.connect(_on_menu_focused)
	popup.index_pressed.connect(_on_menu_pressed)

func _on_button_pressed(button: BaseButton) -> void:
	var labelled := button as Button
	if labelled != null and labelled.text.to_upper() in BACK_LABELS:
		play_back()
		return
	play_click()

func _on_tab_hovered(_tab: int) -> void:
	play_hover()

func _on_tab_selected(_tab: int) -> void:
	play_click()

func _on_drag_ended(_value_changed: bool) -> void:
	play_click()

func _on_menu_focused(_id: int) -> void:
	play_hover()

func _on_menu_pressed(_index: int) -> void:
	play_click()
