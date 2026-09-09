extends SceneTree
const PACK := "res://assets/environment/meadow/"
const CORNERS := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
const SIDES := [TileSet.CELL_NEIGHBOR_TOP_SIDE,TileSet.CELL_NEIGHBOR_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,TileSet.CELL_NEIGHBOR_LEFT_SIDE]

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var tiles: TileSet = load(PACK+"meadow_terrain_tileset.tres")
	assert(tiles.tile_size == Vector2i(64,64))
	assert(tiles.get_source_count() == 3)
	var slices: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"terrain_atlases/slices.json"))
	assert(slices["tiles"].size() == 50)
	var masks := {}
	for entry: Dictionary in slices["tiles"]:
		var atlas: TileSetAtlasSource = tiles.get_source(int(entry["source_id"]))
		var coords := Vector2i(int(entry["atlas_coords"][0]),int(entry["atlas_coords"][1]))
		assert(atlas.has_tile(coords))
		var rect := atlas.get_tile_texture_region(coords)
		assert(rect.size == Vector2i(64,64))
		var original: Texture2D = load("res://"+entry["path"])
		var original_image := original.get_image()
		var sliced_image := atlas.texture.get_image().get_region(rect)
		for y in range(64):
			for x in range(64):
				var a := original_image.get_pixel(x,y)
				var b := sliced_image.get_pixel(x,y)
				assert(a.a == b.a)
				if a.a > 0.0: assert(a == b)
		if entry.has("corners"): masks[int(entry["corners"])] = true
	assert(masks.size() == 16)
	var level: Node2D = load("res://scenes/world/meadow_terrain.tscn").instantiate()
	root.add_child(level)
	var ground: TileMapLayer = level.get_node("Ground")
	assert(ground.get_used_cells().size() == 2560)
	assert(_ground_edges_match(ground))
	var paths: TileMapLayer = level.get_node("Paths")
	assert(paths.get_used_cells().size() > 80)
	for pos: Vector2i in paths.get_used_cells():
		var data := paths.get_cell_tile_data(pos)
		assert(data.terrain_set == 1)
		for i in range(4):
			var neighbor := paths.get_cell_source_id(pos+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]) != -1
			assert((data.get_terrain_peering_bit(SIDES[i]) == 0) == neighbor)
	var paint := TileMapLayer.new()
	paint.tile_set = tiles
	root.add_child(paint)
	var soil: Array[Vector2i] = []
	for y in range(9):
		for x in range(9):
			paint.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
			if x in range(3,6) and y in range(3,6): soil.append(Vector2i(x,y))
	paint.set_cells_terrain_connect(soil,0,1,true)
	assert(_ground_edges_match(paint))
	assert(paint.get_cell_tile_data(Vector2i(4,4)).get_terrain_peering_bit(CORNERS[0]) == 1)
	paint.set_cells_terrain_connect(soil,0,0,true)
	assert(_ground_edges_match(paint))
	assert(paint.get_cell_tile_data(Vector2i(4,4)).get_terrain_peering_bit(CORNERS[0]) == 0)
	var game: Node = load("res://scenes/world/game.tscn").instantiate()
	root.add_child(game)
	assert(game.has_node("MeadowTerrain/Ground"))
	assert(game.has_node("MeadowTerrain/Paths"))
	assert(not game.has_node("MeadowTerrain/Trees"))
	print("PASS: all 50 atlas slices match originals; 2560 saved ground cells; grass/soil painting and repainting; connected paths; actual game scene loads terrain.")
	game.free()
	paint.free()
	level.free()
	quit()

func _ground_edges_match(layer: TileMapLayer) -> bool:
	for pos: Vector2i in layer.get_used_cells():
		var a := layer.get_cell_tile_data(pos)
		var right := layer.get_cell_tile_data(pos+Vector2i.RIGHT)
		var down := layer.get_cell_tile_data(pos+Vector2i.DOWN)
		if right:
			if not (a.get_terrain_peering_bit(CORNERS[1]) == right.get_terrain_peering_bit(CORNERS[0])): return false
			if not (a.get_terrain_peering_bit(CORNERS[3]) == right.get_terrain_peering_bit(CORNERS[2])): return false
		if down:
			if not (a.get_terrain_peering_bit(CORNERS[2]) == down.get_terrain_peering_bit(CORNERS[0])): return false
			if not (a.get_terrain_peering_bit(CORNERS[3]) == down.get_terrain_peering_bit(CORNERS[1])): return false
	return true
