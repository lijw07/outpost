extends SceneTree
func _initialize() -> void:
	call_deferred("_verify")
func _verify() -> void:
	var game: Node2D = load("res://scenes/environment/meadow_playground.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var pickables := get_nodes_in_group("meadow_pickables")
	assert(pickables.size()==42)
	var marker: Node2D = game.get_node("MeadowDressing/WalkMarker")
	var types := {}
	var motion: AnimatedSprite2D = get_nodes_in_group("meadow_plants")[0]
	assert(motion.material is ShaderMaterial)
	var a: float = motion.bend
	await create_timer(1.0/60.0).timeout
	assert(not is_equal_approx(a,motion.bend))
	# Out-of-range interaction awards nothing.
	marker.position = Vector2(80,80)
	game._update_pick_target()
	assert(game._pick_target == null)
	var action := InputEventAction.new()
	action.action = &"interact"
	action.pressed = true
	game._unhandled_input(action)
	assert(game.collected["flowers"]==0 and game.collected["mushrooms"]==0)
	for plant in pickables:
		var name: String = plant.get_meta("asset_name")
		if types.has(name): continue
		types[name]=true
		var old_position: Vector2 = plant.position
		var old_offset: Vector2 = plant.offset
		var old_picked: Texture2D = plant.picked_texture
		marker.position = plant.position
		game._update_pick_target()
		assert(game._pick_target==plant)
		var old_count: int = game.collected[plant.pickup_kind]
		game._unhandled_input(action)
		assert(plant.picked)
		assert(game.collected[plant.pickup_kind]==old_count+1)
		assert(not plant.harvest())
		assert(game.collected[plant.pickup_kind]==old_count+1)
		assert(plant.position==old_position and plant.offset==old_offset)
		if plant is AnimatedSprite2D:
			assert(plant.material.get_shader_parameter("rest_texture")==old_picked)
		else: assert(plant.texture==old_picked)
	assert(types.size()==6)
	assert(game.collected["flowers"]==5 and game.collected["mushrooms"]==1)
	marker.position=Vector2(80,80)
	await create_timer(1.5).timeout
	for plant in pickables:
		if plant is AnimatedSprite2D: assert(plant.animation==&"wind")
	# Normal scene reload resets this art-preview session's harvest state.
	game.free()
	await process_frame
	var fresh: Node2D = load("res://scenes/environment/meadow_playground.tscn").instantiate()
	root.add_child(fresh)
	assert(fresh.collected["flowers"]==0)
	for plant in get_nodes_in_group("meadow_pickables"): assert(not plant.picked)
	fresh.free()
	print("PASS: continuous motion; 42 harvestables / six types; range checks, interaction key, counts, one-shot harvest, unchanged pivots, picked textures and fresh-scene reset.")
	quit()
