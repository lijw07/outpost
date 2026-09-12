extends SceneTree

const Model = preload("res://scripts/restaurant/restaurant_model.gd")
var errors: Array[String] = []
var checks := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:errors.append(label)

func click(button: Control) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size / 2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	var model = Model.new()
	model.coins=100000
	check(not model.expand(3) and model.land==Rect2i(0,0,6,6) and model.coins==100000,"Public frontage rejects purchase atomically")
	for edge in [0,2,1]:
		for attempt in 24:
			if not model.expansion_error(edge).is_empty():break
			check(model.expand(edge),"Available private strip can be bought")
	check(model.land==Rect2i(-2,-2,22,8),"Private land expands fully while preserving public frontage")
	for edge in 4:
		var before: int=model.coins
		check(not model.expand(edge) and model.coins==before,"Outer limit does not charge")
	for rotation in 4:
		var seating = Model.new()
		seating.coins=1000
		check(seating.place("dining",Vector2i(3,2),0).is_empty(),"Table purchased independently")
		var table: Dictionary=seating.objects[0]
		check(seating.objects.size()==1 and seating.coins==940 and seating.table_chair(table).is_empty(),"Table does not include a free seat")
		var cell: Vector2i=table.cell+seating.offset(Vector2i.DOWN,rotation)
		check(seating.place("chair",cell,rotation).is_empty(),"Chair purchased independently")
		check(seating.coins==920 and seating.seat(table)==cell,"Adjacent chair faces and serves table")
		check(seating.remove_at(cell) and seating.objects.size()==1 and seating.coins==935,"Reclaim chair preserves table and refunds chair only")
	var starter=Model.new()
	starter.starter()
	var saved: Dictionary=starter.serialize()
	saved.version=2
	saved.objects=saved.objects.filter(func(item):return item.kind!="chair")
	var migrated=Model.new()
	check(migrated.restore(saved),"Old bundled seating save migrates")
	check(migrated.objects.size()==8 and migrated.coins==starter.coins,"Migration preserves purchased chairs and money")
	check(migrated.serialize().version==3,"New saves identify independent seating")
	var roundtrip=Model.new()
	check(roundtrip.restore(migrated.serialize()) and roundtrip.objects.size()==8,"Roundtrip does not duplicate chairs")
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.opened=false
	for frame in 10:await process_frame
	scene.set_process(false)
	for dimensions in [Vector2i(1280,720),Vector2i(3840,1080),Vector2i(900,1200)]:
		scene.viewport.size=dimensions
		for scale in [22.0,86.0,158.0]:
			for target in [Vector3(-999,18,-999),Vector3(999,18,999),Vector3(-999,0,999),Vector3(999,0,-999)]:
				scene.zoom=scale
				scene.camera_target=target
				scene._update_camera()
				for corner in [Vector2.ZERO,Vector2(dimensions.x,0),Vector2(0,dimensions.y),Vector2(dimensions)]:
					var ray: Vector3=scene.camera.project_ray_origin(corner)
					var direction: Vector3=scene.camera.project_ray_normal(corner)
					var ground: Vector3=ray-direction*(ray.y/direction.y)
					check(scene.camera_bounds.has_point(Vector2(ground.x,ground.z)),"Camera ground footprint remains inside map at every zoom and aspect")
	scene._resize_view()
	scene.camera_target=Vector3(7,0,5)
	scene.zoom=28
	scene._update_camera()
	scene.model.coins=1000
	await click(scene.build_button)
	check(scene.build_mode,"Build button opens independent furniture shop")
	await click(scene.hud.find_child("Build_chair",true,false))
	check(scene.selected=="chair","Chair has its own purchase card")
	scene.hover_cell=Vector2i(3,4)
	check(scene._commit_build(),"Chair places through build controller")
	check(scene.model.objects[-1].kind=="chair" and scene.model.coins==980,"Chair placement charges only chair price")
	await click(scene.hud.find_child("Build_dining",true,false))
	check(scene.selected=="dining","Table has its own purchase card")
	scene.hover_cell=Vector2i(3,3)
	check(scene._commit_build(),"Table places beside separately purchased chair")
	check(scene.model.coins==920,"Separate purchases total advertised prices")
	scene._update_ui()
	for frame in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/separate_furniture.png")
	scene.toggle_build()
	scene.opened=true
	for step in 1800:scene._tick_service(0.1)
	check(scene.model.served>3 and scene.model.earned==scene.model.served*28,"Independent seating supports complete meal and payment cycles")
	var report := {"passed":errors.is_empty(),"checks":checks,"errors":errors,"camera_bounds":str(scene.camera_bounds)}
	FileAccess.open("res://output/restaurant/validation/boundaries_seating.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BOUNDARIES_SEATING ",JSON.stringify(report))
	scene.queue_free()
	for frame in 5:await process_frame
	quit(0 if errors.is_empty() else 1)
