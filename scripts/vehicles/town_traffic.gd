extends Node3D

const MOTOR = preload("res://scripts/vehicles/town_traffic_vehicle.gd")
const BASE := "res://assets/models/city/street_mobility/scenes/"
var routes := {}
var rules := {}
var clock := 0.0
var spawn_clock := 0.0
var serial := 0
var lights: Array[Node3D] = []
var crossings := [5.0,46.0,82.0]
var pedestrian_override := false
var spawned := 0
var signals_stopped := 0
var pedestrian_stops := 0
var road_bounds := Rect2(-48,-54,140,156)

func _ready() -> void:
	add_to_group("town_traffic")
	var bounds := road_bounds
	var west_edge := bounds.position.x-14
	var east_edge := bounds.end.x+14
	var north_edge := bounds.position.y-14
	_route("east",[Vector3(west_edge,0,23.5),Vector3(east_edge,0,23.5)],Vector3(-19,0,23.5),"main")
	_route("west",[Vector3(east_edge,0,19.5),Vector3(west_edge,0,19.5)],Vector3(-1,0,19.5),"main")
	var turn_east: Array[Vector3]=[Vector3(-10.5,0,north_edge),Vector3(-10.5,0,13)]
	_curve(turn_east,Vector3(-10.5,0,13),Vector3(-10.5,0,19),Vector3(-7,0,23.5),Vector3(-1,0,23.5))
	turn_east.append(Vector3(east_edge,0,23.5))
	_route("south_east",turn_east,Vector3(-10.5,0,12),"branch")
	rules.south_east.stop=routes.south_east.get_closest_offset(Vector3(-10.5,0,-36))
	var turn_north: Array[Vector3]=[Vector3(west_edge,0,23.5),Vector3(-19,0,23.5)]
	_curve(turn_north,Vector3(-19,0,23.5),Vector3(-13,0,23.5),Vector3(-7.5,0,19),Vector3(-7.5,0,13))
	turn_north.append(Vector3(-7.5,0,north_edge))
	_route("east_north",turn_north,Vector3(-19,0,23.5),"main")
	rules.east_north.stop=routes.east_north.get_closest_offset(Vector3(-7.5,0,-27))
	for spec in [[Vector3(-19,0,16),0.0],[Vector3(-1,0,28),PI],[Vector3(-17.5,0,12),PI/2]]:
		var fixture: Node3D=load(BASE+"traffic_signal.tscn").instantiate()
		fixture.position=spec[0]
		fixture.rotation.y=spec[1]
		add_child(fixture)
		fixture.set_process(false)
		lights.append(fixture)
	for spec in [[Vector3(-17.5,0,-36),0.0],[Vector3(-5,0,-27),PI]]:
		var sign: Node3D=load(BASE+"stop_sign.tscn").instantiate()
		sign.position=spec[0]
		sign.rotation.y=spec[1]
		add_child(sign)
	for spec in [["bus_stop_shelter",Vector3(12,0,15.3)],["bus_stop_sign",Vector3(15.3,0,16)]]:
		var stop: Node3D=load(BASE+spec[0]+".tscn").instantiate()
		stop.position=spec[1]
		add_child(stop)
	spawn_vehicle("sedan","east",24)
	spawn_vehicle("van","west",24)
	spawn_vehicle("ambulance","south_east",16)
	spawn_vehicle("bus","west",75)

