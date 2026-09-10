extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var game: Node2D = load("res://scenes/environment/legacy_meadow_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var tree: Node2D = game.get_node("MeadowTrees/Oak")
	var marker: Node2D = game.get_node("MeadowDressing/WalkMarker")
	assert(get_nodes_in_group("meadow_trees").size()==4)
	assert(not game._try_chop(tree.global_position))
	marker.position = tree.global_position+Vector2(-60,0)
	for i in range(3):
		assert(game._try_chop(tree.global_position+Vector2(0,-70)))
		while tree._cooldown > 0.0: await physics_frame
	while tree.state=="cutting": await physics_frame
	assert(tree.state=="falling")
	paused = true
	var pose: Transform3D = tree._body.transform
	var elapsed: float = tree._elapsed
	await create_timer(0.3).timeout
	assert(tree._body.transform==pose and tree._elapsed==elapsed)
	paused = false
	await create_timer(6.0).timeout
	assert(tree.state=="fallen" and tree.impact_count==1)
	var pickup := InputEventAction.new()
	pickup.action = &"interact"
	pickup.pressed = true
	assert(tree.log_sprite.visible and is_instance_valid(tree._body))
	marker.global_position=tree.log_sprite.global_position
	game._unhandled_input(pickup)
	await process_frame
	for stick in tree.sticks:
		marker.global_position=stick["sprite"].global_position
		game._unhandled_input(pickup)
		await process_frame
	assert(game.collected["wood"]==5)
	game._unhandled_input(pickup)
	assert(game.collected["wood"]==5)
	game.free()
	await process_frame
	# Leaving/reloading during any transition must clean up its isolated physics space.
	for delay in [0.05,0.55,1.8]:
		var interrupted: Node2D=load("res://scenes/environment/trees/birch.tscn").instantiate()
		root.add_child(interrupted)
		interrupted.hit(Vector2(-100,0),3)
		await create_timer(delay).timeout
		interrupted.free()
		await process_frame
	print("PASS: actual game has four trees; chop range, pause mid-fall, interaction-key wood pickup, no duplicate rewards and cleanup during all transitions.")
	quit()
