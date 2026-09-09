extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var game: Node2D = load("res://scenes/environment/meadow_playground.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var types := {}
	var plants := get_nodes_in_group("meadow_plants")
	assert(plants.size()==119)
	for plant: AnimatedSprite2D in plants:
		types[plant.get_meta("asset_name")]=true
		assert(plant.is_playing() and plant.animation==&"wind")
	assert(types.size()==17)
	assert(game.get_node("MeadowTerrain/Ground").get_used_cells().size()==2560)
	var plant: AnimatedSprite2D = plants[0]
	var frame := plant.frame
	await create_timer(0.16).timeout
	assert(plant.frame != frame)
	var marker: Node2D = game.get_node("MeadowDressing/WalkMarker")
	var camera: Camera2D = game.get_node("Camera2D")
	marker.position = plant.position+Vector2(-45,0)
	Input.action_press("move_right")
	await create_timer(0.14).timeout
	Input.action_release("move_right")
	assert(String(plant.animation).begins_with("brush"))
	marker.position = Vector2(1984,1454)
	await create_timer(1.4).timeout
	assert(plant.animation==&"wind")
	var before := marker.position
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	assert(marker.position.x > before.x and camera.position.x==marker.position.x)
	game._pause_game()
	assert(paused)
	before = marker.position
	Input.action_press("move_right")
	await create_timer(0.06).timeout
	Input.action_release("move_right")
	assert(marker.position==before)
	game.get_node("%PauseMenu").resume()
	assert(not paused)
	print("PASS: playground loads terrain and 168 props; 17 plant types animate, movement triggers brush/recovery, camera follows and pause freezes movement.")
	await create_timer(0.6).timeout
	game.free()
	await process_frame
	quit()
