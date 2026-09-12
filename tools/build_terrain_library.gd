extends SceneTree

const LIBRARY_PATH := "res://assets/models/shared/terrain_library.res"
const MODELS_DIR := "res://assets/models/"
const BLOCK_SIZE := Vector3(2, 2, 2)
const BLOCK_SHAPE_OFFSET := Vector3(0, BLOCK_SIZE.y / 2.0, 0)
const ITEMS: Array[Dictionary] = [
	{"name": "grass_block", "group": "blocks", "solid": true},
	{"name": "grass_flowers_block", "group": "blocks", "solid": true},
	{"name": "dirt_block", "group": "blocks", "solid": true},
	{"name": "sand_block", "group": "blocks", "solid": true},
	{"name": "stone_block", "group": "blocks", "solid": true},
	{"name": "grass_tufts", "group": "plants", "solid": false},
	{"name": "grass_tufts_b", "group": "plants", "solid": false},
	{"name": "flower_patch", "group": "plants", "solid": false},
	{"name": "pebbles", "group": "rocks", "solid": false},
	{"name": "boulder_small", "group": "rocks", "solid": false},
	{"name": "boulder_large", "group": "rocks", "solid": false},
	{"name": "mushroom_toadstool", "group": "mushrooms", "solid": false},
	{"name": "mushroom_cluster", "group": "mushrooms", "solid": false},
	{"name": "stump_brackets", "group": "mushrooms", "solid": false},
	{"name": "rock_mossy", "group": "rocks", "solid": false},
	{"name": "rock_flat", "group": "rocks", "solid": false},
	{"name": "rock_pile", "group": "rocks", "solid": false},
	{"name": "boulder_mossy", "group": "rocks", "solid": false},
	{"name": "bush_round", "group": "plants", "solid": false},
	{"name": "bush_wide", "group": "plants", "solid": false},
	{"name": "bush_berry", "group": "plants", "solid": false},
	{"name": "fern", "group": "plants", "solid": false},
	{"name": "tall_grass", "group": "plants", "solid": false},
	{"name": "reeds", "group": "plants", "solid": false},
	{"name": "flowers_daisy", "group": "plants", "solid": false},
	{"name": "flowers_lavender", "group": "plants", "solid": false},
]

func _initialize() -> void:
	var library := MeshLibrary.new()
	for id in ITEMS.size():
		_add_item(library, id, ITEMS[id])
	var error := ResourceSaver.save(library, LIBRARY_PATH)
	print("terrain library: ", ITEMS.size(), " items -> ", LIBRARY_PATH, " (", error_string(error), ")")
	quit(0 if error == OK else 1)

func _add_item(library: MeshLibrary, id: int, item: Dictionary) -> void:
	var model: Node = load(_scene_path(item)).instantiate()
	var mesh_instance := _first_mesh_instance(model)
	library.create_item(id)
	library.set_item_name(id, item.name)
	library.set_item_mesh(id, mesh_instance.mesh)
	if item.solid:
		library.set_item_shapes(id, [_block_shape(), Transform3D(Basis.IDENTITY, BLOCK_SHAPE_OFFSET)])
	model.free()

func _scene_path(item: Dictionary) -> String:
	return MODELS_DIR + item.group + "/scenes/" + item.name + ".tscn"

func _block_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = BLOCK_SIZE
	return shape

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh_instance(child)
		if found:
			return found
	return null
