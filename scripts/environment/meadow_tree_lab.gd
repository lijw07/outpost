extends Node2D
var wood := 0
var _capturing := false
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1920,1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for tree in get_tree().get_nodes_in_group("meadow_trees"):
		if is_ancestor_of(tree): tree.wood_collected.connect(func(amount: int) -> void: wood += amount)
	if "--tree-capture" in OS.get_cmdline_user_args():
		_capturing = true
		DirAccess.make_dir_recursive_absolute("res://output/meadow/trees_physics/frames")
		_capture()
func _process(_delta: float) -> void:
	var states: Array[String] = []
	for tree in get_tree().get_nodes_in_group("meadow_trees"):
		if is_ancestor_of(tree): states.append("%s: %s"%[tree.species,tree.state])
	$HUD/Status.text = "WOOD: %d    %s"%[wood,"    ".join(states)]
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := get_global_mouse_position()
		for tree in get_tree().get_nodes_in_group("meadow_trees"):
			if not is_ancestor_of(tree): continue
			var bounds := Rect2(tree.standing.offset,tree.standing.texture.get_size())
			if bounds.grow(20).has_point(tree.to_local(at)): tree.hit(at)
	if event.is_action_pressed("interact"):
		for tree in get_tree().get_nodes_in_group("meadow_trees"):
			if is_ancestor_of(tree): tree.collect_wood(get_global_mouse_position(),180.0)
func _capture() -> void:
	var single := "--tree-one-capture" in OS.get_cmdline_user_args()
	for frame in range(420 if single else 300):
		if frame in ([15,70,125] if single else [15,35,55]):
			var i := 0
			for tree in get_tree().get_nodes_in_group("meadow_trees"):
				if not is_ancestor_of(tree): continue
				tree.hit(tree.global_position+Vector2(-100 if i%2==0 else 100,0))
				i += 1
				if single: break
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if frame%2==0:
			get_viewport().get_texture().get_image().save_png("res://output/meadow/trees_physics/frames/frame_%03d.png"%frame)
	get_tree().quit()
