extends SceneTree

func _initialize() -> void:
	var blocks := preload("res://scripts/world/block_library.gd").new()
	DirAccess.make_dir_recursive_absolute("res://assets/models/blocks/textures")
	for id in ["grass","grass_flowers","dirt","sand","stone","gravel","sidewalk","road_asphalt","road_lane","road_crossing"]:
		var top: Image = blocks.tile(id)
		var side: Image = blocks.tile(id,true)
		top.save_png(blocks.BASE+"textures/"+id+"_top.png")
		side.save_png(blocks.BASE+"textures/"+id+"_side.png")
		if not blocks.ROWS.has(id):
			var atlas := Image.create(64,32,false,Image.FORMAT_RGBA8)
			atlas.blit_rect(top,Rect2i(0,0,32,32),Vector2i.ZERO)
			atlas.blit_rect(side,Rect2i(0,0,32,32),Vector2i(32,0))
			atlas.save_png(blocks.BASE+"textures/"+blocks.NAMES[id]+".png")
	FileAccess.open("res://output/blocks_correction/mapping.json",FileAccess.WRITE).store_string(JSON.stringify(blocks.NAMES,"\t"))
	print("BLOCK_ATLAS_TEXTURES_READY")
	quit()
