extends SceneTree

var errors: Array[String] = []
var samples := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func walk(scene: Node, from: Vector2, to: Vector2) -> void:
	var space: PhysicsDirectSpaceState3D = scene.world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .22
	capsule.height = 1.35
	var count := ceili(from.distance_to(to)/.5)
	for i in count+1:
		var p := from.lerp(to,float(i)/maxi(1,count))
		var foot := Vector3(p.x,0,p.y)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform.origin = foot+Vector3.UP*.85
		var hit := space.intersect_shape(query,1)
		check(hit.is_empty(),"Blocked pavement at %s: %s" % [p,hit[0].collider.get_path() if not hit.is_empty() else ""])
		check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.2,foot-Vector3.UP*.2)).is_empty(),"Missing pavement at "+str(p))
		samples += 1

func capture(scene: Node, id: String) -> void:
	for frame in 6:
		await RenderingServer.frame_post_draw
	scene.viewport.get_texture().get_image().save_png("res://output/streetscape/review/"+id+".png")

func _run() -> void:
	var scene = load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in 8:
		await physics_frame
	scene.set_process(false)
	var district: Node3D = scene.world.get_node("MeadowTown")
	var before: Node3D = load("res://output/streetscape/before/placement_pass.tscn").instantiate()
	for child in before.get_children():
		if child.get_meta("district_scenery",false):
			var now := district.get_node_or_null(NodePath(child.name)) as Node3D
			var expected: Transform3D = child.transform
			check(now != null and now.transform.is_equal_approx(expected),"Building moved: "+child.name)
	before.free()
	for route in [[Vector2(-45,16.9),Vector2(88,16.9)],[Vector2(-45,27.5),Vector2(88,27.5)],[Vector2(-13.1,-25),Vector2(-13.1,16.9)],[Vector2(-3.0,-25),Vector2(-3.0,-6.5)],[Vector2(-15,16.9),Vector2(-15,27.5)],[Vector2(-3,16.9),Vector2(-3,27.5)],[Vector2(47,16.9),Vector2(47,55)],[Vector2(83,16.9),Vector2(83,36)]]:
		walk(scene,route[0],route[1])
	if DisplayServer.get_name() != "headless":
		await capture(scene,"neighborhood")
		scene.camera_target = Vector3(13,0,17)
		scene.zoom = 55
		scene._update_camera()
		await capture(scene,"main_street")
		scene.camera_target = Vector3(68,0,35)
		scene.zoom = 48
		scene._update_camera()
		await capture(scene,"waterfront_connections")
		var event := InputEventKey.new()
		event.keycode = KEY_HOME
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		check(scene.zoom == 28 and scene.camera_target == Vector3(8,0,7),"Home no longer returns to the restaurant")
	var report := {"passed":errors.is_empty(),"errors":errors,"walking_samples":samples}
	FileAccess.open("res://output/streetscape/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STREETSCAPE_QA ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
