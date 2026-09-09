extends SceneTree
## Load every authored scene, including standalone panels and art review scenes.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		push_error("Run scene checks through tests/run_ui_checks.py --all.")
		quit(2)
		return
	root.get_node("Settings").set_reduce_motion(true)
	root.get_node("Settings").set_bus_volume("Master", 0.0)
	var paths: Array[String] = []
	collect("res://scenes", paths)
	for path in paths:
		var scene: PackedScene = load(path)
		assert(scene != null and scene.can_instantiate(), path)
		var instance := scene.instantiate()
		root.add_child(instance)
		current_scene = instance
		# Loading transitions are covered by ui_regression; keep this instance for inspection.
		if path == "res://scenes/ui/loading_screen.tscn":
			instance.set_process(false)
		for frame_index in 3:
			await process_frame
		paused = false
		instance.queue_free()
		current_scene = null
		await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.15).timeout
	print("SCENE CHECK: ", paths.size(), " scenes loaded and freed")
	quit()

func collect(directory: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tscn"):
			paths.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		collect(directory.path_join(child), paths)
