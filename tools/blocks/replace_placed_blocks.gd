extends SceneTree

const Blocks := preload("res://scripts/world/block_library.gd")
const Transitions := preload("res://scripts/world/terrain_transitions.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Array[String] = []
	for name in DirAccess.get_files_at("res://scenes/parks"):
		if name.ends_with(".tscn"):
			paths.append("res://scenes/parks/"+name)
	paths.append("res://scenes/world/meadow_restaurant_district.tscn")
	var records: Array = []
	for path in paths:
		var scene: Node3D = load(path).instantiate()
		root.add_child(scene)
		var grids: Array = []
		for grid in scene.find_children("*","GridMap",true,false):
			if grid.owner != scene:
				continue
			var cells: Dictionary = {}
			var library := MeshLibrary.new()
			var by_type: Dictionary = {}
			for cell in grid.get_used_cells():
				var name: String = grid.mesh_library.get_item_name(grid.get_cell_item(cell)).split(":")[0]
				var type := Blocks.type_for(name)
				assert(Blocks.supports(type),"Unexpected terrain item: "+name)
				cells[cell] = type
				if not by_type.has(type):
					var id := library.get_last_unused_item_id()
					var mesh := Blocks.mesh_for(type)
					library.create_item(id)
					library.set_item_name(id,type)
					library.set_item_mesh(id,mesh)
					library.set_item_shapes(id,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
					by_type[type] = id
			grid.clear()
			grid.mesh_library = library
			for cell in cells:
				grid.set_cell_item(cell,by_type[cells[cell]],0)
			var transitions := Transitions.new()
			var report: Dictionary
			if grid.name == "MeadowBlocks":
				report = transitions.apply_district(scene)
			else:
				report = transitions.apply_grid(grid)
			grids.append({"name":grid.name,"cells":cells.size(),"transitions":report})
		var packed := PackedScene.new()
		assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,path)==OK)
		records.append({"scene":path,"grids":grids})
		scene.free()
	FileAccess.open("res://output/blocks_correction/placed_blocks.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("PLACED_BLOCKS_REPLACED ",JSON.stringify(records))
	quit()
