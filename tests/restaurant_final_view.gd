extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 8:await process_frame
	scene.set_process(false)
	for i in 220:scene._tick_service(.1)
	scene._update_ui()
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/starter_serving.png")
	scene.camera_target=Vector3(18,26,5)
	scene.zoom=145
	scene._update_camera()
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/meadow_town.png")
	scene.camera_target=Vector3(12,0,-16)
	scene.zoom=32
	scene._update_camera()
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/meadow_park_final.png")
	var restored=load("res://scripts/restaurant/restaurant_model.gd").new()
	var data=scene.model.serialize()
	data.version=1
	data.expansion=3
	assert(restored.restore(data) and restored.width()==20)
	print("FINAL_MEADOW_VIEW_OK")
	quit()
