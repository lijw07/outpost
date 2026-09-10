extends Node2D
## Bounded, positional menu sounds. Music remains on its separate existing bus.
const VOICES := 10
const LEVELS := {"rifle":-15.0,"hammer":-15.0,"footstep":-24.0,"groan":-22.0,"body_fall":-18.0,"fence_break":-16.0,"timber":-21.0,"launcher":-15.0,"explosion":-18.0,"swing":-22.0,"grenade":-20.0,"reload":-20.0}
const GAPS := {"rifle":0.08,"hammer":0.1,"footstep":0.09,"groan":3.0,"body_fall":0.12,"fence_break":0.2,"timber":0.2,"launcher":0.2,"explosion":0.15,"swing":0.15,"grenade":0.15,"reload":0.2}
var enabled := true
var clock := 0.0
var events := 0
var streams: Dictionary = {}
var next_allowed: Dictionary = {}
var players: Array[AudioStreamPlayer2D] = []
var ambience: AudioStreamPlayer2D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 9321
	for kind: String in LEVELS:
		streams[kind] = load("res://assets/audio/menu/%s.wav" % kind)
	for index in VOICES:
		players.append(_player())
	ambience = _player()
	var fire := load("res://assets/audio/menu/campfire.wav").duplicate() as AudioStreamWAV
	fire.loop_mode = AudioStreamWAV.LOOP_FORWARD
	fire.loop_begin = 0
	fire.loop_end = int(fire.get_length()*fire.mix_rate)
	ambience.stream = fire
	ambience.position = Vector2(1330,620)
	ambience.volume_db = -24
	set_enabled(enabled)

func _player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = &"SFX"
	player.max_distance = 1800
	player.attenuation = 0.7
	add_child(player)
	return player

func set_enabled(active: bool) -> void:
	enabled = active
	if ambience == null:
		return
	if enabled and DisplayServer.get_name() != "headless":
		if not ambience.playing:
			ambience.play()
	else:
		ambience.stop()
		for player in players:
			player.stop()

func advance(delta: float) -> void:
	clock += delta

func emit_sound(kind: String, point: Vector2) -> void:
	if not enabled or not streams.has(kind) or clock < float(next_allowed.get(kind,0.0)):
		return
	next_allowed[kind] = clock+float(GAPS[kind])
	events += 1
	if DisplayServer.get_name() == "headless":
		return
	# Drop an excess event instead of cutting an existing sound or allocating nodes.
	for player in players:
		if not player.playing:
			player.stream = streams[kind]
			player.position = point
			player.volume_db = LEVELS[kind]
			player.pitch_scale = _rng.randf_range(0.92,1.07)
			player.play()
			return

func _exit_tree() -> void:
	set_enabled(false)
	for player in players:
		player.stream = null
	if ambience != null:
		ambience.stream = null
