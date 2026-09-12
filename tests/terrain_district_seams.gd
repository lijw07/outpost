extends SceneTree

const Blocks := preload("res://scripts/world/block_library.gd")
const Transitions := preload("res://scripts/world/terrain_transitions.gd")

func _initialize() -> void:
	call_deferred("_run")

func grid(name: String, at: Vector3, parent: Node3D) -> GridMap:
	var result := GridMap.new()
	result.name = name
	result.position = at
	result.cell_size = Vector3(2,2,2)
	result.cell_center_y = false
	result.mesh_library = MeshLibrary.new()
	var ids := ["road_asphalt","grass","dirt","sidewalk"]
	for i in ids.size():
		var mesh := Blocks.mesh_for(ids[i])
		result.mesh_library.create_item(i)
		result.mesh_library.set_item_name(i,ids[i])
		result.mesh_library.set_item_mesh(i,mesh)
		result.mesh_library.set_item_shapes(i,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
	parent.add_child(result)
	return result

func _run() -> void:
	var district := Node3D.new()
	root.add_child(district)
	var main := grid("MeadowBlocks",Vector3(0,-2,0),district)
	var expansion := grid("ExpansionPaving",Vector3(2,-2,0),district)
	main.set_cell_item(Vector3i.ZERO,0)
	main.set_cell_item(Vector3i(0,0,2),1)
	expansion.set_cell_item(Vector3i.ZERO,3)
	expansion.set_cell_item(Vector3i(0,0,2),2)
	var transitions := Transitions.new()
	transitions.apply_grid(main)
	transitions.apply_grid(expansion)
	var road := main.mesh_library.get_item_name(main.get_cell_item(Vector3i.ZERO))
	var dirt := expansion.mesh_library.get_item_name(expansion.get_cell_item(Vector3i(0,0,2)))
	assert(road == "road_asphalt:,sidewalk,,,,,,", "Missing curb between separately assembled districts: "+road)
	assert(dirt == "dirt:,,,grass,,,,", "Missing grass edge on a translated district path: "+dirt)
	var counts := [main.mesh_library.get_item_list().size(),expansion.mesh_library.get_item_list().size()]
	transitions.apply_grid(main)
	transitions.apply_grid(expansion)
	assert(counts == [main.mesh_library.get_item_list().size(),expansion.mesh_library.get_item_list().size()], "Repeated assembly duplicates seam meshes")
	expansion.position.y = 2
	transitions.apply_grid(main)
	assert(main.mesh_library.get_item_name(main.get_cell_item(Vector3i.ZERO)) == "road_asphalt", "An upper floor incorrectly creates a street curb")
	print("DISTRICT_SEAMS_PASSED curb, grass edge, translated grids, repeated assembly, height separation")
	quit()
