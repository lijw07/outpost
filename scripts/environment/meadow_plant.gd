extends AnimatedSprite2D
## Add moving bodies to the "players" group, or call brush_from() explicitly.

@export var contact_radius := 34.0
var _occupied := false
var _left := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(_animation_finished)
	play(&"wind")
	frame = posmod(int(global_position.x + global_position.y), 8)

func _process(_delta: float) -> void:
	var nearby: Node2D = null
	for body in get_tree().get_nodes_in_group("players"):
		if body is Node2D and global_position.distance_to(body.global_position) < contact_radius:
			nearby = body
			break
	if nearby != null and not _occupied:
		brush_from(nearby.global_position)
	elif nearby == null and _occupied:
		_occupied = false
		if not is_playing():
			play(&"recover_left" if _left else &"recover")

func brush_from(world_position: Vector2) -> void:
	_occupied = true
	_left = world_position.x > global_position.x
	play(&"brush_left" if _left else &"brush")

func _animation_finished() -> void:
	if String(animation).begins_with("brush"):
		if not _occupied:
			play(&"recover_left" if _left else &"recover")
	elif String(animation).begins_with("recover"):
		play(&"wind")
