extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scenes/world/meadow_restaurant_district.tscn"
	var district: Node3D = load(path).instantiate()
	root.add_child(district)
	var report := preload("res://scripts/world/meadow_streetscape.gd").new().apply(district)
	var scene := PackedScene.new()
	assert(scene.pack(district) == OK)
	assert(ResourceSaver.save(scene,path) == OK)
	FileAccess.open("res://output/streetscape/layout.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEADOW_STREETSCAPE ",JSON.stringify(report))
	quit()
