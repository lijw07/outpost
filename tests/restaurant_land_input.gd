extends SceneTree
var errors: Array=[]
var scene
func _initialize() -> void:call_deferred("_run")
func check(value: bool,label: String) -> void:
	if not value:errors.append(label)
func hover(point: Vector2) -> void:
	Input.warp_mouse(point)
	var event:=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	Input.parse_input_event(event)
	for frame in 4:await process_frame
func click(point: Vector2) -> void:
	await hover(point)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
func aim(cell: Vector2i) -> Vector2:
	return scene.camera.unproject_position(scene.cell_world(cell))
func capture(name: String) -> void:
	for i in 4:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/"+name+".png")
func _run() -> void:
	scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.opened=false
	for i in 8:await process_frame
	var left: Vector2=scene.camera.unproject_position(Vector3(0,0,12))
	var right: Vector2=scene.camera.unproject_position(Vector3(12,0,12))
	check(absf(left.y-right.y)<.01,"Restaurant frontage remains horizontal")
	check(absf(scene.camera.rotation.y)<.001,"No sideways camera rotation")
	await capture("straight_restaurant")
	scene.camera_target=Vector3(20,0,6)
	scene.zoom=48
	for i in 4:await process_frame
	scene.model.coins=100
	await hover(aim(Vector2i(6,3)))
	check(scene.plot_hover==1 and scene.plot_hover_bounds==Rect2i(6,0,1,6),"Right hover previews exactly one 1x6 column")
	check(scene.model.land==Rect2i(0,0,6,6) and scene.model.coins==100,"Hover never buys land")
	await capture("strip_insufficient")
	await click(aim(Vector2i(6,3)))
	check(scene.model.width()==6 and scene.model.coins==100,"Unaffordable strip does not charge")
	scene.model.coins=5000
	await click(aim(Vector2i(9,3)))
	check(scene.model.width()==6 and scene.model.coins==5000,"Non-adjacent land cannot be bought")
	await hover(aim(Vector2i(6,3)))
	await capture("one_column_preview")
	await click(aim(Vector2i(6,3)))
	check(scene.model.land==Rect2i(0,0,7,6) and scene.model.coins==4850,"Right click adds exactly one column for 150 coins")
	await click(aim(Vector2i(6,3)))
	check(scene.model.width()==7 and scene.model.coins==4850,"Owned land cannot be bought twice")
	await hover(aim(Vector2i(3,6)))
	check(scene.plot_hover_bounds==Rect2i(0,6,7,1),"A wider restaurant previews one 7x1 row")
	await capture("one_row_preview")
	await click(aim(Vector2i(3,6)))
	check(scene.model.land==Rect2i(0,0,7,6) and scene.model.coins==4850,"Front sidewalk blocks purchase without charging")
	await hover(aim(Vector2i(-1,3)))
	check(scene.plot_hover_bounds==Rect2i(-1,0,1,6),"Left edge previews a 1x6 strip")
	await capture("left_column_preview")
	var first_position: Vector3=scene.furniture_nodes[1].position
	await click(aim(Vector2i(-1,3)))
	check(scene.model.land==Rect2i(-1,0,8,6) and scene.model.coins==4700,"Left expansion adds negative-coordinate land")
	check(scene.furniture_nodes[1].position==first_position,"Left expansion preserves furniture positions")
	await click(aim(Vector2i(3,-1)))
	check(scene.model.land==Rect2i(-1,-1,8,7) and scene.model.coins==4500,"Back expansion adds one row")
	check(scene.model.placement_error("flowers",Vector2i(-1,-1),0).is_empty(),"New left/back corner is buildable")
	var ground: GridMap=scene.world.get_node("MeadowTown/MeadowBlocks")
	for x in range(-1,7):
		for z in range(-1,6):check(ground.get_cell_item(Vector3i(x,0,z))==-1,"Owned floor replaces ground without duplicate blocks")
	var model_script=load("res://scripts/restaurant/restaurant_model.gd")
	var restored=model_script.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(scene.model.serialize()))) and restored.land==scene.model.land,"Expanded origins and dimensions survive save roundtrip")
	var legacy=scene.model.serialize()
	legacy.version=1
	legacy.expansion=3
	check(restored.restore(legacy) and restored.land==Rect2i(0,0,20,6) and restored.business_owned,"Legacy purchased plots remain owned")
	for edge in [0,2,3]:
		while scene.model.expansion_error(edge).is_empty():scene._expand(edge)
		var before: int=scene.model.coins
		scene._expand(edge)
		check(scene.model.coins==before,"Public paths cannot be bought")
	scene.model.coins=6000
	while scene.model.land.end.x<13:scene._expand(1)
	check(is_instance_valid(scene.neighboring_business),"Business remains until boundary reaches its land")
	var cost: int=scene.model.expansion_cost(1)
	var before: int=scene.model.coins
	scene._expand(1)
	check(scene.model.land.end.x==14 and scene.model.business_owned,"Acquisition still adds only one column")
	check(scene.model.coins==before-cost and cost==scene.model.height()*25+1200,"Business surcharge included in advertised strip price")
	check(not is_instance_valid(scene.neighboring_business),"Acquisition removes building and collision")
	check(not scene.model.owned(Vector2i(14,4)),"Unbought neighboring columns stay locked after acquisition")
	for button in scene.hud.find_children("*","Button",true,false):
		check(not "upgrade" in button.text.to_lower() and not "buy garden" in button.text.to_lower(),"No upgrade or land-purchase UI")
	var button: Control=scene.build_button
	for i in 3:await RenderingServer.frame_post_draw
	var remaining: int=scene.model.coins
	await click(button.get_global_transform_with_canvas()*(button.size/2))
	check(scene.build_mode and scene.model.coins==remaining,"Equipment shop control cannot purchase underlying land")
	scene.toggle_build()
	scene.camera_target=Vector3(12,0,-16)
	scene.zoom=32
	await hover(Vector2(5,100))
	await capture("meadow_park")
	scene.camera_target=Vector3(18,26,5)
	scene.zoom=145
	await capture("lush_meadow_town")
	var district: Node3D=scene.world.get_node("MeadowTown")
	check(district.get_node("MeadowUnderstory").get_meta("prop_count")>1500,"Dense meadow understory is present")
	check(district.has_node("MeadowCommonsPark"),"Commons park is integrated")
	var report:={"passed":errors.is_empty(),"errors":errors,"final_land":str(scene.model.land),"coins":scene.model.coins}
	FileAccess.open("res://output/restaurant/validation/land_input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LAND_INPUT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
