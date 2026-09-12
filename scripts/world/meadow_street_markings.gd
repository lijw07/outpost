extends RefCounted

const Blocks := preload("res://scripts/world/block_library.gd")

static func surface_at(cell: Vector3i, current: String) -> String:
	if not current.begins_with("road_"):
		return current
	if (cell.x in [-8,-2,23,41] and cell.z >= 9 and cell.z <= 12) or (cell.z == 7 and cell.x >= -6 and cell.x <= -4):
		return "road_crossing"
	if (cell.z == 10 and cell.x >= -7 and cell.x <= -3) or (cell.x == -5 and cell.z == 8):
		return "road_asphalt"
	return current

static func apply(grid: GridMap) -> void:
	var library := grid.mesh_library.duplicate() as MeshLibrary
	var ids: Dictionary = {}
	for item in library.get_item_list():
		var name := library.get_item_name(item)
		if not ":" in name:
			ids[Blocks.type_for(name)] = item
	for cell in grid.get_used_cells():
		var current := Blocks.type_for(library.get_item_name(grid.get_cell_item(cell)).split(":")[0])
		var desired := surface_at(cell,current)
		if desired == current:
			continue
		if not ids.has(desired):
			var item := library.get_last_unused_item_id()
			var mesh := Blocks.mesh_for(desired)
			library.create_item(item)
			library.set_item_name(item,desired)
			library.set_item_mesh(item,mesh)
			library.set_item_shapes(item,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
			ids[desired] = item
		grid.set_cell_item(cell,ids[desired],0)
	grid.mesh_library = library
