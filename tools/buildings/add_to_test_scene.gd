extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Control = load("res://scenes/world/test_scene.tscn").instantiate()
	scene.set_script(load("res://scripts/buildings/buildings_test_scene.gd"))
	var world: Node3D = scene.get_node("PixelView/SubViewport/World")
	var sections: Node3D = world.get_node("Sections")
	var picker: OptionButton = scene.get_node("Controls/VBoxContainer/SectionPicker")
	for name in ["Buildings", "BuildingPreviewGround"]:
		var old := world.get_node_or_null(name)
		if old != null:
			assert(old.get_meta("building_gallery_generated", false))
			old.free()
	for marker in sections.get_children():
		if marker.get_meta("building_gallery_generated", false):
			picker.remove_item(marker.get_index())
			marker.free()
	var buildings := Node3D.new()
	buildings.name = "Buildings"
	buildings.set_meta("building_gallery_generated", true)
	world.add_child(buildings)
	buildings.owner = scene
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/buildings/catalog.json"))
	for index in catalog.buildings.size():
		var entry: Dictionary = catalog.buildings[index]
		var origin := Vector3(-220 + (index % 4) * 45, 0, (index / 4) * 45)
		var building: Node3D = load(entry.scene).instantiate()
		building.position = origin
		buildings.add_child(building)
		building.owner = scene
		var marker := Marker3D.new()
		marker.name = entry.id
		marker.position = origin + Vector3(entry.entry[0], 0.72, -3.5)
		marker.set_meta("title", entry.title)
		marker.set_meta("building_gallery_generated", true)
		sections.add_child(marker)
		marker.owner = scene
		picker.add_item(entry.title)
	var ground := StaticBody3D.new()
	ground.name = "BuildingPreviewGround"
	ground.set_meta("building_gallery_generated", true)
	ground.position = Vector3(-145, -0.03, 50)
	world.add_child(ground)
	ground.owner = scene
	var visual := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(220, 220)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#434d38")
	mesh.material = material
	visual.mesh = mesh
	ground.add_child(visual)
	visual.owner = scene
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	ground.add_child(collision)
	collision.owner = scene
	scene.get_node("Controls/VBoxContainer").get_child(0).text = "TEST SCENE\nWASD walk · Shift sprint · F nearest door\nR building interiors · C collisions · Q / E orbit · Wheel zoom"
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/test_scene.tscn") == OK)
	scene.free()
	print("TEST_SCENE_BUILDINGS_ADDED ", catalog.buildings.size())
	quit()
