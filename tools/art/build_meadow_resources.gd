extends SceneTree
const PACK := "res://assets/environment/meadow/"

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))
	var trees_only := "--trees-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(PACK+"animations")
	for asset_name: String in manifest["animations"]:
		if trees_only and not asset_name.ends_with("_crown"):
			continue
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for state: String in manifest["animations"][asset_name]:
			var info: Dictionary = manifest["animations"][asset_name][state]
			frames.add_animation(state)
			frames.set_animation_speed(state, info["fps"])
			frames.set_animation_loop(state, info["loop"])
			var texture: Texture2D = load("res://"+info["path"])
			for i in range(int(info["count"])):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(i*int(info["size"][0]),0,int(info["size"][0]),int(info["size"][1]))
				frames.add_frame(state,atlas)
		ResourceSaver.save(frames,PACK+"animations/"+asset_name+".tres")
	if trees_only:
		for species: String in manifest["trees"]:
			_build_tree(species,manifest["trees"][species])
		print("PASS: four corrected tree SpriteFrames resources and layered scenes rebuilt.")
		quit()
		return
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64,64)
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tiles.add_terrain(0)
	tiles.add_terrain(0)
	tiles.set_terrain_name(0,0,"Meadow grass")
	tiles.set_terrain_name(0,1,"Meadow soil")
	tiles.set_terrain_color(0,0,Color("748344"))
	tiles.set_terrain_color(0,1,Color("96764d"))
	var source_ids := {}
	var bit_names := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
	for entry: Dictionary in manifest["assets"]:
		if not entry["kind"] in ["terrain","transitions","paths"]:
			continue
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load("res://"+entry["path"])
		atlas.texture_region_size = Vector2i(64,64)
		atlas.create_tile(Vector2i.ZERO)
		var source_id := tiles.add_source(atlas)
		source_ids[entry["name"]] = source_id
		if entry.has("corners"):
			var data := atlas.get_tile_data(Vector2i.ZERO,0)
			data.terrain_set = 0
			data.terrain = 0 if int(entry["corners"]) > 0 else 1
			for i in range(4):
				data.set_terrain_peering_bit(bit_names[i],0 if (int(entry["corners"]) & (1<<i)) else 1)
	ResourceSaver.save(tiles,PACK+"meadow_tileset.tres")
	var file := FileAccess.open(PACK+"tile_sources.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(source_ids,"\t"))
	DirAccess.make_dir_recursive_absolute("res://scenes/environment/meadow")
	for species: String in manifest["trees"]:
		_build_tree(species,manifest["trees"][species])
	print("PASS: meadow TileSet, ",manifest["animations"].size()," SpriteFrames resources and four layered tree scenes built.")
	quit()

func _build_tree(species: String, info: Dictionary) -> void:
	var tree := Node2D.new()
	tree.name = species.capitalize().replace(" ","")
	tree.set_script(load("res://scripts/environment/meadow_tree.gd"))
	tree.set("species",species)
	var stump := Sprite2D.new()
	stump.name = "Stump"
	stump.texture = load(PACK+"trees/"+species+"_stump_joined.png")
	stump.centered = false
	stump.offset = Vector2(-stump.texture.get_width()/2.0,-stump.texture.get_height()+4)
	tree.add_child(stump)
	stump.owner = tree
	var pivot := Node2D.new()
	pivot.name = "Pivot"
	pivot.position.y = info["trunk_base_y"]
	tree.add_child(pivot)
	pivot.owner = tree
	var trunk := Sprite2D.new()
	trunk.name = "Trunk"
	trunk.texture = load(PACK+"trees/"+species+"_trunk_joined.png")
	trunk.centered = false
	trunk.offset = Vector2(-trunk.texture.get_width()/2.0,-trunk.texture.get_height()+4)
	pivot.add_child(trunk)
	trunk.owner = tree
	var crown := AnimatedSprite2D.new()
	crown.name = "Crown"
	crown.sprite_frames = load(PACK+"animations/"+species+"_crown.tres")
	crown.animation = &"wind"
	crown.centered = false
	crown.offset = Vector2(-int(info["crown_size"][0])/2.0,-int(info["crown_size"][1])+4)
	crown.position.y = float(info["crown_base_y"])-float(info["trunk_base_y"])
	pivot.add_child(crown)
	crown.owner = tree
	var scene := PackedScene.new()
	scene.pack(tree)
	ResourceSaver.save(scene,"res://scenes/environment/meadow/"+species+".tscn")
	tree.free()
