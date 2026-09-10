extends SceneTree
const World := preload("res://scripts/pixel_world/world.gd")
const Art := preload("res://scripts/pixel_world/art.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	await physics_frame
	var world: Node3D = game.renderer
	check(world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,"orthographic world camera")
	check(world.player is CharacterBody3D,"player uses actual 3D collision movement")
	check(world.actors.size() >= 4 and game.simulation.survivors.size() == 4,"four survivors preserved")
	for sheet in ["characters","clothing"]:
		for index in 16:
			check(Art.frame(sheet,index).get_height() == 24,"every character uses a 24px height")
	var axis_x: Vector2 = world.camera.unproject_position(Vector3.RIGHT)-world.camera.unproject_position(Vector3.ZERO)
	var axis_z: Vector2 = world.camera.unproject_position(Vector3.BACK*World.DEPTH)-world.camera.unproject_position(Vector3.ZERO)
	check(absf(axis_x.length()-axis_z.length()) < 0.01,"3D tile axes project to equal screen lengths")
	var wall: Node2D = game.simulation.structures[0]
	var bounds: Rect2 = wall.collision_bounds()
	world.player.position = World.point(Vector2(bounds.get_center().x,bounds.end.y+40))
	for frame in 45:
		await physics_frame
		world.move_player(Vector2.UP,1.0/60.0,Vector2.ZERO)
	check(World.flat(world.player.position).y > bounds.end.y,"player cannot walk through fence")
	var tree: Node3D = world.harvestables[0]
	var tree_point := World.flat(tree.position)
	check(not game.simulation._line_of_fire(tree_point-Vector2(50,0),tree_point+Vector2(50,0)),"standing tree blocks AI line of sight")
	world.player.position = tree.position+Vector3(0.9,0,0)
	for hit in 3:
		check(world.interact(true),"nearby tree accepts axe strike")
	check(not world.interact(),"falling wood cannot be collected early")
	check(game.simulation._line_of_fire(tree_point-Vector2(50,0),tree_point+Vector2(50,0)),"felled tree leaves no invisible AI obstacle")
	world.sync(0.8)
	check(world.interact(),"settled wood can be collected")
	check(game.collected.wood == 3,"wood collection updates HUD inventory")
	var start: Vector3 = world.player.position
	game._pause_game()
	Input.action_press("move_right")
	await create_timer(0.1,true).timeout
	Input.action_release("move_right")
	check(world.player.position == start,"pause freezes the 3D world")
	game.get_node("%PauseMenu").resume()
	game.queue_free()
	await process_frame
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("PIXEL WORLD CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
