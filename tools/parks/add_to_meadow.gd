extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var district: Node3D=load("res://scenes/world/meadow_restaurant_district.tscn").instantiate()
	root.add_child(district)
	preload("res://scripts/parks/park_district_layout.gd").new().apply(district)
	preload("res://scripts/world/terrain_transitions.gd").new().apply_district(district)
	var packed:=PackedScene.new()
	assert(packed.pack(district)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/meadow_restaurant_district.tscn")==OK)
	print("PARK_INTEGRATED")
	quit()
