extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scenes/world/meadow_restaurant_district.tscn"
	var original := FileAccess.get_sha256(path)
	var scene: Node3D = load(path).instantiate()
	root.add_child(scene)
	var report: Dictionary = preload("res://scripts/world/terrain_transitions.gd").new().apply_district(scene)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	if FileAccess.get_sha256(path) != original:
		push_error("District changed during terrain review; leaving the newer scene untouched.")
		quit(2)
		return
	assert(ResourceSaver.save(packed,path) == OK)
	FileAccess.open("res://output/terrain_transitions/district.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DISTRICT_TRANSITIONS ",JSON.stringify(report))
	quit()
