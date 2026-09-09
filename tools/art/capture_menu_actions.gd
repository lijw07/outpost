extends SceneTree
## Enlarged, deterministic action poses for visual QA, not a playable scene.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name()=="headless":
		push_error("Use a rendered disposable review profile.")
		quit(2)
		return
	root.get_node("Settings").set_reduce_motion(true)
	var view := SubViewport.new()
	view.size = Vector2i(1200,960)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(1200,960)
	background.color = Color("35453a")
	view.add_child(background)
	var font: Font = load("res://assets/ui/font/outpost_pixel.ttf")
	for row in 4:
		var label := Label.new()
		label.text = ["WALK / CONTACT - PASS - OPPOSITE CONTACT - PASS","CARRY / TWO-HANDED TIMBER GRIP","BUILD / REST - RAISE - CONTACT - RECOVER","ZOMBIE / REEL - BUCKLE - FALL - REST"][row]
		label.position = Vector2(24,12+row*240)
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",20)
		view.add_child(label)
		var baseline := ColorRect.new()
		baseline.position = Vector2(24,216+row*240)
		baseline.size = Vector2(1152,2)
		baseline.color = Color("65785b")
		view.add_child(baseline)
		for column in 4:
			var actor: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
			actor.setup(row==3,1 if row==2 else 0)
			actor.position = Vector2(140+column*280,216+row*240)
			actor.scale = Vector2(2,2)
			actor.aim = Vector2.DOWN if row<2 else Vector2.RIGHT
			actor.velocity = Vector2(80,0) if row<2 else Vector2.ZERO
			actor.phase = column*0.25+0.001
			actor.action = "run" if row<2 else "build" if row==2 else "idle"
			actor.carrying = 3 if row in [1,2] else 0
			actor.build_clock = column*0.2+0.001
			if row==3:
				actor.health = 0
				actor.death_age = column*0.16+0.001
			view.add_child(actor)
			actor._update_body()
	for frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("user://menu_actions.png")
	view.queue_free()
	await process_frame
	print("ACTION CAPTURE: sixteen registered poses saved.")
	quit()
