extends SceneTree
const PACK := "res://assets/environment/meadow/trees/"
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK+"catalog.json"))["species"]
	for species: String in data:
		var info: Dictionary = data[species]
		var tree := Node2D.new()
		tree.name = species.capitalize().replace(" ","")
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.set_script(load("res://scripts/environment/meadow_tree.gd"))
		tree.set("species",species)
		var whole: Texture2D = load(PACK+species+"_standing.png")
		_sprite(tree,"Standing",whole,Vector2(-whole.get_width()/2.0,-whole.get_height()+4),true)
		_sprite(tree,"Stump",load(PACK+species+"_stump.png"),Vector2(info["stump_offset"][0],info["stump_offset"][1]),false)
		var crown: Texture2D = load(PACK+species+"_crown.png")
		_sprite(tree,"Foliage",crown,Vector2(float(info["pivot_x"])+float(info["crown_x"])-crown.get_width()/2.0,float(info["crown_base_y"])-crown.get_height()+4),false)
		_sprite(tree,"Log",load(PACK+species+"_trunk.png"),Vector2(info["pivot_x"],info["trunk_base_y"])+Vector2(info["trunk_offset"][0],info["trunk_offset"][1]),false)
		var effects := Node2D.new()
		effects.name = "Effects"
		effects.z_index = 20
		tree.add_child(effects)
		effects.owner = tree
		var packed := PackedScene.new()
		assert(packed.pack(tree)==OK)
		assert(ResourceSaver.save(packed,"res://scenes/environment/trees/"+species+".tscn")==OK)
		tree.free()
	print("PASS: four saved choppable tree scenes.")
	quit()
func _sprite(tree: Node2D,name: String,texture: Texture2D,origin: Vector2,visible: bool) -> void:
	var art := Sprite2D.new()
	art.name = name
	art.texture = texture
	art.centered = false
	art.offset = origin
	art.visible = visible
	tree.add_child(art)
	art.owner = tree