func _curve(points: Array[Vector3], a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for step in range(1,25):points.append(a.bezier_interpolate(b,c,d,float(step)/24))

func _route(id: String, points: Array, stop_line: Vector3, axis: String) -> void:
	var curve := Curve3D.new()
	curve.bake_interval=0.15
	for point in points:curve.add_point(point)
	routes[id]=curve
	rules[id]={"signal":curve.get_closest_offset(stop_line),"axis":axis}

func phase(axis: String) -> String:
	var time := fmod(clock,28.0)
	if axis=="main":return "green" if time<12 else "amber" if time<15 else "red"
	return "green" if time>=17 and time<24 else "amber" if time>=24 and time<26 else "red"

func _physics_process(delta: float) -> void:
	clock+=delta
	spawn_clock+=delta
	for index in lights.size():
		var state := phase("branch" if index==2 else "main")
		if lights[index].animation_player.current_animation!=state:lights[index].animation_player.play(state)
	if spawn_clock>5 and vehicles().size()<10:
		spawn_clock=0
		var id: String=["east","west","south_east","east_north"][serial%4]
		var type: String=["sedan","van","sedan","ambulance","bus"][serial%5]
		if type=="bus":id="west"
		spawn_vehicle(type,id)
		serial+=1

func vehicles() -> Array:
	return get_children().filter(func(node):return node.get_script()==MOTOR)

func crossing_clear(point: Vector3) -> bool:
	for car in vehicles():
		if absf(car.position.z-22)<4 and absf(car.position.x-point.x)<car.half_length+1.2:return false
	return true

func spawn_vehicle(type: String, path_id: String, offset := 0.0) -> Node3D:
	var point: Vector3=routes[path_id].sample_baked(offset,true)
	for other in vehicles():
		if other.position.distance_to(point)<12:return null
	var car=load(BASE+type+".tscn").instantiate()
	car.set_script(MOTOR)
	car.vehicle_id=type
	car.wheelbase={"sedan":38.0,"van":44.0,"ambulance":50.0,"bus":94.0}[type]/16.0
	car.director=self
	car.route=routes[path_id]
	car.route_id=path_id
	car.progress=offset
	car.half_length=4.5 if type=="bus" else 2.7 if type in ["van","ambulance"] else 2.2
	car.maximum_speed=5.5 if type=="bus" else 7.0
	car.position=point
	var direction: Vector3=car.route.sample_baked(offset+0.2,true)-point
	car.rotation.y=atan2(-direction.x,-direction.z)
	add_child(car)
	spawned+=1
	return car

func _approach(limit: float, remaining: float, car: Node3D, reason: String) -> float:
	car.travel_limit=minf(car.travel_limit,maxf(0,remaining-0.3))
	var allowed := sqrt(2*car.brake_strength*maxf(0,remaining-0.3))
	if allowed<limit:car.waiting_reason=reason
	return minf(limit,allowed)

func speed_limit(car: Node3D, delta: float) -> float:
	var limit: float=car.maximum_speed
	car.waiting_reason=""
	car.travel_limit=INF
	var rule: Dictionary=rules[car.route_id]
	var signal_distance: float=rule.signal-car.progress-car.half_length
	var state := phase(rule.axis)
	if state!=car.signal_phase:
		car.yellow_committed=state=="amber" and signal_distance>=0 and signal_distance<car.speed*car.speed/(2*car.brake_strength)+0.5
		car.signal_phase=state
	var red: bool = state=="red" or (state=="amber" and not car.yellow_committed)
	if car.route_id=="east_north":
		for other in vehicles():
			if other!=car and other.route_id=="west" and other.position.x>-20 and other.position.x<18:red=true
	if signal_distance>=-0.5 and red:
		limit=_approach(limit,signal_distance,car,"Traffic light / right of way")
		if car.speed<0.1:signals_stopped+=1
	if rule.has("stop") and not car.stops_completed.has("stop"):
		var remaining: float=rule.stop-car.progress-car.half_length
		if remaining>=-0.5:
			limit=_approach(limit,remaining,car,"Stop sign")
			if remaining<0.6 and car.speed<0.1:
				car.stop_clock+=delta
				if car.stop_clock>=1.2:car.stops_completed.stop=true;car.stop_clock=0
	if car.vehicle_id=="bus" and car.route_id=="west" and not car.stops_completed.has("bus"):
		var remaining: float=routes.west.get_closest_offset(Vector3(12,0,19.5))-car.progress
		if remaining>=-0.5:
			limit=_approach(limit,remaining,car,"Bus stop")
			if remaining<0.6 and car.speed<0.1:
				car.stop_clock+=delta
				if car.stop_clock>=3:car.stops_completed.bus=true;car.stop_clock=0
	var forward: Vector3=-car.global_basis.z
	for other in vehicles():
		if other==car:continue
		var separation: Vector3=other.position-car.position
		var ahead := separation.dot(forward)
		var side := absf(separation.dot(car.global_basis.x))
		if ahead>0 and side<1.7 and forward.dot(-other.global_basis.z)>0.3:
			limit=_approach(limit,ahead-car.half_length-other.half_length-2,car,"Following traffic")
	if absf(car.position.z-22)<3:
		for crossing in crossings:
			var ahead: float=(crossing-car.position.x)*forward.x-car.half_length-2
			if ahead<0 or ahead>22:continue
			var occupied := pedestrian_override
			for person in get_tree().get_nodes_in_group("town_pedestrians"):
				if absf(person.global_position.x-crossing)<2.5 and person.global_position.z>16 and person.global_position.z<29:occupied=true
			if occupied:
				limit=_approach(limit,ahead,car,"Pedestrian crossing")
				if car.speed<0.1:pedestrian_stops+=1
	return limit
