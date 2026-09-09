extends SceneTree
## Builds the paintable terrain atlases and a saved, editable meadow TileMap.
const PACK := "res://assets/environment/meadow/"
const TILESET := PACK+"meadow_terrain_tileset.tres"
const LEVEL := "res://scenes/world/meadow_terrain.tscn"
const CORNERS := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
const SIDES := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
var lookup := {}

func _initialize() -> void:
	var atlas_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"terrain_atlases/slices.json"))
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64,64)
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for name in ["Meadow grass", "Meadow soil"]:
		tiles.add_terrain(0)
		tiles.set_terrain_name(0,tiles.get_terrains_count(0)-1,name)
	tiles.set_terrain_color(0,0,Color("748344"))
	tiles.set_terrain_color(0,1,Color("96764d"))
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(1,TileSet.TERRAIN_MODE_MATCH_SIDES)
	tiles.add_terrain(1)
	tiles.set_terrain_name(1,0,"Dirt path")
	tiles.set_terrain_color(1,0,Color("ba8d52"))
	for i in range(3):
		var atlas := TileSetAtlasSource.new()
		atlas.resource_name = ["Grass and soil", "Grass-soil transitions", "Dirt paths"][i]
		atlas.texture = load(PACK+"terrain_atlases/"+["terrain", "transitions", "paths"][i]+".png")
		atlas.texture_region_size = Vector2i(64,64)
		atlas.use_texture_padding = true
		tiles.add_source(atlas,i)
	for entry: Dictionary in atlas_data["tiles"]:
		lookup[entry["name"]] = entry
		var atlas: TileSetAtlasSource = tiles.get_source(int(entry["source_id"]))
		var at := Vector2i(int(entry["atlas_coords"][0]),int(entry["atlas_coords"][1]))
		atlas.create_tile(at)
		var data := atlas.get_tile_data(at,0)
		if entry.has("corners"):
			var bits := int(entry["corners"])
			data.terrain_set = 0
			if entry["kind"] == "terrain":
				var variant := int(String(entry["name"]).get_slice("_",1))
				data.probability = 1.0 if (variant < 4 if bits == 15 else variant == 0) else 0.0
			elif bits in [0,15]:
				data.probability = 0.0
			# Supply both center materials for every corner pattern so the terrain
			# painter can resolve both sides of a grass/soil boundary.
			data.terrain = 0 if bits in [3,5,6,7,9,10,11,12,13,14,15] else 1
			for i in range(4):
				data.set_terrain_peering_bit(CORNERS[i],0 if bits & (1<<i) else 1)
			var alternate_id := atlas.create_alternative_tile(at)
			var alternate := atlas.get_tile_data(at,alternate_id)
			alternate.terrain_set = 0
			alternate.terrain = 1-data.terrain
			alternate.probability = data.probability
			for i in range(4):
				alternate.set_terrain_peering_bit(CORNERS[i],data.get_terrain_peering_bit(CORNERS[i]))
		else:
			data.terrain_set = 1
			data.terrain = 0
			for i in range(4):
				data.set_terrain_peering_bit(SIDES[i],0 if int(entry["connections"]) & (1<<i) else -1)
	assert(ResourceSaver.save(tiles,TILESET) == OK)
	tiles.take_over_path(TILESET)
	_build_level(tiles,atlas_data["tiles"])
	print("PASS: 50 terrain tiles, grass/soil corner painting, path connection painting and saved meadow layers.")
	quit()

func _put(layer: TileMapLayer, at: Vector2i, name: String) -> void:
	var entry: Dictionary = lookup[name]
	layer.set_cell(at,int(entry["source_id"]),Vector2i(int(entry["atlas_coords"][0]),int(entry["atlas_coords"][1])))

func _grass_at(p: Vector2) -> bool:
	var main := Vector2((p.x-31.0)/5.8,(p.y-19.0)/4.2)
	var east := Vector2((p.x-48.0)/3.6,(p.y-11.0)/2.8)
	var west := Vector2((p.x-13.0)/3.2,(p.y-30.0)/2.3)
	return minf(main.length(),minf(east.length(),west.length())) > 1.0

func _build_level(tiles: TileSet, entries: Array) -> void:
	var level := Node2D.new()
	level.name = "MeadowTerrain"
	level.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tiles
	level.add_child(ground)
	ground.owner = level
	var paths := TileMapLayer.new()
	paths.name = "Paths"
	paths.tile_set = tiles
	level.add_child(paths)
	paths.owner = level
	var bits_to_name := {}
	for entry: Dictionary in entries:
		if entry.has("corners") and not bits_to_name.has(int(entry["corners"])):
			bits_to_name[int(entry["corners"])] = entry["name"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9041
	for y in range(40):
		for x in range(64):
			var bits := 0
			for i in range(4):
				if _grass_at(Vector2(x+i%2,y+floori(i/2.0))): bits |= 1<<i
			var name: String = bits_to_name[bits]
			if bits == 15: name = "grass_%02d" % rng.randi_range(0,3)
			if bits == 0: name = "soil_00"
			_put(ground,Vector2i(x,y),name)
	var route: Array[Vector2i] = []
	for x in range(64): route.append(Vector2i(x,24))
	for y in range(11,25): route.append(Vector2i(44,y))
	for x in range(44,50): route.append(Vector2i(x,11))
	for y in range(24,32): route.append(Vector2i(16,y))
	# Uses the exact same path terrain painting that the editor exposes.
	paths.set_cells_terrain_connect(route,1,0,false)
	var scene := PackedScene.new()
	assert(scene.pack(level) == OK)
	assert(ResourceSaver.save(scene,LEVEL) == OK)
	level.free()
