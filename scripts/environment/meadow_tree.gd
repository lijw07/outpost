extends Node2D
## Art-state controller. Combat/inventory code can call hit() and collect_log().

signal hit_received(remaining_hits: int)
signal felled
signal log_collected

@export var species := "oak"
@export var hits_to_fell := 3
var remaining_hits := 3
var state := "standing"
var _motion: Tween
var _shake_time := 0.0
@onready var pivot: Node2D = $Pivot
@onready var crown: AnimatedSprite2D = $Pivot/Crown
@onready var trunk: Sprite2D = $Pivot/Trunk

func _ready() -> void:
	remaining_hits = hits_to_fell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.play(&"wind")
	crown.frame = posmod(int(position.x), 8)

func _process(delta: float) -> void:
	if state == "standing" and _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time-delta)
		pivot.rotation = sin(_shake_time*65.0)*0.035*(_shake_time/0.3)
		if _shake_time == 0.0:
			pivot.rotation = 0.0

func hit(damage := 1) -> void:
	if state != "standing" or damage <= 0:
		return
	remaining_hits = maxi(0, remaining_hits-damage)
	_shake_time = 0.3
	hit_received.emit(remaining_hits)
	_shed_leaves(5)
	if remaining_hits == 0:
		state = "shedding"
		_fell()

func _shed_leaves(amount: int) -> void:
	var debris := CPUParticles2D.new()
	debris.texture = load("res://assets/environment/meadow/effects/leaf_chip.png")
	debris.amount = amount
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 0.9
	debris.direction = Vector2.UP
	debris.spread = 100.0
	debris.initial_velocity_min = 35.0
	debris.initial_velocity_max = 85.0
	debris.gravity = Vector2(12, 150)
	debris.angular_velocity_min = -140.0
	debris.angular_velocity_max = 140.0
	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	debris.emission_rect_extents = Vector2(30, 15)
	debris.position = pivot.position+crown.position+Vector2(0, -40)
	add_child(debris)
	debris.emitting = true
	get_tree().create_timer(1.2).timeout.connect(debris.queue_free)

func _fell() -> void:
	pivot.rotation = 0.0
	$Stump.texture = load("res://assets/environment/meadow/trees/"+species+"_stump.png")
	trunk.texture = load("res://assets/environment/meadow/trees/"+species+"_trunk.png")
	crown.stop()
	_shed_leaves(24)
	_motion = create_tween()
	# Remove the crown/branches first, then tip the exact same exposed trunk.
	_motion.tween_property(crown, "position:y", crown.position.y+38.0, 0.28)
	_motion.parallel().tween_property(crown, "rotation", 0.18, 0.28)
	_motion.parallel().tween_property(crown, "modulate:a", 0.0, 0.28)
	_motion.tween_callback(func() -> void:
		state = "falling"
		crown.hide()
	)
	_motion.tween_property(trunk, "rotation", PI/2.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(trunk, "position:y", -pivot.position.y+8.0, 0.65)
	_motion.tween_property(trunk, "rotation", PI/2.0-0.045, 0.08)
	_motion.tween_property(trunk, "rotation", PI/2.0, 0.1)
	_motion.tween_callback(func() -> void:
		state = "felled"
		felled.emit()
	)

func collect_log() -> bool:
	if state != "felled":
		return false
	trunk.hide()
	state = "collected"
	log_collected.emit()
	return true
