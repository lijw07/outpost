extends SceneTree

const BASE := "res://assets/models/structures/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "collision")
	var built := 0
	for file in DirAccess.get_files_at(BASE + "gltf/"):
		if not file.ends_with(".gltf"):
			continue
		var name := file.get_basename()
		var model: Node3D = load(BASE + "gltf/" + file).instantiate()
		var mesh_instance := _first_mesh_instance(model)
		if mesh_instance == null:
			print("NO MESH ", name)
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		var shape_path := BASE + "collision/" + name + ".res"
		var error := ResourceSaver.save(shape, shape_path)
		if error != OK:
			print("SHAPE FAILED ", name, " ", error_string(error))
			continue
		built += 1
		print(name, " tris=", mesh_instance.mesh.get_faces().size() / 3, " shape_tris=", shape.get_faces().size() / 3)
		_save_scene(name, model, load(shape_path))
	print("built ", built, " scenes")
	quit()

func _save_scene(name: String, model: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = _pascal_case(name)
	model.name = "Model"
	body.add_child(model)
	model.owner = body
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	var error := ResourceSaver.save(packed, BASE + "scenes/" + name + ".tscn")
	if error != OK:
		print("SCENE FAILED ", name, " ", error_string(error))
	body.free()

func _pascal_case(name: String) -> String:
	var parts := name.split("_")
	var out := ""
	for part in parts:
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found:
			return found
	return null
