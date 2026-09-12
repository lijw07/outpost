extends SceneTree

var errors: Array[String] = []
var checks := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok and text not in errors:errors.append(text)

func run() -> void:
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.opened=false
	for frame in 15:await process_frame
	var traffic=scene.world.get_node("TownTraffic")
	var car=traffic.vehicles()[0]
	traffic.clock=18
	car.progress=traffic.rules.east.signal-car.half_length-0.3
	car.position=car.route.sample_baked(car.progress,true)
	check(traffic.speed_limit(car,0.02)<0.1,"Red signal stops before the line")
	traffic.clock=2
	check(traffic.speed_limit(car,0.02)>0,"Green signal releases clear lane")
	car.progress=car.route.get_closest_offset(Vector3(0,0,24))-car.half_length-2.3
	car.position=car.route.sample_baked(car.progress,true)
	traffic.pedestrian_override=true
	car.progress=car.route.get_closest_offset(Vector3(5,0,24))-car.half_length-2.3
	car.position=car.route.sample_baked(car.progress,true)
	check(traffic.speed_limit(car,0.02)<0.1,"Pedestrian crossing takes priority on green")
	traffic.pedestrian_override=false
	check(traffic.speed_limit(car,0.02)>0,"Clear crossing releases vehicle")
	car.position=Vector3(5,0,23.5)
	check(not traffic.crossing_clear(Vector3(5,0,25)),"Pedestrians wait while a vehicle clears the crossing")
	car.position=Vector3(-30,0,23.5)
	check(traffic.crossing_clear(Vector3(5,0,25)),"Pedestrians cross after the vehicle clears")
	var branch=traffic.vehicles().filter(func(item):return item.route_id=="south_east")[0]
	branch.progress=traffic.rules.south_east.stop-branch.half_length-0.3
	branch.position=branch.route.sample_baked(branch.progress,true)
	branch.speed=0
	check(traffic.speed_limit(branch,0.1)<0.1,"Stop sign requires complete stop")
	for step in 13:traffic.speed_limit(branch,0.1)
	check(branch.stops_completed.has("stop"),"Stop sign releases after dwell")
	var bus=traffic.vehicles().filter(func(item):return item.vehicle_id=="bus")[0]
	bus.progress=bus.route.get_closest_offset(Vector3(12,0,20))-0.3
	bus.position=bus.route.sample_baked(bus.progress,true)
	bus.speed=0
	check(traffic.speed_limit(bus,0.1)<0.1,"Bus stops at its stop")
	for step in 31:traffic.speed_limit(bus,0.1)
	check(bus.stops_completed.has("bus"),"Bus departs after boarding dwell")
	for vehicle in traffic.vehicles():vehicle.free()
	traffic.spawn_vehicle("sedan","east",20)
	traffic.spawn_vehicle("van","west",20)
	traffic.spawn_vehicle("ambulance","south_east",20)
	traffic.spawn_vehicle("bus","west",70)
	traffic.clock=0
	Engine.time_scale=4
	var distance := 0.0
	var saw_turn := false
	var saw_stop := false
	var previous_front := {}
	for frame in 1200:
		await physics_frame
		for vehicle in traffic.vehicles():
			var id: int=vehicle.get_instance_id()
			var line: float=traffic.rules[vehicle.route_id].signal
			var front: float=vehicle.progress+vehicle.half_length
			if previous_front.has(id) and previous_front[id]<line and front>=line:
				var state: String=traffic.phase(traffic.rules[vehicle.route_id].axis)
				check(state=="green" or (state=="amber" and vehicle.yellow_committed),"No red entry; amber entry requires an existing safe-clear decision")
			previous_front[id]=front
			check(vehicle.speed<=vehicle.maximum_speed+0.01,"Vehicles stay below road speed limit")
			check(vehicle.position.distance_to(vehicle.route.sample_baked(vehicle.progress,true))<0.1,"Vehicles stay on their lane route")
			distance=maxf(distance,vehicle.distance_driven)
			if vehicle.route_id in ["east_north","south_east"] and absf(vehicle.global_basis.z.x)>0.25 and absf(vehicle.global_basis.z.z)>0.25:saw_turn=true
			if vehicle.waiting_reason!="" and vehicle.speed<0.1:saw_stop=true
	Engine.time_scale=1
	check(distance>45,"Vehicles travel through the actual world")
	check(saw_turn,"Traffic takes curved junction routes")
	check(saw_stop,"Traffic visibly waits during live simulation")
	check(traffic.spawned>8,"Traffic continues arriving automatically")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1536,1024)
	scene._resize_view()
	scene.camera_target=Vector3(22,0,22)
	scene.zoom=150
	scene._update_camera()
	for frame in 6:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/reference_town.png")
	scene.camera_target=Vector3(-26,0,-26)
	scene.zoom=42
	scene._update_camera()
	for frame in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/mall_plaza.png")
	var remaining := []
	for vehicle in traffic.vehicles():remaining.append({"type":vehicle.vehicle_id,"route":vehicle.route_id,"distance":vehicle.distance_driven,"speed":vehicle.speed,"waiting":vehicle.waiting_reason})
	var report := {"passed":errors.is_empty(),"checks":checks,"errors":errors,"longest_vehicle_travel":distance,"spawned":traffic.spawned,"signal_wait_frames":traffic.signals_stopped,"pedestrian_wait_frames":traffic.pedestrian_stops,"remaining_traffic":remaining}
	FileAccess.open("res://output/restaurant/validation/town_traffic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TOWN_TRAFFIC ",JSON.stringify(report))
	scene.queue_free()
	for frame in 5:await process_frame
	quit(0 if errors.is_empty() else 1)
