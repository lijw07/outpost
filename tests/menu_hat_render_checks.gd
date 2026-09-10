extends SceneTree
## Verify the base-sprite crown is clipped beneath hats without erasing other pixels.
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func capture(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name() == "headless" or not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var view := SubViewport.new()
	view.size = Vector2i(160,160)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var actor: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
	view.add_child(actor)
	actor.setup(false,0)
	actor.equip(1,2,0)
	actor.position = Vector2(80,135)
	actor.previous_position = actor.position
	for action in ["run","carry","build","shoot"]:
		for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
			for pose in 4:
				actor.action = action
				actor.aim = direction
				actor.phase = pose*0.25
				actor.armed_phase = actor.phase
				actor.carrying = 3 if action == "carry" else 0
				actor.build_clock = pose*0.2
				actor.velocity = direction*60
				actor.shot_age = 10
				actor._update_body()
				actor.wardrobe.hide()
				actor.wardrobe.held.hide()
				actor.hand_layer.hide()
				actor.body.material.set_shader_parameter("cover_hair",false)
				var original := await capture(view)
				actor.body.material.set_shader_parameter("cover_hair",true)
				var covered := await capture(view)
				var removed := 0
				var outside := 0
				var head: Vector2 = actor.position+actor.head_socket
				var crown := Rect2(head-Vector2(actor.head_width*0.72,actor.head_width*0.9),Vector2(actor.head_width*1.44,actor.head_width*1.12)).grow(1)
				for y in 160:
					for x in 160:
						if original.get_pixel(x,y).a-covered.get_pixel(x,y).a > 0.5:
							removed += 1
							if not crown.has_point(Vector2(x,y)):
								outside += 1
				checks += 1
				if removed == 0 or outside > 0:
					failures += 1
					push_error("FAIL: hat crown mask "+action+" facing "+str(direction)+" pose "+str(pose))
	view.queue_free()
	await process_frame
	print("HAT RENDER CHECK: ",checks," frames, ",failures," failed")
	quit(1 if failures else 0)
