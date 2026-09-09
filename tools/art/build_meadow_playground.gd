extends SceneTree
## Save the dressing as editor-visible nodes, using only existing meadow art.
const PACK := "res://assets/environment/meadow/"

func _initialize() -> void:
	var terrain: Node2D = load("res://scenes/world/meadow_terrain.tscn").instantiate()
	var ground: TileMapLayer = terrain.get_node("Ground")
	var paths: TileMapLayer = terrain.get_node("Paths")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))
	var assets: Array = manifest["assets"].filter(func(a: Dictionary) -> bool: return a["kind"] in ["grass","props"])
	var dressing := Node2D.new()
	dressing.name = "MeadowDressing"
	dressing.y_sort_enabled = true
	dressing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 90826
	var positions: Array[Vector2] = []
	for i in range(168):
		var asset: Dictionary = assets[i%assets.size()]
		var at := Vector2.ZERO
		var found := false
		for attempt in range(1000):
			at = Vector2(rng.randi_range(1160,2790),rng.randi_range(970,1840))
			var cell := ground.local_to_map(at)
			if paths.get_cell_source_id(cell) != -1: continue
			if at.distance_to(Vector2(1984,1454)) < 65: continue
			var data := ground.get_cell_tile_data(cell)
			if asset.get("reactive",false) and data.terrain != 0: continue
			var spacing := 72.0 if asset["name"] in ["boulder","shrub","shrub_flowering"] else 48.0
			if positions.any(func(other: Vector2) -> bool: return other.distance_to(at)<spacing): continue
			found = true
			break
		assert(found, "No space for meadow prop")
		positions.append(at)
		var art: Node2D
		if asset.get("reactive",false):
			var animated := AnimatedSprite2D.new()
			animated.sprite_frames = load(PACK+"animations/"+asset["name"]+".tres")
			animated.animation = &"wind"
			animated.autoplay = "wind"
			animated.centered = false
			animated.offset = -Vector2(asset["pivot"][0],asset["pivot"][1])
			animated.set_script(load("res://scripts/environment/meadow_plant.gd"))
			animated.add_to_group("meadow_plants",true)
			art = animated
		else:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://"+asset["path"])
			sprite.centered = false
			sprite.offset = -Vector2(asset["pivot"][0],asset["pivot"][1])
			art = sprite
		if asset.has("harvest"):
			if not asset.get("reactive",false): art.set_script(load("res://scripts/environment/meadow_pickable.gd"))
			art.set("picked_texture",load("res://"+asset["harvest"]["picked_path"]))
			art.set("pickup_kind",asset["harvest"]["item"])
		art.name = "%s_%03d"%[asset["name"],i]
		art.position = at
		art.set_meta("asset_name",asset["name"])
		dressing.add_child(art)
		art.owner = dressing
	var marker := Node2D.new()
	marker.name = "WalkMarker"
	marker.position = Vector2(1984,1454)
	marker.add_to_group("players",true)
	dressing.add_child(marker)
	marker.owner = dressing
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(0,-16),Vector2(12,0),Vector2(0,16),Vector2(-12,0)])
	outline.color = Color("182522")
	marker.add_child(outline)
	outline.owner = dressing
	var center := Polygon2D.new()
	center.polygon = PackedVector2Array([Vector2(0,-11),Vector2(8,0),Vector2(0,11),Vector2(-8,0)])
	center.color = Color("ffe9a6")
	marker.add_child(center)
	center.owner = dressing
	var dust := Node2D.new()
	dust.name = "Footsteps"
	dust.set_script(load("res://scripts/environment/meadow_footsteps.gd"))
	dressing.add_child(dust)
	dust.owner = dressing
	var packed := PackedScene.new()
	assert(packed.pack(dressing) == OK)
	assert(ResourceSaver.save(packed,"res://scenes/environment/meadow_dressing.tscn") == OK)
	dressing.free()
	terrain.free()
	print("PASS: saved 168 placed props, including all 17 animated plant types, and a walk marker.")
	quit()
