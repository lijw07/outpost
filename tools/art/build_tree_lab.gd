extends SceneTree
func _initialize() -> void:
	var scene := Node2D.new()
	scene.name = "MeadowTreeLab"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.set_script(load("res://scripts/environment/meadow_tree_lab.gd"))
	var terrain: Node2D = load("res://scenes/world/meadow_terrain.tscn").instantiate()
	terrain.position = Vector2(-1024,-600)
	scene.add_child(terrain)
	terrain.owner = scene
	var names := ["oak","birch","young_oak","deadwood"]
	for i in range(4):
		var tree: Node2D = load("res://scenes/environment/trees/"+names[i]+".tscn").instantiate()
		tree.position = Vector2(240+i*480,780)
		tree.scale = Vector2(2,2)
		scene.add_child(tree)
		tree.owner = scene
		var label := Label.new()
		label.text = names[i].replace("_"," ").to_upper()
		label.position = Vector2(160+i*480,860)
		label.add_theme_font_size_override("font_size",28)
		scene.add_child(label)
		label.owner=scene
	var hud := CanvasLayer.new()
	hud.name="HUD"
	scene.add_child(hud)
	hud.owner=scene
	var bg := ColorRect.new()
	bg.size=Vector2(1920,140)
	bg.color=Color("17241fee")
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(bg)
	bg.owner=scene
	for i in range(3):
		var label := Label.new()
		label.name = "Status" if i==2 else "Instructions"+str(i)
		label.text = ["MEADOW / CHOPPABLE TREE TEST","Click a tree three times. Click its left/right side to choose the fall direction. F near wood: collect. R: reset.",""][i]
		label.position=Vector2(24,18+i*40)
		label.add_theme_font_size_override("font_size",24 if i==0 else 20)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hud.add_child(label)
		label.owner=scene
	var packed:=PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/environment/meadow_tree_lab.tscn")==OK)
	scene.free()
	print("PASS: editor-visible tree test scene saved.")
	quit()
