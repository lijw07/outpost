extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	if "--in-game" in OS.get_cmdline_user_args():
		var game: Node2D = load("res://scenes/environment/meadow_playground.tscn").instantiate()
		root.add_child(game)
		current_scene=game
		await process_frame
		for plant in get_nodes_in_group("meadow_pickables"): plant.harvest()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/meadow/harvest_in_game.png")
		game.free()
		quit()
		return
	root.size=Vector2i(1200,700)
	root.content_scale_size=Vector2i(1200,700)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	var stage := Node2D.new()
	root.add_child(stage)
	var bg := Polygon2D.new()
	bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1200,0),Vector2(1200,700),Vector2(0,700)])
	bg.color=Color("263a2c")
	stage.add_child(bg)
	var names := ["flowers_white","flowers_yellow","flowers_purple","clover","mushrooms","shrub_flowering"]
	for i in range(6):
		var base := Vector2((i%3)*400, floori(i/3.0)*340)
		var label := Label.new()
		label.text = names[i].replace("_"," ")+"  /  before → picked"
		label.position=base+Vector2(12,16)
		stage.add_child(label)
		for j in range(2):
			var art := Sprite2D.new()
			art.texture=load("res://assets/environment/meadow/"+("props/"+names[i] if j==0 else "harvested/"+names[i]+"_picked")+".png")
			art.centered=false
			art.offset=Vector2(-art.texture.get_width()/2.0,-art.texture.get_height()+4)
			art.position=base+Vector2(100+j*200,300)
			art.scale=Vector2(2,2)
			art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			stage.add_child(art)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/meadow/harvest_comparison.png")
	stage.free()
	quit()
