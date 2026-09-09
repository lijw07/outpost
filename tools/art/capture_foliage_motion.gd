extends SceneTree
var frames: Array[Image] = []
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	root.size = Vector2i(960,400)
	root.content_scale_size = Vector2i(960,400)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var stage := Node2D.new()
	root.add_child(stage)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,400),Vector2(0,400)])
	background.color = Color("263a2c")
	stage.add_child(background)
	var names := ["grass_dense","grass_seedheads","flowers_white","shrub_flowering"]
	for i in range(4):
		var plant := AnimatedSprite2D.new()
		plant.sprite_frames = load("res://assets/environment/meadow/animations/"+names[i]+".tres")
		plant.centered = false
		var size := plant.sprite_frames.get_frame_texture("wind",0).get_size()
		plant.offset = Vector2(-size.x/2,-size.y+4)
		plant.position = Vector2(120+i*240,340)
		plant.scale = Vector2(3,3)
		plant.set_script(load("res://scripts/environment/meadow_plant.gd"))
		stage.add_child(plant)
	var folder := "res://output/meadow/motion_before" if "--before" in OS.get_cmdline_user_args() else "res://output/meadow/motion_after"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in range(90):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/frame_%03d.png"%i)
	stage.free()
	quit()
