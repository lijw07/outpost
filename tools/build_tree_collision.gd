extends SceneTree

const BASE := "res://assets/models/trees/"
const TREES := ["meadow_oak", "meadow_oak_tall", "meadow_oak_broad", "meadow_oak_leaning", "meadow_oak_young"]
const TOP_HEIGHT := 0.5

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "collision")
	for tree in TREES:
		var root := Node3D.new()
		root.name = _pascal_case(tree)
		var stump := _piece(root, tree, "stump", Vector3.ZERO)
		var top := _piece(root, tree, "top", Vector3(0, TOP_HEIGHT, 0))
		print(tree, " stump_tris=", stump, " top_tris=", top)
		var packed := PackedScene.new()
		packed.pack(root)
		var error := ResourceSaver.save(packed, BASE + "scenes/" + tree + ".tscn")
		if error != OK:
			print("SCENE FAILED ", tree, " ", error_string(error))
		root.free()
	quit()

func _piece(root: Node3D, tree: String, piece: String, offset: Vector3) -> int:
	var model: Node3D = load(BASE + "gltf/%s_%s.gltf" % [tree, piece]).instantiate()
	model.name = piece.capitalize()
	model.position = offset
	root.add_child(model)
	model.owner = root
	var mesh_instance := _first_mesh_instance(model)
	var shape := mesh_instance.mesh.create_trimesh_shape()
	var shape_path := BASE + "collision/%s_%s.res" % [tree, piece]
	ResourceSaver.save(shape, shape_path)
	var body := StaticBody3D.new()
	body.name = "Body"
	model.add_child(body)
	body.owner = root
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = load(shape_path)
	body.add_child(collision)
	collision.owner = root
	return shape.get_faces().size() / 3

func _pascal_case(name: String) -> String:
	var out := ""
	for part in name.split("_"):
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
