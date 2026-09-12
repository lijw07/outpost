extends SceneTree
var errors: Array[String]=[]
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value:errors.append(label)
func click_at(point: Vector2) -> void:
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	Input.parse_input_event(motion)
	for frame in 3:await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		event.global_position=point
		Input.parse_input_event(event)
		await process_frame
func click_control(button: Control) -> void:
	for frame in 3:await RenderingServer.frame_post_draw
	await click_at(button.get_global_transform_with_canvas()*(button.size/2))
func _run() -> void:
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.opened=false
	for i in 8:await process_frame
	await click_control(scene.build_button)
	check(scene.build_mode,"Build button accepts actual mouse input")
	await click_control(scene.hud.find_child("Build_wall",true,false))
	check(scene.selected=="wall","Build palette selection accepts mouse input")
	var before: int=scene.model.objects.size()
	var target: Vector2=scene.camera.unproject_position(scene.cell_world(Vector2i(4,4)))
	await click_at(target)
	check(scene.model.objects.size()==before+1,"Camera ray maps mouse click to correct build tile")
	check(scene.model.objects[-1].cell==Vector2i(4,4),"Placed object is at the clicked tile")
	var event := InputEventKey.new()
	event.keycode=KEY_R
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	check(scene.rotation_step==1,"R rotates the placement preview")
	event.pressed=false
	Input.parse_input_event(event)
	var invalid: Vector2=scene.camera.unproject_position(scene.cell_world(Vector2i(4,2)))
	await click_at(invalid)
	check(scene.model.objects.size()==before+1,"Invalid click does not spend money or place overlaps")
	check(scene.ghost_material.albedo_color.r>.8 and scene.ghost_material.albedo_color.g<.5,"Invalid ghost is visibly red")
	for button in scene.hud.find_children("*","Button",true,false):
		if button.text=="Plants & garden":await click_control(button)
	await click_control(scene.hud.find_child("Build_grass",true,false))
	check(scene.selected=="grass","Nature shop tab exposes purchasable grass")
	await click_at(scene.camera.unproject_position(scene.cell_world(Vector2i(3,0))))
	check(scene.model.objects[-1].kind=="grass","Landscaping is bought and placed through the actual UI")
	await click_control(scene.build_button)
	check(not scene.build_mode,"Finish building resumes service")
	var camera_before: Vector3=scene.camera_target
	var chef_before: Vector3=scene.chefs[0].node.position
	Input.action_press("move_right")
	for i in 12:await process_frame
	Input.action_release("move_right")
	check(scene.camera_target.distance_to(camera_before)>.1,"WASD pans the management camera")
	check(scene.chefs[0].node.position==chef_before,"Camera keys do not control a character")
	var restore=load("res://scripts/restaurant/restaurant_model.gd").new()
	var saved=scene.model.serialize()
	var path := "res://output/restaurant/validation/save_roundtrip.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(saved))
	check(restore.restore(JSON.parse_string(FileAccess.get_file_as_string(path))),"Save data survives a file round trip")
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/mouse_build_verified.png")
	var report={"passed":errors.is_empty(),"errors":errors,"viewport":str(scene.viewport.size),"ui_scale":str(scene.hud.scale),"objects":scene.model.objects.size()}
	FileAccess.open("res://output/restaurant/validation/input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESTAURANT_INPUT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
