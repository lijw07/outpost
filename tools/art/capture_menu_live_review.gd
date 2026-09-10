extends SceneTree
## Godot Movie Maker records real fixed-rate simulation frames and mixed audio.
## Use --write-movie /tmp/menu-movie/frame.png --fixed-fps 60 in a QA profile.
var menu: Control
var frame := 0
var ready_to_record := false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var settings := root.get_node("Settings")
	settings.set_reduce_motion(false)
	settings.set_bus_volume("Master",1.0)
	settings.set_bus_volume("Music",0.6)
	settings.set_bus_volume("SFX",0.85)
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	select_location(0)
	ready_to_record = true
func select_location(index: int) -> void:
	var background: Control = menu.get_node("Background")
	background.show_location(index)
	var simulation: Node2D = background.location.simulation
	simulation.audio.set_enabled(false)
	for tick in (180+index*180):
		simulation.step(1.0/30.0)
	simulation.audio.set_enabled(true)
	print("LIVE CAPTURE: location ",index)
func _process(_delta: float) -> bool:
	if not ready_to_record:
		return false
	frame += 1
	if frame in [240,480]:
		select_location(int(frame/240.0))
	if frame >= 720:
		print("LIVE CAPTURE: 12 seconds, 60 fps, three locations with gameplay audio")
		ready_to_record = false
		call_deferred("finish")
	return false

func finish() -> void:
	menu.queue_free()
	root.get_node("UiAudio").stop_all()
	await process_frame
	await create_timer(0.25).timeout
	quit()
