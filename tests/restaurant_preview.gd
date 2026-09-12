extends SceneTree
var errors: Array[String]=[]
func check(value: bool, label: String) -> void:
	if not value:errors.append(label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for i in 5:await process_frame
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1440,900)
	var scene=load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	scene.set_process(false)
	scene._update_camera()
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/starter_6x6.png")
	check(scene.model.validate_layout(scene.model.objects).is_empty(),"Starter layout must be reachable")
	var barrier=load("res://scripts/restaurant/restaurant_model.gd").new()
	barrier.objects.append({"id":1,"kind":"stove","cell":Vector2i(2,0),"rotation":0})
	for x in 6:
		if x!=2:barrier.place("wall",Vector2i(x,2),0)
	check(not barrier.place("wall",Vector2i(2,2),0).is_empty(),"A complete wall blocking kitchen access is rejected")
	var initial_coins: int=scene.model.coins
	var initial_count: int=scene.model.objects.size()
	check(not scene.model.place("wall",Vector2i(2,5),0).is_empty(),"Entrance placement rejected")
	check(not scene.model.place("wall",Vector2i(13,3),0).is_empty(),"Locked plot placement rejected")
	check(not scene.model.place("stove",Vector2i(1,0),0).is_empty(),"Overlapping furniture rejected")
	check(scene.model.coins==initial_coins and scene.model.objects.size()==initial_count,"Rejected builds are atomic")
	scene.toggle_build()
	scene.selected="dining"
	scene.hover_cell=Vector2i(4,4)
	check(scene._commit_build(),"Add a usable table through build controller")
	check(scene.model.coins==initial_coins-60,"Furniture costs coins")
	scene.selected="erase"
	check(scene._commit_build(),"Reclaim unused table")
	check(scene.model.coins==initial_coins-15,"Reclaim refunds 75 percent")
	scene.selected="window"
	scene.rotation_step=1
	scene.hover_cell=Vector2i(5,1)
	check(scene._commit_build(),"Place rotated window")
	scene.selected="floor"
	scene.hover_cell=Vector2i(3,4)
	check(scene._commit_build(),"Replace floor rather than overlaying it")
	for i in 1800:scene._tick_service(.1)
	scene._expand()
	check(scene.model.width()==7,"Paid expansion unlocks one column")
	scene.selected="dining"
	scene.rotation_step=0
	scene.hover_cell=Vector2i(6,2)
	check(scene._commit_build(),"Build usable furniture on expanded land")
	scene.toggle_build()
	for i in 1800:scene._tick_service(.1)
	check(scene.model.served>=8,"Staff complete repeated customer meal and payment cycles")
	check(scene.model.earned==scene.model.served*28,"Each finished meal pays exactly once")
	var served_before: int=scene.model.served
	var coins_before: int=scene.model.coins
	# Capacity grows through equipment purchases.
	check(scene.model.coins==coins_before,"No automatic upgrade charges")
	for i in 900:scene._tick_service(.1)
	check(scene.model.served>served_before,"Service continues after expansion")
	for i in 1800:scene._tick_service(.1)
	var restored=load("res://scripts/restaurant/restaurant_model.gd").new()
	check(restored.restore(JSON.parse_string(JSON.stringify(scene.model.serialize()))),"Prototype layout restores from serialized data")
	check(restored.land==scene.model.land and restored.coins==scene.model.coins,"Saved layout and economy preserved")
	check(restored.expand() and restored.width()==8,"Second strip adds one more column")
	var guests: int=scene.customers.size()
	scene.opened=false
	for i in 1200:scene._tick_service(.1)
	check(scene.customers.is_empty(),"Closed restaurant lets existing guests leave")
	var after_close: int=scene.model.served
	for i in 200:scene._tick_service(.1)
	check(scene.model.served==after_close,"Closed restaurant stops new arrivals")
	scene.opened=true
	for i in 190:scene._tick_service(.1)
	scene._update_ui()
	scene._update_camera()
	for frame in 8:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/restaurant_service.png")
	scene.toggle_build()
	scene.selected="dining"
	scene._refresh_ghost()
	scene.hover_cell=Vector2i(6,4)
	scene.ghost.position=scene.cell_world(scene.hover_cell)
	scene.ghost_material.albedo_color=Color(.5,1,.72,.52)
	for frame in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/restaurant_build.png")
	scene.toggle_build()
	scene.zoom=145
	scene.camera_target=Vector3(18,26,5)
	scene._update_camera()
	for frame in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/meadow_town.png")
	scene.model.coins=6000
	while scene.model.width()<13:scene._expand()
	check(is_instance_valid(scene.neighboring_business),"Business remains until acquired")
	check(not scene.model.place("wall",Vector2i(14,4),0).is_empty(),"Cannot build on unowned business land")
	var before_buy: int=scene.model.coins
	scene._expand()
	check(scene.model.width()==14 and scene.model.business_owned,"Business acquisition adds one column")
	check(scene.model.coins==before_buy-1350,"Strip and business acquisition charges match")
	check(not is_instance_valid(scene.neighboring_business),"Business mesh and collision removed")
	check(scene.model.place("flowers",Vector2i(13,4),0).is_empty(),"Acquired strip is buildable")
	scene._rebuild_furniture()
	scene.zoom=45
	scene.camera_target=Vector3(20,0,7)
	scene._update_camera()
	scene._update_ui()
	for i in 5:await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/restaurant/review/business_acquired.png")
	var report={"passed":errors.is_empty(),"errors":errors,"served":scene.model.served,"earned":scene.model.earned,"coins":scene.model.coins,"kitchen_level":scene.model.kitchen_level,"expanded_width":scene.model.width(),"closed_guests_drained":guests,"objects":scene.model.objects.size()}
	FileAccess.open("res://output/restaurant/validation/gameplay.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESTAURANT_GAMEPLAY ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
