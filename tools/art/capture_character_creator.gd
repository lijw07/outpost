extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("Settings").reset_bindings()
	root.get_node("Settings").set_reduce_motion(true)
	for save: Dictionary in root.get_node("SaveManager").list_saves():
		root.get_node("SaveManager").delete_save(save.id)
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._start_game(false)
	for frame in 4:
		await process_frame
	menu._save_select_panel._show_name_entry()
	var creator: Control = menu._save_select_panel._creator
	creator.name_field.text = "ALEX"
	creator.profile.sex = "female"
	creator.profile.hair = "bob"
	creator.profile.hair_color = "ginger"
	creator.profile.top = "jacket"
	creator._refresh()
	DirAccess.make_dir_recursive_absolute("user://modular-review")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://modular-review/creator.png")
	creator._select_tab(1)
	await process_frame
	await RenderingServer.frame_post_draw
	var clothes: ScrollContainer = creator._groups[1]
	var last_option: Control = clothes.get_child(0).get_child(-1)
	if last_option.get_global_rect().end.y > clothes.get_global_rect().end.y+1:
		push_error("CREATOR CAPTURE: shoe color is clipped")
		quit(1)
		return
	root.get_texture().get_image().save_png("user://modular-review/clothing.png")
	var saved: Dictionary = root.get_node("SaveManager").create_save("ALEX",creator.profile)
	menu.queue_free()
	await process_frame
	root.get_node("GameSession").save_id = saved.id
	root.get_node("GameSession").character_name = saved.character_name
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	game.renderer.move_player(Vector2.ZERO,1.0/60.0,game.renderer.player_actor.position+Vector2(0,50))
	game.renderer.sync(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://modular-review/in_game.png")
	game.queue_free()
	await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("CREATOR CAPTURE: ",OS.get_user_data_dir()+"/modular-review")
	quit()
