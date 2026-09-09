extends Node2D
## Small native-pixel dust bursts; call step_at() when a foot lands on dirt.
var motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 807

func step_at(world_position: Vector2) -> void:
	for i in range(7):
		motes.append({"p": to_local(world_position), "v": Vector2(_rng.randf_range(-22,22),_rng.randf_range(-30,-8)), "life": 0.0})

func _process(delta: float) -> void:
	for i in range(motes.size()-1,-1,-1):
		motes[i]["life"] += delta
		motes[i]["p"] += motes[i]["v"]*delta
		motes[i]["v"].y += delta*28.0
		if motes[i]["life"] >= 0.48:
			motes.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		draw_rect(Rect2(Vector2(mote["p"]).round(),Vector2(3,2)),Color(0.66,0.53,0.34,1.0-float(mote["life"])/0.48))
