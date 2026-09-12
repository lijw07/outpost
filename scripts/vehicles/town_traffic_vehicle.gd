extends "res://scripts/vehicles/drivable_vehicle.gd"

var director: Node3D
var route: Curve3D
var route_id := ""
var progress := 0.0
var stop_clock := 0.0
var stops_completed := {}
var half_length := 2.2
var distance_driven := 0.0
var waiting_reason := ""
var signal_phase := ""
var yellow_committed := false
var travel_limit := INF

func _physics_process(delta: float) -> void:
	if route == null:return
	var limit: float=director.speed_limit(self,delta)
	speed=move_toward(speed,limit,(acceleration if limit>speed else brake_strength)*delta)
	var next := minf(progress+speed*delta,route.get_baked_length())
	next=minf(next,progress+travel_limit)
	var target := route.sample_baked(next,true)
	var tangent := (route.sample_baked(minf(next+0.25,route.get_baked_length()),true)-target).normalized()
	if tangent.length_squared()<0.1:tangent=-global_basis.z
	var next_yaw := atan2(-tangent.x,-tangent.z)
	var turn := angle_difference(rotation.y,next_yaw)
	var traveled := global_position.distance_to(target)
	var proposed := Transform3D(Basis(Vector3.UP,next_yaw),global_position)
	if not test_move(proposed,target-global_position):
		rotation.y=next_yaw
		var hit := move_and_collide(target-global_position)
		if hit==null:
			progress=next
			distance_driven+=traveled
			if traveled<speed*delta-0.01:speed=traveled/delta
		else:speed=0
	else:
		speed=0
		waiting_reason="Obstacle"
	wheel_angle=wrapf(wheel_angle-traveled/wheel_radius,-PI,PI) if speed>0 else wheel_angle
	steering=move_toward(steering,clampf(atan2(turn*wheelbase,maxf(traveled,0.001)),-0.44,0.44),delta*2)
	for wheel in wheels:wheel.rotation.x=wheel_angle
	for pivot in steering_pivots:pivot.rotation.y=steering
	if progress>=route.get_baked_length()-0.1:queue_free()
