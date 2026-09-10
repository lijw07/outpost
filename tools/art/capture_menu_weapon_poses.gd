extends SceneTree
## Inspect resting holds, overhead melee strikes, and firearm recoil in four directions.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless" or not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var view := SubViewport.new()
	view.size = Vector2i(1400,920)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	root.title = "Outpost - Attack Animation Review"
	root.size = view.size
	var preview := TextureRect.new()
	preview.texture = view.get_texture()
	preview.size = view.size
	root.add_child(preview)
	var background := ColorRect.new()
	background.size = view.size
	background.color = Color("35453a")
	view.add_child(background)
	var actors: Array[Node2D] = []
	for column in 7:
		var title := Label.new()
		title.text = ["UPRIGHT BAT","UPRIGHT KNIFE","OVERHEAD BAT","OVERHEAD KNIFE","OVERHEAD AXE","RIFLE","ZOMBIE STRIKE"][column]
		title.position = Vector2(column*200+14,12)
		title.add_theme_font_size_override("font_size",16)
		view.add_child(title)
		for row in 4:
			var actor: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
			actor.setup(column == 6,0)
			view.add_child(actor)
			if column < 6:
				actor.equip(1 if column == 5 else 0,column%5,[0,2,0,2,6,1][column])
			actor.position = Vector2(column*200+90,row*220+200)
			actor.previous_position = actor.position
			actor.scale = Vector2(1.7,1.7)
			actor.aim = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][row]
			actors.append(actor)
	var motion := "--motion" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("user://rig_pose_frames")
	for frame in (180 if motion else 1):
		var time := frame/60.0 if motion else 0.3
		for index in actors.size():
			var actor: Node2D = actors[index]
			var column := int(index/4.0)
			var row := index%4
			actor.aim = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][row]
			actor.action = "run" if column < 2 else "melee" if column < 5 else "shoot" if column == 5 else "attack"
			actor.melee_clock = fmod(time,float(actor.melee_weapon.cycle)) if actor.action == "melee" else 0.0
			actor.attack_clock = fmod(time,actor.ZOMBIE_ATTACK_CYCLE)
			actor.shot_age = fmod(time,0.4) if actor.action == "shoot" else 10.0
			actor.flash = 0.04 if actor.action == "shoot" and actor.shot_age < 0.06 else 0.0
			actor.animate(1.0/60.0,actor.aim*1.0 if column < 2 else Vector2.ZERO)
		for wait_frame in 2:
			await process_frame
			await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("user://rig_pose_frames/frame_%04d.png" % frame)
	view.queue_free()
	await process_frame
	print("WEAPON POSES: four directions, upright holds, overhead strikes, recoil and zombie contact")
	quit()
