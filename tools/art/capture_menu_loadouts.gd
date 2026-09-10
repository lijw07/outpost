extends SceneTree
## Render enlarged outfit/action combinations in a disposable review profile.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.get_node("Settings").set_reduce_motion(true)
	var view := SubViewport.new()
	view.size = Vector2i(1400,1050)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(1400,1050)
	background.color = Color("35453a")
	view.add_child(background)
	for column in 5:
		var label := Label.new()
		label.text = ["CIVILIAN","MILITARY","POLICE","STREETWEAR","GHILLIE"][column]
		label.position = Vector2(25+column*280,15)
		label.add_theme_font_size_override("font_size",22)
		view.add_child(label)
		for row in 4:
			var actor: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
			actor.setup(false,0)
			actor.equip(column,column,column+row*3)
			if column == 3 or (column == 0 and row > 1):
				actor.wardrobe.outfit = actor.wardrobe.outfit.duplicate()
				actor.wardrobe.outfit.headgear = -1
			actor.position = Vector2(125+column*280,230+row*255)
			actor.scale = Vector2(2.5,2.5)
			actor.aim = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][row]
			actor.action = ["idle","carry","shoot","melee"][row]
			actor.carrying = 3 if row == 1 else 0
			actor.melee_clock = 0.34
			view.add_child(actor)
			actor._update_body()
	if "--motion" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("user://attachment_frames")
		for frame in 180:
			for child in view.get_children():
				if child.get_script() != load("res://scripts/ui/menu_demo_actor.gd"):
					continue
				var row := int((child.position.y-230)/255.0)
				child.aim = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][row]
				child.action = ["run","carry","build","melee"][row]
				child.carrying = 3 if row == 1 else 0
				child.build_clock = fmod(frame/60.0,0.8)
				child.melee_clock = fmod(frame/60.0,float(child.melee_weapon.cycle))
				child.animate(1.0/60.0,child.aim*1.3 if row < 2 else Vector2.ZERO)
			await process_frame
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("user://attachment_frames/frame_%04d.png" % frame)
	for frame in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("user://menu_loadouts.png")
	view.queue_free()
	await process_frame
	print("LOADOUT CAPTURE: twenty outfit/action combinations saved.")
	quit()
