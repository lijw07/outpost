extends Control

const WALK_SPEED := 3.0
const FRAME_DOWN := 0
const FRAME_RIGHT := 1
const FRAME_UP := 2
const FRAME_LEFT := 3

@onready var _survivor: Sprite3D = %Survivor

func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return
	_survivor.position += Vector3(input.x, 0.0, input.y) * WALK_SPEED * delta
	_face(input)

func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		_survivor.frame = FRAME_RIGHT if direction.x > 0.0 else FRAME_LEFT
	else:
		_survivor.frame = FRAME_UP if direction.y < 0.0 else FRAME_DOWN
