extends Node3D

@export var fixture_id := ""
@export var signal_period := 12.0
var signal_clock := 0.0
var lights_on := true
var lid_open := false
var animation_player: AnimationPlayer

func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0]
	set_process(fixture_id == "traffic_signal")
	if fixture_id == "traffic_signal":
		animation_player.play("red")

func _process(delta: float) -> void:
	signal_clock = fmod(signal_clock + delta, signal_period)
	var state := "red" if signal_clock < signal_period * 0.5 else "green" if signal_clock < signal_period * 0.9 else "amber"
	if animation_player.current_animation != state:
		animation_player.play(state)

func set_lights(enabled: bool) -> void:
	lights_on = enabled
	for light in find_children("*", "OmniLight3D", true, false):
		light.visible = enabled

func toggle_lid() -> void:
	if fixture_id != "wheelie_bin" or animation_player == null:
		return
	lid_open = not lid_open
	animation_player.play("lid_open" if lid_open else "lid_close")
