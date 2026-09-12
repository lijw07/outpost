extends CharacterBody3D

@export var vehicle_id := "sedan"
@export var controlled := false
@export var maximum_speed := 9.0
@export var reverse_speed := 4.0
@export var acceleration := 4.0
@export var brake_strength := 12.0
@export var wheelbase := 2.375
@export var wheel_radius := 0.4375
@export var rear_steering := false
var speed := 0.0
var steering := 0.0
var wheel_angle := 0.0
var fork_height := 0.0
var throttle_command := 0.0
var steering_command := 0.0
var brake_command := false
var manual_commands := false
var wheels: Array[Node3D] = []
var steering_pivots: Array[Node3D] = []
var suspension: Node3D
var fork_visual: Node3D
var fork_origin := Vector3.ZERO

func _ready() -> void:
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	safe_margin = 0.01
	for node in $Model.find_children("wheel_*", "Node3D", true, false):
		wheels.append(node)
	for node in $Model.find_children("steer_*", "Node3D", true, false):
		steering_pivots.append(node)
	suspension = $Model.find_child("body_suspension", true, false)
	if vehicle_id == "forklift":
		for node in $Model.find_children("fork*", "Node3D", true, false):
			if not node is MeshInstance3D:
				fork_visual = node
				break
	if fork_visual != null:
		fork_origin = fork_visual.position
	for player in $Model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	add_to_group("drivable_vehicles")

func set_commands(throttle: float, turn: float, braking := false) -> void:
	manual_commands = true
	throttle_command = clampf(throttle, -1.0, 1.0)
	steering_command = clampf(turn, -1.0, 1.0)
	brake_command = braking

func _physics_process(delta: float) -> void:
	if controlled and not manual_commands:
		throttle_command = Input.get_axis("move_down", "move_up")
		steering_command = Input.get_axis("move_right", "move_left")
		brake_command = Input.is_physical_key_pressed(KEY_SPACE)
	if not controlled:
		throttle_command = 0
		steering_command = 0
		brake_command = true
	var previous_speed := speed
	if brake_command:
		speed = move_toward(speed, 0.0, brake_strength * delta)
	elif throttle_command != 0:
		var limit := maximum_speed if throttle_command > 0 else reverse_speed
		var rate := brake_strength if speed * throttle_command < 0 else acceleration
		speed = move_toward(speed, throttle_command * limit, rate * delta)
	else:
		speed = move_toward(speed, 0.0, 1.5 * delta)
	steering = move_toward(steering, steering_command * deg_to_rad(25), 1.8 * delta)
	var yaw_step := speed / wheelbase * tan(steering) * delta
	var proposed := global_transform.rotated_local(Vector3.UP, yaw_step)
	if not test_move(proposed, -proposed.basis.z * speed * delta):
		global_transform = proposed
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	var before := global_position
	move_and_slide()
	var traveled := (global_position - before).dot(forward)
	wheel_angle = wrapf(wheel_angle - traveled / wheel_radius, -PI, PI)
	var hit_obstacle := false
	for index in get_slide_collision_count():
		if absf(get_slide_collision(index).get_normal().y) < 0.5:
			hit_obstacle = true
	if hit_obstacle or (absf(speed) > 0.01 and absf(traveled) < absf(speed * delta) * 0.2):
		speed = 0.0
	for wheel in wheels:
		wheel.rotation.x = wheel_angle
	for pivot in steering_pivots:
		pivot.rotation.y = steering * (-1 if rear_steering else 1)
	if suspension != null:
		var pitch := clampf((previous_speed - speed) * 0.012 / maxf(delta, 0.001), -0.025, 0.035)
		suspension.rotation.x = lerpf(suspension.rotation.x, pitch, minf(delta * 8, 1))
	if controlled and vehicle_id == "forklift" and not manual_commands:
		set_fork_height(fork_height + delta * (float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))))

func set_fork_height(height: float) -> void:
	if fork_visual == null:
		return
	fork_height = clampf(height, 0.0, 1.25)
	fork_visual.position = fork_origin + Vector3.UP * fork_height
	for shape in get_children():
		if shape is CollisionShape3D and shape.has_meta("fork_origin"):
			shape.position = shape.get_meta("fork_origin") + Vector3.UP * fork_height

func reset_at(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	speed = 0
	steering = 0
	wheel_angle = 0
	throttle_command = 0
	steering_command = 0
	brake_command = false
	set_fork_height(0)
	reset_physics_interpolation()
